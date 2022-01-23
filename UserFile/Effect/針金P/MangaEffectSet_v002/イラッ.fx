////////////////////////////////////////////////////////////////////////////////////////////////
//
//  イラッ.fx ver0.0.2  漫画風表現エフェクト(イラッ)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define TexFile  "ira.png"     // 粒子に貼り付けるテクスチャファイル名
int ParticleCount = 10;        // 粒子の描画オブジェクト数
float ParticleSize = 1.0;      // 粒子大きさ
float ParticleRot = 1.0;       // 粒子の回転角
float ParticleLife = 1.5;      // 粒子の寿命(秒)
float ParticleDecrement = 0.7; // 粒子が消失を開始する時間(ParticleLifeとの比)

float Rmin = 3.0;      // 配置半径最小値
float Rmax = 7.0;      // 配置半径最大値
float Rotmin = -40.0;  // 移動方向角最小値
float Rotmax = 40.0;   // 移動方向角最大値

int SeedR = 3;         // 配置半径に関する乱数シード
int SeedRot = 9;       // 移動方向角に関する乱数シード
int SeedPRot = 8;      // 粒子回転に関する乱数シード
int SeedBlink = 8;     // 粒子点滅に関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

static float diffDmin = radians( Rotmin );
static float diffDmax = radians( Rotmax );

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


texture2D ParticleTex <
    string ResourceName = TexFile;
    int MipLevels = 0;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
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


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand1 = abs(0.7f*sin(124 * SeedRot * Index + 19) + 0.3f*cos(235 * SeedRot * Index + 23));
    float rand2 = abs(0.6f*sin(83 * SeedR * Index + 23) + 0.4f*cos(91 * SeedR * Index + 29));
    float rand3 = 0.4f*sin(53 * SeedPRot * Index + 17) + 0.6f*cos(61 * SeedPRot * Index + 19);
    float rand4 = 0.6f*sin(37 * SeedBlink * Index + 13) + 0.4f*cos(71 * SeedBlink * Index + 17);

    // パーティクルサイズ
    Pos.xy *= ParticleSize;

    //  パーティクル回転
    float prot = rand3;
    Pos.xy = Rotation2D(Pos.xy, ParticleRot*rand3);

    // パーティクル配置
    float rot = lerp(diffDmin, diffDmax, rand1);
    float e = (Rmax-Rmin) * 0.1f;
    float r = lerp( Rmin-e, Rmax+e, rand2 );
    Pos.xy += float2( r*sin(rot), r*cos(rot) ) * 0.1f;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 粒子の透過度
    float t = fmod( time+ParticleLife*rand4, ParticleLife*2.0f );
    float alpha = (1.0f - smoothstep(ParticleDecrement*ParticleLife, ParticleLife, t)) * AcsTr;
    Out.Color = float4(1.0f, 1.0f, 1.0f, alpha);

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
   float4 Color = tex2D( ParticleSamp, IN.Tex );
   Color *= IN.Color;
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
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

