////////////////////////////////////////////////////////////////////////////////////////////////
//
//  EasyBillboard.fx ver0.0.3  お絵描きツールで作成したアクセを使う簡易汎用ビルボード
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix             : VIEW;
float4x4 ProjMatrix             : PROJECTION;
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// アクセサリパラメータ
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
#ifndef MIKUMIKUMOVING
    #ifndef MME_MIPMAP
    MIPFILTER = LINEAR;
    #endif
#endif
    AddressU  = BORDER;
    AddressV  = BORDER;
    BorderColor = float4(0,0,0,0);
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

#ifndef MIKUMIKUMOVING
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
#else
    // 頂点座標
    if (MMM_IsDinamicProjection)
    {
        Pos = mul( Pos, WorldMatrix );
        float4x4 vpmat = mul( ViewMatrix, MMM_DynamicFov(ProjMatrix, length( CameraPosition - Pos.xyz )) );
        Out.Pos = mul( Pos, vpmat );
    }
    else
    {
        Out.Pos = mul( Pos, WorldViewProjMatrix );
    }
#endif

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Billboard_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    float4 Color = tex2D( ObjTexSampler, Tex );
    Color.a *= AcsTr;
    return Color;
}

technique MainTec0 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Billboard_VS();
        PixelShader  = compile ps_2_0 Billboard_PS();
    }
}

technique MainTec1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Billboard_VS();
        PixelShader  = compile ps_2_0 Billboard_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
