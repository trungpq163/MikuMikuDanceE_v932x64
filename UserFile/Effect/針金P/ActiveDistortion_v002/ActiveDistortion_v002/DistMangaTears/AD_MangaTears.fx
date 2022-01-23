////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DistMangaTears.fx ver0.0.4 漫画風涙パーティクルエフェクト歪みver(MangaTears.fx改変,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 粒子数設定
#define UNIT_COUNT   2   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

#define NORMAL_TYPE  2    // 粒子テクスチャの種類(とりあえず1,2で選択,1:ノーマルマップ粒小,2:ノーマルマップ粒大)

// 粒子パラメータ設定
float ParticleSize = 0.3;       // 粒子大きさ
float ParticleScaleUp = 1.0;     // 粒子の時間経過による拡大度
float ParticleReboundSize = 3.0; // はね返り後の粒子伸縮度
float ParticleSpeed = 12.0;      // 粒子初速度
float ParticleLife = 3.0;        // 粒子の寿命(秒)

// 物理パラメータ設定
float3 GravFactor = {0.0, -25.0, 0.0};   // 重力定数
float ResistFactor = 1.0;          // 速度抵抗力
float CoefRebound = 0.2;           // 地面のはね返り係数
float ReboundNoise = 5.0;          // 地面はね返り後の分散度

float3 OffsetPos = {0.0, 0.0, -1.0};  // 粒子発生位置の補正値(両目に付ける場合はXは0にしてMMDで設定)
float3 StartDirect = {1.0, 0.8, 0.0}; // 粒子放出方向ベクトル


// 必要に応じてノーマルマップテクスチャをここで定義

#if NORMAL_TYPE == 1
   #define TEX_FileName  "ParticleNormal1.png" // 粒子に貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  2     // 粒子テクスチャのx方向粒子数
   #define TEX_PARTICLE_YNUM  2     // 粒子テクスチャのy方向粒子数
   #define TEX_PARTICLE_PXSIZE 128  // 1粒子当たりに使われているテクスチャのピクセルサイズ
#endif

#if NORMAL_TYPE == 2
   #define TEX_FileName  "ParticleNormal2.png" // 粒子に貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  2     // 粒子テクスチャのx方向粒子数
   #define TEX_PARTICLE_YNUM  2     // 粒子テクスチャのy方向粒子数
   #define TEX_PARTICLE_PXSIZE 128  // 1粒子当たりに使われているテクスチャのピクセルサイズ
#endif

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

#define DEPTH_FAR  5000.0f   // 深度最遠値

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

static float3 sDirect = normalize( StartDirect );

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

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// 粒子テクスチャ(ノーマルマップ)
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
sampler CoordSmp : register(s2) = sampler_state
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

// 1ステップ前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmpOld = sampler_state
{
   Texture = <CoordTexOld>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp : register(s3) = sampler_state
{
   Texture = <VelocityTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 時間間隔設定

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

float time1 : Time;
float time2 : Time < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;

#ifndef MIKUMIKUMOVING

float elapsed_time : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = (TimeSync ? clamp(elapsed_time, 0.001f, 0.1f) : clamp(elapsed_time2, 0.0f, 0.1f)) * TimeRate;

#else

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_R32F" ;
>;
sampler TimeTexSmp : register(s1) = sampler_state
{
   Texture = <TimeTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_D24S8";
>;
static float Dt = clamp(time - tex2Dlod(TimeTexSmp, float4(0.5f, 0.5f, 0, 0)).r, 0.0f, 0.1f) * TimeRate;

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}

#endif

// 1フレーム当たりの粒子発生数
static float P_Count = AcsSi*0.1f * Dt *60;


////////////////////////////////////////////////////////////////////////////////////////////////

// 床判定の位置と向き
bool flagFloorCtrl : CONTROLOBJECT < string name = "FloorControl.x"; >;
float4x4 FloorCtrlWldMat : CONTROLOBJECT < string name = "FloorControl.x"; >;
static float3 FloorPos = flagFloorCtrl ? FloorCtrlWldMat._41_42_43  : float3(0, 0, 0);
static float3 FloorNormal = flagFloorCtrl ? normalize(FloorCtrlWldMat._21_22_23) : float3(0, 1, 0);

// スケーリングなしの床ワールド変換行列
static float4x4 FloorWldMat = flagFloorCtrl ? float4x4( normalize(FloorCtrlWldMat._11_12_13), 0,
                                                        normalize(FloorCtrlWldMat._21_22_23), 0,
                                                        normalize(FloorCtrlWldMat._31_32_33), 0,
                                                        FloorCtrlWldMat[3] )
                                            : float4x4( 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 );

// ワールド変換行列で、スケーリングなしの逆行列を計算する。
float4x4 InverseWorldMatrix(float4x4 mat) {
    float3x3 mat3x3_inv = transpose((float3x3)mat);
    float3x3 mat3x3_inv2 = float3x3( normalize(mat3x3_inv[0]),
                                     normalize(mat3x3_inv[1]),
                                     normalize(mat3x3_inv[2]) );
    return float4x4( mat3x3_inv2[0], 0, 
                     mat3x3_inv2[1], 0, 
                     mat3x3_inv2[2], 0, 
                     -mul(mat._41_42_43, mat3x3_inv2), 1 );
}
// スケーリングなしの床ワールド逆変換行列
static float4x4 InvFloorWldMat = flagFloorCtrl ? InverseWorldMatrix( FloorCtrlWldMat )
                                               : float4x4( 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 );


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


////////////////////////////////////////////////////////////////////////////////////////////////
// ラインビルボード行列(ワールド変換行列になる)
float4x4 GetLineBillboardMatrix(float3 Point1, float3 Point2, float Scale)
{
    float3 xAxis = normalize( cross( Point2 - Point1, Point1 - CameraPosition ) ) * Scale;
    float3 yAxis = normalize( Point2 - Point1 ) * (length( Point2 - Point1 )/Scale*10 + Scale);
    float3 zAxis = normalize( cross( xAxis, yAxis ) );
    return float4x4( xAxis,                0.0f,
                     yAxis,                0.0f,
                     zAxis,                0.0f,
                     (Point2+Point1)*0.5f, 1.0f );
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
      Pos.xyz = WorldMatrix._41_42_43 + OffsetPos;  // 発生初期座標

      // 新たに粒子を発生させるかどうかの判定
      if(p_index < Vel.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
      if(p_index < Vel.w+P_Count){
         Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生
      }
   }else{
   // 発生粒子は疑似物理計算で座標を更新
      // 加速度計算(速度抵抗力+重力)
      float3 Accel = -Vel.xyz * ResistFactor + GravFactor;

      // 新しい座標に更新
      Pos.xyz += Dt * (Vel.xyz + Dt * Accel);

      // すでに発生している粒子は経過時間を進める
      Pos.w += Dt;

      if(Pos.w-1.0f >  ParticleLife){
          Pos.w *= step(Pos.w-1.0f, ParticleLife); // 指定時間を超えると0
      }else{
         // 跳ね返ったら寿命間近にする
         if( Pos.w <= ParticleLife - 10.0f*Dt/max(TimeRate, 0.01f) + 1.0f){
            if(dot(Pos.xyz-FloorPos, FloorNormal) < 0.0f){
               Pos.w = ParticleLife - 10.0f*Dt/max(TimeRate, 0.01f) + 1.0f;
            }
         }
      }
   }

   // 0フレーム再生で粒子初期化
   if(time < 0.001f) Pos = float4(WorldMatrix._41_42_43 + OffsetPos, 0.0f);

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

   int j = floor( Tex.y*TEX_HEIGHT );

   if(Pos.w < 1.001111f){
      // 発生したての粒子に初速度与える
      float3 vec  = float3( 0.0f, PAI*0.5f, 0.0f );
      float3 v = cross( sDirect, float3(0.0f, 1.0f, 0.0f) ); // 放出方向への回転軸
      v = any(v) ? normalize(v) : float3(0,0,1);
      float rot = acos( dot(float3(0.0f, 1.0f, 0.0f), sDirect) ); // 放出方向への回転角
      float sinHD = sin(0.5f * rot);
      float cosHD = cos(0.5f * rot);
      float4 q1 = float4(v*sinHD, cosHD);
      float4 q2 = float4(-v*sinHD, cosHD);
      vec = MulQuat( MulQuat(q2, float4(vec, 0.0f)), q1).xyz; // 放出方向への回転(クォータニオン)
      Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) ) * ParticleSpeed;
   }else{
      // 粒子の速度計算
      float3 rand = Color2Float(j, 3);

      // 加速度計算(速度抵抗力+重力)
      float3 Accel = -Vel.xyz * ResistFactor + GravFactor;

      // 新しい座標に更新
      Vel.xyz += Dt * Accel;

      // 床の裏側に入った時の処理
      if(dot(Pos.xyz-FloorPos, FloorNormal) < 0.0f){
         float3 reboundVel = mul(Vel.xyz, (float3x3)InvFloorWldMat);
         reboundVel.x = ReboundNoise * (rand.x - 0.5f);
         reboundVel.y = CoefRebound * abs(reboundVel.y) * (rand.y + 0.1f);
         reboundVel.z = ReboundNoise * (rand.z - 0.5f);
         Vel.xyz = mul(reboundVel, (float3x3)FloorWldMat);
         // 床の傾き分の補正(適当)
         float3 flrGrvDir = cross( cross(normalize(GravFactor), FloorNormal), FloorNormal);
         if(dot(flrGrvDir, GravFactor) < 0.0f) flrGrvDir = -flrGrvDir;
         Vel.xyz += flrGrvDir * ReboundNoise * 0.7f;
      }
   }

   // 次発生粒子の起点
   Vel.w += P_Count;
   if(Vel.w >= float(TEX_WIDTH*TEX_HEIGHT)) Vel.w -= float(TEX_WIDTH*TEX_HEIGHT);
   if(time < 0.001f) Vel.w = 0.0f;

   return Vel;
}

///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos       : POSITION;    // 射影変換座標
    float2 Tex       : TEXCOORD0;   // テクスチャ
    float4 VPos      : TEXCOORD1;   // ビュー座標
    float2 Param     : TEXCOORD2;   // alpha値,z回転
    float4 Color     : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out = (VS_OUTPUT2)0;

   int i = RepertIndex;
   int j = round( Pos.z * 100.0f );
   int Index0 = i * TEX_HEIGHT + j;
   float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
   Pos.z = 0.0f;

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 0));
   float4 Pos1 = Pos0 + tex2Dlod(VelocitySmp, float4(texCoord, 0, 0)) * max(Dt, 0.001f);

   // 経過時間
   float etime = Pos0.w - 1.0f;

   // 乱数設定
   float rand0 = 0.5f * (0.66f * sin(22.1f * Index0) + 0.33f * cos(33.6f * Index0) + 1.0f);
   float rand1 = 0.5f * (0.31f * sin(45.3f * Index0) + 0.69f * cos(73.4f * Index0) + 1.0f);

   // 経過時間に対する粒子拡大度
   float scale = ParticleScaleUp * etime + 1.0f;

   // 粒子の大きさ
   scale = (0.2f+rand0) * ParticleSize * scale * 10.0f;

   // はね返り粒子の大きさ
   if(dot(Pos0.xyz-FloorPos, FloorNormal) < 0.0f){
       Pos.x /= ParticleReboundSize;
       Pos.y *= ParticleReboundSize;
   }

   // 粒子の回転
   float rot = 6.18f * ( rand1 - 0.5f )*0.0;
   Pos.xy = Rotation2D(Pos.xy, rot);

   // ラインビルボード(ワールド座標)
   if(etime > 0.0001f){
       Pos = mul( Pos, GetLineBillboardMatrix(Pos0.xyz, Pos1.xyz, scale) );
       Out.Param.y = rot - atan2(Pos1.y - Pos0.y, Pos1.x - Pos0.x);
   }else{
       Pos.xyz = float4(Pos0.xyz, 1.0f);
       Out.Param.y = rot;
   }

   // カメラ視点のビュー変換
   Out.VPos = mul( Pos, ViewMatrix );

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, GET_VPMAT(Pos) );

   // 粒子のα値
   Out.Param.x = step(0.01f, etime);

   // テクスチャ座標
   int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // ノーマルマップ参照
    float4 Color = tex2D( ParticleSamp, IN.Tex );
    Color.a *= IN.Param.x;

    // 透明部位は描画しない
    clip( Color.a - 0.5f );

    // 法線(0～1になるよう補正)
    float3 Normal = float3(2.0f * Color.r - 1.0f, 1.0f - 2.0f * Color.g,  -Color.b);
    Normal.xy = Rotation2D(Normal.xy, IN.Param.y);
    Normal = normalize(Normal);
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, IN.Param.x*AcsTr);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
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
            "LoopEnd=;"
       #ifdef MIKUMIKUMOVING
       "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
       #endif
       ;
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
        ZWRITEENABLE = FALSE;
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
    #ifdef MIKUMIKUMOVING
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
    #endif
}

