//===================================================================
// 
//===================================================================

//パラメータ

// 背景の色
#define CANVAS_COLOR	float3(1,1.0,0.95)

// ブラシテクスチャ名
#define	BRUSH_TEXTURE_NAME	"brushs.png"
// ブラシの個数
#define TEX_X_UNIT	4
#define TEX_Y_UNIT	2

// ブラシのサイズ。アクセのSiでも操作可能 
#define	BRUSH_SCALE		(1.0)

// ブラシの最大サイズ
#define MAX_BRUSH_SIZE	(1.5)

// エッジを検出する。エッジ付近だけを残してあとは適当に描画する
#define USE_EDGE_MAP	1

// ブラシ表示数。1～8程度。 (実際にはこの数字x1024個表示される。)
#define UNIT_COUNT		4


//****************** 設定はここまで

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#define PARTICLE_COUNT		1024

int RepeatCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepeatIndex;				// 複製モデルカウンタ


//-------------------------------------------------------------------

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

texture DetailMap: OFFSCREENRENDERTARGET <
	string Description = "Detail Map for ikDryBrush";
	float4 ClearColor = { 0, 1, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "A8B8G8R8";
	string DefaultEffect = 
		"self = hide;"
		"*.pm* = DetailMap_Chara.fx;"
		"* = DetailMap.fx";
>;
sampler2D DetailSamp = sampler_state {
	texture = <DetailMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


#define	PI	(3.14159265359)

// ぼかし処理の重み係数：
float4 BlurWeightArray[] = {
	float4(0.0920246, 0.0902024, 0.0849494, 0.0768654),
	float4(0.0668236, 0.0558158, 0.0447932, 0.0345379)
};
static float BlurWeight[8] = (float[8])BlurWeightArray;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float2 SampStep = 1.0 / ViewportSize.xy;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

//static float AspectRatio = ViewportSize.x / ViewportSize.y;
static int GridY = floor(sqrt( PARTICLE_COUNT * UNIT_COUNT / ViewportAspect));
static int GridX = floor(PARTICLE_COUNT * UNIT_COUNT / GridY);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float4 ClearColorBlack = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "A8B8G8R8";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;


//#define TEX_FORMAT	"A8B8G8R8"
#define TEX_FORMAT	"A16B16G16R16F"
#define GRAD_FORMAT	"A16B16G16R16F"
#define DETAIL_TEX_FORMAT	"A8B8G8R8"

#define DECL_TEXTURE( _map, _samp, _size, _fmt) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		int MipLevels = 1; \
		float2 ViewportRatio = {1.0/(_size), 1.0/(_size)}; \
		string Format = _fmt; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		MinFilter = POINT;	MagFilter = POINT; AddressU  = CLAMP;	AddressV = CLAMP; \
	}; \
	sampler2D _samp##Linear = sampler_state { \
		texture = <_map>; \
		MinFilter = LINEAR;	MagFilter = LINEAR; AddressU  = CLAMP;	AddressV = CLAMP; \
	}; \

DECL_TEXTURE( ColorWorkMap1, ColorWorkSamp1, 2.0, TEX_FORMAT)
DECL_TEXTURE( ColorWorkMap2, ColorWorkSamp2, 2.0, TEX_FORMAT)
DECL_TEXTURE( GradMap1, GradSamp1, 2.0, GRAD_FORMAT)
DECL_TEXTURE( GradMap2, GradSamp2, 2.0, GRAD_FORMAT)

DECL_TEXTURE( DetailMap1, DetailSamp1, 2.0, DETAIL_TEX_FORMAT)
DECL_TEXTURE( DetailMap2, DetailSamp2, 2.0, DETAIL_TEX_FORMAT)

DECL_TEXTURE( ErrorMap, ErrorSamp, 4.0, GRAD_FORMAT)

texture2D InfoMap : RENDERCOLORTARGET <
	bool AntiAlias = false;
	int MipLevels = 1;
	int2 Dimensions = {PARTICLE_COUNT, UNIT_COUNT};
	string Format ="A16B16G16R16F";
>;
sampler2D InfoSamp = sampler_state {
	texture = <InfoMap>;
	MinFilter = POINT;	MagFilter = POINT; AddressU  = CLAMP;	AddressV = CLAMP;
};
texture2D InfoDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {PARTICLE_COUNT, UNIT_COUNT};
	string Format = "D24S8";
>;

texture2D BrushTex <
	string ResourceName = BRUSH_TEXTURE_NAME;
	int MipLevels = 1;
>;
sampler BrushSamp = sampler_state {
	texture = <BrushTex>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV  = CLAMP;
};


// ガンマ補正
const float gamma = 2.2333; // 2.2が一般的な値
const float epsilon = 1.0e-6;

float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

// YUV変換
// YUVは負値になることがあるので、正規化するかfloatで保存する。
static float3x3 matToYUV = {
	 0.2126,	-0.09991,	 0.615,
	 0.7152,	-0.33609,	-0.55861,
	 0.0722,	 0.436,		-0.05639
};

static float3x3 matToRGB = {
	 1.0,		 1.0,		 1.0,
	 0.0,		-0.21482,	 2.12798,
	 1.28033,	-0.38059,	 0.0
};

float3 rgb2yuv(float3 rgb) { return mul(rgb, matToYUV);}
float3 yuv2rgb(float3 yuv) { return mul(yuv, matToRGB);}
float yuv2gray(float3 yuv) { return yuv.x; }

float4 GetColor(float4 uv)
{
	float4 Color = 1;
//	Color.rgb = tex2Dlod(ScnSamp, uv);
	Color.rgb = tex2Dlod(ColorWorkSamp2, uv).rgb;
	return Color;
}

// 色の差が大きいほど、返り値は大きくなる
float CalcWeight(float3 c0, float3 c1)
{
//	return dot(float3(0.5,0.25,0.25), abs(c0 - c1));
	return dot(1/3.0, abs(c0 - c1));
}

float CalcWeight(float4 c0, float4 c1)
{
	return CalcWeight(c0.rgb, c1.rgb);
}

//-----------------------------------------------------------------------------
// 

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform int level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;

	float2 invScreenSize = 1.0 / floor(ViewportSize / level);
	Out.TexCoord.xy = Tex + 0.5 * invScreenSize;
	Out.TexCoord.zw = invScreenSize;
	return Out;
}

VS_OUTPUT VS_Blur( float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool bBlurX, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;

	float2 invScreenSize = 1.0 / floor(ViewportSize / level);
	Out.TexCoord.xy = Tex + 0.5 * invScreenSize;
	float2 offset = invScreenSize;
	Out.TexCoord.zw = (bBlurX) ? float2(offset.x, 0) : float2(0, offset.y);

	return Out;
}

VS_OUTPUT VS_Info( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 invScreenSize = 1.0 / float2(PARTICLE_COUNT, UNIT_COUNT);
	Out.TexCoord.xy = Tex + 0.5 * invScreenSize;
	Out.TexCoord.zw = invScreenSize;
	return Out;
}

// 重み付きダウンスケール + yuv化
float4 PS_Downscale( float4 TexCoord: TEXCOORD0, uniform sampler2D smp, uniform float weightScale) : COLOR
{
	float2 texCoord = TexCoord.xy;
	float2 offset = TexCoord.zw * 0.25;

	#define GetPixel(u,v)	float4(rgb2yuv(tex2D(smp, texCoord + float2(u,v) * offset).rgb), 1)
	float4 col0 = GetPixel(-1,-1);
	float4 col1 = GetPixel( 1,-1);
	float4 col2 = GetPixel(-1, 1);
	float4 col3 = GetPixel( 1, 1);

	col0.w = 4 - (1 + CalcWeight(col0, col1) + CalcWeight(col0, col2) + CalcWeight(col0, col3));
	col1.w = 4 - (1 + CalcWeight(col1, col0) + CalcWeight(col1, col2) + CalcWeight(col1, col3));
	col2.w = 4 - (1 + CalcWeight(col2, col0) + CalcWeight(col2, col1) + CalcWeight(col2, col3));
	col3.w = 4 - (1 + CalcWeight(col3, col0) + CalcWeight(col3, col1) + CalcWeight(col3, col2));

	float4 col = (col0.w > col1.w) ? col0 : col1;
	col = (col.w > col2.w) ? col : col2;
	col = (col.w > col3.w) ? col : col3;

	return float4(col.rgb, 1);
}

float4 PS_SmartBlur( float4 TexCoord: TEXCOORD0, uniform sampler2D smp, uniform bool bQuantize) : COLOR
{
	float2 texCoord = TexCoord.xy;
	float2 offset = TexCoord.zw;

	float4 Color0 = tex2D( smp, texCoord );
	Color0.w = 1;
	float4 Color = Color0 * BlurWeight[0];

	[unroll] for(int i = 1; i < 8; i++)
	{
		float4 uv = offset.xyxy * float4(i,i, -i,-i) + texCoord.xyxy;
		float4 cp = tex2D(smp, uv.xy);
		float4 cn = tex2D(smp, uv.zw);

		float ColorSigma2 = 0.07;
		float invColorSigma2 = -1.0 / (2.0 * ColorSigma2 * ColorSigma2);
		float wp = CalcWeight(Color0, cp);
		float wn = CalcWeight(Color0, cn);
		Color += float4(cp.rgb, 1) * exp(wp*wp*invColorSigma2) * BlurWeight[i];
		Color += float4(cn.rgb, 1) * exp(wn*wn*invColorSigma2) * BlurWeight[i];
	}

	Color.rgb = Color.rgb / Color.w;
	return Color;
}

// calc EigenVector from ST
float2 CalcEigenVector(float2 uv)
{
	float4 grad = tex2D(GradSamp1, uv);
	float t11 = grad.x;
	float t22 = grad.y;
	float t12 = grad.z;

	float d0 = (t11 - t22) * (t11 - t22) + 4.0 * t12 * t12;
	float d = sqrt(max(d0, 1e-6)) * 0.5;
	float lambda1 = (t11 + t22) * 0.5 + d;
//	float lambda2 = (t11 + t22) * 0.5 - d;
	float2 ev1 = float2(t12, t11 - lambda1);
//	float2 ev2 = float2(t12, t11 - lambda2);

	// 乱数はNaN対策
	float sinz, cosz;
	sincos(uv.x * ViewportSize.x * 71.1 + uv.y * ViewportSize.y * 123.1, sinz, cosz);
	float2 ev = normalize(ev1 + float2(cosz, sinz) * 1e-4);

	return ev;
}

// 傾きデータの生成
float4 PS_MakeST(VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	#undef GetPixel
	#define GetPixel(u,v)	rgb2gray(tex2D( smp, uv + float2(u,v) * offset).rgb)

	float c1 = GetPixel( 1, 1);
	float c2 = GetPixel( 0, 1);
	float c3 = GetPixel(-1, 1);
	float c4 = GetPixel( 1, 0);
//	float c5 = GetPixel( 0, 0);
	float c6 = GetPixel(-1, 0);
	float c7 = GetPixel( 1,-1);
	float c8 = GetPixel( 0,-1);
	float c9 = GetPixel(-1,-1);

	float dx = (c1 + c4 + c7) - (c3 + c6 + c9);
	float dy = (c1 + c2 + c3) - (c7 + c8 + c9);

	float s = 16.0 / 3.0; // 適当にスケーリング
	dx *= s;
	dy *= s;

	float dxx = dx * dx;
	float dxy = dx * dy;
	float dyy = dy * dy;
	float weight = saturate(sqrt(dxx+dyy));

	return float4(dxx, dyy, dxy, weight);
}

// 傾きデータのブラー
float4 PS_STBlur( float4 TexCoord: TEXCOORD0, uniform sampler2D smp) : COLOR
{
	float2 texCoord = TexCoord.xy;
	float2 offset = TexCoord.zw;
	float4 Color0 = tex2D( smp, texCoord );
	float4 Color = float4(Color0.xyz, 1) * BlurWeight[0];

	[unroll] for(int i = 1; i < 8; i++)
	{
		float4 uv = offset.xyxy * float4(i,i, -i,-i) + texCoord.xyxy;
		float4 cp = tex2D(smp, uv.xy);
		float4 cn = tex2D(smp, uv.zw);
		Color += float4(cp.xyz, 1) * cp.w * BlurWeight[i];
		Color += float4(cn.xyz, 1) * cn.w * BlurWeight[i];
	}

	Color.xyz /= Color.w;
	Color.w = saturate(sqrt(Color.x + Color.y));
	return Color;
}

#if USE_EDGE_MAP > 0
// エッジをチェック
float4 PS_EdgeMap( float4 TexCoord: TEXCOORD0) : COLOR
{
	float2 uv = TexCoord.xy;
	float2 offset = TexCoord.zw;

	float4 c5 = tex2D(GradSamp1, uv + float2( 0, 0) * offset);
	float edge = saturate(c5.w);
		// float2 CalcEigenVector(float2 uv) で傾きの方向を調べ、似た傾向なら重みを減らす?

	float2 result = tex2D( DetailSamp, uv).xy;

	return float4(result, edge, 1);
}
#endif

float4 PS_DetailBlur( float4 TexCoord: TEXCOORD0, uniform sampler2D smp, uniform bool bLast) : COLOR
{
	float2 texCoord = TexCoord.xy;
	float2 offset = TexCoord.zw;
	float3 Color = tex2D( smp, texCoord ).xyz * BlurWeight[0];

	[unroll] for(int i = 1; i < 8; i++)
	{
		float4 uv = offset.xyxy * float4(i,i, -i,-i) + texCoord.xyxy;
		float3 cp = tex2D(smp, uv.xy).xyz;
		float3 cn = tex2D(smp, uv.zw).xyz;
		Color += (cp + cn) * BlurWeight[i];
	}

	if (bLast)
	{
		float2 lod = tex2D( DetailSamp, texCoord);
		Color.x = max(Color.x, lod.x);

		#if USE_EDGE_MAP > 0
		float v = (Color.z < 0.2) ? 0.5 : (max(Color.z - 0.5, 0) * 2.0 + 1.0);
		Color.x = saturate(v * (Color.x + 1.0/255.0));
		#endif

		Color.y = lod.y;
	}

	return float4(Color.xyz, 0);
}


//-------------------------------------------------------------------
// パーティクル情報を生成

float2 GetParticleLocation(int2 iuv)
{
	int index = iuv.x * UNIT_COUNT + iuv.y;
	float iy = index % GridY;
	float ix = floor(index / GridY);
	// シャッフル
	float iw2 = floor(GridX / 2);
	float ih2 = floor(GridY / 2);
	ix = (ix % iw2) * 2 - (ix > iw2);
	iy = (iy % ih2) * 2 + (iy > ih2);
	float posx = (ix + 0.5) * (1.0 / (GridX - 2));
	float posy = 1.0 - (iy - 0.5) * (1.0 / (GridY - 2));
	// 乱数
	posx += sin(index * 71.1) * (1.0 / GridX) / 8.0;
	posy += sin(index * 3.1415 * 1.61) * (1.0 / GridY) / 8.0;

	return float2(posx, posy);
}

float4 PS_SetupParticle(VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	int2 iuv = floor(uv * float2(PARTICLE_COUNT, UNIT_COUNT));
	uv = GetParticleLocation(iuv);
	return float4(uv, CalcEigenVector(uv));
}

float4 PS_SetupParticle2(VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	int2 iuv = floor(IN.TexCoord.xy * float2(PARTICLE_COUNT, UNIT_COUNT));

	uv = GetParticleLocation(iuv);
	float3 lum = float3(uv, 0.0);
	float2 offset = 1.0 / float2(GridX, GridY) / 4.0;
	for(int vy = 0; vy <= 5; vy++) {
		for(int vx = 0; vx <= 5; vx++) {
			float2 uv0 = uv + float2(vx-2,vy-2) * offset;
			float3 lum0 = tex2Dlod(ErrorSamp, float4(uv0, 0,0)).xyz;
			lum = (lum0.z > lum.z) ? lum0 : lum;
		}
	}

	uv = lum.xy;

	float4 errorResult = float4(0,0,-2,-2);
	float4 result = float4(uv, CalcEigenVector(uv));

	// エラーが小さすぎるなら描画対象外
	result = (lum.z < 0.1) ? errorResult : float4(uv, CalcEigenVector(uv));

	return result;
}


//-------------------------------------------------------------------
//
float4 PS_DrawScene(VS_OUTPUT IN) : COLOR
{
	return float4(rgb2yuv(CANVAS_COLOR),1);
}

float4 PS_CheckError(VS_OUTPUT IN, uniform float sensitivity) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw * 0.5;
	float ColorSigma = 0.1;

	float3 repair = tex2D(ColorWorkSamp2Linear, uv).rgb;

	// 周囲で一番エラー値の高い場所をメモする
	float3 lum = float3(uv, 0.0);
	for(int vy = 0; vy <= 5; vy++) {
		for(int vx = 0; vx <= 5; vx++) {
			float2 uv0 = uv + float2(vx-2,vy-2) * offset;
			float2 lod = tex2Dlod( DetailSamp1, float4(uv0,0,0));
			float3 col = tex2Dlod( ColorWorkSamp1, float4(uv0,0,0));
			float w = 1.0 - exp(-CalcWeight(col, repair) / (2.0 *ColorSigma * ColorSigma));
			w *= lerp(lod.x, 1, sensitivity);
			if (w > lum.z)
			{
				lum = float3(uv0, w);
			}
		}
	}

	return float4(lum, 1);
}



float4 PS_CheckError3(VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw * 0.5;
	float ColorSigma = 0.1;

	float3 repair = tex2D(ColorWorkSamp2Linear, uv).rgb;

	float2 lod = tex2D( DetailSamp1, uv);
	float3 col = tex2D(ColorWorkSamp1, uv);
	float w = 1.0 - exp(-CalcWeight(col, repair) / (2.0 * ColorSigma * ColorSigma));
	w *= lod.x;

	return float4(saturate(w), 0,0,1);
}

// 修復用の色を計算
float4 PS_Repair(VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float sigma = 1.0 / (2.0 * 3.0);

	offset *= CalcEigenVector(uv).yx;
	float3 base = tex2D( ScnSamp, uv).rgb;
	float4 sum = float4(base, 1);

	for(int i = 0; i < 8; i++)
	{
		float3 col0 = tex2D( ScnSamp, uv + i * offset).rgb;
		float w = exp(-dot(abs(col0 - base), 1) * sigma);
		sum += float4(col0, 1) * (w * (w >= 0.1));

		col0 = tex2D( ScnSamp, uv - i * offset).rgb;
		w = exp(-dot(abs(col0 - base), 1) * sigma);
		sum += float4(col0, 1) * (w * (w >= 0.1));
	}

	float3 repair = rgb2yuv(sum.rgb / sum.w);
	repair.x = floor(repair * 8.0 + 0.5) / 8.0; // 量子化
	repair = yuv2rgb(repair);

	float err = tex2D(ErrorSampLinear, uv).x;
	return float4(repair, err);
}



//-------------------------------------------------------------------
// ブラシ描画

struct VS_OUTPUT2
{
	float4 Pos		: POSITION;	// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 Color	: COLOR0;		// 粒子の乗算色
};

VS_OUTPUT2 VS_Brush(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform float size)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepeatIndex;
	int j = round( Pos.z * 100.0f );
	int index = i * PARTICLE_COUNT + j;

	float4 grad = tex2Dlod(InfoSamp, float4((j+0.5)/PARTICLE_COUNT,(i+0.5)/UNIT_COUNT,0,0));
	float4 TexPos = float4(grad.xy,0,0);
	float2 Pos0 = TexPos.xy;
	Pos0.y = 1 - Pos0.y;

	float scale = min(size * (AcsSi * 0.1) * BRUSH_SCALE, MAX_BRUSH_SIZE);
	Pos.xy *= scale * float2(0.5, 1.0);
	float3x3 matWTmp = { grad.z,grad.w,0, -grad.w,grad.z,0,  0,0,1};
	Pos.xy = mul( Pos.xy, (float2x2)matWTmp );
	if (ViewportAspect >= 1.0)
	{
	Pos.y *= ViewportAspect;
	}
	else
	{
		Pos.x *= (1.0 / ViewportAspect);
	}

	Pos.xy += (Pos0.xy * 2.0 - 1.0);
	Pos.zw = 1;
	Out.Pos = Pos;

	// テクスチャ
	int tindex = floor(abs(sin(index) * 1024)) % (TEX_X_UNIT * TEX_Y_UNIT);
	int tex_i = tindex % TEX_X_UNIT;
	int tex_j = tindex / TEX_X_UNIT;
	float2 texScale = float2(1.0 / TEX_X_UNIT, 1.0 / TEX_Y_UNIT);
	Out.Tex = float2(Tex.x + tex_i, Tex.y + tex_j) * texScale;

	#if 1
	// グラデあり
	float4 coluv0 = TexPos;
	float4 coluv1 = TexPos;
	coluv0.xy -= (grad.wz * scale * 0.025); // = 0.5*0.5*0.1
	coluv1.xy += (grad.wz * scale * 0.025);
	float4 col0 = GetColor(coluv0);
	float4 col1 = GetColor(coluv1);
	float4 col = (Tex.y < 0.5) ? col0 : col1;
	col = (CalcWeight(col0, col1) > 0.1) ? col : ((col0 + col1) * 0.5);
	#else
	// 単色
	float4 col = GetColor(TexPos);
	#endif
	Out.Color = col;
	// Out.Color = float4(0,0,1,1);

	return Out;
}

float4 PS_Brush( VS_OUTPUT2 IN) : COLOR0
{
	float4 Color = IN.Color;
	float alpha = tex2D( BrushSamp, IN.Tex ).r;
	Color.a *= alpha;
	clip(Color.a - 1.0/255.0);
	return Color;
}


//-------------------------------------------------------------------
//
float4 PS_Last(VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float3 base = tex2D( ScnSamp, uv).rgb;
	float4 colyuv = tex2D(ColorWorkSamp1Linear, uv);

	// upscale
	#if 1
	#undef GetPixel
	#define GetPixel(u,v)	float4((colyuv * 3.0 + (tex2D(ColorWorkSamp1Linear, uv + float2(u,v) * offset * 2.0).rgb)) * 0.25, 1)
	float4 col0 = GetPixel(-1, 0);
	float4 col1 = GetPixel( 1, 0);
	float4 col2 = GetPixel( 0,-1);
	float4 col3 = GetPixel( 0, 1);
	float3 baseyuv = rgb2yuv(base);
	col0.w = CalcWeight(col0.rgb, baseyuv);
	col1.w = CalcWeight(col1.rgb, baseyuv);
	col2.w = CalcWeight(col2.rgb, baseyuv);
	col3.w = CalcWeight(col3.rgb, baseyuv);
	colyuv = (col0.w < col1.w) ? col0 : col1;
	colyuv = (colyuv.w < col2.w) ? colyuv : col2;
	colyuv = (colyuv.w < col3.w) ? colyuv : col3;
	#endif

	float4 repair = tex2D(ColorWorkSamp2Linear, uv);
	float err = repair.w;
	float2 lod = tex2D( DetailSamp, uv);
	float3 col = yuv2rgb(colyuv.rgb);

	col = lerp(col, base, err * err * 0.5);
	col = lerp(col, repair.rgb, lod.x*lod.x * 0.25);
	col = lerp(base, col, lod.y * AcsTr);

	return float4(col, 1);
}


//-------------------------------------------------------------------
technique OilPaint <
	string Script = 
		//----------------------------------------------------------------
		// オリジナル画像の作成
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		// 色の準備
		"RenderColorTarget0=ColorWorkMap1;	Pass=DownscalePass;"
		"RenderColorTarget0=GradMap1;		Pass=SmartBlurXPass;"
		"RenderColorTarget0=ColorWorkMap2;	Pass=SmartBlurYPass;"

		// StructureTensorによる勾配の計算
		"RenderColorTarget0=GradMap1;		Pass=MakeSTPass;"
		// EdgeMap
		#if USE_EDGE_MAP > 0
		"RenderColorTarget0=DetailMap1;	Pass=EdgeMapPass;"
		#endif
		"RenderColorTarget0=DetailMap2;	Pass=DetailBlurXPass;"
		"RenderColorTarget0=DetailMap1;	Pass=DetailBlurYPass;"
		// STの平滑化
		"RenderColorTarget0=GradMap2;		Pass=STBlurXPass;"
		"RenderColorTarget0=GradMap1;		Pass=STBlurYPass;"

		// ブラシ(粗)
		"RenderDepthStencilTarget=InfoDepthBuffer;"
		"RenderColorTarget0=InfoMap;		Pass=SetupParticlePass;"

		"RenderDepthStencilTarget=DepthBuffer; Clear=Depth;"
		"RenderColorTarget0=ColorWorkMap1;	Pass=DrawScenePass;"
		"LoopByCount=RepeatCount;"
		"LoopGetIndex=RepeatIndex;"
			"Pass=DrawObject;"
		"LoopEnd=;"

		// ブラシ(中)
		"RenderColorTarget0=ErrorMap;		Pass=CheckErrorPass1;"
		"RenderDepthStencilTarget=InfoDepthBuffer;"
		"RenderColorTarget0=InfoMap;		Pass=SetupParticlePass2;"

		"RenderDepthStencilTarget=DepthBuffer; Clear=Depth;"
		"RenderColorTarget0=ColorWorkMap1;"
		"LoopByCount=RepeatCount;"
		"LoopGetIndex=RepeatIndex;"
			"Pass=DrawObject2;"
		"LoopEnd=;"

		// ブラシ(細)
		"RenderColorTarget0=ErrorMap;		Pass=CheckErrorPass2;"
		"RenderDepthStencilTarget=InfoDepthBuffer;"
		"RenderColorTarget0=InfoMap;		Pass=SetupParticlePass2;"

		"RenderDepthStencilTarget=DepthBuffer; Clear=Depth;"
		"RenderColorTarget0=ColorWorkMap1;"
		"LoopByCount=RepeatCount;"
		"LoopGetIndex=RepeatIndex;"
			"Pass=DrawObject3;"
		"LoopEnd=;"

		// 補正用の色を計算
		"RenderColorTarget0=ErrorMap;		Pass=CheckErrorPass3;"
		"RenderColorTarget0=ColorWorkMap2;	Pass=RepairPass;"

		// 最終合成
		"RenderDepthStencilTarget=;"
		"RenderColorTarget0=;				Pass=LastPass;"
	;
> {

	//----------------------------------------------------------------
	// 
	pass DownscalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(2.0);
		PixelShader  = compile ps_3_0 PS_Downscale(ScnSamp, 1.0);
	}

	pass DetailBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(true, 2.0);
		#if USE_EDGE_MAP > 0
		PixelShader  = compile ps_3_0 PS_DetailBlur(DetailSamp1, false);
		#else
		PixelShader  = compile ps_3_0 PS_DetailBlur(DetailSamp, false);
		#endif
	}
	pass DetailBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(false, 2.0);
		PixelShader  = compile ps_3_0 PS_DetailBlur(DetailSamp2, true);
	}

	pass MakeSTPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(2.0);
		PixelShader  = compile ps_3_0 PS_MakeST(ColorWorkSamp1);
	}
	pass STBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(true, 2.0);
		PixelShader  = compile ps_3_0 PS_STBlur(GradSamp1);
	}
	pass STBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(false, 2.0);
		PixelShader  = compile ps_3_0 PS_STBlur(GradSamp2);
	}

	#if USE_EDGE_MAP > 0
	pass EdgeMapPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(2.0);
		PixelShader  = compile ps_3_0 PS_EdgeMap();
	}
	#endif

	//----------------------------------------------------------------
	pass SmartBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(true, 2.0);
		PixelShader  = compile ps_3_0 PS_SmartBlur(ColorWorkSamp1, false);
	}
	pass SmartBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(false, 2.0);
		PixelShader  = compile ps_3_0 PS_SmartBlur(GradSamp1, true);
	}

	//----------------------------------------------------------------
	// 

	pass SetupParticlePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Info();
		PixelShader  = compile ps_3_0 PS_SetupParticle();
	}
	pass SetupParticlePass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Info();
		PixelShader  = compile ps_3_0 PS_SetupParticle2();
	}

	//----------------------------------------------------------------
	// 
	pass DrawScenePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(2.0);
		PixelShader  = compile ps_3_0 PS_DrawScene();
	}

	pass DrawObject {
		ZEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Brush(1.0);
		PixelShader  = compile ps_3_0 PS_Brush();
	}
	pass DrawObject2 {
		ZEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Brush(0.5);
		PixelShader  = compile ps_3_0 PS_Brush();
	}
	pass DrawObject3 {
		ZEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Brush(0.25);
		PixelShader  = compile ps_3_0 PS_Brush();
	}

	pass CheckErrorPass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(4.0);
		PixelShader  = compile ps_3_0 PS_CheckError(0.15);
	}
	pass CheckErrorPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(4.0);
		PixelShader  = compile ps_3_0 PS_CheckError(0.1);
	}
	pass CheckErrorPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(4.0);
		PixelShader  = compile ps_3_0 PS_CheckError3();
	}
	pass RepairPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(2.0);
		PixelShader  = compile ps_3_0 PS_Repair();
	}

	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common(1.0);
		PixelShader  = compile ps_3_0 PS_Last();
	}
}
//===================================================================
