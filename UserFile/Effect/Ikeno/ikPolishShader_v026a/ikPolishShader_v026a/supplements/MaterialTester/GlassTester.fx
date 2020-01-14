//-----------------------------------------------------------------------------
// GlassTester用にカスタマイズしたforward_glass.fx
//-----------------------------------------------------------------------------

#define TEST_CONTROLLER_NAME	"GlassTester.pmx"

// Smoothnessの指定方法：
// 0: モデルのスペキュラパワーから自動で決定する。
// 1: スムースネスを使用。
// 2: ラフネスを使用。
#define SMOOTHNESS_TYPE			1

#define	SMOOTHNESS_MAP_ENABLE	1	// 1:テクスチャを使う、0:使わない
#define SMOOTHNESS_MAP_FILE		"textures/stone_tiles_smoothness.png"

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

// 屈折表現を無効にするか?
// ikPolishShader.fxsub 内の ENABLE_REFRACTION が 1 かつ、
// DISABLE_REFRACTION が 0 のとき屈折が有効になる。
#define DISABLE_REFRACTION		0

// 厚みの計算方法
#define THICKNESS_TYPE			1
// 0: 固定値
// 1: 裏面ポリゴンとの差
// 2: 深度差 (水面に使用する)


// MMD標準のシャドウマップで陰影計算を行うか?
#define USE_MMD_SHADOW	0


//----------------------------------------------------------
// スペキュラ関連

// スフィアマップ無効
#define IGNORE_SPHERE	1

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.1;

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
// 草などアルファ抜きしている場合はエッジに強いハイライトが出ることがある。
#define ENABLE_SPECULAR_ALPHA	1


//----------------------------------------------------------
// その他

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)


// これよりも不透明度が低いなら除外する
const float CutoutThreshold = 1.0 / 255.0;


//-----------------------------------------------------------------------------
//

#include "../../ikPolishShader.fxsub"

#include "../../Sources/constants.fxsub"
#include "../../Sources/structs.fxsub"
#include "../../Sources/mmdparameter.fxsub"
#include "../../Sources/mmdutil.fxsub"
#include "../../Sources/colorutil.fxsub"
#include "../../Sources/lighting.fxsub"
#include "../../Sources/octahedron.fxsub"

#define IGNORE_EMISSIVE			// 環境色を無効にする。
#define	ENABLE_CLEARCOAT	0

#define SMOOTHNESS_MAP_LOOPNUM	NORMALMAP_MAIN_LOOPNUM
#define PARALLAX_LOOPNUM NORMALMAP_MAIN_LOOPNUM
#define SMOOTHNESS_MAP_SCALE	1.0
#define SMOOTHNESS_MAP_OFFSET	0.0


//-----------------------------------------------------------------------------

float mDirectLightP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光+"; >;
float mDirectLightM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光-"; >;

bool bLinearBegin : CONTROLOBJECT < string name = "ikLinearBegin.x"; >;
bool bLinearEnd : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;
static bool bOutputLinear = (bLinearEnd && !bLinearBegin);


#define REF_CTRL	string name = TEST_CONTROLLER_NAME

float METALNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Metalness"; >;
float SMOOTHNESS_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Smoothness"; >;
float ALPHA_VALUE : CONTROLOBJECT < REF_CTRL; string item = "Transparent"; >;
float NORMALMAP_MAIN_HEIGHT : CONTROLOBJECT < REF_CTRL; string item = "NormalHeight"; >;
float NormalMapLoop  : CONTROLOBJECT < REF_CTRL; string item = "NormalLoop"; >;
static float NORMALMAP_MAIN_LOOPNUM = NormalMapLoop * 2.0 + 1.0;
float PARALLAX_HEIGHT : CONTROLOBJECT < REF_CTRL; string item = "ParallaxHeight"; >;
float BaseTexture : CONTROLOBJECT < REF_CTRL; string item = "BaseTexture"; >;

float HSV_H : CONTROLOBJECT < REF_CTRL; string item = "Hue"; >;
float HSV_S : CONTROLOBJECT < REF_CTRL; string item = "Saturation"; >;
float HSV_V_INV : CONTROLOBJECT < REF_CTRL; string item = "@Brightness"; >;
static float HSV_V = 1 - HSV_V_INV;
float SURFACE_ABSORPTION_RATE : CONTROLOBJECT < REF_CTRL; string item = "SurfaceAbsorption"; >;
float BODY_ABSORPTION_RATE : CONTROLOBJECT < REF_CTRL; string item = "BodyAbsorption"; >;


// 座法変換行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 WorldMatrix			: WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 ViewProjMatrix			: VIEWPROJECTION;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

// ライト色
float3	LightDiffuse		: DIFFUSE   < string Object = "Light"; >;
float3	LightSpecular		: SPECULAR  < string Object = "Light"; >;

#if defined(IGNORE_EMISSIVE)
static float3	BaseAmbient = MaterialAmbient;
static float3	BaseEmissive = 0;
#elif defined(EMISSIVE_AS_AMBIENT)
static float3	BaseAmbient = saturate(MaterialAmbient + MaterialEmissive);
static float3	BaseEmissive = 0;
#else
static float3	BaseAmbient = MaterialAmbient;
static float3	BaseEmissive = MaterialEmissive;
#endif

// ライトの強度
static float3 LightColor = LightSpecular * CalcLightValue(mDirectLightP, mDirectLightM, DefaultLightScale);

#if THICKNESS_TYPE == 1
#define BACKFACE_AWARE 1
#else
#define BACKFACE_AWARE 0
#endif

#if THICKNESS_TYPE == 2
shared texture PPPNormalMapRT: RENDERCOLORTARGET;
sampler NormalMap = sampler_state {
	texture = <PPPNormalMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
#endif

#if DISABLE_REFRACTION == 1 || REFRACTION_TYPE == 0
	#ifdef REFRACTION_TYPE
	#undef REFRACTION_TYPE
	#endif
	#define REFRACTION_TYPE		0

#else
	// 屈折マップを使う
	#if REFRACTION_TYPE == 1
	shared texture2D PPPRefractionMap1 : RENDERCOLORTARGET;
	sampler RefractionSamp1 = sampler_state {
		texture = <PPPRefractionMap1>;
		MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
		AddressU  = CLAMP;	AddressV = CLAMP;
	};
	#else

	#define DECL_REFRA_TEXTURE( _map, _samp, _size) \
		texture2D _map : RENDERCOLORTARGET; \
		sampler _samp = sampler_state { \
			texture = <_map>; \
			MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE; \
			AddressU = CLAMP; AddressV = CLAMP; \
		};

	shared DECL_REFRA_TEXTURE( PPPRefractionMap1, RefractionSamp1, 1)
	shared DECL_REFRA_TEXTURE( PPPRefractionMap4, RefractionSamp4, 1)
	shared DECL_REFRA_TEXTURE( PPPRefractionMap16, RefractionSamp16, 1)
	shared DECL_REFRA_TEXTURE( PPPRefractionMap64, RefractionSamp64, 1)

	#endif
#endif


#if BACKFACE_AWARE > 0
texture2D BackfaceTex : RenderColorTarget
<
	bool AntiAlias = false;
	int Miplevels = 1;
//	string Format = "R16F" ; // 深度のみ
	string Format = "G16R16F" ; // 深度+ラフネス
>;
sampler BackfaceSmp = sampler_state {
	texture = <BackfaceTex>;
	AddressU  = CLAMP; AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;
#endif

#if SMOOTHNESS_TYPE == 0
float GetSmoothness(float2 uv) { return saturate((log2(SpecularPower+1)-1)/8.0); }
#else
float GetSmoothness(float2 uv) { return SMOOTHNESS_VALUE; }
#endif


shared texture PPPEnvMap2: RENDERCOLORTARGET;
sampler EnvMapSamp0 = sampler_state {
	texture = <PPPEnvMap2>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU  = WRAP;	AddressV = WRAP;
};

texture2D EnvironmentBRDFTex <
	string ResourceName = "../../Sources/Assets/EnvironmentBRDF.dds";
	// string Format = "A16B16G16R16F";
	int MipLevels = 1;
>;
sampler EnvironmentBRDF = sampler_state {
	texture = <EnvironmentBRDFTex>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV  = CLAMP;
};


#define TEXTURE_SAMPLER(_TexID)	TextureSamp_##_TexID

#define DECL_TEXTURE( _TexID, _fname) \
	texture TextureMap_##_TexID < string ResourceName = _fname; >; \
	sampler TEXTURE_SAMPLER(_TexID) = sampler_state { \
		texture = <TextureMap_##_TexID>; \
		MinFilter = Linear;	MagFilter = Linear;	MipFilter = None; \
		AddressU  = WRAP;	AddressV  = WRAP; \
	};

#if SMOOTHNESS_MAP_ENABLE > 0
DECL_TEXTURE(0, SMOOTHNESS_MAP_FILE)
#endif

#define ANISO_NUM 16
#define DECL_NORMAL_TEXTURE( _name, _res) \
	texture _name##Map < string ResourceName = _res; >; \
	sampler _name##Samp = sampler_state { \
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



struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float4 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float4 PPos		: TEXCOORD4;	// スクリーン座標
	#if IGNORE_SPHERE == 0
	float2 SpTex	: TEXCOORD5;	// スフィアマップテクスチャ座標
	#endif
	float4 ToonColor	: TEXCOORD6;
	float4 WPos		: TEXCOORD7;
};

struct LightingResult
{
	float3 diffuse;
	float3 specular;
};


static float MAX_MIP_LEVEL = log2(ENV_WIDTH) - 1.0;

static float IoR = 1.0 / (METALNESS_VALUE / 0.25 + 1.0); // 適当


float4 GetEnvColor(float3 vec, float roughness)
{
	float s = 1 - roughness;
	roughness = (1 - s * s);

	float lod = roughness * MAX_MIP_LEVEL;
	float2 uv = EncodeOctahedron(vec);
	return tex2Dlod(EnvMapSamp0, float4(uv,0,lod));
}

#if ENABLE_CLEARCOAT > 0
static float ClearcoatRoughness = ConvertToRoughness(ClearcoatSmoothness);

float3 ApplyClearCoat(BufferShadow_OUTPUT IN,
	float shadow, float3 bodyColor, inout float3 specular, float roughness)
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);
	float3 NPoly = N;

	float3 clearcoatN = N; // normalize(lerp(N, NPoly, USE_POLYGON_NORMAL));
	float3 clearcoatR = reflect(-V, clearcoatN);
	float clearcoatNV = abs(dot(clearcoatN, V));

	float3 brdf = tex2D(EnvironmentBRDF, float2(roughness, clearcoatNV)).xyz;
	float3 reflectance = (ClearcoatF0 * brdf.x + brdf.y);

	float3 diffuse = CalcDiffuse(L, clearcoatN, V) * shadow * LightColor;
	diffuse += GetEnvColor(clearcoatN, 1.0) * brdf.z;

	float coatThickness = (1 - clearcoatNV) * (1 - ClearcoatColor.a) + ClearcoatColor.a;
	coatThickness *= ClearcoatColor.a;
	bodyColor = lerp(bodyColor, ClearcoatColor.rgb * diffuse, coatThickness);
	specular *= lerp(1, ClearcoatColor.rgb, coatThickness);

	float3 ccSpecular;
	ccSpecular = CalcSpecular(L, clearcoatN, V, roughness, ClearcoatF0);
	ccSpecular *= LightColor * shadow;
	ccSpecular += GetEnvColor(clearcoatR, roughness) * reflectance;
	specular = lerp(specular, ccSpecular, ClearcoatIntensity);

	return bodyColor;
}
#endif


#if SMOOTHNESS_TYPE == 2
float ConvertToRoughness(float val) { return val; }
#else
float ConvertToRoughness(float val) { return 1 - val; }
#endif

float GetRoughness(float2 uv)
{
	#if SMOOTHNESS_MAP_ENABLE > 0
	float smoothness = tex2D(TEXTURE_SAMPLER(0), uv * SMOOTHNESS_MAP_LOOPNUM).r;
	smoothness = lerp(GetSmoothness(uv), smoothness, BaseTexture);
	#else
	float smoothness = GetSmoothness(uv);
	#endif
	return saturate(ConvertToRoughness(smoothness));
}


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

	// Tを元にBを再構築する。
	// N == T の場合、Bは0付近になるので、生のBを使う
	float3 B1 = cross(N, T0);
	if (dot(B1,B1) < 1e-4) B1 = B0;
	if (dot(B1,B1) < 1e-4) B1 = N.zxy * float3(1,-1,-1);

	// to be orthogonal matrix
	float3 B = normalize(B1);
	float3 T = normalize(cross(B, N));
	B *= SIGN(dot(B, B0));
	T *= SIGN(dot(T, T0));

	return float3x3(T, B, N);
}

#if NORMALMAP_ENABLE > 0

float3 CalcNormal(float2 Tex, float3x3 matTangentToWorld)
{
	float2 tex = Tex * NORMALMAP_MAIN_LOOPNUM; //メイン
	float3 NormalColor = tex2D( NormalMainSamp, tex).xyz * 2 - 1;
	NormalColor.xy *= NORMALMAP_MAIN_HEIGHT;

	#if NORMALMAP_SUB_ENABLE > 0
	float2 texSub = Tex * NORMALMAP_SUB_LOOPNUM; //サブ
	float3 NormalColorSub = tex2D( NormalSubSamp, texSub).xyz * 2 - 1;
	NormalColor.xy += NormalColorSub.xy * NORMALMAP_SUB_HEIGHT;
	#endif

	NormalColor.xyz = normalize(NormalColor.xyz);

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


void PerturbateTexCoord(inout BufferShadow_OUTPUT IN)
{
#if PARALLAX_ENABLE > 0 || NORMALMAP_ENABLE > 0

	float3 V = normalize(CameraPosition - IN.WPos.xyz);
	float3 Norig = normalize(IN.Normal);
	float2 texCoord = IN.Tex.xy;

	float3x3 matTangentToWorld = ComputeTangent(Norig, V, texCoord);

	#if PARALLAX_ENABLE > 0
	float4 offset = GetParallaxOffset(texCoord, V, matTangentToWorld);
	texCoord.xy += offset.xy;
	IN.Tex.xy = texCoord;
	#endif

	#if NORMALMAP_ENABLE > 0
	IN.Normal = CalcNormal(texCoord, matTangentToWorld);
	#endif

#endif
}

//-----------------------------------------------------------------------------
//

float3 CalcNormalizedToon()
{
	float3 result = 1;
	if (use_toon)
	{
		float3 linearColor = Degamma(MaterialToon);
		float g = Luminance(linearColor);
		result = lerp(1, linearColor / max(g, 0.01), saturate(ToonColor_Scale));
	}

	return result;
}

static float3 NormalizedToon = CalcNormalizedToon();

float3 CalcToonColor(float3 c)
{
	float3 c0 = saturate(c);
	return (NormalizedToon * (c0 * c0 - c0) + c);
}

float3 CalcToonLight(float3 c, float3 toonColor)
{
	float g = saturate(Luminance(c) * 2.0 - 0.5);
	return c * lerp(toonColor, 1, g);
}

static float3 MaterialBaseColor = Degamma((!use_toon) ? MaterialDiffuse.rgb : BaseAmbient);

float3 hsv2rgb(float3 c)
{
	float3 hcol = saturate((abs(frac(c.x + float3(3,2,1)/3)*6 - 3) - 1));
	return float3(lerp(1, hcol, c.y) * c.z);
}


float4 GammaCorrect(float4 c)
{
	return bOutputLinear ? c : Gamma(c);
}

float CalcShadow(float4 zcalc, float shadowVal)
{
	#if USE_MMD_SHADOW > 0
	return CalcMMDShadow(zcalc);
	#else
	return 1;
	#endif
}

float2 CalcScreenPosition(float4 ppos)
{
	float2 texCoord = ppos.xy / ppos.w * float2(0.5, -0.5) + 0.5;
	texCoord += ViewportOffset;
	return texCoord;
}

float GetThickness(BufferShadow_OUTPUT IN, float2 ppos)
{
	#if THICKNESS_TYPE == 0
		float3 V = normalize(IN.Eye);
		float3 N = normalize(IN.Normal);
		float thickness = 0.1 / max(abs(dot(N,V)), 0.3); // 仮の厚み

	#elif THICKNESS_TYPE == 1
		float backDist = tex2D(BackfaceSmp, ppos).x;
		float frontDist = length(IN.Eye);
		float thickness = max(backDist - frontDist, 0.1);

	#else
		float backDist = tex2D(NormalMap, ppos).w;
		float frontDist = length(IN.Eye);
		float thickness = max(backDist - frontDist, 0.1);

	#endif

	return thickness;
}

float2 RefractiveScreenPosition(BufferShadow_OUTPUT IN, float2 ppos, float thickness)
{
#if REFRACTION_TYPE > 0
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);
	float3 R = normalize(refract(-V, N, IoR));

	float4 wpos = IN.WPos;
	wpos.xyz += R * thickness;

	return CalcScreenPosition( mul( wpos, ViewProjMatrix ) );
#else
	return ppos;
#endif
}

float3 GetRefractiveColor(BufferShadow_OUTPUT IN, float2 ppos, float thickness, float roughness)
{
#if REFRACTION_TYPE == 1

	float lod = saturate(roughness) * 6.0;
	return tex2Dlod(RefractionSamp1, float4(ppos,0,lod));

#elif REFRACTION_TYPE > 1

	float lod = saturate(roughness) * 3.0;
	float4 col0 = tex2D(RefractionSamp1, ppos);
	float4 col1 = tex2D(RefractionSamp4, ppos);
	float4 col2 = tex2D(RefractionSamp16, ppos);
	float4 col3 = tex2D(RefractionSamp64, ppos);
	col0 = lerp(col0, col1, saturate(lod));
	col0 = lerp(col0, col2, saturate(lod-1));
	col0 = lerp(col0, col3, saturate(lod-2));
	return col0.rgb;

#else
	return 0;
#endif
}


float3 CalcReflectance(BufferShadow_OUTPUT IN, MaterialParam mat)
{
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);
	float NV = abs(dot(N, V));
	float2 brdf = tex2D(EnvironmentBRDF, float2(mat.roughness, NV)).xy;
	return (mat.f0 * brdf.x + brdf.y);
}

LightingResult CalcLighting(BufferShadow_OUTPUT IN, MaterialParam mat, float shadow)
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);

	// 拡散反射(直接光+環境光)
	float diffuse = CalcDiffuse(L, N, V);
	float3 light = (diffuse * shadow) * LightColor;
	light *= (1.0 - mat.metalness);
	light = CalcToonLight(light, IN.ToonColor.rgb);

	// 鏡面反射
	float3 specular = CalcSpecular(L, N, V, mat.roughness, mat.f0);
	float3 R = reflect(-V, N);
	float3 reflectance = CalcReflectance(IN, mat);
	float3 SpSpecular = GetEnvColor(R, mat.roughness).rgb * reflectance;
	specular = specular * LightSpecular * shadow + SpSpecular;

	LightingResult Out;
	Out.diffuse = light;
	Out.specular = specular;
	return Out;
}

float BackSurfaceRoughness(float roughness, float2 ppos)
{
	#if BACKFACE_AWARE > 0

	#if 0
	float backRoughness = tex2D(BackfaceSmp, ppos).y;
	#else
	// ノイズが必要
	float maxLod = log2(ViewportSize.y);
	float lod = max(roughness * maxLod - 1, 0); // 表面のラフネスの影響を受ける
	float col = roughness; // ad-hoc
	#define REFRACTION_LOOP 2
	float2 duv = (lod + 0.25) / REFRACTION_LOOP / ViewportSize;
	for(int vy = -REFRACTION_LOOP; vy <= REFRACTION_LOOP; vy++) {
		for(int vx = -REFRACTION_LOOP; vx <= REFRACTION_LOOP; vx++) {
			float2 uv = ppos + duv * float2(vx,vy);
			col = max(col, tex2Dlod(BackfaceSmp, float4(uv,0,0)).y);
		}
	}
	float backRoughness = col;
	#endif

	#else
	// 裏面が無い場合は、表と同じ値にする
	float backRoughness = roughness;
	#endif
	backRoughness = saturate(1.0 - (1.0 - roughness) * (1.0 - backRoughness));

	return backRoughness;
}

float4 ApplyRefractionColor(BufferShadow_OUTPUT IN, MaterialParam mat, float4 result)
{
	#if REFRACTION_TYPE > 0
	float2 ppos = CalcScreenPosition(IN.PPos);

	float thickness = GetThickness(IN, ppos);
	float2 uv = RefractiveScreenPosition(IN, ppos, thickness);
	float backRoughness = BackSurfaceRoughness(mat.roughness, uv);

	float3 background = GetRefractiveColor(IN, uv, thickness, backRoughness);
	float3 reflectance = CalcReflectance(IN, mat);

	float3 absorptionColor = (1.0 - mat.albedo) * BODY_ABSORPTION_RATE;
	float3 bodyAbsorption = exp2(-max(thickness * absorptionColor, 0.001));
	float3 surafaceAbsorption = lerp(1, mat.albedo, saturate(SURFACE_ABSORPTION_RATE));
	float3 absorption = bodyAbsorption * surafaceAbsorption;

	background *= absorption * (1.0 - reflectance);
	result.rgb = lerp(background, result.rgb, result.a);

	result.a = 1; // 不透明扱い
	#else

	#endif
	return result;
}



float4 AdjustAlpha(float4 result, float3 specular)
{
#if ENABLE_SPECULAR_ALPHA > 0
	// スペキュラに応じて不透明度を上げる。
	result.rgb = result.rgb * result.a + specular;
	float2 luminnance = max(result.rg, result.ba);
	float alpha = saturate(max(luminnance.x, luminnance.y));
	result.rgb /= max(alpha, 1.0/1024);
	result.a = alpha;
#else

	result.rgb += specular;
#endif
	return result;
}




//-----------------------------------------------------------------------------
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD0;	// Zバッファテクスチャ
};

VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );
	Out.ShadowMapTex = Out.Pos;
	return Out;
}

float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0, float2 Tex : TEXCOORD1 ) : COLOR
{
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ZValuePlot_VS();
		PixelShader  = compile ps_3_0 ZValuePlot_PS();
	}
}


//-----------------------------------------------------------------------------
// オブジェクト描画

BufferShadow_OUTPUT DrawObject_VS(
	VS_AL_INPUT IN, uniform bool useSelfShadow)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	float4 Pos = IN.Pos;
	float3 Normal = IN.Normal.xyz;

	Out.Pos = mul( Pos, WorldViewProjMatrix );

	float4 WPos = mul( Pos, WorldMatrix );
	Out.WPos = WPos;
	Out.Eye = CameraPosition - WPos.xyz; // NOTE: 単位ベクトルではない

	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfShadow)
	{
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	Out.PPos = Out.Pos;
	Out.Tex.xy = IN.Tex;

	#if IGNORE_SPHERE == 0
	if ( use_spheremap && use_subtexture) Out.SpTex = IN.AddUV1.xy;
	#endif


	Out.ToonColor.rgb = CalcNormalizedToon();

	return Out;
}

float4 DrawObject_PS(BufferShadow_OUTPUT IN, uniform bool useSelfShadow) : COLOR
{
	PerturbateTexCoord(IN);

	// 素材自体の色
	float4 albedo = float4(MaterialBaseColor, 1);
	if ( use_texture )
	{
		float4 texColor = Degamma(GetTextureColor(IN.Tex.xy));
		albedo *= lerp(1, texColor, BaseTexture);
		albedo.rgb *= hsv2rgb( float3(HSV_H, HSV_S, HSV_V));
	}

	float3 SpSpecular = 0;
	#if IGNORE_SPHERE == 0
	if ( use_spheremap ) {
		float2 SpTex = mul( N, (float3x3)ViewMatrix ).xy * float2(0.5, -0.5) + 0.5;
		float4 TexColor = GetSphereColor(use_subtexture ? IN.SpTex : SpTex);
		if(spadd) {
			SpSpecular = TexColor.rgb * LightSpecular * SphereScale;
		} else {
			albedo.rgb *= (Degamma(TexColor.rgb) * SphereScale + (1.0 - SphereScale));
		}
	}
	#endif

	float roughness = GetRoughness(IN.Tex.xy);

	MaterialParam mat = {
		METALNESS_VALUE,
		roughness,
		1, // intensity
		1, // AO
		1, // Cavity
		0, // sssvalue
		0, // emissive
		lerp(METALNESS_VALUE * (1.0 - 0.05) + 0.05, albedo.rgb, METALNESS_VALUE),
		1,
		albedo.rgb
	};

	albedo.a *= MaterialDiffuse.a * lerp(0.01, 1.0, ALPHA_VALUE);
	clip(albedo.a - CutoutThreshold);
	albedo.a = saturate(albedo.a);

	float shadow = (useSelfShadow) ? CalcShadow(IN.ZCalcTex, 1) : 1;
	LightingResult lighting = CalcLighting(IN, mat, shadow);
	float3 specular = lighting.specular + SpSpecular;
	float4 result = float4(lighting.diffuse, 1.0) * albedo;
	result = ApplyRefractionColor(IN, mat, result);

	result.rgb += BaseEmissive;

	#if ENABLE_CLEARCOAT > 0
	result.rgb = ApplyClearCoat(IN, shadow, result.rgb, specular, ClearcoatRoughness);
	#endif

	result = AdjustAlpha(result, specular);
	result = GammaCorrect(result);
	return result;
}


#if BACKFACE_AWARE > 0
struct Backface_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float4 Tex		: TEXCOORD0;	// テクスチャ
//	float3 Normal	: TEXCOORD1;	// 法線
	float Distance	: TEXCOORD2;
};

Backface_OUTPUT DrawBackface_VS(VS_AL_INPUT IN)
{
	Backface_OUTPUT Out = (Backface_OUTPUT)0;

	float4 Pos = IN.Pos;
	float3 Normal = IN.Normal.xyz;
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Tex.xy = IN.Tex;

	float4 WPos = mul( Pos, WorldMatrix );
	Out.Distance = distance(CameraPosition, WPos.xyz);
//	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	return Out;
}

// 裏面のスムースネスも出力する
float4 DrawBackface_PS(Backface_OUTPUT IN) : COLOR
{
	// テクスチャを見て透明なら破棄?
	float roughness = GetRoughness(IN.Tex.xy);
//	float3 N = normalize(IN.Normal);
	return float4(IN.Distance, roughness, 0,1);
}
#endif

#if BACKFACE_AWARE > 0
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
	string Script = \
		"RenderColorTarget0=BackfaceTex;" \
		"RenderDepthStencilTarget=DepthBuffer;" \
		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth; Clear=Color; Clear=Depth;" \
		"Pass=DrawBackface;" \
	\
		"RenderColorTarget0=;" \
		"RenderDepthStencilTarget=;" \
		"Pass=DrawObject;" \
	; > { \
		pass DrawBackface { \
			CullMode = CW; AlphaBlendEnable = false; AlphaTestEnable = false; \
			VertexShader = compile vs_3_0 DrawBackface_VS(); \
			PixelShader  = compile ps_3_0 DrawBackface_PS(); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
	}

#else
#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
	}

#endif


OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTecBS0, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}

//-----------------------------------------------------------------------------

