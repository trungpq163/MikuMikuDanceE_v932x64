////////////////////////////////////////////////////////////////////////////////////////////////
//
//  キラーン.fx ver0.0.2  漫画風表現エフェクト(キラーン)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int ParticleCount = 30;   // パーティクルの描画オブジェクト数
float LightSize = 0.5;   // 光粒子大きさ
float LightCross = 1.0;   // 光粒子の十字度合い
float LightAmp = 1.0;     // 光粒子瞬き振幅
float LightFreq = 3.0;    // 光粒子瞬き周波数

float Xmin = -5.0;        // X範囲最小値
float Xmax = 5.0;         // X範囲最大値
float Ymin = -5.0;        // Y範囲最小値
float Ymax = 7.0;         // Y範囲最大値

int SeedXY = 7;           // 配置に関する乱数シード
int SeedSize = 3;         // サイズに関する乱数シード
int SeedBlink = 13;       // 瞬きに関する乱数シード
int SeedCross = 11;       // 十字度合いに関する乱数シード


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


texture2D ParticleTex1 <
    string ResourceName = "kira1.png";
    int MipLevels = 0;
>;
sampler ParticleSamp1 = sampler_state {
    texture = <ParticleTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex2 <
    string ResourceName = "kira2.png";
    int MipLevels = 0;
>;
sampler ParticleSamp2 = sampler_state {
    texture = <ParticleTex2>;
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
    float3 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand0 = 0.6f*sin(37 * SeedSize * Index + 13) + 0.4f*cos(71 * SeedSize * Index + 17)+1.2f;
    float rand1 = 0.4f*sin(53 * SeedBlink * Index + 17) + 0.6f*cos(61 * SeedBlink * Index + 19);
    float rand2 = abs(0.7f*sin(124 * SeedXY * Index + 19) + 0.3f*cos(235 * SeedXY * Index + 23));
    float rand3 = abs(0.6f*sin(83 * SeedXY * Index + 23) + 0.4f*cos(91 * SeedXY * Index + 29));
    float rand4 = (sin(47 * SeedCross * Index + 29) + cos(81 * SeedCross * Index + 31) + 3.0f) * 0.1f;

    // パーティクルサイズ
    Pos.xy *= max(rand0 * LightSize + LightAmp*sin(LightFreq*time+rand1*6.28f), 0.0f);

    // パーティクル配置
    float x = lerp(Xmin, Xmax, rand2) * 0.1f;
    float y = lerp(Ymin, Ymax, rand3) * 0.1f;
    Pos.xy += float2(x, y);

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 粒子の透過度
    Out.Color = float4(AcsTr, AcsTr, AcsTr, 1.0f);

    // テクスチャ座標
    Out.Tex = float3(Tex, 1.0f+LightCross*rand4);

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( ParticleSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= IN.Color.xyz*0.5f;
    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object";
    string Script = "LoopByCount=ParticleCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

