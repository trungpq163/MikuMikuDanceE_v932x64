//-----------------------------------------------------------------------------
// 汎用のプリセット。

//----------------------------------------------------------
// SSS用の設定

// ベルベット効果を有効にするか?
#define ENABLE_VELVET	0
const float VelvetExponent = 2.0;			// 縁の大きさ
const float VelvetBaseReflection = 0.01;	// 正面での明るさ 
#define VELVET_MUL_COLOR		float3(0.50, 0.50, 0.50)	// 正面の色(乗算)
#define VELVET_MUL_RIM_COLOR	float3(1.00, 1.00, 1.00)	// 縁の色(乗算)
#define VELVET_ADD_COLOR		float3(0.00, 0.00, 0.00)	// 正面の色(加算)
#define VELVET_ADD_RIM_COLOR	float3(0.00, 0.00, 0.00)	// 縁の色(加算)

//----------------------------------------------------------
// スペキュラ関連

// 髪の毛の専用のスペキュラを追加する
#define ENABLE_HAIR_SPECULAR	0
// 髪の毛のツヤ
const float HairSmoothness = 0.5;	// (0～1)
// 髪の毛のスペキュラの強さ
const float HairSpecularIntensity = 1.0;	// (0～1)
// 髪の毛の向きの基準になるボーン名
// #define HAIR_CENTER_BONE_NAME	"頭"


// スフィアマップ無効。
#define IGNORE_SPHERE	1

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.1;

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
// 草などアルファ抜きしている場合はエッジに強いハイライトが出ることがある。
#define ENABLE_SPECULAR_ALPHA	0


//----------------------------------------------------------
// その他

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)

// アルファをカットアウトする
// 葉っぱなどの抜きテクスチャで縁が汚くなる場合に使う。
#define Enable_Cutout	0
#define CutoutThreshold	0.5		// 透明/不透明の境界の値


//=============================================================================
// MikuMikuMob対応 ここから

// &InsertHeader;  ここにMikuMikuMob設定ヘッダコードが挿入されます

// MikuMikuMob対応 ここまで
//=============================================================================


//----------------------------------------------------------
// 共通処理の読み込み

//-----------------------------------------------------------------------------
//

#include "ikPolishShader.fxsub"
#include "constants.fxsub"
#include "structs.fxsub"
#include "mmdutil.fxsub"
#include "colorutil.fxsub"
#include "lighting.fxsub"

bool ExistPolish : CONTROLOBJECT < string name = "ikPolishShader.x"; >;


// 拡散反射
shared texture2D PPPDiffuseMap : RENDERCOLORTARGET;
sampler DiffuseMapSamp = sampler_state {
	texture = <PPPDiffuseMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// 鏡面反射
shared texture2D PPPReflectionMap : RENDERCOLORTARGET;
sampler ReflectionMapSamp = sampler_state {
	texture = <PPPReflectionMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// バックライト、ベルベット、クリアコートで法線を使う。それ以外は不要
#if !defined(DISABLE_NORMALMAP)
// 法線マップ
shared texture PPPNormalMapRT: RENDERCOLORTARGET;
sampler NormalMap = sampler_state {
	texture = <PPPNormalMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
#endif

//-----------------------------------------------------------------------------

float mDirectLightP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光+"; >;
float mDirectLightM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光-"; >;

bool bLinearBegin : CONTROLOBJECT < string name = "ikLinearBegin.x"; >;
bool bLinearEnd : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;
static bool bOutputLinear = (bLinearEnd && !bLinearBegin);

// 座法変換行列
float4x4 matW			: WORLD;
float4x4 matV			: VIEW;
float4x4 matVP			: VIEWPROJECTION;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

// ライト色
float3	LightDiffuse		: DIFFUSE   < string Object = "Light"; >;
float3	LightSpecular		: SPECULAR  < string Object = "Light"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float3	MaterialToon		: TOONCOLOR;

// アクセサリのスペキュラは1/10されているのでそれを補正する
//#define SpecularColor	Degamma(MaterialSpecular * (LightDiffuse.r * 9 + 1))

static float3	BaseAmbient = MaterialAmbient;
static float3	BaseEmissive = MaterialEmissive;

// ライトの強度
static float3 LightColor = LightSpecular * CalcLightValue(mDirectLightP, mDirectLightM, DefaultLightScale);

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

bool use_texture;
bool use_subtexture;	// サブテクスチャフラグ
bool use_spheremap;
bool use_toon;

bool	transp;   // 半透明フラグ
#define Toon	3

float ConvertToRoughness(float val) { return (1 - val) * (1 - val); }


/*
#if !defined(DISABLE_NORMALMAP)
float4 AdjustTexCoord(float4 nd, inout float2 texCoord)
{
	float4 nd0 = tex2D(NormalMap, texCoord);
	float4 nd1 = tex2D(NormalMap, texCoord + float2(-1, 0) / ViewportSize);
	float4 nd2 = tex2D(NormalMap, texCoord + float2( 1, 0) / ViewportSize);
	float4 nd3 = tex2D(NormalMap, texCoord + float2( 0,-1) / ViewportSize);
	float4 nd4 = tex2D(NormalMap, texCoord + float2( 0, 1) / ViewportSize);

	float d0 = abs(nd0.w - nd.w);
	float d1 = abs(nd1.w - nd.w);
	float d2 = abs(nd2.w - nd.w);
	float d3 = abs(nd3.w - nd.w);
	float d4 = abs(nd4.w - nd.w);

	// エッジではない
	if (d0 < 1.0)
	{
		return nd0;
	}

	if (d1 < 1.0) texCoord.x -= 1.0 / ViewportSize.x;
	if (d2 < 1.0) texCoord.x += 1.0 / ViewportSize.x;
	if (d3 < 1.0) texCoord.y -= 1.0 / ViewportSize.y;
	if (d4 < 1.0) texCoord.y += 1.0 / ViewportSize.y;

	return nd;
}
#endif
*/


#if ENABLE_HAIR_SPECULAR > 0
//-----------------------------------------------------------------------------
// 髪の毛のスペキュラ

#if !defined(HAIR_CENTER_BONE_NAME)
#define HAIR_CENTER_BONE_NAME	"頭"
#endif
float4x4 mHeadMat : CONTROLOBJECT < string name = "(self)"; string item = HAIR_CENTER_BONE_NAME; >;
float3 mHeadPos : CONTROLOBJECT < string name = "(self)"; string item = HAIR_CENTER_BONE_NAME; >;

float3 ComputeHairTangent(float3 N, float3 V, float3 WPos, float2 UV)
{
	// Tは根本から毛先方向を指す。
#if 0
	// タンジェントマップを見て決める
	float3 dp1 = ddx(V);
	float3 dp2 = ddy(V);
	float2 duv1 = ddx(UV);
	float2 duv2 = ddy(UV);
	float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
	float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 T = normalize(mul(float2(duv1.x, duv2.x), inverseM));
	float3 B = normalize(mul(float2(duv1.y, duv2.y), inverseM));
	float2 t = tex2D(TangentMap, UV).xy;
	T = normalize(T * t.x + B * t.y);
#else
	// 頭ボーンの下方向を向く
	// 距離が離れるほど頭の中心からの距離にする
	float3 T0 = -mHeadMat[1].xyz;
	float3 T1 = WPos - mHeadPos;
	float l = length(T1);
	T1 /= max(l, 1);
	T0 = normalize(lerp(T0, T1, saturate(l - 5.0) ));
		// 50cm～60cmに掛けて接線の向きを補間する

	float3 B = normalize(cross(N, T0));
	float3 T = normalize(cross(B, N));
#endif

	return T;
}

// Gaussian distribution
float HairGaussian(float beta, float theta)
{
	#define SQRT_2PI	2.50662827		// sqrt(2.0 * PI) ≒ 2.5
	float beta2 = 2.0 * beta * beta;
	float theta2 = theta * theta;
//	return exp(-theta2 / beta2) / sqrt(PI * beta2);
	return exp(-theta2 / beta2) / (beta * SQRT_2PI);
}

// Marschnerを適当に改造したもの
float3 SimpleHairSepc(float3 N, float3 T, float3 V, float3 L, float smoothness, float3 attenuation)
{
	float shift = 3.0 * DEG_TO_RAD;	// キューティクルの傾き
	float roughness = lerp(10.0, 5.0, smoothness) * DEG_TO_RAD;	// 表面の粗さ。
	float t = 0.75; // 透過率

	float alphaR = -1.0 * shift;
	float alphaTT = 0.5 * shift;
	float alphaTRT = 2.0 * shift;
	float betaR = 1.0 * roughness;
	float betaTT = 0.5 * roughness;
	float betaTRT = 2.0 * roughness;

	float TL = dot(T, L);
	float thetaI = asin(TL);
	float thetaR = asin(dot(T, V));
	float thetaH = (thetaR + thetaI) * 0.5;
//	float thetaD = (thetaR - thetaI) * 0.5;

	float M_R = HairGaussian(betaR, thetaH - alphaR);
	float M_TT = HairGaussian(betaTT, thetaH - alphaTT);
	float M_TRT = HairGaussian(betaTRT, thetaH - alphaTRT);

	// 適当な色の減衰：経路が長いほど色が減衰する。
	float l = 1.0 / (abs(TL) + 0.1);
	float3 N_TT = exp(-l * attenuation);
	float3 N_TRT = N_TT * N_TT;

	// 適当な反射/透過率：光の総和を1以下に抑えるための処理
	float cosPhi = dot(N,L);
	float T_R = (1.0 - t) * saturate(cosPhi);
	float T_TT = (t * t) * saturate(cosPhi * -0.5 + 0.5);
	float T_TRT = (t * (1.0 - t) * t) * 1.0;

	return (M_R * T_R + M_TT *T_TT * N_TT + M_TRT * T_TRT * N_TRT) * HairSpecularIntensity;
}

float3 CalcHairColor()
{
	// 減衰色のブースト
	float3 attenuation = saturate(1.0 - Degamma(MaterialToon));
	float g0 = Luminance(attenuation);
	attenuation *= attenuation;
	attenuation *= attenuation;
	float g1 = Luminance(attenuation);
	attenuation = attenuation * g0 / max(g1, 0.01) + 0.01;
	return attenuation;
}

float3 GetHairSepcular(float3 N, float3 V, float3 L, float3 WPos, float2 uv, float3 attenuation)
{
	float3 T = ComputeHairTangent(N, V, WPos, uv);
	float3 hairSpec = SimpleHairSepc(N, T, V, L, HairSmoothness, attenuation);
	hairSpec *= Luminance(LightSpecular);
	return hairSpec;
}
#endif


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

float3 CalcToonLight(float3 c, float3 toonColor)
{
	float g = saturate(Luminance(c) * 2.0 - 0.5);
	return c * lerp(toonColor, 1, g);
}

static float3 MaterialBaseColor = Degamma(
	((!use_toon) ? MaterialDiffuse.rgb : BaseAmbient)
	#if IS_LIGHT > 0
		+ MaterialEmissive
	#endif
);


//-----------------------------------------------------------------------------
// オブジェクト描画

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標

	float4 Tex		: TEXCOORD0;	// テクスチャ
	float4 Normal	: TEXCOORD1;	// 法線, 深度
	float3 Eye		: TEXCOORD2;	// カメラとの相対位置
	float4 PPos		: TEXCOORD3;	// スクリーン座標
	#if IGNORE_SPHERE == 0
	float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
	#endif
	float4 ToonColor	: TEXCOORD5;

	#if ENABLE_HAIR_SPECULAR > 0
	float4 WPos		: TEXCOORD6;
	float4 HairColor	: TEXCOORD7;
	#endif
};

BufferShadow_OUTPUT DrawObject_VS(
	VS_AL_INPUT IN, int vIndex : _INDEX, uniform bool useSelfShadow)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	float4 LPos = mul( IN.Pos, matW );
	float3 LNormal = mul( IN.Normal.xyz, (float3x3)matW );
	MOB_TRANSFORM TrOut = MOB_TransformPositionNormal(LPos, LNormal, vIndex);
	float4 WPos = TrOut.Pos;
	float3 WNormal = TrOut.Normal;

	Out.Pos = mul( WPos, matVP );
	Out.Eye = CameraPosition - WPos.xyz;

	Out.Normal.xyz = WNormal;
	Out.Normal.w = mul(WPos, matV).z;

	Out.PPos = Out.Pos;
	Out.Tex.xy = IN.Tex;

	#if IGNORE_SPHERE == 0
	if ( use_spheremap && use_subtexture) Out.SpTex = IN.AddUV1.xy;
	#endif

	Out.ToonColor.rgb = CalcNormalizedToon();

	#if ENABLE_HAIR_SPECULAR > 0
	Out.WPos = WPos;
	Out.HairColor.rgb = CalcHairColor();
	#endif

	return Out;
}



float4 DrawObject_PS(BufferShadow_OUTPUT IN, uniform bool useSelfShadow) : COLOR
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal.xyz);
	float3 NPoly = N;

	float2 texCoord = IN.PPos.xy / IN.PPos.w * float2(0.5, -0.5) + 0.5;
	texCoord += ViewportOffset;

	// 素材自体の色
	float4 albedo = float4(MaterialBaseColor,1);

	#if !defined(DISABLE_NORMALMAP)
	// float4 nd = AdjustTexCoord(IN.Normal, texCoord);
	float4 nd = tex2D(NormalMap, texCoord);
	N = normalize(nd.xyz);
	#endif

	if ( use_texture )
	{
		albedo *= Degamma(GetTextureColor(IN.Tex.xy));
	}

	float3 subSpecular = 0;
	#if IGNORE_SPHERE == 0
	if ( use_spheremap ) {
		float2 SpTex = mul( N, (float3x3)matV ).xy * float2(0.5, -0.5) + 0.5;
		float4 TexColor = GetSphereColor(use_subtexture ? IN.SpTex : SpTex);
		if(spadd) {
			subSpecular = TexColor.rgb * LightSpecular * SphereScale;
		} else {
			albedo.rgb *= (Degamma(TexColor.rgb) * SphereScale + (1.0 - SphereScale));
		}
	}
	#endif

	#if defined(ENABLE_VELVET) && ENABLE_VELVET > 0
	float velvetLevel = pow(1.0 - abs(dot(N,V)), VelvetExponent);
	velvetLevel = saturate(velvetLevel * (1.0 - VelvetBaseReflection) + VelvetBaseReflection);
	float3 velvetMulCol = lerp(VELVET_MUL_COLOR, VELVET_MUL_RIM_COLOR, velvetLevel);
	float3 velvetAddCol = lerp(VELVET_ADD_COLOR, VELVET_ADD_RIM_COLOR, velvetLevel);
	albedo.rgb = saturate(albedo.rgb * velvetMulCol + velvetAddCol);
	#endif

	// ライトの計算
	float4 diffusemap = tex2D(DiffuseMapSamp, texCoord);
	float4 specmap = tex2D(ReflectionMapSamp, texCoord);
	float shadow = (useSelfShadow) ? diffusemap.w : 1;

	// 拡散反射(直接光+環境光)
	float3 light = diffusemap.rgb;

	// 鏡面反射
	float3 specular = specmap.rgb + subSpecular;
	// 髪の毛のスペキュラ
	#if ENABLE_HAIR_SPECULAR > 0
	float3 hairSpec = GetHairSepcular(N, V, L, IN.WPos.xyz, texCoord, IN.HairColor.rgb);
	// return float4(hairSpec * saturate(diffusemap.rgb), 1);
	specular += hairSpec * saturate(diffusemap.rgb);
	#endif

	// 最終的な色の計算
	light = CalcToonLight(light, IN.ToonColor.rgb);
	if (!ExistPolish) light = 1; // 適当
	float4 result = float4(light, MaterialDiffuse.a) * albedo;

	#if Enable_Cutout > 0
	clip(result.a - CutoutThreshold);
	result.a = 1;
	#endif

	// クリアコート層
	// (未対応)

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

	result.rgb = bOutputLinear ? result.rgb : Gamma(result.rgb);

	return result;
}


#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
		string Script = MOB_LOOPSCRIPT_OBJECT; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTecBS0, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

//-----------------------------------------------------------------------------

