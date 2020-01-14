////////////////////////////////////////////////////////////////////////////////////////////////
//
// 屈折用マップを作成
// 鏡面の裏側だけを描画する。
//
// 針金Pの WF_Object.fxsub を改造。
//
////////////////////////////////////////////////////////////////////////////////////////////////

#include "Settings.fxsub"
#include "Commons.fxsub"


///////////////////////////////////////////////////////////////////////////////////////////////
// 鏡面座標変換パラメータ

// ワールド座標系における鏡像位置への変換
#define	WldMirrorPos	WaveObjectPosition
static float3 WldMirrorNormal = float3( 0.0, IsInWater ? 1.0 : -1.0, 0.0 );

// 鏡面表裏判定(座標が鏡面の裏側にある時だけ＋)
float IsFace( float4 Pos )
{
    return (Pos.y-WldMirrorPos.y) * WldMirrorNormal.y;
}

// 水中の厚み：屈折で必要になるのはカメラが水上にある場合のみ
inline float CalcWaterTichkness(float depth, float3 pos, float3 v)
{
	return max(depth - DistanceToWater(pos, v), 0);
}


///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 ProjMatrix               : PROJECTION;
float4x4 CalcViewProjMatrix(float4x4 v, float4x4 p)
{
	p._11_22 *= FrameScale;
	return mul(v, p);
}
static float4x4 ViewProjMatrix = CalcViewProjMatrix(ViewMatrix, ProjMatrix);

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3 MMDLightDirection : DIRECTION < string Object = "Light"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float SpecularPower      : SPECULARPOWER < string Object = "Geometry"; >;
float3 MaterialToon      : TOONCOLOR;
// ライト色
float3 LightDiffuse   : DIFFUSE   < string Object = "Light"; >;
float3 LightAmbient   : AMBIENT   < string Object = "Light"; >;
float3 LightSpecular  : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4 TextureAddValue  : ADDINGTEXTURE;
float4 TextureMulValue  : MULTIPLYINGTEXTURE;
float4 SphereAddValue   : ADDINGSPHERETEXTURE;
float4 SphereMulValue   : MULTIPLYINGSPHERETEXTURE;

bool parthf;   // パースペクティブフラグ
bool transp;   // 半透明フラグ
bool spadd;    // スフィアマップ加算合成フラグ
#define SKII1  1500
#define SKII2  8000
#define Toon   3

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

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

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = POINT;
    MAGFILTER = POINT;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos       : POSITION;    // 射影変換座標
    float4 ZCalcTex  : TEXCOORD0;   // Z値
    float4 Tex       : TEXCOORD1;   // テクスチャ
    float3 Normal    : TEXCOORD2;   // 法線
    float3 Eye       : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex     : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 WPos      : TEXCOORD5;   // 鏡像元モデルのワールド座標
    float4 Color     : COLOR0;      // ディフューズ色
};

// 頂点シェーダ(鏡像反転)
VS_OUTPUT BasicMirror_VS(float4 pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,
	uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ライト視点によるワールドビュー射影変換(光源も鏡像化されていることを考慮)
    Out.ZCalcTex = mul( pos, LightWorldViewProjMatrix );

    // ワールド座標変換
    pos = mul( pos, WorldMatrix );
    Out.WPos = pos; // ワールド座標

    // カメラとの相対位置(光源も鏡像化されていることを考慮)
    Out.Eye = CameraPosition - pos.xyz;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( pos, ViewProjMatrix );

    // 頂点法線(光源も鏡像化されていることを考慮)
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    Out.Tex.xy = Tex; //テクスチャUV
 
   // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0, dot( Out.Normal, -MMDLightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    if ( useSphereMap ) {
            // スフィアマップテクスチャ座標(外縁が見えやすくなるので少し補正)
            float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy * 0.99f;
            Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
            Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }

    return Out;
}

float CalcShdow(float4 ZCalcTex)
{
	float comp = 1;

    // テクスチャ座標に変換
    ZCalcTex /= ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - ZCalcTex.y)*0.5f;
    if( any( saturate(TransTexCoord) - TransTexCoord ) ) {
        // シャドウバッファ外
        ;
    } else {
        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
    }

	return comp;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow) : COLOR0
{
    // 鏡面の裏側にある部位は鏡像表示しない
    clip( IsFace( IN.WPos ) );

    float4 Color = IN.Color;
    float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色

    if(useTexture){
        // テクスチャ適用
        float4 TexColor = tex2D(ObjTexSampler,IN.Tex.xy);
        // テクスチャ材質モーフ数
        TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
        Color *= TexColor;
        ShadowColor *= TexColor;
    }

	// スペキュラ色計算
	float3 HalfVector = normalize( normalize(IN.Eye) + -MMDLightDirection );
	float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        // スフィアテクスチャ材質モーフ数
        TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
            ShadowColor.rgb *= TexColor.rgb;
        }
        Color.a *= TexColor.a;
        ShadowColor.a *= TexColor.a;
    }

	// スペキュラ適用
	Color.rgb += Specular;

	float comp = (useSelfshadow) ? CalcShdow(IN.ZCalcTex) : 1.0;

	if ( useToon ) {
		// トゥーン適用
		comp = min(saturate(dot(IN.Normal,-MMDLightDirection)*Toon),comp);
		ShadowColor.rgb *= MaterialToon;
	}

	Color = lerp(ShadowColor, Color, comp);
/*
	// 水中フォグ
	// メイン側で追加するので不要
	if (!IsInWater)
	{
		float depth = distance(IN.WPos.xyz, CameraPosition);
		float thickness = CalcWaterTichkness(depth, CameraPosition, -normalize(IN.Eye));
		Color.rgb = CalcFogColor(Color.rgb, thickness);
	}
*/
	return float4(Color.rgb, Color.a);
}



#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = toon;  bool UseSelfShadow = selfshadow;\
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BasicMirror_VS(tex, sphere, toon); \
			PixelShader  = compile ps_3_0 Basic_PS(tex, sphere, toon, selfshadow); \
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


technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
