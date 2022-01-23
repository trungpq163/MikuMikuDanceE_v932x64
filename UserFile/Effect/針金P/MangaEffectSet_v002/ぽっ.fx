////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ぽっ.fx ver0.0.2  漫画風表現エフェクト(ぽっ)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define TexFile  "hart.png"   // 粒子に貼り付けるテクスチャファイル名
int ParticleCount = 30;    // 粒子の描画オブジェクト数
float ParticleSize = 0.5;  // 粒子大きさ
float ParticleSpeed = 0.3; // 粒子のスピード
float ParticleAmp = 1.0;   // 粒子の水平移動振幅
float ParticleFreq = 2.0;  // 粒子の水平移動周波数

float Rmin = 2.0;          // 配置半径最小値
float Rmax = 9.0;          // 配置半径最大値
float Rotmin = -30.0;      // 移動方向角最小値
float Rotmax = 30.0;       // 移動方向角最大値

int SeedR = 3;             // 配置半径に関する乱数シード
int SeedRot = 13;          // 移動方向角に関する乱数シード
int SeedShake = 8;         // 水平移動に関する乱数シード


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
    float rand3 = 0.4f*sin(53 * SeedShake * Index + 17) + 0.6f*cos(61 * SeedShake * Index + 19);

    // パーティクルサイズ
    Pos.xy *= ParticleSize;

    // パーティクル配置
    float rot = lerp(diffDmin, diffDmax, rand1);
    float e = (Rmax-Rmin) * 0.1f;
    float r = lerp( Rmin-e, Rmax+e, fmod(rand2+ParticleSpeed*time, 1.0f) );
    Pos.xy += float2( r*sin(rot), r*cos(rot) ) * 0.1f;
    Pos.x += ParticleAmp * sin( ParticleFreq * time + rand3 * 6.28f ) * smoothstep(Rmin, Rmax, r) * 0.1f;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 粒子の透過度
    r = abs( (r-Rmin)/(Rmax-Rmin) - 0.5f );
    float alpha = ( 1.0f-smoothstep(0.2f, 0.5f, r) ) * AcsTr;
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

