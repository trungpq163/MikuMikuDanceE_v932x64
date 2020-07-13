//-----------------------------------------------------------------------------
// MaterialTester用にカスタマイズされた、MaterialMap.fx
//-----------------------------------------------------------------------------

// コントローラ名
// テスト用モデル以外に割り当てても動作するようにコントローラ名を直接指定する。
#define TEST_CONTROLLER_NAME	"MaterialTester.pmx"
//#define TEST_CONTROLLER_NAME	"(self)"

//-----------------------------------------------------------------------------
// 法線マップを使用するか?
#define USE_NORMALMAP
// USE_NCHL_SETTINGSと両方使う場合、サブ法線のみが有効になります。

// メイン法線マップ
#define NORMALMAP_MAIN_FILENAME "brick_n.png" //ファイル名
//コントローラで指定する。
//const float NormalMapMainLoopNum = 1;				//繰り返し回数
//const float NormalMapMainHeightScale = 0.05;		//高さ補正 正で高くなる 0で平坦

// サブ法線マップ(微細な凹凸用)
#define NORMALMAP_SUB_FILENAME "dummy_n.bmp" //ファイル名
const float NormalMapSubLoopNum = 7;			//繰り返し回数
const float NormalMapSubHeightScale = 0.2;		//高さ補正 正で高くなる 0で平坦

// 影描画のタイプ
// 0: 影を薄くする (顔用)
// 1: 通常
#define SHADOW_TYPE		1

// 設定ここまで
//-----------------------------------------------------------------------------


// 座法変換行列
float4x4 matW			: WORLD;
float4x4 matWV		: WORLDVIEW;
float4x4 matWVP		: WORLDVIEWPROJECTION;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float	SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float3	LightDiffuse		: DIFFUSE   < string Object = "Light"; >;

// 材質モーフ対応
float4	TextureAddValue		: ADDINGTEXTURE;
float4	TextureMulValue		: MULTIPLYINGTEXTURE;
float4	SphereAddValue		: ADDINGSPHERETEXTURE;
float4	SphereMulValue		: MULTIPLYINGSPHERETEXTURE;

// ガンマ補正
#define Degamma(x)	pow(max(x,1e-4), 2.2)

static float4 DiffuseColor  = MaterialDiffuse;
static float3 SpecularColor = (Degamma(MaterialSpecular * (LightDiffuse.r * 9 + 1))) * 0.95 + 0.05;

#define REF_CTRL	string name = TEST_CONTROLLER_NAME
float CustomMetalness : CONTROLOBJECT < REF_CTRL; string item = "Metalness"; >;
float CustomSmoothness : CONTROLOBJECT < REF_CTRL; string item = "Smoothness"; >;
float NonmetalF0 : CONTROLOBJECT < REF_CTRL; string item = "NonmetalF0"; >;
float CustomIntensity : CONTROLOBJECT < REF_CTRL; string item = "Intensity"; >;
float SSSValue : CONTROLOBJECT < REF_CTRL; string item = "SSSValue"; >;
float NormalMapMainHeightScale : CONTROLOBJECT < REF_CTRL; string item = "Normal1Height"; >;
float NormalMap1Loop : CONTROLOBJECT < REF_CTRL; string item = "Normal1Loop"; >;
static float NormalMapMainLoopNum = NormalMap1Loop * 10.0 + 1.0;

bool	 spadd;	// スフィアマップ加算合成フラグ

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphereSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};


#ifdef USE_NORMALMAP
//メイン法線マップ
#define ANISO_NUM 16

texture2D NormalMap <
    string ResourceName = NORMALMAP_MAIN_FILENAME;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};

//サブ法線マップ
texture2D NormalMapSub <
    string ResourceName = NORMALMAP_SUB_FILENAME;
>;
sampler NormalMapSampSub = sampler_state {
    texture = <NormalMapSub>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};
#endif

shared texture PPPNormalMapRT: RENDERCOLORTARGET;
shared texture PPPMaterialMapRT: RENDERCOLORTARGET;
shared texture PPPAlbedoMapRT: RENDERCOLORTARGET;


///////////////////////////////////////////////////////////////////////////////////////////////
// 
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}

float4 CalcNormal(float2 Tex,float3 Eye,float3 Normal)
{
#if !defined(USE_NORMALMAP)
	return float4(Normal,1);
#else
	float4 Norm = 1;

	float2 tex = Tex* NormalMapMainLoopNum;//メイン
	float4 NormalColor = tex2D( NormalMapSamp, tex) * 2 - 1;
	NormalColor.rg *= NormalMapMainHeightScale;
	NormalColor.rgb = normalize(NormalColor.rgb);

	float2 texSub = Tex * NormalMapSubLoopNum;//サブ
	float4 NormalColorSub = tex2D( NormalMapSampSub, texSub)*2-1;	//-1～1の値にする
	NormalColorSub.rg *= NormalMapSubHeightScale;
	NormalColorSub.rgb = normalize(NormalColorSub.rgb);

	NormalColor.rg += NormalColorSub.rg;
	NormalColor.rgb = normalize(NormalColor.rgb);

	float3x3 tangentFrame = compute_tangent_frame(Normal, Eye, Tex);
	Norm.rgb = normalize(mul(NormalColor.rgb, tangentFrame));

	return Norm;
#endif
}


inline float4 GetTextureColor(float2 uv)
{
	float4 TexColor = tex2D( ObjTexSampler, uv);
	TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
	return TexColor;
}

inline float4 GetSphereColor(float2 uv)
{
	float4 TexColor = tex2D(ObjSphereSampler, uv);
	TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
	return TexColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT
{
	float4 Pos	: POSITION;
	float3 Normal	: TEXCOORD0;
	float2 Tex	: TEXCOORD1;
	float3 WPos	: TEXCOORD2;
	float Distance	: TEXCOORD3;
	float2 SpTex	: TEXCOORD4;
};

struct PS_OUT_MRT
{
	float4 Color		: COLOR0;
	float4 Normal		: COLOR1;
	float4 Material		: COLOR2;
	float4 Albedo		: COLOR3;
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex: TEXCOORD0,
	 uniform bool useTexture, uniform bool useSphereMap)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, matWVP );
	Out.Normal = normalize(mul(Normal,(float3x3)matW));
	Out.Tex = Tex;

	Out.WPos = mul( Pos, matW ).xyz;
	Out.Distance = mul(Pos, matWV).z;

	if ( useSphereMap && !spadd) {
		float2 NormalWV = normalize(mul( Normal, (float3x3)matWV )).xy;
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}

	return Out;
}


PS_OUT_MRT Basic_PS( VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR
{
	float2 texCoord = IN.Tex.xy;
	float4 albedo = DiffuseColor;
	if ( useTexture ) albedo *= GetTextureColor(texCoord);

	// clip(albedo.a - AlphaThreshold);

	#if !defined(USE_NCHL_SETTINGS)
	// 加算のスフィアマップは擬似スペキュラだと思われるので無視
	if ( useSphereMap && !spadd) albedo.rgb *= GetSphereColor(IN.SpTex).rgb;
	#endif
	albedo.rgb = Degamma(albedo.rgb);

	const float3 V = normalize(CameraPosition - IN.WPos);
	const float3 N = CalcNormal(IN.Tex, V, normalize(IN.Normal)).xyz;

	float4 params = 1;
	params = float4(CustomMetalness, CustomSmoothness, CustomIntensity, SSSValue);


	// スペキュラの色＝反射色とみなす
	float metalness = params.x;
	float3 speccol = (albedo * 0.5 + 0.5) * SpecularColor;
	speccol = lerp(NonmetalF0, speccol, metalness);

	PS_OUT_MRT Out;
	Out.Color = float4(speccol, SHADOW_TYPE);
	Out.Normal = float4(N, IN.Distance);
	Out.Material = params;
	Out.Albedo = float4(albedo.rgb, 1);

	return Out;
}

#define OBJECT_TEC(name, mmdpass, tex, sphere) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; \
	string Script = \
		"RenderColorTarget0=;" \
		"RenderColorTarget1=PPPNormalMapRT;" \
		"RenderColorTarget2=PPPMaterialMapRT;" \
		"RenderColorTarget3=PPPAlbedoMapRT;" \
		"RenderDepthStencilTarget=;" \
		"Pass=DrawObject;" \
	; \
	> { \
		pass DrawObject { \
			AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE; \
			VertexShader = compile vs_3_0 Basic_VS(tex, sphere); \
			PixelShader  = compile ps_3_0 Basic_PS(tex, sphere); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false, false)
OBJECT_TEC(MainTec1, "object", true, false)
OBJECT_TEC(MainTec2, "object", false, true)
OBJECT_TEC(MainTec3, "object", true, true)
OBJECT_TEC(MainTecBS0, "object_ss", false, false)
OBJECT_TEC(MainTecBS1, "object_ss", true, false)
OBJECT_TEC(MainTecBS2, "object_ss", false, true)
OBJECT_TEC(MainTecBS3, "object_ss", true, true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
