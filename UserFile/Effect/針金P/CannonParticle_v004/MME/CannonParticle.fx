////////////////////////////////////////////////////////////////////////////////////////////////
//
//  CannonParticle.fx ver0.0.4 打ち出し式パーティクルエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 粒子数設定
#define UNIT_COUNT   2   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

#define MMD_LIGHT   1    // MMDの照明色に 0:連動しない, 1:連動する

#define TEX_FileName  "sample.png"  // 粒子に貼り付けるテクスチャファイル名
#define TEX_PARTICLE_XNUM   1       // 粒子テクスチャのx方向粒子数
#define TEX_PARTICLE_YNUM   1       // 粒子テクスチャのy方向粒子数
#define TEX_USE_MIPMAP      0       // テクスチャのミップマップ生成,0:しない,1:する
#define TEX_ZBuffWrite      1       // Zバッファの書き換え 0:しない, 1:する (テクスチャにα透過がある場合は0にする)

#define USE_SPHERE       1          // スフィアマップを 0:使う, 1:使わない
#define SPHERE_SATURATE  1          // スフィアマップ適用後に 0:そのまま, 1:色範囲を0～1に制限 ←ここが0だとAutoLuminousで発光する
#define SPHERE_FileName  "sphere_sample.png" // 粒子に貼り付けるスフィアマップテクスチャファイル名

// 粒子パラメータ設定
float3 ParticleColor = {1.0, 1.0, 1.0}; // テクスチャの乗算色(RBG)
float ParticleRandamColor = 0.8;   // 粒子色のばらつき度(0.0～1.0)
float ParticleSize = 0.2;          // 粒子大きさ
float ParticleSpeedMin = 150.0;    // 粒子初速度最小値
float ParticleSpeedMax = 200.0;    // 粒子初速度最大値
float ParticleRotSpeed = 4.0;      // 粒子の回転スピード
float ParticleInitPos = 1.0;       // 粒子発生時の分散位置(大きくすると粒子の初期配置が広くなります)
float ParticleLife = 8.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.9;     // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleOccur = 1.0;         // 粒子発生度(大きくすると粒子が出やすくなる)
float DiffusionAngle = 10.0;       // 発射拡散角(0.0～180.0)
float FloorFadeMax = 5.0;          // フェードアウト開始高さ
float FloorFadeMin = 0.0;          // フェードアウト終了高さ

// 物理パラメータ設定
float3 GravFactor = {0.0, -20.0, 0.0};   // 重力定数
float ResistFactor = 5.0;          // 速度抵抗力
float RotResistFactor = 8.0;       // 回転抵抗力(大きくするとゆらゆら感が増します)

// 時間制御コントロールファイル名
#define TimrCtrlFileName  "TimeControl.x"


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ArrangeFileName "Arrange.pfm" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A   4           // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH     UNIT_COUNT  // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT    1024        // 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

static float diffD = radians( clamp(90.0f - DiffusionAngle, -90.0f, 90.0f) );

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

// 時間設定
float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;
float elapsed_time : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = (TimeSync ? clamp(elapsed_time, 0.001f, 0.1f) : clamp(elapsed_time2, 0.0f, 0.1f)) * TimeRate;

#if MMD_LIGHT == 1
float3 LtColor : AMBIENT < string Object = "Light"; >;
static float3 LightColor = saturate( (LtColor + float3(0.3f, 0.3f, 0.3f)) * 0.833f + float3(0.5f, 0.5f, 0.5f) );
static float3 ResColor = ParticleColor * LightColor;
#else
float3 LightColor = float3(1, 1, 1);
static float3 ResColor = ParticleColor;
#endif

// 1フレーム当たりの粒子発生数
static float P_Count = ParticleOccur * (Dt / ParticleLife) * AcsSi*100;

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ViewProjMatrix : VIEWPROJECTION;

#if(TEX_USE_MIPMAP == 1)
// オブジェクトに貼り付けるテクスチャ(ミップマップも生成)
    texture2D ParticleTex <
        string ResourceName = TEX_FileName;
        int MipLevels = 0;
    >;
    sampler ParticleTexSamp = sampler_state {
        texture = <ParticleTex>;
        MinFilter = ANISOTROPIC;
        MagFilter = ANISOTROPIC;
        MipFilter = LINEAR;
        MaxAnisotropy = 16;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };

    #if(USE_SPHERE == 1)
    texture2D ParticleSphere <
        string ResourceName = SPHERE_FileName;
        int MipLevels = 0;
    >;
    sampler ParticleSphereSamp = sampler_state {
        texture = <ParticleSphere>;
        MinFilter = ANISOTROPIC;
        MagFilter = ANISOTROPIC;
        MipFilter = LINEAR;
        MaxAnisotropy = 16;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };
    #endif

#else
// オブジェクトに貼り付けるテクスチャ(ミップマップ生成なし)
    texture2D ParticleTex <
        string ResourceName = TEX_FileName;
        int MipLevels = 1;
    >;
    sampler ParticleTexSamp = sampler_state {
        texture = <ParticleTex>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = NONE;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };

    #if(USE_SPHERE == 1)
    texture2D ParticleSphere <
        string ResourceName = SPHERE_FileName;
        int MipLevels = 1;
    >;
    sampler ParticleSphereSamp = sampler_state {
        texture = <ParticleSphere>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = NONE;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };
    #endif

#endif

// 配置･乱数情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};

// 粒子座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s3) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp = sampler_state
{
   Texture = <VelocityTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float3 Color2Float(int index, int item)
{
    return tex2D(ArrangeSmp, float2((item+0.5f)/TEX_WIDTH_A, (index+0.5f)/TEX_HEIGHT)).xyz;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 粒子の回転行列
float3x3 RoundMatrix(int index, float etime)
{
   float rotX = ParticleRotSpeed * (1.0f + 0.3f*sin(247*index)) * etime + (float)index * 147.0f;
   float rotY = ParticleRotSpeed * (1.0f + 0.3f*sin(368*index)) * etime + (float)index * 258.0f;
   float rotZ = ParticleRotSpeed * (1.0f + 0.3f*sin(122*index)) * etime + (float)index * 369.0f;

   float sinx, cosx;
   float siny, cosy;
   float sinz, cosz;
   sincos(rotX, sinx, cosx);
   sincos(rotY, siny, cosy);
   sincos(rotZ, sinz, cosz);

   float3x3 rMat = { cosz*cosy+sinx*siny*sinz, cosx*sinz, -siny*cosz+sinx*cosy*sinz,
                    -cosy*sinz+sinx*siny*cosz, cosx*cosz,  siny*sinz+sinx*cosy*cosz,
                     cosx*siny,               -sinx,       cosx*cosy,               };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

///////////////////////////////////////////////////////////////////////////////////////
// 粒子の発生・座標更新計算(xyz:座標,w:経過時間+1sec,wは更新時に1に初期化されるため+1sからスタート)
float4 UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, Tex);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, Tex);

   int i = floor( Tex.x*TEX_WIDTH );
   int j = floor( Tex.y*TEX_HEIGHT );
   int p_index = j + i * TEX_HEIGHT;

   if(Pos.w < 1.001f){
   // 未発生粒子の中から新たに粒子を発生させる
      float3 WPos = Color2Float(j, 0);
      float3 WPos0 = WorldMatrix._41_42_43;
      WPos *= ParticleInitPos * 0.1f;
      WPos = mul( float4(WPos,1), WorldMatrix ).xyz;
      Pos.xyz = (WPos - WPos0) / AcsSi * 10.0f + WPos0;  // 発生初期座標

      // 新たに粒子を発生させるかどうかの判定
      if(p_index < Vel.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
      if(p_index < Vel.w+P_Count){
         Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生
      }
   }else{
   // 発生粒子は疑似物理計算で座標を更新
      // 粒子の法線ベクトル
      float3 normal = mul( float3(0.0f,0.0f,1.0f), RoundMatrix(p_index, Pos.w) );

      // 抵抗係数の設定
      float v = length( Vel.xyz );
      float cosa = dot( normalize(Vel.xyz), normal );
      float coefResist = lerp(ResistFactor, 0.0f, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));
      float coefRotResist = lerp(0.2f, RotResistFactor, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));

      // 加速度計算(速度抵抗力+回転抵抗力+重力)
      float3 Accel = -Vel.xyz * coefResist - normal * v * cosa * coefRotResist + GravFactor;

      // 新しい座標に更新
      Pos.xyz += Dt * (Vel.xyz + Dt * Accel);

      // すでに発生している粒子は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w-1.0f, ParticleLife); // 指定時間を超えると0
   }

   // 0フレーム再生で粒子初期化
   if(time < 0.001f) Pos = float4(WorldMatrix._41_42_43, 0.0f);

   return Pos;
}

///////////////////////////////////////////////////////////////////////////////////////
// 粒子の速度計算(xyz:速度,w:発生起点)
float4 UpdateVelocity_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, Tex);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, Tex);

   int i = floor( Tex.x*TEX_WIDTH );
   int j = floor( Tex.y*TEX_HEIGHT );
   int p_index = j + i * TEX_HEIGHT;

   if(Pos.w < 1.00111f){
   // 発生したての粒子に初速度与える
      float3 rand = Color2Float(j, 2);
      float time1 = time + 100.0f;
      float ss, cs;
      sincos( lerp(diffD, PAI*0.5f, frac(rand.x*time1)), ss, cs );
      float st, ct;
      sincos( lerp(-PAI, PAI, frac(rand.y*time1)), st, ct );
      float3 vec  = float3( cs*ct, ss, cs*st );
      Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) )
                * lerp(ParticleSpeedMin, ParticleSpeedMax, frac(rand.z*time1));
   }else{
   // 粒子の速度計算
      // 粒子の法線ベクトル
      float3 normal = mul( float3(0.0f,0.0f,1.0f), RoundMatrix(p_index, Pos.w) );

      // 抵抗係数の設定
      float v = length( Vel.xyz );
      float cosa = dot( normalize(Vel.xyz), normal );
      float coefResist = lerp(ResistFactor, 0.0f, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));
      float coefRotResist = lerp(0.2f, RotResistFactor, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));

      // 加速度計算(速度抵抗力+回転抵抗力+重力)
      float3 Accel = -Vel.xyz * coefResist - normal * v * cosa * coefRotResist + GravFactor;

      // 新しい速度に更新
      Vel.xyz += Dt * Accel;
   }

   // 次発生粒子の起点
   Vel.w += P_Count;
   if(Vel.w >= float(TEX_WIDTH*TEX_HEIGHT)) Vel.w -= float(TEX_WIDTH*TEX_HEIGHT);
   if(time < 0.001f) Vel.w = 0.0f;

   return Vel;
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos       : POSITION;    // 射影変換座標
    float2 Tex       : TEXCOORD0;   // テクスチャ
    float  TexIndex  : TEXCOORD1;   // テクスチャ粒子インデクス
    float2 SpTex     : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 Color     : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out=(VS_OUTPUT2)0;

   int i = RepertIndex;
   int j = round( Pos.z * 100.0f );
   int Index0 = i * TEX_HEIGHT + j;
   float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
   Pos.z = 0.0f;
   Out.TexIndex = float(j);

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 0));

   // 経過時間
   float etime = Pos0.w - 1.0f;

   // 粒子の法線ベクトル
   float3 Normal = normalize(float3(0.0f, 0.0f, -0.2f) - Pos.xyz);

   // 粒子の大きさ
   Pos.xy *= ParticleSize * 10.0f;

   // 粒子の回転
   Pos.xyz = mul( Pos.xyz, RoundMatrix(Index0, etime) );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の乗算色
   float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
   alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
   Out.Color = float4( ResColor, alpha );

   // テクスチャ座標
   int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

    #if( USE_SPHERE==1 )
       // スフィアマップテクスチャ座標
       Normal = mul( Normal, RoundMatrix(Index0, etime) );
       float2 NormalWV = mul( Normal, (float3x3)ViewMatrix ).xy;
       Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
       Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    #endif

   return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // 粒子の色
    float4 Color = IN.Color;
    Color *= tex2D( ParticleTexSamp, IN.Tex );

    // ランダム色設定
    float4 randColor = tex2D(ArrangeSmp, float2(3.5f/TEX_WIDTH_A, (IN.TexIndex+0.5f)/TEX_HEIGHT));
    Color.rgb *= lerp(float3(1.0f,1.0f,1.0f), randColor.rgb, ParticleRandamColor);

    #if( USE_SPHERE==1 )
        // スフィアマップ適用
        Color.rgb += tex2D(ParticleSphereSamp, IN.SpTex).rgb * LightColor;
        #if( SPHERE_SATURATE==1 )
            Color = saturate( Color );
        #endif
    #endif

    #if( TEX_ZBuffWrite==1 )
        clip(Color.a - 0.5);
    #endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;";
>{
    pass UpdatePos < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 UpdatePos_PS();
    }
    pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 UpdateVelocity_PS();
    }
    pass DrawObject {
        ZENABLE = TRUE;
        #if TEX_ZBuffWrite==0
        ZWRITEENABLE = FALSE;
        #endif
        AlphaBlendEnable = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}

