////////////////////////////////////////////////////////////////////////////////////////////////
//	ポイントライトSS用双放物面シャドウマップ
//	ビームマンＰ
//	ベース
//  動的双放物面環境マップ ver1.0
//  舞力介入P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


float3 CameraPosition : CONTROLOBJECT < string name = "(OffscreenOwner)";>;


// カメラの向き　1…正面 -1…背面
#define CAMERA_DIRECTION   -1

// Z方向の奥行き
#define Z_MAX   1024.0
#define Z_MIN   1.0

static float4x4 ViewMatrix  = {
    CAMERA_DIRECTION, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, CAMERA_DIRECTION, 0,
    -CameraPosition.x*CAMERA_DIRECTION, -CameraPosition.y, -CameraPosition.z*CAMERA_DIRECTION, 1,
};

// 座法変換行列
float4x4 WorldMatrix              : WORLD;
static float4x4 WorldViewMatrix   = mul(WorldMatrix,ViewMatrix);

//float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
//float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
//float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

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
// 動的双放物面環境マップ

float4 CalcProj(float4 Pos) {
    float L = length(Pos.xyz);
    Pos.xyz /= L;
    Pos.xy /= Pos.z+1;
    float d = dot(Pos.xy,Pos.xy);
    Pos.z = L + d*d;
    Pos.z = (Pos.z - Z_MIN)/(Z_MAX-Z_MIN);
    Pos.w = 1;
    return Pos;
}
float4 CalcWVP(float4 Pos) {
    return CalcProj( mul(Pos, WorldViewMatrix) );
}


// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {

}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float2 Tex : TEXCOORD0;
    float Z : TEXCOORD1;    // Z値
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION,float2 Tex: TEXCOORD0)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = CalcWVP( Pos );
    Out.Z = Out.Pos.z / Out.Pos.w;
    Out.Tex = Tex;
    //Out.Z = length(mul(Pos,WorldMatrix) - CameraPosition);

    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN) : COLOR
{
	float z = IN.Z;
	float a = MaterialDiffuse.a * tex2D(ObjTexSampler,IN.Tex).a;
	if(a <= 0.9)
	{
		a = 0;
	}
	return float4(z,z,z,a);
}

technique MainTec0 < string MMDPass = "object";> {

}
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
