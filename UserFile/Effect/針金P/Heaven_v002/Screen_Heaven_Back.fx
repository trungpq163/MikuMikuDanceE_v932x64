////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Screen_Heaven_Back.fx ver0.0.2  ヘブンフィルターエフェクト･スクリーン固定版(モデル後面配置)
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx,FireParticleSystem.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int ParticleCount = 50;     // 光粒子の描画オブジェクト数
float LightScale = 1.0;     // 光粒子大きさ
float LightSpeedMin = 0.1;  // 光粒子最小スピード
float LightSpeedMax = 0.2;  // 光粒子最大スピード
float LightCross = 2.0;     // 光粒子の十字度合い

int SeedXY = 7;           // 配置に関する乱数シード
int SeedSize = 3;         // サイズに関する乱数シード
int SeedSpeed = 13;       // スピードに関する乱数シード
int SeedCross = 11;       // 十字度合いに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int Index;

float time : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5f, 0.5f)/ViewportSize);

texture2D BackTex <
    string ResourceName = "HeavenBack.png";
>;
sampler BackSamp = sampler_state {
    texture = <BackTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex1 <
    string ResourceName = "Particle1.png";
>;
sampler ParticleSamp1 = sampler_state {
    texture = <ParticleTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex2 <
    string ResourceName = "Particle2.png";
>;
sampler ParticleSamp2 = sampler_state {
    texture = <ParticleTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// 背景描画

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Back_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);

    return Out;
}

// ピクセルシェーダ
float4 Back_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    float4 Color = tex2D( BackSamp, Tex );
    Color.a *= AcsTr;
    return Color;
}

// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0"; > {
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Back_VS();
        PixelShader  = compile ps_2_0 Back_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Tex        : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand0 = abs(0.6f*sin(37 * SeedSize * Index + 13) + 0.4f*cos(71 * SeedSize * Index + 17));
    float rand1 = abs(0.4f*sin(53 * SeedSpeed * Index + 17) + 0.6f*cos(61 * SeedSpeed * Index + 19));
    float rand2 = abs(0.7f*sin(124 * SeedXY * Index + 19) + 0.3f*cos(235 * SeedXY * Index + 23));
    float rand3 = abs(0.6f*sin(83 * SeedXY * Index + 23) + 0.4f*cos(91 * SeedXY * Index + 29));
    float rand4 = (sin(47 * SeedCross * Index + 29) + cos(81 * SeedCross * Index + 31) + 3.0f) * 0.1f;

    // パーティクルサイズ
    float scale = (0.5f + rand0) * LightScale;
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;

    // パーティクル配置
    float speed = lerp(LightSpeedMin, LightSpeedMax, rand1);
    Pos.x += 2.0f * (rand2 - 0.5f);
    float y =2.0f * (rand3 - 0.5f);
    Pos.y += ((y+speed*time+1.0f)%2.0f-1.0f)*1.2f;
    Out.Pos = Pos;

    // テクスチャ座標
    Out.Tex = float3(Tex, 1.2f+LightCross*rand4);

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( ParticleSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= 0.4f*AcsTr;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "1-1000";
    string Script = "LoopByCount=ParticleCount;"
                    "LoopGetIndex=Index;"
                        "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

