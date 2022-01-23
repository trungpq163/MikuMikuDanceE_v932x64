////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ActiveParticleC.fx ver0.0.6 オブジェクトが移動に応じてテクスチャ粒子を放出します(色･サイズ変化)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 粒子数設定
#define UNIT_COUNT   4   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

// テクスチャ設定
#define TEX_GradMapFile "sampleGrad.png" // 色変化テクスチャファイル名
#define TEX_FileName  "sample3.png"      // 粒子に貼り付けるテクスチャファイル名
#define TEX_PARTICLE_XNUM  1       // 粒子テクスチャのx方向粒子数
#define TEX_PARTICLE_YNUM  1       // 粒子テクスチャのy方向粒子数
#define TEX_USE_MIPMAP  0          // テクスチャのミップマップ生成,0:しない,1:する
#define TEX_ADD_FLG     0          // 0:半透明合成, 1:加算合成

// 粒子パラメータ設定
float ParticleSize = 0.3;          // 粒子大きさ
float ParticleSpeedMin = 1.0;      // 粒子初期最小スピード
float ParticleSpeedMax = 2.5;      // 粒子初期最大スピード
float ParticleRotSpeedMin = 1.0;   // 粒子回転速度範囲最小値
float ParticleRotSpeedMax = 3.0;   // 粒子回転速度範囲最大値
float ParticleRotRandam = 0.0;     // 粒子回転ばらつき度(0.0～1.0)
float ParticleInitPos = 0.5;       // 粒子発生時の相対位置(大きくすると粒子の配置がばらつきます)
float ParticleLife = 3.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.7;     // 粒子が消失を開始する時間(ParticleLifeとの比)
float ParticleScaleUp = 1.5;       // 粒子発生後の拡散度
float OccurFactor = 1.5;           // オブジェクト移動量に対する粒子発生度(大きくすると粒子が出やすくなる)
float ObjVelocityRate = 2.0;       // オブジェクト移動方向に対する粒子速度依存度

// 物理パラメータ設定
float3 GravFactor = {0.0, 0.0, 0.0};   // 重力定数
float ResistFactor = 0.0;              // 速度抵抗係数

// (風等の)空間の流速場を定義する関数
// 粒子位置ParticlePosにおける空気の流れを記述します。
// 戻り値が0以外の時はオブジェクトが動かなくても粒子を放出します。
// ただし速度抵抗係数がResistFactor>0でないと流速場は粒子の動きに影響を与えません。
float3 VelocityField(float3 ParticlePos)
{
   float3 vel = float3( 0.0, 0.0, 0.0 );
   return vel;
}

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

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

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
static float TimeScale = IsTimeCtrl ? 1.0f/max(TimeRate, 0.01) : 1.0f;

// 時間設定
float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;
float elapsed_time : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = (TimeSync ? clamp(elapsed_time, 0.001f, 0.1f) : clamp(elapsed_time2, 0.0f, 0.1f)) * TimeRate;

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ViewProjMatrix : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// カメラZ回転追従のビルボード行列
static float3x3 InvViewMatrix = transpose( (float3x3)ViewMatrix );
static float3 xAxis = cross( float3(0.0f, 1.0f, 0.0f),  - CameraPosition );
static float3 yAxis = cross( InvViewMatrix[2], xAxis );
static float3 zAxis = InvViewMatrix[2];
static float3x3 RotMatrix = float3x3(xAxis, yAxis, zAxis);
static float3x3 BillboardZRotMatrix = float3x3( normalize(RotMatrix[0].xyz),
                                                normalize(RotMatrix[1].xyz),
                                                normalize(RotMatrix[2].xyz) );

#if(TEX_USE_MIPMAP == 1)
// オブジェクトに貼り付けるテクスチャ(ミップマップも生成)
texture2D ParticleTex <
    string ResourceName = TEX_FileName;
    int MipLevels = 0;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    MaxAnisotropy = 5;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
#else
// オブジェクトに貼り付けるテクスチャ(ミップマップ生成なし)
texture2D ParticleTex <
    string ResourceName = TEX_FileName;
    int MipLevels = 1;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
#endif

// 色変化テクスチャ
texture GradationTex<
   string ResourceName = TEX_GradMapFile;
>;
sampler GradationSamp = sampler_state
{
   texture = <GradationTex>;
   MinFilter = LINEAR;
   MagFilter = LINEAR;
   MipFilter = NONE;
   AddressU = CLAMP;
   AddressV = CLAMP;
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
sampler CoordSmp : register(s0) = sampler_state
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

float4 UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, Tex);

   // 粒子の速度
   float3 Vel = tex2D(VelocitySmp, Tex).xyz;

   if(Pos.w < 1.001f){
   // 未発生粒子の中から移動距離に応じて新たに粒子を発生させる
      // 現在のオブジェクト座標
      float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);

      // 1フレーム前のオブジェクト座標
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      WPos0.xyz -= VelocityField(WPos1) * Dt; // 流体速度場位置補正

      // 1フレーム間の発生粒子数
      float p_count = length( WPos1 - WPos0.xyz ) * OccurFactor * AcsSi*0.1f;

      // 粒子インデックス
      int i = floor( Tex.x*TEX_WIDTH );
      int j = floor( Tex.y*TEX_HEIGHT );
      float p_index = float( i*TEX_HEIGHT + j );

      // 新たに粒子を発生させるかどうかの判定
      if(p_index < WPos0.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
      if(p_index < WPos0.w+p_count){
         // 粒子発生座標
         float s = (p_index - WPos0.w) / p_count;
         float aveSpeed = (ParticleSpeedMin + ParticleSpeedMax) * 0.5f;
         Pos.xyz = lerp(WPos0.xyz, WPos1, s) + Vel * ParticleInitPos * Color2Float(j, 1).x / aveSpeed;
         Pos.w = 1.0011f + step(TimeRate, 0.001f) * 0.25f;  // Pos.w>1.001で粒子発生
      }else{
         Pos.xyz = WPos1;
      }
   }else{
   // 発生中粒子の座標を更新
      // 加速度計算(速度抵抗力+重力)
      float3 Accel = ( VelocityField(Pos.xyz) - Vel ) * ResistFactor + GravFactor;

      // 新しい座標に更新
      Pos.xyz += Dt * (Vel + Dt * Accel);

      // すでに発生している粒子は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w-1.0f, ParticleLife); // 指定時間を超えると0(粒子消失)
   }

   // 0フレーム再生で粒子初期化
   if(time < 0.001f) Pos = float4(BackWorldCoord(WorldMatrix._41_42_43), 0.0f);

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////
// 粒子の速度計算

float4 UpdateVelocity_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, Tex);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, Tex);

   if(Pos.w < 1.00111){
      // 発生したての粒子に初速度を与える
      int j = floor( Tex.y*TEX_HEIGHT );
      float speed = lerp( ParticleSpeedMin, ParticleSpeedMax, Color2Float(j, 1).y );
      float3 pVel = Color2Float(j, 0) * speed;
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);
      float3 wVel = normalize(WPos1-WPos0.xyz) * ObjVelocityRate; // オブジェクト移動方向を付加する
      Vel = float4( wVel+pVel, 1.0f )  ;
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

float4 WorldCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトのワールド座標
   float3 Pos1 = BackWorldCoord(WorldMatrix._41_42_43);
   float4 Pos0 = tex2D(WorldCoordSmp, Tex);
   Pos0.xyz -= VelocityField(Pos1) * Dt; // 流体速度場位置補正

   // 次発生粒子の起点
   float p_count = length( Pos1 - Pos0.xyz ) * OccurFactor * AcsSi*0.1f;
   float w = Pos0.w + p_count;
   if(w >= float(TEX_WIDTH*TEX_HEIGHT)) w -= float(TEX_WIDTH*TEX_HEIGHT);
   if(time < 0.001f) w = 0.0f;

   return float4(Pos1, w);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos      : POSITION;    // 射影変換座標
    float2 Tex      : TEXCOORD0;   // テクスチャ
    float  Distance : TEXCOORD1;   // 壁距離
    float4 Color    : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out;

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

   // 経過時間に対する粒子拡大度
   float scale = ParticleScaleUp * sqrt(etime) + 0.1;

   // 粒子の大きさ
   Pos.xy *= ParticleSize * scale * 10.0f;

   // 粒子の回転
   float rand0 = 0.5f * (0.66f * sin(22.1f * Index0) + 0.33f * cos(33.6f * Index0) + 1.0f);
   float rand1 = 0.5f * (0.31f * sin(45.3f * Index0) + 0.69f * cos(73.4f * Index0) + 1.0f);
   float rot = etime * lerp(ParticleRotSpeedMin, ParticleRotSpeedMax, rand0) + 6.18f * ParticleRotRandam * (rand1-0.5f);
   Pos.xy = Rotation2D(Pos.xy, rot);

   // ビルボード
   Pos.xyz = mul( Pos.xyz, BillboardZRotMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の遮蔽面距離
   Out.Distance = dot(Pos.xyz-SmoothPos, SmoothNormal);

   // 経過時間に対する粒子透過度
   float stAlpha = 4.0f * etime * TimeScale;
   float alpha = min( stAlpha, smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) );
   alpha *= step(0.001f, etime) * AcsTr;

   // 粒子の色
   #if TEX_ADD_FLG == 1
   Out.Color = float4( etime/ParticleLife, alpha, alpha, 1.0f );
   #else
   Out.Color = float4( etime/ParticleLife, 1.0f, 1.0f, alpha );
   #endif

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
   // 粒子の色
   float4 Color = tex2D( ParticleSamp, IN.Tex );
   Color.rgb *= tex2D( GradationSamp, float2(IN.Color.r, 0.5f) ).rgb * IN.Color.g;
   Color.a *= IN.Color.a;

   // 遮蔽面処理
   if( IsSmooth ){
      float pSize = clamp(ParticleSize, 0.5f, 2.0f);
      #if TEX_ADD_FLG == 1
      Color.rgb *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Distance);
      #else
      Color.a *= smoothstep(0.1f * pSize, 0.2f * pSize * SmoothSi, IN.Distance);
      #endif
   }

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
   pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS();
   }
   pass DrawObject {
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
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}

