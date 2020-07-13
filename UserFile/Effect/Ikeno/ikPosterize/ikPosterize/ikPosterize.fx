////////////////////////////////////////////////////////////////////////////////////////////////
// posterize

// パラメータ

// パレットファイルの名前
#define	PALLET_FILENAME		"poster.png"
//#define	PALLET_FILENAME		"poster_mono.png"

#define	PALLET_ROW			16	// 1パレット当たりの最大色数
#define	PALLET_COLUMN		16	// パレットの数

// グラデを平らにしたあとで色を決める。
// 0:無効、8～16程度:有効。数値が高いほどグラデは滑らかなままになる。
#define	ENABLE_PRE_FLATTEN	0

// ノイズが減る代わりに詳細がつぶれる。 0:無効、1:有効
#define ENABLE_EDDE_SMOOTH	0

// 明るさの近似度で色を選択する度合。値が低いほど色の近さを優先する。(0.0～2.0程度)
// Si:1のときの値。Si:2なら、BrightnessRate * 2が実際の値になる。
#define	BrightnessRate	1.5


//****************** 設定はここまで

//テクスチャフォーマット
//#define TEXFORMAT "A16B16G16R16F"
#define TEXFORMAT "A8B8G8R8"

float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


////////////////////////////////////////////////////////////////////////////////////////////////

#if !defined(ENABLE_EDDE_SMOOTH)
#define	ENABLE_EDDE_SMOOTH	0
#endif
#if !defined(ENABLE_PRE_FLATTEN)
#define	ENABLE_PRE_FLATTEN	0
#endif
#if ENABLE_PRE_FLATTEN == 1
#undef	ENABLE_PRE_FLATTEN
#define	ENABLE_PRE_FLATTEN	8
#endif


// ぼかし処理の重み係数：
#define MAX_BLUR_NUM	8
float WT[] = {
	0.0920246,
	0.0902024,
	0.0849494,
	0.0768654,
	0.0668236,
	0.0558158,
	0.0447932,
	0.0345379,
};

#define	PI	(3.14159265359)

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = 0.5 / ViewportSize;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "A8B8G8R8";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = POINT;	MagFilter = POINT;
	AddressU  = CLAMP;	AddressV  = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;


#define DECL_TEXTURE( _map, _samp) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		int MipLevels = 1; \
		string Format = TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		MinFilter = POINT;	MagFilter = POINT;	AddressU  = CLAMP;	AddressV  = CLAMP; \
	}; \
	sampler2D _samp##Linear = sampler_state { \
		texture = <_map>; \
		MinFilter = LINEAR;	MagFilter = LINEAR;	AddressU  = CLAMP;	AddressV  = CLAMP; \
	}

DECL_TEXTURE( BlurMap1, BlurSamp1);
DECL_TEXTURE( BlurMap2, BlurSamp2);
#if ENABLE_EDDE_SMOOTH > 0
DECL_TEXTURE( BlurMap3, BlurSamp3);
#endif

texture2D ColorPallet <
	string ResourceName = PALLET_FILENAME;
>;
sampler ColorPalletSmp = sampler_state{
	texture = <ColorPallet>;
	MinFilter = POINT;	MagFilter = POINT; MipFilter = None;
	AddressU  = CLAMP; AddressV = CLAMP;
};

static float PalletV = (floor(AcsX) + 0.5) * (1.0 / PALLET_COLUMN);
static float BrightnessRate2 = BrightnessRate * max(AcsSi, 0) * 0.1;

//-----------------------------------------------------------------------------
const float epsilon = 1.0e-6;

inline float rgb2gray(float3 rgb)
{
	return max(dot(float3(0.299, 0.587, 0.114), rgb), 0);
}

// 色が近いほど大きな値を返す
inline float CalcWeightColor(float4 col1, float4 col2)
{
	float3 dif = abs(col1.rgb - col2.rgb);
	float d = dot(dif, dif);
	return exp(-d * 4.0 - epsilon);
}

// 色が近いほど小さな値を返す
inline float CalcColorDistance(float4 col1, float4 col2)
{
	float3 dif = abs(col1.rgb - col2.rgb);
	float g1 = rgb2gray(col1.rgb);
	float g2 = rgb2gray(col2.rgb);
	float d = dot(dif, dif) + abs(g1-g2) * BrightnessRate2;
//	float d = dot(dif, dif);
//	float d = abs(g1-g2) * BrightnessRate;

	// パレット自体に色の重みを設定する
	// float a = 1 - col2.a;
	// float s = 1 + a * a * 10.0;
	return d;
}


//-----------------------------------------------------------------------------
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
};


VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.TexCoord.xy = ViewportOffset + Tex.xy;
	Out.TexCoord.zw = 2.0 * ViewportOffset;
	return Out;
}


float4 PS_Blur(VS_OUTPUT IN, uniform sampler2D Samp, uniform bool blurX) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 step = IN.TexCoord.zw * (blurX ? float2(1,0) : float2(0,1));

	float4 color0 = tex2D( Samp, uv);

	float weightSum = WT[0];
	float4 color = color0 * weightSum;

	[unroll] for(int i = 1; i < MAX_BLUR_NUM; i++)
	{
		float w = WT[i];
		float4 color1 = tex2D( Samp, step * i + uv);
		float w1 = CalcWeightColor(color1, color0) * w;
		color += color1 * w1;
		weightSum += w1;

		float4 color2 = tex2D( Samp,-step * i + uv);
		float w2 = CalcWeightColor(color2, color0) * w;
		color += color2 * w2;
		weightSum += w2;
	}

	color /= weightSum;

	#if ENABLE_PRE_FLATTEN > 0
	if (!blurX)
	{
		color.rgb = floor(color.rgb * ENABLE_PRE_FLATTEN + 0.5) * (1.0 / ENABLE_PRE_FLATTEN);
	}
	#endif

	return color;
}

#if ENABLE_EDDE_SMOOTH > 0
inline float CalcBlur2Weight(float w) { return w * 0.8 + 0.2; }

float4 PS_Blur2(VS_OUTPUT IN, uniform sampler2D Samp, uniform bool blurX) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 step = IN.TexCoord.zw * (blurX ? float2(1,0) : float2(0,1));

	float4 color0 = tex2D( Samp, uv);
	float weightSum = WT[0] * CalcBlur2Weight(color0.w);
	float4 color = color0 * weightSum;

	[unroll] for(int i = 1; i < MAX_BLUR_NUM; i++)
	{
		float w = WT[i];
		float4 color1 = tex2D( Samp, step * i + uv);
		float w1 = CalcBlur2Weight(color1.w);
		color += color1 * w1;
		weightSum += w1;

		float4 color2 = tex2D( Samp,-step * i + uv);
		float w2 = CalcBlur2Weight(color2.w);
		color += color2 * w2;
		weightSum += w2;
	}

	color = color / max(weightSum, 0.01);
	return color;
}
#endif

//-----------------------------------------------------------------------------
// 

float4 PS_Colorize(VS_OUTPUT IN, uniform sampler2D Samp) : COLOR
{
	float4 col = tex2D(Samp,IN.TexCoord.xy);

	float4 pal = tex2D(ColorPalletSmp, float2(0.5/PALLET_ROW, PalletV));
	float4 result = pal;
	float minDistance = CalcColorDistance(col, pal);

	for(int i = 1; i < PALLET_ROW; i++)
	{
		float4 pal = tex2Dlod(ColorPalletSmp, float4((i+0.5) * (1.0/PALLET_ROW), PalletV, 0, 0));
		float dist = CalcColorDistance(col, pal);
		if (dist < minDistance)
		{
			result = pal;
			minDistance = dist;
		}
	}

	return result;
}





#if ENABLE_EDDE_SMOOTH > 0
//-----------------------------------------------------------------------------
// エッジ検出

inline bool IsEdge(float3 col1, float3 col2)
{
	return (col1.rgb != col2.rgb);
}

inline bool IsEdgeNeighbor(float4 col1, float4 col2)
{
//	return (col1.rgba == col2.rgba);
	return (col1.rgb == col2.rgb && col1.a > 0.0);
}

inline bool IsNotEdge(float4 col1, float4 col2)
{
	return (col1.rgb == col2.rgb && col1.a < 0.5);
}
inline bool IsNotEdge2(float4 col0, float4 col1, float4 col2)
{
	return (col0.rgb == col1.rgb && col1.rgb == col2 && col1.a < 0.5);
}
inline bool IsNotEdge3(float4 col00, float4 col01, float4 col1, float4 col2)
{
	return ((col00.rgb == col1.rgb || col01.rgb == col1.rgb) && col1.rgb == col2 && col1.a < 0.5);
}

float4 PS_EdgeDetect( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR
{
	float2 offset = 1.0 / ViewportSize.xy;
	float3 center = tex2D(Samp, Tex).rgb;

	float3 rgbL = tex2D( Samp, Tex + float2(-1, 0) * offset).rgb;
	float3 rgbR = tex2D( Samp, Tex + float2( 1, 0) * offset).rgb;
	float3 rgbU = tex2D( Samp, Tex + float2( 0,-1) * offset).rgb;
	float3 rgbD = tex2D( Samp, Tex + float2( 0, 1) * offset).rgb;

	float3 rgbL2 = tex2D( Samp, Tex + float2(-2, 0) * offset).rgb;
	float3 rgbR2 = tex2D( Samp, Tex + float2( 2, 0) * offset).rgb;
	float3 rgbU2 = tex2D( Samp, Tex + float2( 0,-2) * offset).rgb;
	float3 rgbD2 = tex2D( Samp, Tex + float2( 0, 2) * offset).rgb;

	float3 rgbLU = tex2D( Samp, Tex + float2(-1,-1) * offset).rgb;
	float3 rgbRU = tex2D( Samp, Tex + float2( 1,-1) * offset).rgb;
	float3 rgbLD = tex2D( Samp, Tex + float2(-1, 1) * offset).rgb;
	float3 rgbRD = tex2D( Samp, Tex + float2( 1, 1) * offset).rgb;

	int edge = 0;
	edge += IsEdge(rgbL, center);
	edge += IsEdge(rgbR, center);
	edge += IsEdge(rgbU, center);
	edge += IsEdge(rgbD, center);

	edge += IsEdge(rgbL2, center);
	edge += IsEdge(rgbR2, center);
	edge += IsEdge(rgbU2, center);
	edge += IsEdge(rgbD2, center);

	edge += IsEdge(rgbLU, center);
	edge += IsEdge(rgbRU, center);
	edge += IsEdge(rgbLD, center);
	edge += IsEdge(rgbRD, center);


	return float4(center, edge > 0);
}

// エッジ範囲の拡大
float4 PS_EdgeDilation( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR
{
	float2 offset = 1.0 / ViewportSize.xy;
	float4 center = tex2D(Samp, Tex);

	float4 rgbL = tex2D( Samp, Tex + float2(-1, 0) * offset);
	float4 rgbR = tex2D( Samp, Tex + float2( 1, 0) * offset);
	float4 rgbU = tex2D( Samp, Tex + float2( 0,-1) * offset);
	float4 rgbD = tex2D( Samp, Tex + float2( 0, 1) * offset);

	float4 rgbLU = tex2D( Samp, Tex + float2(-1,-1) * offset);
	float4 rgbRU = tex2D( Samp, Tex + float2( 1,-1) * offset);
	float4 rgbLD = tex2D( Samp, Tex + float2(-1, 1) * offset);
	float4 rgbRD = tex2D( Samp, Tex + float2( 1, 1) * offset);

	int edge = center.a;
	center.a = 1;
	edge += IsEdgeNeighbor(rgbL, center);
	edge += IsEdgeNeighbor(rgbR, center);
	edge += IsEdgeNeighbor(rgbU, center);
	edge += IsEdgeNeighbor(rgbD, center);

	edge += IsEdgeNeighbor(rgbLU, center);
	edge += IsEdgeNeighbor(rgbRU, center);
	edge += IsEdgeNeighbor(rgbLD, center);
	edge += IsEdgeNeighbor(rgbRD, center);

	return float4(center.rgb, edge > 0.5);
}

// エッジの縮小
float4 PS_EdgeErosion( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR
{
	float2 offset = 1.0 / ViewportSize.xy;
	float4 center = tex2D(Samp, Tex);

	float4 rgbL = tex2D( Samp, Tex + float2(-1, 0) * offset);
	float4 rgbR = tex2D( Samp, Tex + float2( 1, 0) * offset);
	float4 rgbU = tex2D( Samp, Tex + float2( 0,-1) * offset);
	float4 rgbD = tex2D( Samp, Tex + float2( 0, 1) * offset);

	float4 rgbL2 = tex2D( Samp, Tex + float2(-2, 0) * offset);
	float4 rgbR2 = tex2D( Samp, Tex + float2( 2, 0) * offset);
	float4 rgbU2 = tex2D( Samp, Tex + float2( 0,-2) * offset);
	float4 rgbD2 = tex2D( Samp, Tex + float2( 0, 2) * offset);

	float4 rgbLU = tex2D( Samp, Tex + float2(-1,-1) * offset);
	float4 rgbRU = tex2D( Samp, Tex + float2( 1,-1) * offset);
	float4 rgbLD = tex2D( Samp, Tex + float2(-1, 1) * offset);
	float4 rgbRD = tex2D( Samp, Tex + float2( 1, 1) * offset);

	int edge = (center.a < 0.5);
	edge += IsNotEdge(rgbL, center);
	edge += IsNotEdge(rgbR, center);
	edge += IsNotEdge(rgbU, center);
	edge += IsNotEdge(rgbD, center);

	edge += IsNotEdge2(rgbL, rgbL2, center);
	edge += IsNotEdge2(rgbR, rgbR2, center);
	edge += IsNotEdge2(rgbU, rgbU2, center);
	edge += IsNotEdge2(rgbD, rgbD2, center);

	edge += IsNotEdge3(rgbL, rgbU, rgbLU, center);
	edge += IsNotEdge3(rgbR, rgbU, rgbRU, center);
	edge += IsNotEdge3(rgbL, rgbD, rgbLD, center);
	edge += IsNotEdge3(rgbR, rgbD, rgbRD, center);

	return float4(center.rgb, edge < 0.5);
}

// 穴埋め
float4 PS_Padding( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR
{
	float4 col = tex2D(Samp, Tex);
	float4 pal = tex2D(ColorPalletSmp, float2(0.5/PALLET_ROW, PalletV));
	float4 result = pal;
	float minDistance = CalcColorDistance(col, pal);

	for(int i = 1; i < PALLET_ROW; i++)
	{
		float4 pal = tex2Dlod(ColorPalletSmp, float4((i+0.5) * (1.0/PALLET_ROW), PalletV, 0,0));
		float dist = CalcColorDistance(col, pal);
		if (dist < minDistance)
		{
			result = pal;
			minDistance = dist;
		}
	}

	float4 c = tex2D(BlurSamp3, Tex);
	return c.a < 0.5 ? c : result;
}
#endif

//-----------------------------------------------------------------------------
// アンチエイリアス

float4 PS_Antialias( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR
{
	float2 offset = 1.5 / ViewportSize.xy;
	float4 center = tex2D(Samp, Tex);

	// 色の差が大きいところ
	float3 rgbL = tex2D( Samp, Tex + float2(-1, 0) * offset).rgb;
	float3 rgbR = tex2D( Samp, Tex + float2( 1, 0) * offset).rgb;
	float3 rgbU = tex2D( Samp, Tex + float2( 0,-1) * offset).rgb;
	float3 rgbD = tex2D( Samp, Tex + float2( 0, 1) * offset).rgb;

	float lumaC = rgb2gray(center.rgb);
	float lumaL = rgb2gray(rgbL);
	float lumaR = rgb2gray(rgbR);
	float lumaU = rgb2gray(rgbU);
	float lumaD = rgb2gray(rgbD);
	float4 grad = saturate(abs(lumaC - float4(lumaL,lumaR,lumaU,lumaD)));

#if 1
	float4 rcpGrad = 1.0 / clamp(grad * 4.0, 1.0, 4.0);

	float gradX = clamp(grad.x - grad.y, -1, 1);	// xの差が大きい
	float gradY = clamp(grad.z - grad.w, -1, 1);	// yの差が大きい
	float absGradX = saturate(max(grad.x, grad.y) * 4 + 0.1);	// xの差が大きい
	float absGradY = saturate(max(grad.z, grad.w) * 4 + 0.1);	// yの差が大きい

	float2 vl = float2(-1, gradY) * rcpGrad.x * absGradY;
	float2 vr = float2( 1, gradY) * rcpGrad.y * absGradY;
	float2 vu = float2(gradX, -1) * rcpGrad.z * absGradX;
	float2 vd = float2(gradX,  1) * rcpGrad.w * absGradX;

	float3 cl = tex2D(Samp, Tex + vl * offset).rgb;
	float3 cr = tex2D(Samp, Tex + vr * offset).rgb;
	float3 cu = tex2D(Samp, Tex + vu * offset).rgb;
	float3 cd = tex2D(Samp, Tex + vd * offset).rgb;

	float3 col = center.rgb;
	col = (col + cl + cr + cu + cd) * (1.0 / 5.0);

#else
	// 簡易版
	float3 col = (center.rgb * 2 + rgbL + rgbR + rgbU + rgbD) * (1.0 / 6.0);
#endif

	float3 orig = tex2D(ScnSamp, Tex).rgb;
	col = lerp(orig, col, AcsTr);

	return float4(col, 1);
}




////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=BlurMap1;		Pass=BlurPassX;"
		"RenderColorTarget0=BlurMap2;		Pass=BlurPassY;"
		"RenderColorTarget0=BlurMap1;		Pass=ColorPass;"

		#if ENABLE_EDDE_SMOOTH > 0
		"RenderColorTarget0=BlurMap2;		Pass=EdgeDetectPass;"
		"RenderColorTarget0=BlurMap1;		Pass=EdgeDilationPass;"
		"RenderColorTarget0=BlurMap2;		Pass=EdgeErosionPass;"
		#if 1
		"RenderColorTarget0=BlurMap1;		Pass=EdgeErosionPass2;"
		"RenderColorTarget0=BlurMap2;		Pass=EdgeErosionPass;"
		#endif
		"RenderColorTarget0=BlurMap3;		Pass=EdgeErosionPass2;"
		"RenderColorTarget0=BlurMap1;		Pass=BlurPassX2;"
		"RenderColorTarget0=BlurMap2;		Pass=BlurPassY2;"
		"RenderColorTarget0=BlurMap1;		Pass=PaddingPass;"
		#endif

		"RenderDepthStencilTarget=;"
		"RenderColorTarget0=;				Pass=LastPass;"
	;
> {
	pass BlurPassX < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(ScnSamp, true);
	}
	pass BlurPassY < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp1, false);
	}

	pass ColorPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Colorize(BlurSamp2);
	}

	#if ENABLE_EDDE_SMOOTH > 0
	pass EdgeDetectPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeDetect(BlurSamp1);
	}
	pass EdgeDilationPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeDilation(BlurSamp2);
	}
	pass EdgeErosionPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeErosion(BlurSamp1);
	}
	pass EdgeErosionPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeErosion(BlurSamp2);
	}

	pass BlurPassX2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur2(BlurSamp3, true);
	}
	pass BlurPassY2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur2(BlurSamp1, false);
	}

	pass PaddingPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Padding(BlurSamp2);
	}
	#endif

	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Antialias(BlurSamp1Linear);
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
