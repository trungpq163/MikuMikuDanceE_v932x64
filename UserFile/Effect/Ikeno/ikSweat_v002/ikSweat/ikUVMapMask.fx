////////////////////////////////////////////////////////////////////////////////////////////////
// マスク用。
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 一定以上の半透明は不透明とみなす。
const float AlphaThreshold = 0.75;

// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler DefSampler : register(s0);
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);



///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;

	float4 ZCalcTex	: TEXCOORD1;
	float3 Normal	: TEXCOORD2;
	float3 Eye		: TEXCOORD3;
	float Depth		: TEXCOORD4;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSelfShadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Tex = Tex;

	Out.Depth = Out.Pos.z;

	return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSelfShadow) : COLOR0
{
	if ( useTexture ) {
		// テクスチャ適用
		float4 Color = 1;
		Color.a *= tex2D( ObjTexSampler, IN.Tex ).a;
		clip(Color.a - AlphaThreshold);
	}

	return float4(0, 0, 0, IN.Depth);
}


#define OBJECT_TEC(name, mmdpass, tex, shadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSelfShadow = shadow;>\
	{ \
		pass DrawObject { \
			AlphaBlendEnable = FALSE; \
			AlphaTestEnable = FALSE; \
			VertexShader = compile vs_3_0 Basic_VS(tex, shadow); \
			PixelShader  = compile ps_3_0 Basic_PS(tex, shadow); \
		} \
	}


OBJECT_TEC(MainTec0, "object", true, false)
OBJECT_TEC(MainTec4, "object", false, false)

OBJECT_TEC(BSTec0, "object_ss", true, true)
OBJECT_TEC(BSTec4, "object_ss", false, true)


technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
