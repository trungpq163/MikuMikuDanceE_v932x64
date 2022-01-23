////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Particle.fx 空間歪みエフェクト(ActiveParticleSmoke.fxの改造,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 粒子数設定
#define UNIT_COUNT   2   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

// 粒子パラメータスイッチ
#define NORMAL_TYPE  2    // 粒子テクスチャの種類(とりあえず1,2で選択,1:ノーマルマップ粒小,2:ノーマルマップ粒大)

// 粒子パラメータ設定
float ParticleSize = 5.0;           // 粒子大きさ
float ParticleSpeedMin = 0.1;       // 粒子初期最小スピード
float ParticleSpeedMax = 0.3;       // 粒子初期最大スピード
float ParticleInitPos = 0.0;        // 粒子発生時の相対位置(大きくすると粒子の初期配置がばらつきます)
float ParticleLife = 5.0;           // 粒子の寿命(秒)
float ParticleDecrement = 0.5;      // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleScaleUp = 0.1;        // 粒子発生後の拡大度
float ParticleShadeDiffusion = 4.0; // 粒子発生後の陰影拡散度(大きくすると時間がたつにつれ陰影がぼやけてくる)
float OccurFactor = 4.0;            // オブジェクト移動量に対する粒子発生度(大きくすると粒子が出やすくなる)
float ObjVelocityRate = 0.2;        // オブジェクト移動方向に対する粒子速度依存度

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

// オプションのコントロールファイル名
#define BackgroundCtrlFileName  "BackgroundControl.x" // 背景座標コントロールファイル名
#define TimrCtrlFileName        "TimeControl.x"       // 時間制御コントロールファイル名


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ArrangeFileName "Arrange.pfm" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  4            // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH    UNIT_COUNT   // テクスチャピクセル幅
#define TEX_HEIGHT   1024         // テクスチャピクセル高さ

#define PAI 3.14159265f   // π

#define DEPTH_FAR  5000.0f   // 深度最遠値

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

// オプションのコントロールパラメータ
bool IsBack : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;
float4x4 BackMat : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;

float3 LightDirection : DIRECTION < string Object = "Camera"; >;
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
static float Dt = clamp(time - tex2D(TimeTexSmp, float2(0.5f, 0.5f)).r, 0.0f, 0.1f) * TimeRate;

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}

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
         Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生
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
   if(time < 0.001f) Pos = float4(WorldMatrix._41_42_43, 0.0f);

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

   if(Pos.w < 1.00111f){
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
    float3 Param     : TEXCOORD1;   // x経過時間,yボードピクセルサイズ,z回転
    float4 VPos      : TEXCOORD4;   // ビュー座標
    float4 Color     : COLOR0;      // 粒子の色
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
   Pos0.xyz = InvBackWorldCoord(Pos0.xyz);

   // 経過時間
   float etime = Pos0.w - 1.0f;
   Out.Param.x = etime;

   // 乱数設定
   float3 rand = tex2Dlod(ArrangeSmp, float4(3.5f/TEX_WIDTH_A, (j+0.5f)/TEX_HEIGHT, 0, 0)).xyz;

   // 経過時間に対する粒子拡大度
   float scale = ParticleScaleUp * sqrt(etime) + 0.1f;

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

    // カメラ視点のビュー変換
    Out.VPos = mul( Pos, ViewMatrix );

   // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

   // 粒子の乗算色
   float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
   Out.Color = float4(0, 0, 0, alpha);

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
    // 粒子テクスチャ(ノーマルマップ)から法線計算
    float shadeDiffuse = max( IN.Param.y, lerp(0, ParticleShadeDiffusion, IN.Param.x/ParticleLife) );
    float4 Color = tex2Dlod( ParticleSamp, float4(IN.Tex, 0, shadeDiffuse) );

    // 透明部位は描画しない
    clip( Color.a - 0.5f );

    // 法線(0～1になるよう補正)
    float3 Normal = float3(2.0f * Color.r - 1.0f, 1.0f - 2.0f * Color.g,  -Color.b);
    Normal.xy = Rotation2D(Normal.xy, IN.Param.z);
    Normal = normalize(Normal);
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, IN.Color.a);

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
        "RenderColorTarget0=WorldCoord;"
            "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
            "Pass=UpdateWorldCoord;"
       #ifdef MIKUMIKUMOVING
       "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
       #endif
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;"
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
    pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 WorldCoord_VS();
        PixelShader  = compile ps_2_0 WorldCoord_PS();
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
    pass DrawObject {
        ZENABLE = TRUE;
        ZWRITEENABLE = FALSE;
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}




///////////////////////////////////////////////////////////////////////////////////////
// エッジ・地面影・ZPlotは表示しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot";> { }

