////////////////////////////////////////////////////////////////////////////////////////////////
//
//
////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#include "../ikPolishShader.fxsub"

//-----------------------------------------------------------------------------
//

float3 TargetPosition : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float3 LightDirection	: DIRECTION < string Object = "Light"; >;

#include	"rsm_common.fxsub"


//-----------------------------------------------------------------------------



// 座法変換行列
float4x4 matW			: WORLD;
static float4x4 lightMatWV = mul(matW, lightMatV);
static float4x4 lightMatWVP = mul(lightMatWV, lightMatP);

shared texture PPPRSMAlbedoMapRT : RENDERCOLORTARGET;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
static float4 DiffuseColor  = MaterialDiffuse;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// ガンマ補正
const float epsilon = 1.0e-6;
const float gamma = 2.2;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

////////////////////////////////////////////////////////////////////////////////////////////////

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

struct DrawObject_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float2 Tex      : TEXCOORD0;    // テクスチャ
	float Distance	: TEXCOORD1;
	float3 Normal	: TEXCOORD2;

    float4 Color    : COLOR0;       // ディフューズ色
};

struct PS_OUT_MRT
{
	float4 Normal		: COLOR0;
	float4 Color		: COLOR1;
};


// 頂点シェーダ
DrawObject_OUTPUT DrawObject_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture)
{
    DrawObject_OUTPUT Out = (DrawObject_OUTPUT)0;

    Out.Pos = mul( Pos, lightMatWVP );
	Out.Distance = mul(Pos, lightMatWV).z;
	Out.Normal = mul(Normal, (float3x3)matW);

    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
PS_OUT_MRT DrawObject_PS(DrawObject_OUTPUT IN, uniform bool useTexture)
{
	float4 Color = DiffuseColor;
	if ( useTexture ) {
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		Color *= TexColor;
	}

	clip(Color.a - AlphaThreshold);

	float3 N = normalize(IN.Normal.xyz);

	#if defined(ENABLE_DOUBLE_SIDE_SHADOW) && ENABLE_DOUBLE_SIDE_SHADOW > 0
	float diffuse = dot(N,-LightDirection);
	// 裏向きのポリゴンを表にする
	//N = N * ((diffuse >= 0) ? 1 : -1);
	// 裏向きのポリゴンを陰にする
	Color.rgb *= ((diffuse >= 0) ? 1 : 0);
	#endif

	PS_OUT_MRT Out;
	Out.Color = Degamma4(Color);
		// ここでは陰影計算をしない
		// 色をブーストしておく?
	Out.Normal = float4(N, IN.Distance);

	return Out;
}

#if defined(ENABLE_DOUBLE_SIDE_SHADOW) && ENABLE_DOUBLE_SIDE_SHADOW > 0
#define	SET_CULL_MODE		CullMode = NONE;
#else
#define	SET_CULL_MODE
#endif

#define OBJECT_TEC(name, mmdpass, tex, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; \
	string Script = \
		"RenderColorTarget0=;" \
		"RenderColorTarget1=PPPRSMAlbedoMapRT;" \
		"RenderDepthStencilTarget=;" \
		"Pass=DrawObject;" \
		"RenderColorTarget1=;" \
	; \
	> { \
		pass DrawObject { \
			AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE; \
			SET_CULL_MODE \
			VertexShader = compile vs_3_0 DrawObject_VS(tex); \
			PixelShader  = compile ps_3_0 DrawObject_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec2, "object", false, false)
OBJECT_TEC(MainTec3, "object", true, false)

OBJECT_TEC(MainTecBS2, "object_ss", false, true)
OBJECT_TEC(MainTecBS3, "object_ss", true, true)


///////////////////////////////////////////////////////////////////////////////////////////////
