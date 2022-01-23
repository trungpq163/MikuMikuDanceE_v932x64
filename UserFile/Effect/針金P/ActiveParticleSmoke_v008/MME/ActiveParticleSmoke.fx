////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ActiveParticleSmoke.fx ver0.0.8 納豆ミサイルっぽいエフェクト
//  オブジェクトの移動に応じて煙が尾を引きます  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 粒子数設定
#define UNIT_COUNT   8   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

// 粒子パラメータスイッチ
#define SMOKE_TYPE  1    // 煙の種類(とりあえず0～2で選択,0:従来通り,1:ノーマルマップ使用粒小,2:ノーマルマップ使用粒大)
#define MMD_LIGHT   1    // MMDの照明操作に 0:連動しない, 1:連動する

// 粒子パラメータ設定
float3 ParticleColor = {1.0, 1.0, 1.0}; // 粒子の色(RBG)
float ParticleSize = 1.5;           // 粒子大きさ
float ParticleSpeedMin = 0.5;       // 粒子初期最小スピード
float ParticleSpeedMax = 1.5;       // 粒子初期最大スピード
float ParticleInitPos = 0.0;        // 粒子発生時の相対位置(大きくすると粒子の初期配置がばらつきます)
float ParticleLife = 5.0;           // 粒子の寿命(秒)
float ParticleDecrement = 0.3;      // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleScaleUp = 2.0;        // 粒子発生後の拡大度
float ParticleContrast = 0.4;       // 粒子陰影のコントラスト(0.0～1.0、ノーマルマップ使用時のみ有効)
float ParticleShadeDiffusion = 4.0; // 粒子発生後の陰影拡散度(大きくすると時間がたつにつれ陰影がぼやけてくる、ノーマルマップのみ)
float OccurFactor = 1.0;            // オブジェクト移動量に対する粒子発生度(大きくすると粒子が出やすくなる)
float ObjVelocityRate = -1.5;       // オブジェクト移動方向に対する粒子速度依存度
float3 StartDirect = {0.0, 1.0, 0.0};   // 初期噴射方向ベクトル
float DiffusionAngle = 180.0;           // 初期噴射拡散角(0.0～180.0)


// 追加粒子設定
#define UNIT_COUNT0   0   // ←この数×1024 が一度に描画出来る追加粒子の数になる(整数値で指定,0にすると追加粒子描画は行わない)
#define TEX_ADD_FLG   1   // 0:半透明合成, 1:加算合成

float3 ParticleColor0 = {1.0, 0.4, 0.0}; // 追加粒子の色(RBG)
float ParticleLightPower0 = 1.0;    // 加算合成時の輝度
float ParticleLife0 = 0.3;          // 追加粒子の寿命(秒)
float OccurFactor0 = 2.0;           // オブジェクト移動量に対する追加粒子発生度(大きくすると粒子が出やすくなる)


// 物理パラメータ設定
float3 GravFactor = {0.0, 0.0, 0.0};    // 重力定数
float ResistFactor = 0.0;               // 速度抵抗係数

// (風等の)空間の流速場を定義する関数
// 粒子位置ParticlePosにおける空気の流れを記述します。
// 戻り値が0以外の時はオブジェクトが動かなくても粒子を放出します。
// ただし速度抵抗係数がResistFactor>0でないと流速場は粒子の動きに影響を与えません。
float3 VelocityField(float3 ParticlePos)
{
   float3 vel = float3( 0.0, 0.0, 0.0 );
   return vel;
}


// 必要に応じて煙のテクスチャをここで定義
#if SMOKE_TYPE == 0
   #define TEX_FileName  "Smoke.png"     // 粒子に貼り付けるテクスチャファイル名
   #define TEX_TYPE   0             // 粒子テクスチャの種類 0:通常テクスチャ, 1:ノーマルマップ
   #define TEX_PARTICLE_XNUM  1     // 粒子テクスチャのx方向粒子数
   #define TEX_PARTICLE_YNUM  1     // 粒子テクスチャのy方向粒子数
   #define TEX_PARTICLE_PXSIZE 128  // 1粒子当たりに使われているテクスチャのピクセルサイズ
#endif

#if SMOKE_TYPE == 1
   #define TEX_FileName  "SmokeNormal1.png" // 粒子に貼り付けるテクスチャファイル名
   #define TEX_TYPE   1             // 粒子テクスチャの種類 0:通常テクスチャ, 1:ノーマルマップ
   #define TEX_PARTICLE_XNUM  2     // 粒子テクスチャのx方向粒子数
   #define TEX_PARTICLE_YNUM  2     // 粒子テクスチャのy方向粒子数
   #define TEX_PARTICLE_PXSIZE 128  // 1粒子当たりに使われているテクスチャのピクセルサイズ
#endif

#if SMOKE_TYPE == 2
   #define TEX_FileName  "SmokeNormal2.png" // 粒子に貼り付けるテクスチャファイル名
   #define TEX_TYPE   1             // 粒子テクスチャの種類 0:通常テクスチャ, 1:ノーマルマップ
   #define TEX_PARTICLE_XNUM  2     // 粒子テクスチャのx方向粒子数
   #define TEX_PARTICLE_YNUM  2     // 粒子テクスチャのy方向粒子数
   #define TEX_PARTICLE_PXSIZE 128  // 1粒子当たりに使われているテクスチャのピクセルサイズ
#endif

// オプションのコントロールファイル名
#define BackgroundCtrlFileName  "BackgroundControl.x" // 背景座標コントロールファイル名
#define SmoothCtrlFileName      "SmoothControl.x"     // 接地面スムージングコントロールファイル名
#define TimrCtrlFileName        "TimeControl.x"       // 時間制御コントロールファイル名


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ArrangeFileName "Arrange.pfm" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  4            // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH    UNIT_COUNT   // テクスチャピクセル幅
#define TEX_HEIGHT   1024         // テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

// オプションのコントロールパラメータ
bool IsBack : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;
float4x4 BackMat : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;

bool IsSmooth : CONTROLOBJECT < string name = SmoothCtrlFileName; >;
float SmoothSi : CONTROLOBJECT < string name = SmoothCtrlFileName; string item = "Si"; >;
float4x4 SmoothMat : CONTROLOBJECT < string name = SmoothCtrlFileName; >;
static float3 SmoothPos = SmoothMat._41_42_43;
static float3 SmoothNormal = normalize(SmoothMat._21_22_23);

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
float3 LightDirection : DIRECTION < string Object = "Light"; >;
float3 LightColor : SPECULAR < string Object = "Light"; >;
static float3 ResColor = ParticleColor * lerp(float3(0.5f, 0.5f, 0.5f), float3(1.33f, 1.33f, 1.33f), LightColor);
static float3 ResColor0 = ParticleColor0 * lerp(float3(0.5f, 0.5f, 0.5f), float3(1.33f, 1.33f, 1.33f), LightColor);
#else
float3 LightDirection : DIRECTION < string Object = "Camera"; >;
static float3 ResColor = ParticleColor;
static float3 ResColor0 = ParticleColor0;
#endif

static float diffD = saturate( 1.0f - DiffusionAngle / 180.0 );
static float3 sDirect = normalize( StartDirect );

float3 CameraPosition : POSITION  < string Object = "Camera"; >;
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 座標変換行列
float4x4 WorldMatrix       : WORLD;
float4x4 ViewMatrix        : VIEW;
float4x4 ProjMatrix        : PROJECTION;
float4x4 ViewProjMatrix    : VIEWPROJECTION;
float4x4 ViewMatrixInverse : VIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

// 粒子テクスチャ
texture2D ParticleTex <
    string ResourceName = TEX_FileName;
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

// 配置･乱数情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp : register(s2) = sampler_state{
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

// オブジェクトのワールド座標記録用
texture WorldCoord : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp = sampler_state
{
   Texture = <WorldCoord>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture WorldCoordDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 噴射口追加粒子テクスチャ定義

#if (UNIT_COUNT0 > 0)

#define TEX_WIDTH0  UNIT_COUNT0  // テクスチャピクセル幅

int RepertCount0 = UNIT_COUNT0;  // シェーダ内描画反復回数

// 粒子座標記録用
texture CoordTex0 : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH0;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp0 : register(s3) = sampler_state
{
   Texture = <CoordTex0>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer0 : RenderDepthStencilTarget <
   int Width=TEX_WIDTH0;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// 粒子速度記録用
texture VelocityTex0 : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH0;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp0 = sampler_state
{
   Texture = <VelocityTex0>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};

// オブジェクトのワールド座標記録用
texture WorldCoord0 : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp0 = sampler_state
{
   Texture = <WorldCoord0>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};

#endif


////////////////////////////////////////////////////////////////////////////////////////////////

// 配置･乱数情報テクスチャからデータを取り出す
float3 Color2Float(int index, int item)
{
    return tex2D(ArrangeSmp, float2((item+0.5f)/TEX_WIDTH_A, (index+0.5f)/TEX_HEIGHT)).xyz;
}

////////////////////////////////////////////////////////////////////////////////////////////////

// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

// クォータニオンの積算
float4 MulQuat(float4 q1, float4 q2)
{
   return float4(cross(q1.xyz, q2.xyz)+q1.xyz*q2.w+q2.xyz*q1.w, q1.w*q2.w-dot(q1.xyz, q2.xyz));
}

// 背景アクセ基準のワールド座標→MMDワールド座標
float3 InvBackWorldCoord(float3 pos)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        pos = mul( float4(pos, 1), float4x4( BackMat[0]*scaling,
                                             BackMat[1]*scaling,
                                             BackMat[2]*scaling,
                                             BackMat[3] )      ).xyz;
    }
    return pos;
}

// MMDワールド座標→背景アクセ基準のワールド座標
float3 BackWorldCoord(float3 pos)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        float3x3 mat3x3_inv = transpose((float3x3)BackMat) * scaling;
        pos = mul( float4(pos, 1), float4x4( mat3x3_inv[0], 0, 
                                             mat3x3_inv[1], 0, 
                                             mat3x3_inv[2], 0, 
                                            -mul(BackMat._41_42_43,mat3x3_inv), 1 ) ).xyz;
    }
    return pos;
}

// MMDワールド変換行列→背景アクセ基準のワールド変換行列
float4x4 BackWorldMatrix(float4x4 mat)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        float3x3 mat3x3_inv = transpose((float3x3)BackMat) * scaling;
        mat = mul( mat, float4x4( mat3x3_inv[0], 0, 
                                  mat3x3_inv[1], 0, 
                                  mat3x3_inv[2], 0, 
                                 -mul(BackMat._41_42_43,mat3x3_inv), 1 ) );
    }
    return mat;
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


////////////////////////////////////////////////////////////////////////////////////////
// 粒子の発生・座標更新計算(xyz:座標,w:経過時間+1sec,wは更新時に1に初期化されるため+1sからスタート)

float4 UpdatePos_PS(float2 Tex: TEXCOORD0, uniform bool calcMain, uniform int texWidth, 
                    uniform sampler smpCoord, uniform sampler smpVelocity, uniform sampler smpWorldCoord) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(smpCoord, Tex);

   // 粒子の速度
   float3 Vel = tex2D(smpVelocity, Tex).xyz;

   if(Pos.w < 1.001f){
   // 未発生粒子の中から移動距離に応じて新たに粒子を発生させる
      // 現在のオブジェクト座標
      float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);

      // 1フレーム前のオブジェクト座標
      float4 WPos0 = tex2D(smpWorldCoord, float2(0.5f, 0.5f));
      WPos0.xyz -= VelocityField(WPos1) * Dt; // 流体速度場位置補正

      // 1フレーム間の発生粒子数
      float occurFact = calcMain ? OccurFactor : OccurFactor0;
      float p_count = length( WPos1 - WPos0.xyz ) * occurFact * AcsSi*0.1f;

      // 粒子インデックス
      int i = floor( Tex.x*texWidth );
      int j = floor( Tex.y*TEX_HEIGHT );
      float p_index = float( i*TEX_HEIGHT + j );

      // 新たに粒子を発生させるかどうかの判定
      if(p_index < WPos0.w) p_index += float(texWidth*TEX_HEIGHT);
      if(p_index < WPos0.w+p_count){
         // 粒子発生座標
         float s = (p_index - WPos0.w) / p_count;
         float aveSpeed = (ParticleSpeedMin + ParticleSpeedMax) * 0.5f;
         Pos.xyz = lerp(WPos0.xyz, WPos1, s) + Vel * ParticleInitPos * Color2Float(j, 1).x / aveSpeed;
         Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生
      }else{
         Pos.xyz = WPos1;
      }
   }else{
   // 発生中粒子の座標を更新
      // 加速度計算(速度抵抗力+重力)
      float3 Accel = ( VelocityField(Pos.xyz) - Vel ) * ResistFactor + GravFactor;

      // 座標移動量
      float3 dPos = Dt * (Vel + Dt * Accel);

      // 発生直後の粒子位置を一様化(初速度に伴う偏りを均一化する)
      if(Pos.w < 1.00111f){
          int j = floor( Tex.y*TEX_HEIGHT );
          dPos = lerp(float3(0,0,0), dPos, Color2Float(j, 1).y);
      }

      // 座標・経過時間の更新
      Pos += float4(dPos, Dt);

      // 指定時間を超えると0(粒子消失)
      if( calcMain ){
          Pos.w *= step(Pos.w-1.0f, ParticleLife);
      }else{
          Pos.w *= step(Pos.w-1.0f, ParticleLife0);
      }
   }

   // 0フレーム再生で粒子初期化
   if(time < 0.001f) Pos = float4(BackWorldCoord(WorldMatrix._41_42_43), 0.0f);

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////
// 粒子の速度計算

float4 UpdateVelocity_PS(float2 Tex: TEXCOORD0, uniform sampler smpCoord,
                         uniform sampler smpVelocity, uniform sampler smpWorldCoord) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(smpCoord, Tex);

   // 粒子の速度
   float4 Vel = tex2D(smpVelocity, Tex);

   if(Pos.w < 1.00111f){
      // 発生したての粒子に初速度与える
      int j = floor( Tex.y*TEX_HEIGHT );
      float3 vec = Color2Float(j, 0);
      float3 v = cross( sDirect, vec ); // 放出方向への回転軸
      v = any(v) ? normalize(v) : float3(0,0,1);
      float rot = acos( dot( vec, sDirect) ) * diffD; // 放出方向への回転角
      float sinHD = sin(0.5f * rot);
      float cosHD = cos(0.5f * rot);
      float4 q1 = float4(v*sinHD, cosHD);
      float4 q2 = float4(-v*sinHD, cosHD);
      vec = MulQuat( MulQuat(q2, float4(vec, 1.0f)), q1).xyz; // 放出方向への回転(クォータニオン)
      float speed = lerp( ParticleSpeedMin, ParticleSpeedMax, Color2Float(j, 1).y );
      Vel = float4( normalize( mul( vec, (float3x3)BackWorldMatrix(WorldMatrix) ) ) * speed, 1.0f );
      float4 WPos0 = tex2D(smpWorldCoord, float2(0.5f, 0.5f));
      float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);
      Vel.xyz += normalize(WPos1-WPos0.xyz)*ObjVelocityRate; // オブジェクト移動方向を付加する
   }else{
      // 発生中粒子の速度計算
      float3 Accel = ( VelocityField(Pos.xyz) - Vel.xyz ) * ResistFactor + GravFactor; // 加速度計算(速度抵抗力+重力)
      Vel.xyz += Dt * Accel; // 新しい速度に更新
   }

   return Vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトのワールド座標記録

VS_OUTPUT WorldCoord_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = float2(0.5f, 0.5f);

    return Out;
}

float4 WorldCoord_PS(float2 Tex: TEXCOORD0, uniform bool calcMain, uniform int texWidth, uniform sampler smpWorldCoord) : COLOR
{
   // オブジェクトのワールド座標
   float3 Pos1 = BackWorldCoord(WorldMatrix._41_42_43);
   float4 Pos0 = tex2D(smpWorldCoord, Tex);
   Pos0.xyz -= VelocityField(Pos1) * Dt; // 流体速度場位置補正

   // 次発生粒子の起点
   float occurFact = calcMain ? OccurFactor : OccurFactor0;
   float p_count = length( Pos1 - Pos0.xyz ) * occurFact * AcsSi*0.1f;
   float w = Pos0.w + p_count;
   if(w >= float(texWidth*TEX_HEIGHT)) w -= float(texWidth*TEX_HEIGHT);
   if(time < 0.001f) w = 0.0f;

   return float4(Pos1, w);
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos       : POSITION;    // 射影変換座標
    float2 Tex       : TEXCOORD0;   // テクスチャ
    float3 Param     : TEXCOORD1;   // x経過時間,yボードピクセルサイズ,z回転
    float  Distance  : TEXCOORD2;   // 壁距離
    float3 LightDir  : TEXCOORD3;   // ライト方向
    float4 Color     : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool calcMain, uniform int texWidth, uniform sampler smpCoord)
{
   VS_OUTPUT2 Out = (VS_OUTPUT2)0;

   int i = RepertIndex;
   int j = round( Pos.z * 100.0f );
   int Index0 = i * TEX_HEIGHT + j;
   float2 texCoord = float2((i+0.5f)/texWidth, (j+0.5f)/TEX_HEIGHT);
   Pos.z = 0.0f;

   // 粒子の座標
   float4 Pos0 = tex2Dlod(smpCoord, float4(texCoord, 0, 0));
   Pos0.xyz = InvBackWorldCoord(Pos0.xyz);

   // 経過時間
   float etime = Pos0.w - 1.0f;
   Out.Param.x = etime;

   // 乱数設定
   float3 rand = tex2Dlod(ArrangeSmp, float4(3.5f/TEX_WIDTH_A, (j+0.5f)/TEX_HEIGHT, 0, 0)).xyz;

   // 経過時間に対する粒子拡大度
   float scale = ParticleScaleUp * sqrt(etime) + 2.0f;

   // 粒子の大きさ
   scale *= 0.5f + rand.x;
   Pos.xy *= ParticleSize * scale * 10.0f;

   // ボードに貼るテクスチャのミップマップレベル
   float pxLen = length(CameraPosition - Pos0.xyz);
   float4 pxPos = float4(0.0f, abs(Pos.y), pxLen, 1.0f);
   pxPos = mul( pxPos, ProjMatrix );
   float pxSize = ViewportSize.y * pxPos.y/pxPos.w;
   Out.Param.y = max( log2(TEX_PARTICLE_PXSIZE/pxSize), 0.0f );

   // 粒子の回転
   float rot = 2.0f * PAI * rand.y;
   Pos.xy = Rotation2D(Pos.xy, rot);
   Out.Param.z = rot;

   // ビルボード
   Pos.xyz = mul( Pos.xyz, BillboardMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の遮蔽面距離
   Out.Distance = dot(Pos.xyz-SmoothPos, SmoothNormal);

   // カメラ視点のライト方向
   Out.LightDir = mul(-LightDirection, (float3x3)ViewMatrix);

   // 粒子の乗算色
   float pLife = calcMain ? ParticleLife : ParticleLife0;
   float alpha = step(0.001f, etime) * smoothstep(-pLife, -pLife*ParticleDecrement, -etime) * AcsTr;
   Out.Color = calcMain ? float4(ResColor, alpha) : float4(ResColor0, alpha);

   // テクスチャ座標
   int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN, uniform bool calcMain ) : COLOR0
{
   #if TEX_TYPE == 1
   // 粒子テクスチャ(ノーマルマップ)から法線計算
   float shadeDiffuse = max( IN.Param.y, lerp(0, ParticleShadeDiffusion, IN.Param.x/ParticleLife) );
   float4 Color = tex2Dlod( ParticleSamp, float4(IN.Tex, 0, shadeDiffuse) );
   float3 Normal = float3(2.0f * Color.r - 1.0f, 1.0f - 2.0f * Color.g,  -Color.b);
   Normal.xy = Rotation2D(Normal.xy, IN.Param.z);
   Normal = normalize(Normal);

   // 粒子の色
   Color.rgb = saturate(IN.Color.rgb * lerp(1.0f-ParticleContrast, 1.0f, max(dot(Normal, IN.LightDir), 0.0f)));
   Color.a *= tex2Dlod( ParticleSamp, float4(IN.Tex, 0, 0) ).a * IN.Color.a;

   #else
   // 粒子テクスチャの色
   float4 Color = tex2D( ParticleSamp, IN.Tex );

   // 粒子の色
   Color *= IN.Color;
   Color.rgb = saturate(Color.rgb);
   #endif

   // 遮蔽面処理
   if( IsSmooth ){
      float pSize = clamp(ParticleSize, 0.5f, 2.0f);
      if( calcMain ){
         Color.a *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Distance);
      }else{
         #if TEX_ADD_FLG == 1
         Color.rgb *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Distance);
         #else
         Color.a *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Distance);
         #endif
      }
   }

   // α透過部は描画しない
   clip(Color.a - 0.005f);

   #if TEX_ADD_FLG == 1
   if( !calcMain ) Color.rgb *= Color.a * ParticleLightPower0;
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
       "RenderColorTarget0=WorldCoord;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;"
       #if (UNIT_COUNT0 > 0)
       "RenderColorTarget0=CoordTex0;"
	    "RenderDepthStencilTarget=CoordDepthBuffer0;"
	    "Pass=UpdatePos0;"
       "RenderColorTarget0=VelocityTex0;"
	    "RenderDepthStencilTarget=CoordDepthBuffer0;"
	    "Pass=UpdateVelocity0;"
       "RenderColorTarget0=WorldCoord0;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord0;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount0;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject0;"
            "LoopEnd=;"
       #endif
       ;
>{
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS( true, TEX_WIDTH, CoordSmp, VelocitySmp, WorldCoordSmp );
   }
   pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS( CoordSmp, VelocitySmp, WorldCoordSmp );
   }
   pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS( true, TEX_WIDTH, WorldCoordSmp );
   }
   pass DrawObject {
       ZENABLE = TRUE;
       ZWRITEENABLE = FALSE;
       AlphaBlendEnable = TRUE;
       VertexShader = compile vs_3_0 Particle_VS( true, TEX_WIDTH, CoordSmp );
       PixelShader  = compile ps_3_0 Particle_PS( true );
   }
   #if (UNIT_COUNT0 > 0)
   pass UpdatePos0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS( false, TEX_WIDTH0, CoordSmp0, VelocitySmp0, WorldCoordSmp0 );
   }
   pass UpdateVelocity0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS( CoordSmp0, VelocitySmp0, WorldCoordSmp0 );
   }
   pass UpdateWorldCoord0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS( false, TEX_WIDTH0, WorldCoordSmp0 );
   }
   pass DrawObject0 {
       ZENABLE = TRUE;
       ZWRITEENABLE = FALSE;
       AlphaBlendEnable = TRUE;
       #if TEX_ADD_FLG == 1
         DestBlend = ONE;
         SrcBlend = ONE;
       #else
         DestBlend = INVSRCALPHA;
         SrcBlend = SRCALPHA;
       #endif
       VertexShader = compile vs_3_0 Particle_VS( false, TEX_WIDTH0, CoordSmp0 );
       PixelShader  = compile ps_3_0 Particle_PS( false );
   }
   #endif
}


// テクニック(MMDPass = "object"と同じ, 影ONにしないとZPlot描画が行われないので)
technique MainTecSS1 < string MMDPass = "object_ss";
   string Script = 
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=WorldCoord;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;"
       #if (UNIT_COUNT0 > 0)
       "RenderColorTarget0=CoordTex0;"
	    "RenderDepthStencilTarget=CoordDepthBuffer0;"
	    "Pass=UpdatePos0;"
       "RenderColorTarget0=VelocityTex0;"
	    "RenderDepthStencilTarget=CoordDepthBuffer0;"
	    "Pass=UpdateVelocity0;"
       "RenderColorTarget0=WorldCoord0;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord0;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount0;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject0;"
            "LoopEnd=;"
       #endif
       ;
>{
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS( true, TEX_WIDTH, CoordSmp, VelocitySmp, WorldCoordSmp );
   }
   pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS( CoordSmp, VelocitySmp, WorldCoordSmp );
   }
   pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS( true, TEX_WIDTH, WorldCoordSmp );
   }
   pass DrawObject {
       ZENABLE = TRUE;
       ZWRITEENABLE = FALSE;
       AlphaBlendEnable = TRUE;
       VertexShader = compile vs_3_0 Particle_VS( true, TEX_WIDTH, CoordSmp );
       PixelShader  = compile ps_3_0 Particle_PS( true );
   }
   #if (UNIT_COUNT0 > 0)
   pass UpdatePos0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS( false, TEX_WIDTH0, CoordSmp0, VelocitySmp0, WorldCoordSmp0 );
   }
   pass UpdateVelocity0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS( CoordSmp0, VelocitySmp0, WorldCoordSmp0 );
   }
   pass UpdateWorldCoord0 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS( false, TEX_WIDTH0, WorldCoordSmp0 );
   }
   pass DrawObject0 {
       ZENABLE = TRUE;
       ZWRITEENABLE = FALSE;
       AlphaBlendEnable = TRUE;
       #if TEX_ADD_FLG == 1
         DestBlend = ONE;
         SrcBlend = ONE;
       #else
         DestBlend = INVSRCALPHA;
         SrcBlend = SRCALPHA;
       #endif
       VertexShader = compile vs_3_0 Particle_VS( false, TEX_WIDTH0, CoordSmp0 );
       PixelShader  = compile ps_3_0 Particle_PS( false );
   }
   #endif
}


///////////////////////////////////////////////////////////////////////////////////////
// ZPlotパーティクル描画

// 透過値に対する深度読み取り閾値
#define AlphaClipThreshold  0.2f

// 座標変換行列
float4x4 LightViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;
float4x4 LightViewMatrixInverse : VIEWINVERSE < string Object = "Light"; >;

static float3x3 LightBillboardMatrix = {
    normalize(LightViewMatrixInverse[0].xyz),
    normalize(LightViewMatrixInverse[1].xyz),
    normalize(LightViewMatrixInverse[2].xyz),
};

struct VS_OUTPUT3
{
    float4 Pos          : POSITION;    // 射影変換座標
    float2 Tex          : TEXCOORD0;   // テクスチャ
    float4 ShadowMapTex : TEXCOORD1;    // Zバッファテクスチャ
    float2 Param        : TEXCOORD2;   // alpha,高さ
};

// 頂点シェーダ
VS_OUTPUT3 ParticleZPlot_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT3 Out = (VS_OUTPUT3)0;

   int i = RepertIndex;
   int j = round( Pos.z * 100.0f );
   int Index0 = i * TEX_HEIGHT + j;
   float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
   Pos.z = 0.0f;

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 0));
   Pos0.xyz = InvBackWorldCoord(Pos0.xyz);

   // 経過時間
   float etime = Pos0.w - 1.0f;
   Out.Param.x = etime;

   // 乱数設定
   float3 rand = tex2Dlod(ArrangeSmp, float4(3.5f/TEX_WIDTH_A, (j+0.5f)/TEX_HEIGHT, 0, 0)).xyz;

   // 経過時間に対する粒子拡大度
   float scale = ParticleScaleUp * sqrt(etime) + 2.0f;

   // 粒子の大きさ
   scale *= 0.5f + rand.x;
   Pos.xy *= ParticleSize * scale * 10.0f;

   // 粒子の回転
   float rot = 2.0f * PAI * rand.y;
   Pos.xy = Rotation2D(Pos.xy, rot);

   // ビルボード
   Pos.xyz = mul( Pos.xyz, LightBillboardMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

   // ライト視点のビュー射影変換
   Out.Pos = mul( Pos, LightViewProjMatrix );

   // テクスチャ座標を頂点に合わせる
   Out.ShadowMapTex = Out.Pos;

   // 粒子の遮蔽面高さ
   Out.Param.y = dot(Pos.xyz-SmoothPos, SmoothNormal);

   // α値
   float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
   Out.Param.x = alpha;

   // テクスチャ座標
   int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}

// ピクセルシェーダ
float4 ParticleZPlot_PS( VS_OUTPUT3 IN ) : COLOR0
{
   // α値
   float alpha = tex2D( ParticleSamp, IN.Tex ).a * IN.Param.x;

   // 遮蔽面処理
   if( IsSmooth ){
      float pSize = clamp(ParticleSize, 0.5f, 2.0f);
      alpha *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Param.y);
   }

   // α透過部は描画しない
   clip(alpha - AlphaClipThreshold);

   // R色成分にZ値を記録する
   return float4(IN.ShadowMapTex.z/IN.ShadowMapTex.w, 0, 0, 1);
}


///////////////////////////////////////////////////////////////////////////////////////
// ZPlotテクニック
technique ZplotTec < string MMDPass = "zplot";
   string Script = "LoopByCount=RepertCount;"
                   "LoopGetIndex=RepertIndex;"
                      "Pass=ZValuePlot;"
                   "LoopEnd=;" ;
>{
    pass ZValuePlot {
       AlphaBlendEnable = TRUE;
       VertexShader = compile vs_3_0 ParticleZPlot_VS();
       PixelShader  = compile ps_3_0 ParticleZPlot_PS();
   }
}

// エッジ・地面影は表示しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

