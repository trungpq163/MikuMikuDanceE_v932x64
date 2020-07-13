////////////////////////////////////////////////////////////////////////////////////////////////
//
//  full.fx改を弄ったものを、さらに弄ったもの。
//	ikPointColor用に高コントラストの絵を作る。単独での使用は想定していない。
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// トゥーンカラー時に強制的に影の色を濃くする。1で通常通り、大きい数値ほど影が濃くなる。
#define	ToonContrastPower		16

// リムライトの強さ。リムライトによって黒く潰れた部分に白い輪郭線が出る。
#define	RimLightPower		8			// 大きいほど、線が細くなる
#define	RimLightIntensity	1.0			// リムライトの強さ。0で無効、1で真っ白になる。




/////////////////////////////////////////////////////////////////////////////////////////
// ■ ExcellentShadowシステム　ここから↓

float X_SHADOWPOWER = 1.0;   //アクセサリ影濃さ
float PMD_SHADOWPOWER = 0.2; //モデル影濃さ

//スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

//SSAOマップ取得
shared texture2D ExShadowSSAOMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "R16F";
>;

sampler2D ExShadowSSAOMapSamp = sampler_state {
    texture = <ExShadowSSAOMapOut>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

// スクリーンサイズ
float2 ES_ViewportSize : VIEWPORTPIXELSIZE;
static float2 ES_ViewportOffset = (float2(0.5,0.5)/ES_ViewportSize);

bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
bool Exist_ExShadowSSAO : CONTROLOBJECT < string name = "ExShadowSSAO.x"; >;
float ShadowRate : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Tr"; >;
float3   ES_CameraPos1      : POSITION  < string Object = "Camera"; >;
float es_size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; >;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;

static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43 );
static float CameraDistance1 = length(ES_CameraPos1 - es_move1); //カメラとシャドウ中心の距離

// ■ ExcellentShadowシステム　ここまで↑
/////////////////////////////////////////////////////////////////////////////////////////

// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection	: DIRECTION < string Object = "Light"; >;
float3   CameraPosition	: POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float	SpecularPower	 : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon		: TOONCOLOR;
float4   EdgeColor		 : EDGECOLOR;
float4   EgColor;



// 謎の係数スペキュラーパワーを適当にスムースネスに置き換える。(0:マット。1:ツルツル)
// 計算は適当。
float CalcSmoothness(float power)
{
	// 1に近過ぎると、ピーキーになりすぎてハイライトがでないので、0.2～0.98の間に抑える
	return saturate((log(power) / log(2) - 1) / 16.0) * 0.96 + 0.02;
}

// スムースネスから適当にリフレクタンスに置き換える。
// 金属で0.8以上。非金属は0.1前後。UE4では非金属は0.04(IOR=1.5)で固定らしい。
inline float CalcF0(float smoothness)
{
	float a = smoothness * 2.0;
	float f0 = (a <= 1.0) ? pow(a,6) : (pow(abs(a-1), 1/6.0) + 1.0);
	return (f0 * 0.5 * 0.85 + 0.05);
}

static float Smoothness = CalcSmoothness(SpecularPower);
static float F0 = CalcF0(Smoothness);



// 材質モーフ対応
float4   TextureAddValue   : ADDINGTEXTURE;
float4   TextureMulValue   : MULTIPLYINGTEXTURE;
float4   SphereAddValue    : ADDINGSPHERETEXTURE;
float4   SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

// ライト色
float3   LightDiffuse		: DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient		: AMBIENT   < string Object = "Light"; >;
float3   LightSpecular	 : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool	 parthf;   // パースペクティブフラグ
bool	 transp;   // 半透明フラグ
bool	 spadd;	// スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	 3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
//

#define	PI	(3.14159265359)

// ガンマ補正
const float gamma = 2.2;
inline float3 Degamma(float3 col) { return pow(col, gamma); }
inline float3 Gamma(float3 col) { return pow(col, 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float CalcDiffuse(float3 L, float3 N, float3 V, float smoothness, float f0)
{
	const float NL = dot(N,L);
	float result = NL;					// 普通のランバート
	return saturate(result);
}


// 金属の場合、F0はrgb毎に異なる値を持つ
inline float CalcFresnel(float NV, float F0)
{
	return F0 + (1.0 - F0) * pow(1 - NV, 5);
}

inline float CalcG1(float NV, float k)
{
	return 1.0 / (NV * (1.0 - k) + k);
}

inline float CalcV(float NV, float a)
{
	return NV * (0.5 - a) + 0.5 * a;
}

//スペキュラの計算
float CalcSpecular(float3 L, float3 N, float3 V, float smoothness, float f0)
{
	float3 H = normalize(L + V);	// ハーフベクトル

#if 0
	float3 Specular = max(0,dot( H, N ));
	float power = pow(2,smoothness * 16);
	float3 result = pow(Specular, power);
	return result *= (2.0 + power) / (2.0 * PI);
#else

	float a = 1 - smoothness;
	a *= a;
	float aSq = a * a;
	float NV = saturate(dot(N, V));
	float NH = saturate(dot(N, H));
	float VH = saturate(dot(V, H));
	float NL = saturate(dot(N, L));
	float LH = saturate(dot(L, H));

	// NDF: Trowbridge-Reitz(GGX)
	float CosSq = (NH * NH) * (aSq - 1) + 1;
	float D = aSq / (PI * CosSq * CosSq);

	// フレネル項
	float F = CalcFresnel(LH, f0);

	// 幾何学的減衰係数(G項)
	// GGX用のG項
	float k = a * 0.5;
	float k2 = k * k;
	float vis = rcp(LH * LH * (1 - k2) + k2);

	return saturate(NL * D * F * vis / 4.0);
	// return max(0, D * F * G / (4.0 * NL * NV));
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
	// カメラ視点のワールドビュー射影変換
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
	// 輪郭色で塗りつぶし
	return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;

		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	// カメラ視点のワールドビュー射影変換
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
	// アンビエント色で塗りつぶし
	return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_2_0 Shadow_VS();
		PixelShader  = compile ps_2_0 Shadow_PS();
	}
}



///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD0;	// Zバッファテクスチャ
//	float2 Tex		: TEXCOORD1;	// テクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	// ライトの目線によるワールドビュー射影変換をする
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );

	// テクスチャ座標を頂点に合わせる
	Out.ShadowMapTex = Out.Pos;

//	Out.Tex = Tex;

	return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0, float2 Tex : TEXCOORD1 ) : COLOR
{
/*
	float3 alpha = tex2D( ObjTexSampler, Tex ).a;
	clip(alpha - 0.5);
*/
	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
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
	float4 Pos		: POSITION;	 // 射影変換座標
	float4 ZCalcTex : TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal   : TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;	 // スフィアマップテクスチャ座標

    // ■ ExcellentShadowシステム　ここから↓
    float4 ScreenTex : TEXCOORD5;   // スクリーン座標
    // ■ ExcellentShadowシステム　ここまで↑

};

// 頂点シェーダ
BufferShadow_OUTPUT DrawObject_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,
	uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );

	// カメラとの相対位置
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;
	// 頂点法線
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfShadow)
	{
		// ライト視点によるワールドビュー射影変換
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );

		// ■ ExcellentShadowシステム　ここから↓
		//スクリーン座標取得
		Out.ScreenTex = Out.Pos;
		//超遠景におけるちらつき防止
		Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));
		// ■ ExcellentShadowシステム　ここまで↑
	}

	// テクスチャ座標
	Out.Tex = Tex;
	
	if ( useSphereMap ) {
		// スフィアマップテクスチャ座標
		float2 NormalWV = mul( Normal, (float3x3)WorldViewMatrix ).xy;
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}

	return Out;
}


// ピクセルシェーダ
float4 DrawObject_PS(BufferShadow_OUTPUT IN,
	uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow) : COLOR
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);
	if (dot(N,V) < 0.0) N = -N; // 両面ポリゴンを裏から見ている

	float rimLight = pow(1.0 - saturate(dot(N,V)), RimLightPower) * RimLightIntensity;

	float specular = CalcSpecular(L, N, V, Smoothness, F0);
	float diffuse = CalcDiffuse(L, N, V, Smoothness, F0);

	float4 Color = float4(1,1,1, DiffuseColor.a);
	if ( !useToon ) {
		Color.rgb = (Degamma(AmbientColor) + Degamma(DiffuseColor.rgb));
	}

	float4 ShadowColor = float4(Degamma(AmbientColor), Color.a);  // 影の色
	if ( useTexture ) {
		// テクスチャ適用
		float4 TexColor = Degamma4(tex2D( ObjTexSampler, IN.Tex ));
		Color *= TexColor;
		ShadowColor *= TexColor;
	}
	if ( useSphereMap ) {
		// スフィアマップ適用
		// 薄いハイライトはガンマ補正を掛けると見えなくなる...
		// float3 TexColor = Degamma(tex2D(ObjSphareSampler,IN.SpTex).rgb);
		float3 TexColor = tex2D(ObjSphareSampler,IN.SpTex).rgb;
		if(spadd) {
			Color.rgb += TexColor;
			ShadowColor.rgb += TexColor;
		} else {
			Color.rgb *= TexColor;
			ShadowColor.rgb *= TexColor;
		}
	}
	
	float comp = 1;

	if (useSelfShadow)
	{
		// ■ ExcellentShadowシステム　ここから↓
		if(Exist_ExcellentShadow)
		{
			IN.ScreenTex.xyz /= IN.ScreenTex.w;
			float2 TransScreenTex;
			TransScreenTex.x = (1.0f + IN.ScreenTex.x) * 0.5f;
			TransScreenTex.y = (1.0f - IN.ScreenTex.y) * 0.5f;
			TransScreenTex += ES_ViewportOffset;
			comp = tex2D(ScreenShadowMapProcessedSamp, TransScreenTex).r;

			float SSAOMapVal = 0;
			if(Exist_ExShadowSSAO){
				SSAOMapVal = tex2D(ExShadowSSAOMapSamp , TransScreenTex).r; //陰度取得
			}

			if ( useToon ) {
				ShadowColor.rgb *= lerp(1, Degamma(MaterialToon), SSAOMapVal);
			} else {
				ShadowColor.rgb *= (1 - SSAOMapVal);
			}
		}
		else
		// ■ ExcellentShadowシステム　ここまで↑
		{
			// テクスチャ座標に変換
			IN.ZCalcTex.xy /= IN.ZCalcTex.w;
			float2 TransTexCoord;
			TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
			TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
			if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
				// シャドウバッファ外
				;
			} else {
				float a = (parthf) ? SKII2*TransTexCoord.y : SKII1;

				// 光源方向に応じてデプスを補正する
				float nl = dot(N,L);
				float d = (IN.ZCalcTex.z - (saturate(-nl) * 0.5)) / IN.ZCalcTex.w;

				comp = 1 - saturate(max(d - tex2D(DefSampler,TransTexCoord).r , 0.0f)*a-0.3f);
			}
		}

		specular *= comp;
	}

	comp = min(comp, diffuse);

	// スペキュラ適用
	Color.rgb += specular * Degamma(SpecularColor);

	if ( useToon ) {
		// トゥーン適用
		comp = saturate(comp * Toon);
		ShadowColor.rgb *= pow(Degamma(MaterialToon), ToonContrastPower);
	}

	Color.rgb = lerp(ShadowColor.rgb, Color.rgb, comp);
	Color.rgb += rimLight;

	return Gamma4(Color);
}



#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = toon;  bool UseSelfShadow = selfshadow;\
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(tex, sphere, toon, selfshadow); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false, false, false, false)
OBJECT_TEC(MainTec1, "object", true, false, false, false)
OBJECT_TEC(MainTec2, "object", false, true, false, false)
OBJECT_TEC(MainTec3, "object", true, true, false, false)
OBJECT_TEC(MainTec4, "object", false, false, true, false)
OBJECT_TEC(MainTec5, "object", true, false, true, false)
OBJECT_TEC(MainTec6, "object", false, true, true, false)
OBJECT_TEC(MainTec7, "object", true, true, true, false)

OBJECT_TEC(MainTecBS0, "object_ss", false, false, false, true)
OBJECT_TEC(MainTecBS1, "object_ss", true, false, false, true)
OBJECT_TEC(MainTecBS2, "object_ss", false, true, false, true)
OBJECT_TEC(MainTecBS3, "object_ss", true, true, false, true)
OBJECT_TEC(MainTecBS4, "object_ss", false, false, true, true)
OBJECT_TEC(MainTecBS5, "object_ss", true, false, true, true)
OBJECT_TEC(MainTecBS6, "object_ss", false, true, true, true)
OBJECT_TEC(MainTecBS7, "object_ss", true, true, true, true)



///////////////////////////////////////////////////////////////////////////////////////////////
