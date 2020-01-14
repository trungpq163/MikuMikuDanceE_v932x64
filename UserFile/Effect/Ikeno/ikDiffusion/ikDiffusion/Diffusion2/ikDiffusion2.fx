////////////////////////////////////////////////////////////////////////////////////////////////
// ikDiffusion2.fx
////////////////////////////////////////////////////////////////////////////////////////////////

// 色補正用の係数。0.5～5.0くらいにする。2.0が推奨値
// 値が大きいほど明るい部分だけが滲む。
const float FakeGammaScale = 2.0;

// 線形空間で計算をするか？
#define	ENABLE_GAMMA_CORRECT	1

// カメラと水平な面ほど色を乗せる。
#define	ENABLE_NORMAL		1

//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// 高精度テクスチャを使うか？
#define	USE_FLOAT_TEXTURE	0

// テクスチャフォーマット
#if defined(USE_FLOAT_TEXTURE) && USE_FLOAT_TEXTURE > 0
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"
#define WORK_TEXFORMAT "A16B16G16R16F"
#else
#define TEXFORMAT "A8R8G8B8"
#define WORK_TEXFORMAT "A8R8G8B8"
#endif

//****************** 設定はここまで

const float gamma = 2.233333333;
#define	PI	(3.14159265359)
#define Rad2Deg(x)	((x) * 180 / PI)

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// ワーク用テクスチャの設定
#define FILTER_MODE			MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
#define ADDRESSING_MODE		AddressU = CLAMP; AddressV = CLAMP;

float4x4 AcsMat : CONTROLOBJECT < string name = "(self)"; >;
float AcsSi0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float4 hsv2rgb(float3 hsv)
{
	float h = frac(hsv.x) * 6.0;
	float s = hsv.y;
	float v = hsv.z;

	float i = floor(h);
	float j = h - i;
	float m = v * (1.0 - s);
	float n = v * (1.0 - s * j);
	float k = v * (1.0 - s * (1.0 - j));

	float3 result = 0;
	result += float3(v,k,m) * max(1.0 - abs(i - 0), 0);
	result += float3(n,v,m) * max(1.0 - abs(i - 1), 0);
	result += float3(m,v,k) * max(1.0 - abs(i - 2), 0);
	result += float3(m,n,v) * max(1.0 - abs(i - 3), 0);
	result += float3(k,m,v) * max(1.0 - abs(i - 4), 0);
	result += float3(v,m,n) * max(1.0 - abs(i - 5), 0);

	return float4(result, 1);
}

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

float4 AdjustedHueColor(float h)
{
	float4 col = hsv2rgb(float3(h, 1, 1));
	float gray = rgb2gray(col.rgb);
	col.rgb /= gray;
	return col;
}

static float4 HueColor = AdjustedHueColor(AcsMat._41 * 0.1);
static float AcsY = saturate(AcsMat._42 * 0.5);
static float AcsZ = clamp(AcsMat._43 + 1.0, 0.0, 2.0);
static float AcsSi = saturate(AcsSi0 * 0.1 * 0.5);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float2 SampleStep = (float2(1.0,1.0) / ViewportSize.xy);

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	bool AntiAlias = true;
	int MipLevels = 1;
	float2 ViewportRatio = {1,1};
	string Format = TEXFORMAT;
>;

sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	LINEAR_FILTER_MODE	ADDRESSING_MODE
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = true; \
		int MipLevels = 1; \
		float2 ViewportRatio = {1.0/(_size), 1.0/(_size)}; \
		string Format = WORK_TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		LINEAR_FILTER_MODE	ADDRESSING_MODE \
	}; \

DECL_TEXTURE( DownscaleMap1, DownscaleSamp1, 2)
DECL_TEXTURE( DownscaleMap2, DownscaleSamp2, 4)
DECL_TEXTURE( DownscaleMap3, DownscaleSamp3, 8)
DECL_TEXTURE( DownscaleMap4, DownscaleSamp4,16)
DECL_TEXTURE( BlurMap2, BlurSamp2, 4)
DECL_TEXTURE( BlurMap3, BlurSamp3, 8)
DECL_TEXTURE( BlurMap4, BlurSamp4,16)

#if defined(ENABLE_NORMAL) && ENABLE_NORMAL > 0
texture NormalMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikDiffusion";
	float4 ClearColor = { 1.0, 0, 0, 1 };
	float2 ViewportRatio = {1, 1};
	float ClearDepth = 1.0;
	string Format = "D3DFMT_R16F";
	bool AntiAlias = true;
	int MipLevels = 1;
	string DefaultEffect = 
		"self = hide;"
		"* = Normal.fx";
>;

sampler DepthMap = sampler_state {
	texture = <NormalMapRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
};
#endif

static const float BlurWeight[] = {
	0.0920246,
	0.0902024,
	0.0849494,
	0.0768654,
	0.0668236,
	0.0558158,
	0.0447932,
	0.0345379,
};

//-----------------------------------------------------------------------------
// ガンマ補正
float epsilon = 1.0e-4;
#if defined(ENABLE_GAMMA_CORRECT) && ENABLE_GAMMA_CORRECT > 0
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
#else
inline float3 Degamma(float3 col) { return col; }
inline float3 Gamma(float3 col) { return col; }
#endif
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float2 Offset		: TEXCOORD1;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex.xy + ViewportOffset.xy * level;
	Out.Offset = SampleStep * level;

	return Out;
}

//-----------------------------------------------------------------------------
// 低解像度のバッファを作る
float4 PS_DownSampling( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 col = tex2D(smp, IN.TexCoord);
	col.rgb = pow(max(col.rgb, epsilon), (gamma * FakeGammaScale));

	return col;
}

//-----------------------------------------------------------------------------
// ボカす
float4 PS_Blur( VS_OUTPUT IN, uniform float scale, uniform sampler2D smp, uniform bool bBlurX) : COLOR
{
	float2 texCoord = IN.TexCoord;
	float2 offset = (bBlurX) ? float2(IN.Offset.x, 0) : float2(0, IN.Offset.y);
	float4 sum = 0;

	sum = tex2D(smp, texCoord) * BlurWeight[0];
	for(int i = 1; i < 8; i++)
	{
		float3 col = tex2D(smp, texCoord + offset * i).rgb +
					 tex2D(smp, texCoord - offset * i).rgb;
		sum.rgb += col * BlurWeight[i];
	}

	return sum;
}


//-----------------------------------------------------------------------------
// 低解像度マップを高解像度に復元
float4 PS_UpSampling( VS_OUTPUT IN, uniform sampler2D smp, uniform sampler2D smp2, uniform bool bLast) : COLOR
{
	float2 texCoord = IN.TexCoord;
	float2 offset = IN.Offset * 0.5;

	float4 Color0 = tex2D(smp, texCoord);
	float4 Color1 = 
		tex2D(smp2, texCoord + offset * float2(-1,-1)) + 
		tex2D(smp2, texCoord + offset * float2(-1, 1)) + 
		tex2D(smp2, texCoord + offset * float2( 1,-1)) + 
		tex2D(smp2, texCoord + offset * float2( 1, 1));
	Color1 *= 0.25;

	if (!bLast)
	{
		return max(Color0, Color1);
	}
	else
	{
		float4 Color0g = pow(max(Color0, epsilon), (gamma * FakeGammaScale));
		Color1 = lerp(Color0g, Color1, AcsSi);
		Color0 = Degamma4(Color0);

		// ディフュージョンの結果をモノトーンにする
		float gray1 = saturate(rgb2gray(Color1.rgb));
		float3 monoColor = lerp(HueColor.rgb * gray1, 1, gray1);
		Color1.rgb = lerp(Color1.rgb, monoColor, AcsY);
//		return float4(Gamma(Color1.rgb), 1);

		float gray0 = rgb2gray(Color0.rgb);

		// 暗いほど加算する
		// 法線に応じて適用度を変える
		#if defined(ENABLE_NORMAL) && ENABLE_NORMAL > 0
		float n = tex2D(DepthMap, texCoord).r;
		float t = 1.0 - (1.0 - n) * (1.0 - gray0);
		float4 Color = lerp(max(Color0, Color1), Color0, t);
		#else
		float4 Color = Color0;
		#endif

		// ディフュージョン
		float4 Color2 = pow(max(Color, epsilon), 1.3);
		Color1 = Color1 * Color1;
		Color2 = saturate(Color2 + Color1 - saturate(Color2 * Color1));
		Color = lerp(Color, Color2, AcsZ);

		// フラットになりすぎるのでコントラストを戻す
		float grayZ = rgb2gray(Color.rgb);
		float g = lerp(gray0, max(gray0, grayZ), AcsTr);
		Color = Color * (g / max(grayZ, 0.1));

		return float4(Gamma(Color.rgb), 1);
	}
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

		"RenderColorTarget0=DownscaleMap1;"
		"Pass=DownScale;"

		"RenderColorTarget0=BlurMap2;"
		"Pass=BlurPass2X;"
		"RenderColorTarget0=DownscaleMap2;"
		"Pass=BlurPass2Y;"
		"RenderColorTarget0=BlurMap3;"
		"Pass=BlurPass3X;"
		"RenderColorTarget0=DownscaleMap3;"
		"Pass=BlurPass3Y;"
		"RenderColorTarget0=BlurMap4;"
		"Pass=BlurPass4X;"
		"RenderColorTarget0=DownscaleMap4;"
		"Pass=BlurPass4Y;"
		"RenderColorTarget0=BlurMap3;"
		"Pass=UpScale3;"

		"RenderColorTarget0=BlurMap2;"
		"Pass=UpScale2;"
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=UpScale;"
	;
> {
	pass DownScale < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownSampling(ScnSamp);
	}

	pass BlurPass2X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(2, DownscaleSamp1, true);
	}
	pass BlurPass2Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(2, BlurSamp2, false);
	}
	pass BlurPass3X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(4, DownscaleSamp2, true);
	}
	pass BlurPass3Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(4, BlurSamp3, false);
	}
	pass BlurPass4X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(8, DownscaleSamp3, true);
	}
	pass BlurPass4Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(8, BlurSamp4, false);
	}

	pass UpScale3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_UpSampling(DownscaleSamp3, DownscaleSamp4, false);
	}
	pass UpScale2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(DownscaleSamp2, BlurSamp3, false);
	}
	pass UpScale < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_UpSampling(ScnSamp, BlurSamp2, true);
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////

