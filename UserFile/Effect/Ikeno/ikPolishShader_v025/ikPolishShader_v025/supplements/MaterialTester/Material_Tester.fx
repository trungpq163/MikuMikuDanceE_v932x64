//-----------------------------------------------------------------------------
// MaterialTester用にカスタマイズされた、Material.fx
//-----------------------------------------------------------------------------

// コントローラ名
// テスト用モデル以外に割り当てても動作するようにコントローラ名を直接指定する。
#define TEST_CONTROLLER_NAME	"MaterialTester.pmx"
//#define TEST_CONTROLLER_NAME	"(self)"

#define MATERIAL_TYPE			1
#define	EMISSIVE_TYPE			2

#define SMOOTHNESS_TYPE			1
#define	SMOOTHNESS_MAP_ENABLE	1
#define SMOOTHNESS_MAP_FILE		"textures/stone_tiles_smoothness.png"
#define SPECULAR_COLOR_TYPE		1

#define INTENSITY_TYPE		1 // AO
#define	INTENSITY_MAP_ENABLE	1
#define INTENSITY_MAP_FILE		"textures/stone_tiles_ambientocclusion.png"

#define AlphaThreshold		0.5

#define NORMALMAP_ENABLE		1
#define NORMALMAP_MAIN_FILENAME "textures/stone_tiles_normal.png"

#define NORMALMAP_SUB_ENABLE	0
#define NORMALMAP_SUB_FILENAME "textures/dummy_n.bmp"
#define NORMALMAP_SUB_LOOPNUM	1.0
#define NORMALMAP_SUB_HEIGHT	1.0

// 方向の反転
// 0: 反転なし
// 1: xを反転
// 2: yを反転
// 3: x,yを反転
#define	NORMALMAP_FLIP		0


#define PARALLAX_ENABLE		1
#define PARALLAX_FILENAME	"textures/stone_tiles_height.png"

// テクスチャ上での参照距離
// (参照ピクセル/テクスチャサイズ)
#define PARALLAX_LENGTH		(32.0/512.0)

#define PARALLAX_ITERATION	8	// 検索回数(1～16)


// 設定ここまで
//-----------------------------------------------------------------------------

#define PARALLAX_LOOPNUM NORMALMAP_MAIN_LOOPNUM


#define TO_MATERIAL_TYPE(x)	(x)

#define MT_MASK		TO_MATERIAL_TYPE(0)
#define MT_NORMAL	TO_MATERIAL_TYPE(1)
#define MT_METAL	TO_MATERIAL_TYPE(1)
#define MT_SKIN		TO_MATERIAL_TYPE(1)
#define MT_FACE		TO_MATERIAL_TYPE(2)
#define MT_LEAF		TO_MATERIAL_TYPE(3)
#define MT_EMISSIVE	TO_MATERIAL_TYPE(4)

#define MT_AO		TO_MATERIAL_TYPE(8)
#define MT_CAVITY	TO_MATERIAL_TYPE(16)

#define REF_CTRL	string name = TEST_CONTROLLER_NAME

float METALNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Metalness"; >;
float SMOOTHNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Smoothness"; >;
float INTENSITY_VALUE_INV : CONTROLOBJECT < REF_CTRL; string item = "@Intensity"; >;
static float INTENSITY_VALUE = 1 - INTENSITY_VALUE_INV;

float mEmissiveValue : CONTROLOBJECT < REF_CTRL; string item = "Emissive"; >;
static float EMISSIVE_VALUE = mEmissiveValue * 2.0;
float SSS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "SSSValue"; >;
float HSV_H : CONTROLOBJECT < REF_CTRL; string item = "Hue"; >;
float HSV_S : CONTROLOBJECT < REF_CTRL; string item = "Saturation"; >;
float HSV_V_INV : CONTROLOBJECT < REF_CTRL; string item = "@Brightness"; >;
static float HSV_V = 1 - HSV_V_INV;

float NORMALMAP_MAIN_HEIGHT : CONTROLOBJECT < REF_CTRL; string item = "NormalHeight"; >;
float NormalMapLoop  : CONTROLOBJECT < REF_CTRL; string item = "NormalLoop"; >;
static float NORMALMAP_MAIN_LOOPNUM = NormalMapLoop * 2.0 + 1.0;
float PARALLAX_HEIGHT : CONTROLOBJECT < REF_CTRL; string item = "ParallaxHeight"; >;
float BaseTexture : CONTROLOBJECT < REF_CTRL; string item = "BaseTexture"; >;

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

#define TEXTURE_SAMPLER(_TexID)	TextureSamp_##_TexID

#define DECL_TEXTURE( _TexID, _fname) \
	texture2D TextureMap_##_TexID < string ResourceName = _fname; >; \
	sampler2D TEXTURE_SAMPLER(_TexID) = sampler_state { \
		texture = <TextureMap_##_TexID>; \
		MinFilter = Linear;	MagFilter = Linear;	MipFilter = None; \
		AddressU  = WRAP;	AddressV  = WRAP; \
	};

#if SMOOTHNESS_MAP_ENABLE > 0
DECL_TEXTURE(0, SMOOTHNESS_MAP_FILE)
#endif
#if INTENSITY_MAP_ENABLE > 0
DECL_TEXTURE(1, INTENSITY_MAP_FILE)
#endif

static float4 DiffuseColor  = float4(saturate((MaterialAmbient.rgb+MaterialEmissive.rgb)),MaterialDiffuse.a);


// ガンマ補正
#define Degamma(x)	pow(max(x,1e-4), 2.2)
float Luminance(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

float3 hsv2rgb(float3 c)
{
	float3 hcol = saturate((abs(frac(c.x + float3(3,2,1)/3)*6 - 3) - 1));
	return float3(lerp(1, hcol, c.y) * c.z);
}

//static float3 SpecularColor = (Degamma(MaterialSpecular)) * 0.95 + 0.05;
static float3 SpecularColor = (Degamma(MaterialSpecular * (LightDiffuse.r * 9 + 1))) * 0.95 + 0.05;
	// MaterialSpecular はモデルなら1、アクセサリなら1/10になる。
	// LightDiffuse は モデルなら0,0,0、アクセサリなら1,1,1になる。

float GetMetalness(float2 uv) { return METALNESS_VALUE; }

#if SMOOTHNESS_TYPE == 0
float GetSmoothnessSub(float2 uv) { return saturate((log2(SpecularPower+1)-1)/8.0); }
#else
float GetSmoothnessSub(float2 uv) { return SMOOTHNESS_VALUE; }
#endif
float GetSmoothness(float2 uv)
{
	float smoothness = GetSmoothnessSub(uv);
	#if SMOOTHNESS_MAP_ENABLE > 0
	float val = tex2D( TEXTURE_SAMPLER(0), uv * NORMALMAP_MAIN_LOOPNUM).x;
	smoothness = lerp(smoothness, val, BaseTexture);
	#endif
	return smoothness;
}


float GetSSSValue(float2 uv) { return SSS_VALUE; }

float GetIntensity(float2 uv)
{
	float intensity = INTENSITY_VALUE;
	#if INTENSITY_MAP_ENABLE > 0
	float val = tex2D( TEXTURE_SAMPLER(1), uv * NORMALMAP_MAIN_LOOPNUM).x;
	return saturate(lerp(intensity, lerp(1, val, INTENSITY_VALUE), BaseTexture));
	#else
	return saturate(intensity);
	#endif
}


#define ANISO_NUM 16
#define DECL_NORMAL_TEXTURE( _name, _res) \
	texture2D _name##Map < string ResourceName = _res; >; \
	sampler2D _name##Samp = sampler_state { \
		texture = <_name##Map>; \
		MINFILTER = ANISOTROPIC;	MAGFILTER = ANISOTROPIC;	MIPFILTER = ANISOTROPIC; \
		MAXANISOTROPY = ANISO_NUM; \
		AddressU  = WRAP;	AddressV  = WRAP; \
	}; \

#if NORMALMAP_ENABLE > 0
//メイン法線マップ
DECL_NORMAL_TEXTURE( NormalMain, NORMALMAP_MAIN_FILENAME)
#if NORMALMAP_SUB_ENABLE > 0
DECL_NORMAL_TEXTURE( NormalSub, NORMALMAP_SUB_FILENAME)
#endif
#endif

#if PARALLAX_ENABLE > 0
DECL_NORMAL_TEXTURE( Height, PARALLAX_FILENAME)
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

float SIGN(float f) { return (f >= 0.0) ? 1 : -1; }

float3x3 ComputeTangent(float3 N, float3 V, float2 UV)
{
	float3 dp1 = ddx(V);
	float3 dp2 = ddy(V);
	float2 duv1 = ddx(UV);
	float2 duv2 = ddy(UV);
	float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
	float2x3 invM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 T0 = normalize(mul(float2(duv1.x, duv2.x), invM));
	float3 B0 = normalize(mul(float2(duv1.y, duv2.y), invM));

	// to be orthogonal matrix
	float3 B = normalize(cross(N, T0));
	float3 T = normalize(cross(B, N));
	B *= SIGN(dot(B, B0));
	T *= SIGN(dot(T, T0));

	return float3x3(T, B, N);
}

#if NORMALMAP_ENABLE > 0

float3 CalcNormal(float2 Tex, float3x3 matTangentToWorld)
{
	float2 tex = Tex * NORMALMAP_MAIN_LOOPNUM; //メイン
	float4 NormalColor = tex2D( NormalMainSamp, tex) * 2 - 1;
	NormalColor.xy *= NORMALMAP_MAIN_HEIGHT;

	#if NORMALMAP_SUB_ENABLE > 0
	float2 texSub = Tex * NORMALMAP_SUB_LOOPNUM; //サブ
	float4 NormalColorSub = tex2D( NormalSubSamp, texSub) * 2 - 1;
	NormalColor.xy += NormalColorSub.xy * NORMALMAP_SUB_HEIGHT;
	#endif

	NormalColor.xyz = normalize(NormalColor.xyz);
	NormalColor.w = 1;

	#if NORMALMAP_FLIP == 3
	NormalColor.xy *= -1;
	#elif NORMALMAP_FLIP == 1
	NormalColor.x *= -1;
	#elif NORMALMAP_FLIP == 2
	NormalColor.y *= -1;
	#endif

	// NormalColor = normalize(NormalColor);
	return normalize(mul(NormalColor, matTangentToWorld));
}
#else
float4 CalcNormal(float2 Tex,float3 Eye,float3 Normal)
{
	return float4(Normal,1);
}
#endif


#if PARALLAX_ENABLE > 0
float4 GetParallaxOffset(float2 uv, float3 V, float3x3 matTangentToWorld)
{
	float3x3 matWorldToTangent = transpose(matTangentToWorld);
	matWorldToTangent[0] = normalize(matWorldToTangent[0]);
	matWorldToTangent[1] = normalize(matWorldToTangent[1]);
	matWorldToTangent[2] = normalize(matWorldToTangent[2]);
	float3 vUv = mul(V, matWorldToTangent);
	vUv.xyz = normalize(vUv.xyz);
	vUv.xy *= (PARALLAX_LENGTH) * (PARALLAX_HEIGHT) / (vUv.z + 0.4142);

	float2 dx = ddx(uv);
	float2 dy = ddy(uv);

	float3 uv0 = float3(uv * PARALLAX_LOOPNUM, 1);
	float3 vuv = float3(vUv.xy * PARALLAX_LOOPNUM, -1) * (1.0 / PARALLAX_ITERATION);
	float3 uv1 = uv0 - vuv;
	float2 prevH = float2(1, 1);
	float4 pt = 0;

	for(int i = 0; i <= PARALLAX_ITERATION; i++)
	{
		uv1 += vuv;
		float h = tex2Dgrad(HeightSamp, uv1.xy, dx, dy).x;
		// float h = GET_CHANNEL_VALUE(tex2Dgrad(HeightSamp, uv1.xy, dx, dy), PARALLAX__CHANNEL);
		float2 curH = float2(uv1.z, h);
		if (curH.x <= curH.y)
		{
			pt = float4(curH, prevH.xy);
			uv1 -= vuv;
			vuv *= 0.5;
		}
		else
		{
			prevH = curH;
		}
	}

	float2 fd = pt.xz - pt.yw;
	float denom = fd.y - fd.x;
	float z = (abs(denom) > 1e-4)
		? saturate((pt.x * fd.y - pt.z * fd.x) / denom)
		: 0;

	float h0 = tex2Dgrad(HeightSamp, uv0.xy, dx, dy).x;
	if (h0 == 1) z = 1;

	// float height = z;
	uv1.xy = uv0.xy + vUv.xy * PARALLAX_LOOPNUM * (1 - z);
	float height = tex2Dgrad(HeightSamp, uv1.xy, dx, dy).x;
	height *= PARALLAX_HEIGHT;

	return float4(vUv.xy * (1.0 - z), height, 1);
}
#endif


float4 GetTextureColor(float2 uv)
{
	float4 TexColor = tex2D( ObjTexSampler, uv);
	TexColor = lerp(1, TexColor, BaseTexture);

	#if EMISSIVE_TYPE == 4
	TexColor.rgb = tex2D( LightSamp, uv).rgb;
	#endif

	TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;

	TexColor.rgb *= hsv2rgb( float3(HSV_H, HSV_S, HSV_V));

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
	float3 V = normalize(CameraPosition - IN.WPos.xyz);
	float3 Norig = normalize(IN.Normal);
	float depth = IN.WPos.w;
	float2 texCoord = IN.Tex.xy;

	#if PARALLAX_ENABLE > 0 || NORMALMAP_ENABLE > 0
	float3x3 matTangentToWorld = ComputeTangent(Norig, V, texCoord);
	#endif

	#if PARALLAX_ENABLE > 0
	float4 offset = GetParallaxOffset(texCoord, V, matTangentToWorld);
	texCoord.xy += offset.xy;
	depth -= offset.z;
	#endif

	#if NORMALMAP_ENABLE > 0
	float3 N = CalcNormal(texCoord, matTangentToWorld);
	#else
	float3 N = Norig;
	#endif

	float4 albedo = DiffuseColor;
	if ( useTexture ) albedo *= GetTextureColor(texCoord);
	clip(albedo.a - AlphaThreshold);

	#if !defined(IGNORE_SPHERE)
	if ( useSphereMap && !spadd) albedo.rgb *= GetSphereColor(IN.SpTex).rgb;
	#endif
	albedo.rgb = Degamma(albedo.rgb);

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
	float attribute = (emissive >= 1.0/255.0) ? (MT_EMISSIVE) : (MATERIAL_TYPE);
	float extraValue = (attribute == MT_EMISSIVE) ? emissive : sssValue;

	#if INTENSITY_TYPE == 0
	// 何もしない
	#elif INTENSITY_TYPE == 1
	attribute += MT_AO;
	#elif INTENSITY_TYPE == 2
	attribute += MT_CAVITY;
	#elif INTENSITY_TYPE == 3
	attribute += MT_CAVITY;
	float NV = saturate(dot(N,V));
	float cavity = (1.0 - NV) * (1.0 - NV);
	intensity = lerp(intensity, 1, cavity);
	#endif
	float extraValue2 = intensity;
	float materialID = attribute / 255.0;

	#if SPECULAR_COLOR_TYPE == 0
	// OLD STYLE
	float3 speccol = (albedo.rgb * 0.5 + 0.5) * SpecularColor;
	albedo.rgb = lerp(albedo.rgb, speccol, metalness);
	#elif SPECULAR_COLOR_TYPE == 1
	// なにもしない
	#elif SPECULAR_COLOR_TYPE == 2
	// スペキュラ色のみで決定
	albedo.rgb = lerp(albedo.rgb, SpecularColor, metalness);
	#endif

	Out.Color = float4(albedo.rgb, extraValue2);
	Out.Material = float4(metalness, roughness, extraValue, materialID);
//	Out.Albedo = float4(albedo.rgb, 1);

#else
	// マスク
	Out.Color = float4(albedo.rgb, 0);
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



