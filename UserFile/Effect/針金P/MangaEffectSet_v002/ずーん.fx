////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ずーん.fx ver0.0.2  漫画風表現エフェクト(ずーん)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float2 Size = float2(0.7, 0.5); // 大きさ
float ScrollSpeed = 0.2;        // スクロールスピード
float LineAmp = 0.03;           // 縦波線振幅
float LineWaveLen = 10.0;       // 縦波線波長
float LineFreq = 1.5;           // 縦波線周波数


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int Index;

float time : Time;

// 座標変換行列
float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix             : VIEW;
float4x4 ProjMatrix             : PROJECTION;
float4x4 ViewProjMatrix         : VIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;


texture2D Tex1 <
    string ResourceName = "zooon1.png";
    int MipLevels = 0;
>;
sampler Samp1 = sampler_state {
    texture = <Tex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = WRAP;
};

texture2D Tex2 <
    string ResourceName = "zooon2.png";
    int MipLevels = 0;
>;
sampler Samp2 = sampler_state {
    texture = <Tex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D Tex3 <
    string ResourceName = "zooon3.png";
    int MipLevels = 0;
>;
sampler Samp3 = sampler_state {
    texture = <Tex3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifdef MIKUMIKUMOVING
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#else
    #define GET_VPMAT(p) (ViewProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // オブジェクトサイズ
    Pos.xy *= Size;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // 背面テクスチャ
    float2 Tex1 = float2(IN.Tex.x, IN.Tex.y-ScrollSpeed*time);
    float4 Color = tex2D( Samp1, Tex1 );

    // 背面テクスチャの型抜き
    float4 Color1 = tex2D( Samp3, IN.Tex );
    Color.a *= Color1.r;

    // 縦波線テクスチャ
    float2 Tex2 = float2(IN.Tex.x+LineAmp*sin(LineWaveLen*IN.Tex.y+LineFreq*time), IN.Tex.y);
    float4 Color2 = tex2D( Samp2, Tex2 );

    // 線形合成
    Color.xyz = lerp(Color.xyz, Color2.xyz, Color2.a);
    Color.a = ( 1.0f - (1.0f-Color.a)*(1.0f-Color2.a) ) * AcsTr;

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

