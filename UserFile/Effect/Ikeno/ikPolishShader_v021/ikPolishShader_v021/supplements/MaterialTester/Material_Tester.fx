//-----------------------------------------------------------------------------
// MaterialTester用にカスタマイズされた、Material.fx
//-----------------------------------------------------------------------------

// コントローラ名
// テスト用モデル以外に割り当てても動作するようにコントローラ名を直接指定する。
#define TEST_CONTROLLER_NAME	"MaterialTester.pmx"
//#define TEST_CONTROLLER_NAME	"(self)"

#define MATERIAL_TYPE			1
#define SMOOTHNESS_TYPE			1
#define SPECULAR_COLOR_TYPE		0
#define	EMISSIVE_TYPE			2

#define AlphaThreshold		0.5

#define NORMALMAP_ENABLE		1
#define NORMALMAP_MAIN_FILENAME "assets/brick_n.png"

#define NORMALMAP_SUB_ENABLE	0
#define NORMALMAP_SUB_FILENAME "assets/dummy_n.bmp"
#define NORMALMAP_SUB_LOOPNUM	1.0
#define NORMALMAP_SUB_HEIGHT	1.0

// 設定ここまで
//-----------------------------------------------------------------------------

#define TO_MATERIAL_TYPE(x)	(x)

#define MT_MASK		TO_MATERIAL_TYPE(0)
#define MT_NORMAL	TO_MATERIAL_TYPE(1)
#define MT_METAL	TO_MATERIAL_TYPE(1)
#define MT_SKIN		TO_MATERIAL_TYPE(1)
#define MT_FACE		TO_MATERIAL_TYPE(2)
#define MT_LEAF		TO_MATERIAL_TYPE(3)
#define MT_EMISSIVE	TO_MATERIAL_TYPE(4)

#define REF_CTRL	string name = TEST_CONTROLLER_NAME

float METALNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Metalness"; >;
float SMOOTHNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Smoothness"; >;
float INTENSITY_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Intensity"; >;

float mEmissiveValue : CONTROLOBJECT < REF_CTRL; string item = "Emissive"; >;
static float EMISSIVE_VALUE = mEmissiveValue * 2.0;
float SSS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "SSSValue"; >;

float NORMALMAP_MAIN_HEIGHT : CONTROLOBJECT < REF_CTRL; string item = "Normal1Height"; >;
float NormalMap1Loop : CONTROLOBJECT < REF_CTRL; string item = "Normal1Loop"; >;
static float NORMALMAP_MAIN_LOOPNUM = NormalMap1Loop * 10.0 + 1.0;

//-----------------------------------------------------------------------------




/////////////////////////////////////////////////////////////////////////////////////////

// スフィアマップを無視する
#define	IGNORE_SPHERE

/*
#if MATERIAL_TYPE != MT_EMISSIVE
#undef	EMISSIVE_TYPE
#define	EMISSIVE_TYPE	1
#endif
*/

// 座法変換行列
float4x4 matW		: WORLD;
float4x4 matWV		: WORLDVIEW;
float4x4 matWVP		: WORLDVIEWPROJECTION;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float	SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;

float3	CameraPosition		: POSITION  < string Object = "Camera"; >;
float3	LightDiffuse		: DIFFUSE   < string Object = "Light"; >;

// 材質モーフ対応
float4	TextureAddValue		: ADDINGTEXTURE;
float4	TextureMulValue		: MULTIPLYINGTEXTURE;
float4	SphereAddValue		: ADDINGSPHERETEXTURE;
float4	SphereMulValue		: MULTIPLYINGSPHERETEXTURE;

bool	use_texture;
bool	use_subtexture;    // サブテクスチャフラグ
bool	spadd;	// スフィアマップ加算合成フラグ

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};


#if !defined(IGNORE_SPHERE)
// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphereSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};
#endif

static float4 DiffuseColor  = float4(saturate((MaterialAmbient.rgb+MaterialEmissive.rgb)),MaterialDiffuse.a);


// ガンマ補正
#define Degamma(x)	pow(max(x,1e-4), 2.2)
float Luminance(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

//static float3 SpecularColor = (Degamma(MaterialSpecular)) * 0.95 + 0.05;
static float3 SpecularColor = (Degamma(MaterialSpecular * (LightDiffuse.r * 9 + 1))) * 0.95 + 0.05;
	// MaterialSpecular はモデルなら1、アクセサリなら1/10になる。
	// LightDiffuse は モデルなら0,0,0、アクセサリなら1,1,1になる。

float GetMetalness(float2 uv) { return METALNESS_VALUE; }

	#if SMOOTHNESS_TYPE == 0
	float GetSmoothness(float2 uv) { return saturate((log2(SpecularPower+1)-1)/8.0); }
	#else
	float GetSmoothness(float2 uv) { return SMOOTHNESS_VALUE; }
	#endif

float GetSSSValue(float2 uv) { return SSS_VALUE; }

float GetIntensity(float2 uv) { return INTENSITY_VALUE; }

#if NORMALMAP_ENABLE > 0
//メイン法線マップ
#define ANISO_NUM 16

#define DECL_NORMAL_TEXTURE( _name, _res) \
	texture2D _name##Map < string ResourceName = _res; >; \
	sampler2D _name##Samp = sampler_state { \
		texture = <_name##Map>; \
		MINFILTER = ANISOTROPIC;	MAGFILTER = ANISOTROPIC;	MIPFILTER = ANISOTROPIC; \
		MAXANISOTROPY = ANISO_NUM; \
		AddressU  = WRAP;	AddressV  = WRAP; \
	}; \

DECL_NORMAL_TEXTURE( NormalMain, NORMALMAP_MAIN_FILENAME)
#if NORMALMAP_SUB_ENABLE > 0
DECL_NORMAL_TEXTURE( NormalSub, NORMALMAP_SUB_FILENAME)
#endif
#endif

shared texture PPPNormalMapRT: RENDERCOLORTARGET;
shared texture PPPMaterialMapRT: RENDERCOLORTARGET;
// shared texture PPPAlbedoMapRT: RENDERCOLORTARGET;


#if SMOOTHNESS_TYPE == 2
// float ConvertToRoughness(float val) { return val * val; }
float ConvertToRoughness(float val) { return val; }
#else
//float ConvertToRoughness(float val) { return (1 - val) * (1 - val); }
float ConvertToRoughness(float val) { return 1.0 - val; }
#endif


#if EMISSIVE_TYPE == 0
#define ENABLE_AL	1
#elif EMISSIVE_TYPE == 3 || EMISSIVE_TYPE == 4
#define IS_LIGHT	1
#endif


struct VS_OUTPUT
{
	float4 Pos		: POSITION;
	float3 Normal	: TEXCOORD0;
	float4 Tex		: TEXCOORD1;
	float4 WPos		: TEXCOORD2;

	#if !defined(IGNORE_SPHERE)
	float2 SpTex	: TEXCOORD3;
	#endif

	#if ENABLE_AL > 0
	float4 ColorAL	: COLOR0;		// AL用の発光色
	#endif
};

struct PS_OUT_MRT
{
	float4 Color		: COLOR0;
	float4 Normal		: COLOR1;
	float4 Material		: COLOR2;
//	float4 Albedo		: COLOR3;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// 自己発光


#if EMISSIVE_TYPE == 2
float GetEmissiveValue(float2 uv) { return EMISSIVE_VALUE; }
#endif

float3 GetEmissiveColor(VS_OUTPUT IN, float3 baseColor, out float emissive)
{
	emissive = 0;

#if ENABLE_AL > 0
	float4 alColor = GetAutoluminousColor(IN.ColorAL, IN.Tex);
	baseColor += alColor.rgb;
	emissive = alColor.w;

#elif EMISSIVE_TYPE == 1
	// 発行しない

#elif IS_LIGHT > 0
	emissive = 1; // 仮

#elif EMISSIVE_TYPE == 2
	emissive = GetEmissiveValue(IN.Tex);

#endif

	return baseColor;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 

#if NORMALMAP_ENABLE > 0
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
	float2 tex = Tex* NORMALMAP_MAIN_LOOPNUM; //メイン
	float4 NormalColor = tex2D( NormalMainSamp, tex) * 2 - 1;
	NormalColor.xy *= NORMALMAP_MAIN_HEIGHT;

	#if NORMALMAP_SUB_ENABLE > 0
	float2 texSub = Tex * NORMALMAP_SUB_LOOPNUM; //サブ
	float4 NormalColorSub = tex2D( NormalSubSamp, texSub) * 2 - 1;
	NormalColor.xy += NormalColorSub.xy * NORMALMAP_SUB_HEIGHT;
	#endif

	NormalColor.xyz = normalize(NormalColor.xyz);
	NormalColor.w = 1;

	float4 Norm = 1;
	float3x3 tangentFrame = compute_tangent_frame(Normal, Eye, Tex);
	Norm.xyz = normalize(mul(NormalColor.xyz, tangentFrame));
	return Norm;
}
#else
float4 CalcNormal(float2 Tex,float3 Eye,float3 Normal)
{
	return float4(Normal,1);
}
#endif


float4 GetTextureColor(float2 uv)
{
	float4 TexColor = tex2D( ObjTexSampler, uv);

	#if EMISSIVE_TYPE == 4
	TexColor.rgb = tex2D( LightSamp, uv).rgb;
	#endif

	TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
	return TexColor;
}

float4 GetSphereColor(float2 uv)
{
	#if !defined(IGNORE_SPHERE)
	float4 TexColor = tex2D(ObjSphereSampler, uv);
	TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
	return TexColor;
	#else
	return 1;
	#endif
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex: TEXCOORD0,
	#if ENABLE_AL > 0
	float4 AddUV1 : TEXCOORD1,
	float4 AddUV2 : TEXCOORD2,
	float4 AddUV3 : TEXCOORD3,
	#endif
	uniform bool useTexture, uniform bool useSphereMap)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, matWVP );
	Out.Normal = normalize(mul(Normal,(float3x3)matW));
	Out.Tex.xy = Tex;
	Out.WPos = float4(mul( Pos, matW ).xyz, mul(Pos, matWV).z);

	#if !defined(IGNORE_SPHERE)
	if ( useSphereMap && !spadd) {
		float2 NormalWV = normalize(mul( Normal, (float3x3)matWV )).xy;
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}
	#endif

	#if ENABLE_AL > 0
	float2 ALTex;
	Out.ColorAL = DecodeALInfo(AddUV1, AddUV2, AddUV3, ALTex);
	Out.Tex.zw = ALTex;
	#endif

	return Out;
}


PS_OUT_MRT Basic_PS( VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR
{
	PS_OUT_MRT Out = (PS_OUT_MRT)0;

	float2 texCoord = IN.Tex.xy;

	float4 albedo = DiffuseColor;
	if ( useTexture ) albedo *= GetTextureColor(texCoord);
	clip(albedo.a - AlphaThreshold);

	#if !defined(IGNORE_SPHERE)
	if ( useSphereMap && !spadd) albedo.rgb *= GetSphereColor(IN.SpTex).rgb;
	#endif
	albedo.rgb = Degamma(albedo.rgb);

	const float3 V = normalize(CameraPosition - IN.WPos.xyz);
	const float3 N = CalcNormal(texCoord, V, normalize(IN.Normal)).xyz;
	float depth = IN.WPos.w;

#if MATERIAL_TYPE != MT_MASK

	float metalness = GetMetalness(texCoord);
	float roughness = ConvertToRoughness(GetSmoothness(texCoord));
	float sssValue = lerp(GetSSSValue(texCoord), 0, metalness);
	float intensity = saturate(GetIntensity(texCoord) * 0.5);

	float emissive = 0;
	albedo.rgb = GetEmissiveColor(IN, albedo.rgb, emissive);
	emissive = saturate(emissive / 8.0);

	//-----------------------------------------------------------------------------
	// 属性設定
	// emissiveとsssは排他的
	float enableEmissive = (emissive >= 1.0/255.0);
	float attribute = (emissive >= 1.0/255.0) ? (MT_EMISSIVE) : (MATERIAL_TYPE);
	float materialID = attribute / 255.0;

	//-----------------------------------------------------------------------------

	float extraValue = (attribute == MT_EMISSIVE) ? emissive : sssValue;
	float extraValue2 = intensity;

	#if USE_ALBEDO_AS_SPECULAR_COLOR == 0
	// OLD STYLE
	float3 speccol = (albedo.rgb * 0.5 + 0.5) * SpecularColor;
	albedo.rgb = lerp(albedo.rgb, speccol, metalness);
	#elif USE_ALBEDO_AS_SPECULAR_COLOR == 1
	// なにもしない
	#elif USE_ALBEDO_AS_SPECULAR_COLOR == 2
	// スペキュラ色のみで決定
	albedo.rgb = lerp(albedo.rgb, SpecularColor, metalness);
	#endif

	Out.Color = float4(albedo.rgb, extraValue2);
	Out.Material = float4(metalness, roughness, extraValue, materialID);
//	Out.Albedo = float4(albedo.rgb, 1);

#else
	// マスク
#endif

	Out.Normal = float4(N, depth);

	return Out;
}

#define OBJECT_TEC(name, mmdpass, tex, sphere) \
	technique name < string MMDPass = mmdpass; \
	string Script = \
		"RenderColorTarget0=;" \
		"RenderColorTarget1=PPPNormalMapRT;" \
		"RenderColorTarget2=PPPMaterialMapRT;" \
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


OBJECT_TEC(MainTec0, "object", use_texture, use_subtexture)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, use_subtexture)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////



