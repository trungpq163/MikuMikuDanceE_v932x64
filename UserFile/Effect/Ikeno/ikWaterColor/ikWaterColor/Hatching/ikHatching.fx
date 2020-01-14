//パラメータ

// 影の領域：小さいほど影が小さくなる。0～1.0
#define ShadowThreshold		0.3

// ハッチングの色
const float3 HatchingColor = float3(0.0,0.0,0);
//const float3 HatchingColor = float3(0.6,0.3,0);

// 画像の色に応じてハッチング量を調整するか? 0:しない、1:する
#define ENABLE_COLOR_AWARE	1

// ハッチングテクスチャ

#define HATCHING_TEXTURE0	"pattern/hatching0.png"
#define HATCHING_TEXTURE1	"pattern/hatching1.png"
#define HATCHING_TEXTURE2	"pattern/hatching2.png"
#define HATCHING_TEXTURE3	"pattern/hatching3.png"
/*
#define HATCHING_TEXTURE0	"pattern/hatching00.png"
#define HATCHING_TEXTURE1	"pattern/hatching01.png"
#define HATCHING_TEXTURE2	"pattern/hatching02.png"
#define HATCHING_TEXTURE3	"pattern/hatching03.png"
*/
/*
#define HATCHING_TEXTURE0	"pattern/pattern00.png"
#define HATCHING_TEXTURE1	"pattern/pattern01.png"
#define HATCHING_TEXTURE2	"pattern/pattern02.png"
#define HATCHING_TEXTURE3	"pattern/pattern03.png"
*/

// 繰り返し回数。大きい数値ほど、ハッチングが細かくなる。
#define HATCHING_LOOP_NUM	10

// ハッチングをフレーム毎にズラすか? 0:しない、1:する
#define ENABLE_JITTERING	0
// 編集中もハッチングを動かすか? (ENABLE_JITTERINGが0の場合、無効)
#define TimeSync	1


//****************** 設定はここまで

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

////////////////////////////////////////////////////////////////////////////////////////////////

#define	PI	(3.14159265359)

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float AspectRatio = ViewportSize.y / ViewportSize.x;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;

float2 CalcUVOffset()
{
	#if defined(ENABLE_JITTERING) && ENABLE_JITTERING > 0
		float time = TimeSync ? time1 : time2;
		float2 offset = time * float2(127.1,311.7);
		return frac(sin(offset+20.)*53758.5453123) * 2 - 1.0;
	#else
		return 0;
	#endif
}
static float2 UVOffset = CalcUVOffset();


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "A8B8G8R8";
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

texture ShadowMap: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikHatching";
	float4 ClearColor = { 1, 0, 0, 1 };
	float2 ViewportRatio = {1,1};
	float ClearDepth = 1.0;
	string Format = "R16F";
	bool AntiAlias = false;
	string DefaultEffect = 
		"self = hide;"
		"* = DrawShadow.fx";
>;

sampler2D ShadowSamp = sampler_state {
	texture = <ShadowMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#define DECL_TEXTURE( _name, _map, _samp) \
	texture2D _map < \
		string ResourceName = _name; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE; \
		AddressU  = WRAP; AddressV = WRAP; \
	};

DECL_TEXTURE(HATCHING_TEXTURE0, hatchingMap0, hatchingSamp0);
DECL_TEXTURE(HATCHING_TEXTURE1, hatchingMap1, hatchingSamp1);
DECL_TEXTURE(HATCHING_TEXTURE2, hatchingMap2, hatchingSamp2);
DECL_TEXTURE(HATCHING_TEXTURE3, hatchingMap3, hatchingSamp3);

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

//-----------------------------------------------------------------------------
// 固定定義

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

//-----------------------------------------------------------------------------
// 共通のVS
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset.xy;
	return Out;
}

//-----------------------------------------------------------------------------
// 影の描画
float4 PS_Last( VS_OUTPUT IN ) : COLOR
{
	float4 Color = tex2D(ScnSamp, IN.TexCoord);
	float shadow = tex2D(ShadowSamp, IN.TexCoord).r;

	// 色の濃さを考慮する?
	#if defined(ENABLE_COLOR_AWARE) && ENABLE_COLOR_AWARE > 0
	float gray = rgb2gray(Color.rgb);
	shadow = lerp(shadow * gray, gray, 0.2);
	#endif

	float denom = max(1.0 * AcsSi * (ShadowThreshold * 0.1), 1.0e-4);
	shadow = saturate(shadow / denom);

	float2 uv = IN.TexCoord * HATCHING_LOOP_NUM + UVOffset;
	uv.y *= AspectRatio;

	float h = 1;
	float h0 = tex2D(hatchingSamp0, uv).r;
	float h1 = tex2D(hatchingSamp1, uv).r;
	float h2 = tex2D(hatchingSamp2, uv).r;
	float h3 = tex2D(hatchingSamp3, uv).r;
	if (shadow < 1.00) h = h0;
	if (shadow < 0.75) h *= h1;
	if (shadow < 0.50) h *= h2;
	if (shadow < 0.25) h *= h3;
	shadow = h;

	shadow = lerp(1, shadow, AcsTr);
	Color.rgb = lerp(Color.rgb * HatchingColor, Color.rgb, shadow);

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
