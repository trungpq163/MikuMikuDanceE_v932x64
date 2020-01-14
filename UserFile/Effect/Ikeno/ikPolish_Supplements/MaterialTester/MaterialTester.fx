////////////////////////////////////////////////////////////////////////////////////////////////
// MaterialTester用にカスタマイズしたPolsihMain.fx
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)

// 第二スペキュラ
// 車のコート層とボディ本体、皮膚と汗などのように複数のハイライトがある場合用
const float SecondSpecularSmooth =	 0.4;		// 1に近づくほどスペキュラが鋭くなる。(0～1)
const float SecondSpecularIntensity = 0.0;		// スペキュラの強度。0でオフ。1で等倍。(0～)

// PMXEditorの環境色をライトの強さの影響を受けるようにする。
// #define EMMISIVE_AS_AMBIENT
#define IGNORE_EMISSIVE			// 環境色を無効にする。

// AutoLuminous対策。明るい部分をカットする。
// #define DISABLE_HDR

// スフィアマップ無効
// スフィアマップによる偽ハイライトが不自然に見える場合に無効化する。
// NCHL用のモデルを使う場合も、スフィアマップを無効にする。
//#define IGNORE_SPHERE

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.25;

// テスト用：色を無視する。
//#define DISABLE_COLOR

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
// #define ENABLE_SPECULAR_ALPHA

//----------------------------------------------------------
// SSS用の設定

// 逆光からの光で明るくする(カーテンや葉っぱなどに使う)
//#define ENABLE_BACKLIGHT

// 材質設定のSSSにより、にじんだ光につく色
#define ScatterColor	MaterialToon
//#define ScatterColor	float3(1.0, 0.6, 0.3)

// SSS効果を有効にするか。
// #define ENABLE_SSS

// 表層：表面の色
const float3 TopCol = float3(1.0,1.0,1.0);	// 色
const float TopScale = 2.0;					// 視線との角度差に反応する度合い。
const float TopBias = 0.01;					// 正面でどの程度影響を与えるか
const float TopIntensity = 0.0;				// 全体影響度
// 深層：内部の色
const float3 BottomCol = float3(1.0, 1.0, 1.0);	// 色
const float BottomScale = 0.4;			// 視線との角度差に反応する度合い。
const float BottomBias = 0.2;			// 正面でどの程度影響を与えるか
const float BottomIntensity = 0.0;			// 全体影響度

// #include "PolishMain_common.fxsub"


////////////////////////////////////////////////////////////////////////////////////////////////
//#include "../ikPolishShader.fxsub"
// コントローラ名
#define CONTROLLER_NAME		"ikPolishController.pmx"
float DefaultLightScale = 1.0;		// 直接光(=ライトの強さ)のデフォルト値
inline float CalcLightValue(float plusValue, float minusValue, float defaultValue)
{
	float v = plusValue - minusValue + 1.0;
	return ((v <= 1.0) ? v : ((v - 1.0) * 4.0 + 1.0)) * defaultValue;
}
//-------------------------


bool Exist_Polish : CONTROLOBJECT < string name = "ikPolishShader.x"; >;

// アンビエントマップ
shared texture2D PPPReflectionMap : RENDERCOLORTARGET;
sampler ReflectionMapSamp = sampler_state {
	texture = <PPPReflectionMap>;
	Filter = NONE;	AddressU  = CLAMP;	AddressV = CLAMP;
};

// 材質マップ
shared texture PPPMaterialMapRT: RENDERCOLORTARGET;
sampler MaterialMap = sampler_state {
	texture = <PPPMaterialMapRT>;
	Filter = NONE;	AddressU  = CLAMP;	AddressV = CLAMP;

};

// 法線マップ
shared texture PPPNormalMapRT: RENDERCOLORTARGET;
sampler NormalMap = sampler_state {
	texture = <PPPNormalMapRT>;
	Filter = NONE;	AddressU  = CLAMP;	AddressV = CLAMP;
};


/////////////////////////////////////////////////////////////////////////////////////////

float mDirectLightP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光+"; >;
float mDirectLightM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光-"; >;
float mTestMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "テストモード"; >;

// 座法変換行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 WorldMatrix			: WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

// ライト色
float3	LightDiffuse		: DIFFUSE   < string Object = "Light"; >;
float3	LightSpecular	 	: SPECULAR  < string Object = "Light"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbientOrig	: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissiveOrig	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float3	MaterialToon		: TOONCOLOR;

// アクセサリのスペキュラは1/10されているのでそれを補正する
#define SpecularColor	Degamma(MaterialSpecular * (LightDiffuse.r * 9 + 1))
/*
// NCHLの設定
#define SpecularColor	saturate(MaterialSpecular.g * 2)
*/

#if defined(IGNORE_EMISSIVE)
static float3	MaterialAmbient = MaterialAmbientOrig;
static float3	MaterialEmissive = 0;
#elif defined(EMMISIVE_AS_AMBIENT)
static float3	MaterialAmbient = saturate(MaterialAmbientOrig + MaterialEmissiveOrig);
static float3	MaterialEmissive = 0;
#else
static float3	MaterialAmbient = MaterialAmbientOrig;
static float3	MaterialEmissive = MaterialEmissiveOrig;
#endif

// ライトの強度
static float LightScale = CalcLightValue(mDirectLightP, mDirectLightM, DefaultLightScale);
static float3 LightColor = LightSpecular * LightScale;

// 材質モーフ対応
float4	TextureAddValue   : ADDINGTEXTURE;
float4	TextureMulValue   : MULTIPLYINGTEXTURE;
float4	SphereAddValue    : ADDINGSPHERETEXTURE;
float4	SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

bool use_texture;
bool use_spheremap;
bool use_toon;

bool	 parthf;   // パースペクティブフラグ
bool	 transp;   // 半透明フラグ
bool	 spadd;	// スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	 3

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

/*
//トゥーンマップのテクスチャ
texture ObjectToonTexture: MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state {
	texture = <ObjectToonTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = NONE;
	ADDRESSU  = CLAMP;
	ADDRESSV  = CLAMP;
};
*/

////////////////////////////////////////////////////////////////////////////////////////////////
//

#define	PI	(3.14159265359)

// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }
inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

float3 CalcNormalizedToon()
{
	float3 result = 0;
	if (use_toon)
	{
		float3 linearColor = Degamma(MaterialToon);
		float g = rgb2gray(linearColor) * 0.75;
			// グレースケールを実際より暗く扱うのは、定数Toonによる明るさの底上げに相当する。
		result = (g - linearColor) * ToonColor_Scale / (g - g*g + 1e-4);
	}
	return result;
}

static float3 NormalizedToon = CalcNormalizedToon();

inline float3 CalcToonColor(float3 c)
{
	float3 c0 = saturate(c);
	return saturate(NormalizedToon * (c0 * c0 - c0) + c);
}

static float3 MaterialBaseColor = Degamma((!use_toon) ? MaterialDiffuse.rgb : MaterialAmbient);

inline float CalcDiffuse(float3 L, float3 N, float3 V, float smoothness, float3 f0)
{
	float roughness = (1 - smoothness);
	float sigma2 = roughness * roughness;

	// A tiny improvement of Oren-Nayar reflectance model
	float NL = saturate(dot(N ,L));
	float NV = abs(dot(N, V)+1e-5);
	float LV = saturate(dot(L, V));
	float s = LV - NL * NV;
	float st = (s <= 0.0) ? s : (s / (max(NL,NV)+1e-6));
//	float A = 1.0 / ((PI * 0.5 - 2.0/3.0) * sigma2 + PI);
	float A = 1 / ((0.5 - 2.0/3.0/PI) * sigma2 + 1);  // MEMO: 正規化分を戻す。
	float B = sigma2 * A;
	float result = NL * (A + B * st);

	return saturate(result);
}


// 金属の場合、F0はrgb毎に異なる値を持つ
inline float3 CalcFresnel(float NV, float3 F0)
{
	// Schlickの近似式
//	return F0 + (1.0 - F0) * pow(1 - NV, 5);
	float fc = pow(max(1 - NV, 1e-5), 5);
	return (1.0 - F0) * fc + F0;
}

//スペキュラの計算
float3 CalcSpecular(float3 L, float3 N, float3 V, float smoothness, float3 f0)
{
	float3 H = normalize(L + V);

	float a = max(1 - smoothness, 1e-3);
	a *= a;

	float NH = saturate(dot(N, H));
	float NL = saturate(dot(N, L));
	float LH = saturate(dot(L, H));

	float CosSq = (NH * NH) * (a - 1) + 1;
	float D = a / (CosSq * CosSq); // MEMO: 正規化項の1.0/PIを削っている。
	float3 F = CalcFresnel(LH, f0);

	float k2 = a * a * 0.25;	// = (a * 0.5)^2
	float vis = (1.0/4.0) / (LH * LH * (1 - k2) + k2);
	return saturate(NL * D * F * vis);
}

inline float3 CalcReflectance(float smoothness, float3 N, float3 V, float3 f0)
{
	float NV = abs(dot(N,V));
	float3 f = CalcFresnel(NV, f0);
	float roughness = max(1.0 - smoothness, 1.0e-4);
	float g = 1.0 / pow(2, roughness * 4.0); // ラフなほど暗くなる
	return saturate(f) * g;
}



////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
technique EdgeTec < string MMDPass = "edge"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
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

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0, float2 Tex : TEXCOORD1 ) : COLOR
{
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 ZValuePlot_VS();
		PixelShader  = compile ps_2_0 ZValuePlot_PS();
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
	float4 ScreenTex	: TEXCOORD5;   // スクリーン座標
};

// 頂点シェーダ
BufferShadow_OUTPUT DrawObject_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useSelfShadow)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	float4 WPos = mul( Pos, WorldMatrix );

	// カメラとの相対位置
	Out.Eye = CameraPosition - WPos.xyz;
	// 頂点法線
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfShadow)
	{
		// ライト視点によるワールドビュー射影変換
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	Out.ScreenTex = Out.Pos;

	// テクスチャ座標
	Out.Tex = Tex;

	#if !defined(IGNORE_SPHERE)
	if ( use_spheremap ) {
		// スフィアマップテクスチャ座標
		float2 NormalWV = mul( Normal, (float3x3)WorldViewMatrix ).xy;
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}
	#endif

	return Out;
}


inline float CalcShadow(BufferShadow_OUTPUT IN, float shadowVal)
{
#if defined(ADD_DEFAULT_SHADOW)
	float shadow = 1;

	// テクスチャ座標に変換
	IN.ZCalcTex /= IN.ZCalcTex.w;
	float2 TransTexCoord;
	TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
	TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
	if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
		; // シャドウバッファ外
	} else {
		float a = (parthf) ? SKII2*TransTexCoord.y : SKII1;
		float d = IN.ZCalcTex.z;
		float z = tex2D(DefSampler,TransTexCoord).r;
		shadow = 1 - saturate(max(d - z , 0.0f)*a-0.3f);
	}

	return min(shadow, shadowVal);
#else
	return shadowVal;
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



// ピクセルシェーダ
float4 DrawObject_PS(BufferShadow_OUTPUT IN, uniform bool useSelfShadow) : COLOR
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);

	float2 texCoord = IN.ScreenTex.xy / IN.ScreenTex.w;;
	texCoord.x = (1.0f + texCoord.x) * 0.5f;
	texCoord.y = (1.0f - texCoord.y) * 0.5f;
	texCoord += ViewportOffset;

	float4 mat = float4(0, 0.5, 1.0, 0.5);
	if (Exist_Polish)
	{
		#if !defined(DISABLE_NORMALMAP)
		// MEMO: 現在の深度とデプスが違い過ぎたら、元の法線を使う?
		// その場合、陰影計算も周囲から深度に応じて補間する必要がある。
		float4 nd = tex2D(NormalMap, texCoord);
		N = normalize(nd.xyz);
		// float depth = nd.w; // = mul(WPos, matWV).z
		#endif
		mat = tex2D(MaterialMap, texCoord);
	}

	float metalness = mat.x;
	float smoothness = mat.y;
	float intensity = mat.z;
	float sss = mat.w * (1 - metalness);

	// 素材自体の色
	float4 albedo = float4(MaterialBaseColor,1);
	if ( use_texture ) albedo *= Degamma4(GetTextureColor(IN.Tex));

	float3 SpSpecular = 0;
	#if !defined(IGNORE_SPHERE)
	if ( use_spheremap ) {
		float4 TexColor = GetSphereColor(IN.SpTex);
		if(spadd) {
			SpSpecular = TexColor.rgb * LightSpecular * SphereScale;
		} else {
			albedo.rgb *= (Degamma(TexColor.rgb) * SphereScale + (1.0 - SphereScale));
		}
	}
	#endif

	// ライトの計算
	float3 f0 = lerp(0.05, (albedo.rgb * 0.8 + 0.2) * SpecularColor, metalness);
	float3 specular = CalcSpecular(L, N, V, smoothness, f0);
	specular += CalcSpecular(L, N, V, SecondSpecularSmooth, f0) * SecondSpecularIntensity;
	specular *= intensity;
	float reflectance = rgb2gray(CalcReflectance(smoothness, N, V, f0));

	float4 ambient = Exist_Polish ? tex2D(ReflectionMapSamp, texCoord) : float4(0,0,0,1);
	float diffuse = CalcDiffuse(L, N, V, smoothness, f0);
	float shadow = (useSelfShadow) ? CalcShadow(IN, ambient.w) : 1;
//	float directLight = min(diffuse, shadow);
	float directLight = diffuse * shadow;
	float3 directLight3 = directLight * LightColor;
	float3 light = Exist_Polish ? ambient.rgb : directLight3;

	#if defined(ScatterColor)
	// 光の滲みよる、ライト色の変化
	float3 dif = light - directLight3;
	light = directLight3 + dif * lerp(1, ScatterColor, sss * saturate(1 - rgb2gray(dif)));
	#endif

	#if defined(ENABLE_BACKLIGHT)
	// 逆光による明るさの追加
	float diffuseBack = CalcDiffuse(L, -N, V, smoothness, f0);
	diffuseBack = max(diffuseBack - diffuse, 0) * shadow;
	float3 diffuseDiff = albedo.rgb * albedo.rgb * diffuseBack;
	light += diffuseDiff * LightColor;
	#endif

	#if !defined(DISABLE_COLOR)
	albedo = saturate(albedo);
	if (mTestMode > 0.5) albedo.rgb = 1;
	#else
	albedo.rgb = 1;
	#endif

	#if defined(ENABLE_SSS)
	// 表面色と内部色が透過によって見える。
	float NV = dot(N, normalize(V));
	float plusNV = saturate(NV);
	float top = pow(1-plusNV, TopScale) * (1.0 - TopBias) + TopBias;
	float bottom = pow(1-plusNV, BottomScale) * (1.0 - BottomBias) + BottomBias;
	albedo.rgb = lerp(albedo.rgb, BottomCol, bottom * BottomIntensity);
	albedo.rgb = lerp(albedo.rgb, TopCol, top * TopIntensity);
	#endif

	light = saturate(CalcToonColor(light) + MaterialEmissive);

	float4 result = float4(light, MaterialDiffuse.a) * albedo;
	result.rgb *= saturate(1 - reflectance);	// 映りこむ分、暗くする。

	specular = specular * LightSpecular * shadow + SpSpecular;

	#if defined(ENABLE_SPECULAR_ALPHA)
	// スペキュラに応じて不透明度を上げる。
	float alpha = result.a;
	float alpha2 = saturate(1 - (1.0 - alpha) * (1.0 - rgb2gray(specular)));
	result.rgb = (result.rgb * alpha + specular) / alpha2;
	result.a = alpha2 * saturate(alpha * (1.0 / (5.0/255.0)));
	#else
	result.rgb += specular;
	#endif

	#if defined(DISABLE_HDR)
	result = saturate(result);
	#endif

	return Gamma4(result);
}


#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTecBS0, "object_ss", true)

///////////////////////////////////////////////////////////////////////////////////////////////

