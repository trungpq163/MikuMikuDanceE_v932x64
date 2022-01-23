////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Billboard.fx ver0.0.1  ビルボードサンプル(ノーマル)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

// ビルボード行列
static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

// オブジェクトのテクスチャ
texture2D ObjectTexture <
    string ResourceName = "sample.png";
    int MipLevels = 0;
>;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
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
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

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


