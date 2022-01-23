////////////////////////////////////////////////////////////////////////////////////////////////
//
//  BillboardYFix.fx ver0.0.1  ビルボードサンプル(Y軸固定版)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 WorldMatrix         : WORLD;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// カメラZ回転追従のビルボード行列
static float3 xAxis = cross( float3(0.0f, 1.0f, 0.0f), WorldMatrix._41_42_43 - CameraPosition );
static float3 yAxis = float3(0.0f, 1.0f, 0.0f);
static float3 zAxis = cross( xAxis, yAxis );
static float3x3 RotMatrix = mul( float3x3(xAxis, yAxis, zAxis), transpose((float3x3)WorldMatrix) );
static float3x3 BillboardYFixMatrix = float3x3( normalize(RotMatrix[0].xyz),
                                                normalize(RotMatrix[1].xyz),
                                                normalize(RotMatrix[2].xyz) );

// オブジェクトのテクスチャ
texture2D ObjectTexture <
    string ResourceName = "sample.png";
    int MipLevels = 0;
>;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    MaxAnisotropy = 16;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 射影変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Billboard_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardYFixMatrix );

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Billboard_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    return tex2D( ObjTexSampler, Tex );
}

//テクニック
technique MainTec0 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Billboard_VS();
        PixelShader  = compile ps_2_0 Billboard_PS();
    }
}

