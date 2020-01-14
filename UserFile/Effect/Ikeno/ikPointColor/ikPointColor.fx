//パラメータ

#include "ikPointColorSettings.fxsub"

#define	DefaultMark		0		// 未初期化時のパレット番号
#define	EnableLinear	1		// パレットの中間色を許すか。0だとパレット内での補間をしなくなる。

#define EnableAlpha		1		// パレットのαを参照するか?


#define EnableDot		0		// 水玉パターンを使用するか?
#define EnableToneDot	1		// カラートーンのグレースケール値で水玉のサイズを決めるか?
	// 0: 元画像のグレースケール値で水玉のサイズを決める



//******************設定はここまで

////////////////////////////////////////////////////////////////////////////////////////////////

float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
static float PallestSlotIndex = saturate(floor(AcsX) / PALLET_SLOT);

float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
static float GridRadius = floor(max(AcsY, 1));

#define	PI	(3.14159265359)

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "D3DFMT_A16B16G16R16F";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

shared texture2D PalletTex <
	string ResourceName = PALLET_FILE_NAME;
>;
sampler PalletTexSamp = sampler_state{
	texture = <PalletTex>;

#if EnableLinear
	MinFilter = LINEAR;
	MagFilter = LINEAR;
#else
	MinFilter = POINT;
	MagFilter = POINT;
#endif
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};



texture PointColorMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikPointColor";
	float4 ClearColor = { DefaultMark * 1.0 / PALLET_HEIGHT, 0, 0, 1 };
	float2 ViewportRatio = {1,1};
	float ClearDepth = 1.0;
	string Format = "D3DFMT_A8L8";
	bool AntiAlias = false;
	string DefaultEffect = 
		"self = hide;"
		"*.pmd = ikColorMark0.fx;"
		"*.pmx = ikColorMark0.fx;"
		"* = hide;";
>;

sampler MarkMap = sampler_state {
	texture = <PointColorMapRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};


//-----------------------------------------------------------------------------
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset.xy;

	return Out;
}

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

float4 PS_Last( VS_OUTPUT IN ) : COLOR
{
	float4 Color = float4(tex2D( ScnSamp, IN.TexCoord).rgb, 1);

	float g = saturate(rgb2gray(Color.rgb));
	float mark = tex2D( MarkMap, IN.TexCoord).r / PALLET_SLOT + PallestSlotIndex;

	#if EnableDot
	float4 PalletColor0 = tex2D( PalletTexSamp, float2((0.5) / PALLET_WIDTH, mark));
	float4 PalletColor1 = tex2D( PalletTexSamp, float2(((PALLET_WIDTH - 2) + 0.5) / PALLET_WIDTH, mark));

	#if EnableToneDot
		float4 PalletColorG = tex2D( PalletTexSamp, float2((g * (PALLET_WIDTH - 2) + 0.5) / PALLET_WIDTH, mark));
		float gMax = rgb2gray(PalletColor1.rgb);
		g = saturate(rgb2gray(PalletColorG.rgb) / max(gMax, 1/1024.0));
	#endif

	float dotRadius = GridRadius * g * 1.42;
		/*
		グレースケール: 半径
			0:		r = 0
			0.5:	r = sqrt(4/2/PI) = 0.79
			0.78	r = 1.0 → 面積 3.14:4 = 0.78:1
			1:		r = 1.4142
		*/

	float2 grid = IN.TexCoord * ViewportSize.xy;
	if (fmod(floor(grid.y / GridRadius), 2) == 1.0)
	{
		grid.x += (GridRadius * 0.5);
	}

	float2 uv = (fmod(grid, GridRadius) * 2.0 - GridRadius);

	float r = sqrt(dot(uv,uv));
	float4 PalletColor = lerp(PalletColor0, PalletColor1, saturate(dotRadius - r));

	#else
		float4 PalletColor = tex2D( PalletTexSamp, float2((g * (PALLET_WIDTH - 2) + 0.5) / PALLET_WIDTH, mark));
	#endif

	#if EnableAlpha
		Color.rgb = lerp(Color.rgb, PalletColor.rgb, PalletColor.a);
	#else
		Color.rgb = PalletColor.rgb;
	#endif

	return Color;
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

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=LastPass;"
	;
> {
	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Last();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
