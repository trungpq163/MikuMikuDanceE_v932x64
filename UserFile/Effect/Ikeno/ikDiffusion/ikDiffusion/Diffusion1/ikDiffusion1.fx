////////////////////////////////////////////////////////////////////////////////////////////////
// ikDiffusion1.fx
////////////////////////////////////////////////////////////////////////////////////////////////

// オリジナル通りの計算式で階調計算を行うか? 0:まじめに計算、1:オリジナル
// オリジナルのほうがコントラストが高くなる。
#define	USE_ORIGINAL_METHOD		1

// 線形空間で計算をするか？ 0:しない、1:する
#define	ENABLE_GAMMA_CORRECT	1

// ボカし部分に色ズレを作るか? 0:しない、1:する
#define ENABLE_COLOR_SHIFT		1


//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// 色ズレの計算精度。大きいほど正確で遅い。8～16程度。
const int MaxColorShiftLoop = 8;


// 高精度のテクスチャを使うか？ 0:低精度のテクスチャ(メモリ使用量少)、1:高精度テクスチャ
// 高精度のテクスチャを使わないと色調が足りなくて、カラーバンディングが発生する。
#define	USE_FLOAT_TEXTURE	1


//****************** 設定はここまで

// テクスチャフォーマット
#if defined(USE_FLOAT_TEXTURE) && USE_FLOAT_TEXTURE > 0
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"
#define WORK_TEXFORMAT "A16B16G16R16F"
#else
#define TEXFORMAT "A8R8G8B8"
#define WORK_TEXFORMAT "A8R8G8B8"
#endif

#define	gamma	(2.233333333)
#define	PI	(3.14159265359)
#define Rad2Deg(x)	((x) * 180 / PI)

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// ワーク用テクスチャの設定
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
#define ADDRESSING_MODE		AddressU = CLAMP; AddressV = CLAMP;

float4x4 AcsMat : CONTROLOBJECT < string name = "(self)"; >;
float AcsSi0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float AcsSi = saturate(AcsSi0 * 0.1 * 0.5);
static float ColorShiftRate = clamp(AcsMat._41 * 0.1, -1.0, 1.0);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float2 SampleStep = (float2(1.0,1.0) / ViewportSize.xy);

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewportRatio = {1,1};
	bool AntiAlias = true;
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;

sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	LINEAR_FILTER_MODE
	ADDRESSING_MODE
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
DECL_TEXTURE( BlurMap2, BlurSamp2, 4)

//-----------------------------------------------------------------------------

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
#if defined(ENABLE_GAMMA_CORRECT) && ENABLE_GAMMA_CORRECT > 0
float epsilon = 1.0e-4;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
#else
inline float3 Degamma(float3 col) { return col; }
inline float3 Gamma(float3 col) { return col; }
#endif
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }


float4 CalcColor(float4 col)
{
	col = Degamma4(col);

	#if defined(USE_ORIGINAL_METHOD) && USE_ORIGINAL_METHOD > 0
	col.rgb = col.rgb * col.rgb;
	#else
	col.rgb = 1.0 - (sqrt(max(4.0 - 4.0 * col.rgb, 1.0e-5)) * 0.5);
	#endif

	return col;
}

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
	return CalcColor(tex2D(smp, IN.TexCoord));
}

//-----------------------------------------------------------------------------
// ボカす
float4 PS_Blur( VS_OUTPUT IN, uniform sampler2D smp, uniform bool bBlurX) : COLOR
{
	float2 texCoord = IN.TexCoord;
	float2 offset = (bBlurX) ? float2(IN.Offset.x, 0) : float2(0, IN.Offset.y);

	float4 sum = tex2D(smp, texCoord) * BlurWeight[0];

	[unroll]
	for(int i = 1; i < 8; i++)
	{
		float3 col = tex2D(smp, texCoord + offset * i).rgb +
					 tex2D(smp, texCoord - offset * i).rgb;
		sum.rgb += col * BlurWeight[i];
	}

	return sum;
}

//-----------------------------------------------------------------------------
// 色ズレ
float4 PS_ColorShift( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 centered = IN.TexCoord * 2.0 - 1.0;
	float2 texCoordR = (centered * (1.0-ColorShiftRate) + 1.0) * 0.5;
	float2 texCoordB = (centered * (1.0+ColorShiftRate) + 1.0) * 0.5;
	float2 offset = (texCoordB - texCoordR) / MaxColorShiftLoop;

	float3 col = 0;
	float3 weightSum = 0;
	for(int i = 0; i < MaxColorShiftLoop; i++)
	{
		float2 texCoord = texCoordR + offset * i;
		float t = i * (2.0 / MaxColorShiftLoop);
		float3 weight = saturate(float3(1.0 - t, 1.0 - abs(1.0 - t), t - 1.0));
		col += tex2D(smp, texCoord).rgb * weight;
		weightSum += weight;
	}

	return float4(col / weightSum, 1);
}

//-----------------------------------------------------------------------------
// 低解像度マップを高解像度に復元
float4 PS_UpSampling( VS_OUTPUT IN, uniform sampler2D smp, uniform sampler2D smp2) : COLOR
{
	float2 texCoord = IN.TexCoord;
	float2 offset = IN.Offset * 0.5;

	float4 Color0 = tex2D(smp, texCoord);
	float4 Color1 = 
		tex2D(smp2, texCoord + offset * float2(-1,-1)) + 
		tex2D(smp2, texCoord + offset * float2(-1, 1)) + 
		tex2D(smp2, texCoord + offset * float2( 1,-1)) + 
		tex2D(smp2, texCoord + offset * float2( 1, 1));

	float4 ColorOrig = Degamma4(Color0);

	// 乗算(レベル補正)
	Color0 = CalcColor(Color0);
	// ボカし量の調整
	Color1 = lerp(Color0, Color1 * 0.25, AcsSi);
	// スクリーン合成
	float4 Color = (Color0 + Color1 - saturate(Color0 * Color1));
	// 比較(明)
	Color = lerp(Color, max(ColorOrig, Color), AcsTr);

	return float4(Gamma(Color.rgb), 1);
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

		#if defined(ENABLE_COLOR_SHIFT) && ENABLE_COLOR_SHIFT > 0
		"RenderColorTarget0=BlurMap2;"
		"Pass=ColorShiftPass;"
		#endif

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
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp1, true);
	}
	pass BlurPass2Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp2, false);
	}

	pass ColorShiftPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_ColorShift(DownscaleSamp2);
	}

	pass UpScale < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		#if defined(ENABLE_COLOR_SHIFT) && ENABLE_COLOR_SHIFT > 0
		PixelShader  = compile ps_3_0 PS_UpSampling(ScnSamp, BlurSamp2);
		#else
		PixelShader  = compile ps_3_0 PS_UpSampling(ScnSamp, DownscaleSamp2);
		#endif
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////

