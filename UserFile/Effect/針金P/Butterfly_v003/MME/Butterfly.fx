////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Butterfly.fx ver0.0.3  蝶の群れパーティクルエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 蝶パラメータスイッチ
#define TEX_TYPE    1    // 蝶の種類(とりあえず1～4でテクスチャ選択)
#define MMD_LIGHT   1    // MMDの照明操作に 0:連動しない, 1:連動する

int Count = 200;  // 蝶の数(最大512まで)

// 蝶パラメータ設定
float ButterflySize = 0.7;       // 蝶のサイズ
float RandamMove = 8.0;          // ランダムな動き度合い
float FlapAmp = 1.8;             // 羽ばたき振幅
float FlapFreq = 14.0;           // 羽ばたき周波数

float DrivingForceFactor = 8.0;  // 推進力(大きくすると移動スピードが速くなる)
float ResistanceFactor = 2.0;    // 抵抗力(大きくすると移動スピードが減衰しやすくなる)
float VerticalAngleLimit = 30.0; // 鉛直移動制限角(0～90)(大きくすると上下方向の移動が活発になる)
float PotentialOutside = 35.0;   // 移動制限外縁距離(大きくすると移動範囲が広くなる)
float PotentialFloor = 2.0;      // 移動制限床面高さ(大きくすると床に近づいた時に高い位置で回避行動をとる)
float PotentialCiel = 30.0;      // 移動制限天井高さ(大きくするとより高い位置まで移動するようになる)

#define UnitHitAvoid  0    // ユニット同士の衝突回避判定をする場合は1にする(重くなる可能性有り)
float WideViewRadius = 30.0;     // 視認エリア半径(大きくすると他のユニットが見つかりやすくなる)
float WideViewAngle = 45.0;      // 視認エリア角度(0～180)(大きくすると他のユニットが見つかりやすくなる)
float SeparationFactor = 30.0;   // 分離度(大きくすると隣接ユニットとの衝突回避度が大きくなる)
float SeparationLength = 10.0;   // 分離判定距離(大きくすると隣接ユニットとの衝突回避行動をとりやすくなる)

#define WriteZBuffer  0    // ユニット描画時にZバッファを書き換える場合は1にする


// 必要に応じて蝶テクスチャをここで定義
#if TEX_TYPE == 1
   #define TEX_FileName  "蝶1.png"  // オブジェクトに貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  2     // テクスチャx方向蝶の数
   #define TEX_PARTICLE_YNUM  1     // テクスチャy方向蝶の数
   #define TEX_ADD_FLG     0        // 0:半透明合成, 1:加算合成
#endif

#if TEX_TYPE == 2
   #define TEX_FileName  "蝶2.png"  // オブジェクトに貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  5     // テクスチャx方向蝶の数
   #define TEX_PARTICLE_YNUM  1     // テクスチャy方向蝶の数
   #define TEX_ADD_FLG     0        // 0:半透明合成, 1:加算合成
#endif

#if TEX_TYPE == 3
   #define TEX_FileName  "蝶3.png"  // オブジェクトに貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  4     // テクスチャx方向蝶の数
   #define TEX_PARTICLE_YNUM  1     // テクスチャy方向蝶の数
   #define TEX_ADD_FLG     0        // 0:半透明合成, 1:加算合成
#endif

#if TEX_TYPE == 4
   #define TEX_FileName  "蝶3(加算合成用).png"  // オブジェクトに貼り付けるテクスチャファイル名
   #define TEX_PARTICLE_XNUM  4     // テクスチャx方向蝶の数
   #define TEX_PARTICLE_YNUM  1     // テクスチャy方向蝶の数
   #define TEX_ADD_FLG     1        // 0:半透明合成, 1:加算合成
#endif


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float OutsideLength = PotentialOutside * AcsSi * 0.1f;
static float CielHeight = PotentialCiel + AcsY;

static float WideViewCosA = cos( radians(WideViewAngle) );
static float VAngLimit = radians(VerticalAngleLimit);

#define ArrangeFileName "ArrangeData.png" // 初期配置情報画像ファイル名
#define ARRANGE_TEX_WIDTH  8       // 初期配置テクスチャピクセル幅
#define ARRANGE_TEX_HEIGHT 512     // 初期配置テクスチャピクセル高さ
#define TEX_WIDTH  1               // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 512             // ユニットデータ格納テクスチャピクセル高さ

float time1 : Time;
float elapsed_time : ELAPSEDTIME;
static float Dt = clamp(elapsed_time, 0.001f, 0.1f);

// 座標変換行列
float4x4 ViewProjMatrix       : VIEWPROJECTION;

float3 LightDirection    : DIRECTION < string Object = "Light"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;
float4x4 LightViewProjMatrix  : VIEWPROJECTION < string Object = "Light"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
// ライト色
float3 LightDiffuse      : DIFFUSE  < string Object = "Light"; >;
float3 LightAmbient      : AMBIENT  < string Object = "Light"; >;
float3 LightSpecular     : SPECULAR < string Object = "Light"; >;
static float4 DiffuseColor  = float4(MaterialDiffuse.rgb  * LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool parthf;   // パースペクティブフラグ
bool transp;   // 半透明フラグ
#define SKII1    1500
#define SKII2    8000

// 配置情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};

// オブジェクトに貼り付けるテクスチャ(ミップマップも生成)
texture2D ParticleTex <
    string ResourceName = TEX_FileName;
    int MipLevels = 0;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 1フレーム前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpCoordOld = sampler_state
{
   Texture = <CoordTexOld>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 現在の座標記録用
shared texture Butterfly_CoordTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Butterfly_SmpCoord : register(s2) = sampler_state
{
   Texture = <Butterfly_CoordTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 速度記録用
shared texture Butterfly_VelocityTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Butterfly_SmpVelocity : register(s3) = sampler_state
{
   Texture = <Butterfly_VelocityTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ポテンシャル記録用
shared texture Butterfly_PotentialTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Butterfly_SmpPotential = sampler_state
{
   Texture = <Butterfly_PotentialTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 共通の深度ステンシルバッファ
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置情報テクスチャからデータを取り出す
float Color2Float(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/ARRANGE_TEX_WIDTH, (j+0.5)/ARRANGE_TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = round(d.w * 255.0f);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの回転行列
float4x4 RoundMatrix(float3 Angle)
{
   float3 AngleY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosy = -AngleY.z;
   float siny = sign(AngleY.x) * sqrt(1.0f - cosy*cosy);
   float3 AngleXY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosx = dot( AngleXY, Angle );
   float sinx = sign(Angle.y) * sqrt(1.0f - cosx*cosx);

   float4x4 rMat = { cosy,       0.0f,  siny,      0.0f,
                    -sinx*siny,  cosx,  sinx*cosy, 0.0f,
                    -cosx*siny, -sinx,  cosx*cosy, 0.0f,
                     0.0f,       0.0f,  0.0f,      1.0f };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの回転逆行列
float4x4 InvRoundMatrix(float3 Angle)
{
   float3 AngleY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosy = -Angle.z;
   float siny = sign(Angle.x) * sqrt(1.0f - cosy*cosy);
   float3 AngleXY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosx = dot( Angle, AngleXY );
   float sinx = sign(Angle.y) * sqrt(1.0f - cosx*cosx);

   float4x4 rMat = { cosy, -sinx*siny, -cosx*siny, 0.0f,
                     0.0f,  cosx,      -sinx,      0.0f,
                     siny,  sinx*cosy,  cosx*cosy, 0.0f,
                     0.0f,  0.0f,       0.0f,      1.0f };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT2 {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

VS_OUTPUT2 Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT2 Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 0フレーム再生でユニット座標を初期化

float4 PosInit_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos;
   if( time1 < 0.001f ){
      // 0フレーム再生でリセット
      int i = floor( texCoord.y*TEX_HEIGHT );
      float y = lerp(PotentialFloor, PotentialCiel, Color2Float(1, i));
      float3 pos = float3(Color2Float(0, i), y, Color2Float(2, i));
      Pos = float4( pos, 0.0f );
   }else{
      Pos = tex2D(Butterfly_SmpCoord, texCoord);
   }

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 方向・速度の計算(xyz:正規化された方向ベクトル，w:速さ)

float4 Velocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 vel;
   if( time1 < 0.001f ){
      // 0フレーム再生で方向初期化
      int i = floor( texCoord.y*TEX_HEIGHT );
      float rx = Color2Float(3, i);
      float ry = Color2Float(4, i);
      float sinx = sin(rx);
      float cosx = cos(rx);
      float siny = sin(ry);
      float cosy = cos(ry);
      float3x3 rMat = { cosy,       0.0f,  siny,
                       -sinx*siny,  cosx,  sinx*cosy,
                       -cosx*siny, -sinx,  cosx*cosy};
      float3 ang = mul( float3(0.0f, 0.0f, -1.0f), rMat );
      vel = float4(ang, 0.0f);
   }else{
      float4 vel0 = tex2D(Butterfly_SmpVelocity, texCoord);
      float3 Pos1 = (float3)tex2D(SmpCoordOld, texCoord);
      float3 Pos2 = (float3)tex2D(Butterfly_SmpCoord, texCoord);
      float3 v = ( Pos2 - Pos1 )/Dt;
      float len = length( v );
      vel = (len > 0.0001f) ? float4( normalize(v), len ) : float4( vel0.xyz, len );
   }

   return vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ポテンシャルの初期化(ポテンシャルによる操舵力は1フレーム前の結果が使われるため
// 0フレーム再生時は初期化の必要有り)

float4 PotentialInit_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // ポテンシャルによるユニットの操舵力
   float4 SteerForce = tex2D(Butterfly_SmpPotential, texCoord);
   if( time1 < 0.001f ){
      // 0フレーム再生でリセット
      SteerForce = float4(0.0f, 0.0f, 0.0f, 0.0f);
   }

   return SteerForce;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値を1フレーム前の座標にコピー

float4 PosCopy_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(Butterfly_SmpCoord, texCoord);
   return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値を更新

float4 PosButterfly_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // 1フレーム前の位置
    float3 Pos0 = tex2D(SmpCoordOld, texCoord).xyz;
    float lenP0 = length( Pos0 );

    // 方向・速度
    float4 v = tex2D(Butterfly_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 回転逆行列
    float3x3 invRMat = (float3x3)InvRoundMatrix(Angle);

    // 操舵力初期化
    float3 SteerForce = 0.0f;

    // ユニットインデックス
    int index = floor( texCoord.y*TEX_HEIGHT );

#if(UnitHitAvoid==1)
    // ユニット同士の衝突回避
    for(int i=0; i<Count; i++){
       if( i != index ){
          float y = (float(i) + 0.5f)/TEX_HEIGHT;
          float3 pos_i = tex2D(SmpCoordOld, float2(texCoord.x, y)).xyz;
          float3 ang_i = tex2D(Butterfly_SmpVelocity, float2(texCoord.x, y)).xyz;
          float len = length( pos_i - Pos0 );
          float cosa = dot( normalize(pos_i - Pos0), Angle );
          if(len < WideViewRadius && cosa > WideViewCosA){ // 視認ユニットかどうか
             if(len < SeparationLength){
                float3 pos_local = mul( pos_i-Pos0, invRMat );
                SteerForce += normalize( -pos_local ) * SeparationFactor / len * min(1.0f, time1/5.0f);
             }
          }
       }
    }
#endif

    // ポテンシャルによる操舵力を付加
    SteerForce += tex2D(Butterfly_SmpPotential, texCoord).xyz;

    // 気まぐれな動き
    SteerForce.x += RandamMove*(Color2Float(5, index)+0.5f)*sin(Color2Float(6, index)*time1+Color2Float(3, index));

    // 操舵力の方向をワールド座標系に変換
    SteerForce = mul( SteerForce, (float3x3)RoundMatrix(Angle) );

    // 加速度計算(推進力+抵抗力+操舵力)
    float3 Accel = DrivingForceFactor * Angle - ResistanceFactor * Vel + SteerForce;

    // 蝶の羽ばたきパラメータ
    float flap = 0.5f*(1.0f-cos(FlapFreq*(1.0f+0.3f*(Color2Float(7, index)-0.5f))*time1+Color2Float(4, index)));
    flap = 1.0f - pow(flap, 1.5f);

    // 新しい座標に更新
    float4 Pos = float4( Pos0 + Dt * (Vel + Dt * Accel), flap );

    // 鉛直方向角度制限
    if( (PotentialFloor <= Pos.y && Pos.y <= CielHeight) ||
        (Pos.y < PotentialFloor && Pos.y < Pos0.y) ||
        (CielHeight < Pos.y && Pos.y > Pos0.y) ){
       float3 pos2 = Pos.xyz - Pos0;
       float3 pos3 = float3(pos2.x, 0.0f, pos2.z );
       float a = acos( min(dot( normalize(pos2), normalize(pos3) ), 1.0f) );
       if(a > VAngLimit){
          pos3.y = sign(pos2.y) * length(pos3) * tan(VAngLimit);
          Pos = float4( Pos0 + pos3, flap );
       }
    }

    return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// ユニットを指定範囲内に留めるためのポテンシャルによる操舵力を求める

float4 Potential_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // ユニットの位置
    float3 Pos0 = (float3)tex2D(Butterfly_SmpCoord, texCoord);
    float lenP0 = length( Pos0 );

    // ユニットの方向・速度
    float4 v = tex2D(Butterfly_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 回転逆行列
    float3x3 invRMat = (float3x3)InvRoundMatrix(Angle);

    // ポテンシャルによる操舵力初期化
    float3 SteerForce = float3(0.0f, 0.0f, 0.0f);

    // 外縁ポテンシャル(遠くに行きすぎないように)
    float limit = (lenP0 < 2.0f*OutsideLength) ? -abs(cos(time1)) : -0.9999f;
    float p = clamp(-OutsideLength-Pos0.x, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(-1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos0.x-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(-OutsideLength-Pos0.z, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, -1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos0.z-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, 1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }

    // 床面ポテンシャル(床下に潜らないように)
    p = max( PotentialFloor - Pos0.y, 0.0f);
    SteerForce.y += p*p;

    // 天井ポテンシャル(昇り過ぎないように)
    p = max( Pos0.y - CielHeight, 0.0f);
    SteerForce.y -= p*p;

   return float4(SteerForce, 0.0f);
}

/////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos    : POSITION;    // 射影変換座標
    float2 Tex    : TEXCOORD0;   // テクスチャ
    float3 Normal : TEXCOORD1;   // 法線
    float3 Eye    : TEXCOORD2;   // カメラとの相対位置
    float4 Color  : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT Particle_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, int index: _INDEX)
{
   VS_OUTPUT Out;

   int Index = round( -Pos.y * 100.0f );
   int Index2 = round( fmod(index, 8.0f) );
   Pos.y = 0.0f;
   float2 texCoord = float2(0.5f/TEX_WIDTH, (Index+0.5f)/TEX_HEIGHT);

   // 蝶の基点座標
   float4 Pos0 = tex2Dlod(Butterfly_SmpCoord, float4(texCoord, 0, 0));

   // 蝶の方向ベクトル
   float3 Angle = tex2Dlod(Butterfly_SmpVelocity, float4(texCoord, 0, 0)).xyz;

   // 蝶の羽ばたき
   float rot = 0.0f;
   if(Index2 < 4){
      rot = lerp(radians(30.0f), radians(-85.0f), Pos0.w);
   }else{
      rot = lerp(radians(-30.0f), radians(85.0f), Pos0.w);
   }
   Pos.xy = Rotation2D(Pos.xy, rot);
   Pos.y -= FlapAmp * (Pos0.w-0.5f) * 0.1f;
   Normal.xy = Rotation2D(Normal.xy, rot);

   // 蝶の大きさ
   Pos.xyz *= ButterflySize * 10.0f;

   // 蝶の回転
   float4x4 rotMat = RoundMatrix(Angle);
   Pos = mul( Pos, rotMat );
   Out.Normal = normalize( mul( Normal, (float3x3)rotMat ) );

   // 蝶のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(Index, Count);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // カメラとの相対位置
   Out.Eye = CameraPosition - Pos.xyz;

   // ディフューズ色＋アンビエント色 計算
   Out.Color.rgb = AmbientColor;
   Out.Color.rgb += max(0.0f, dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
   Out.Color.a = AcsTr*step(Index, Count);
   Out.Color = saturate( Out.Color );

   // テクスチャ座標
   int texIndex = Index % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT IN ) : COLOR0
{
#if(MMD_LIGHT==1)
   // スペキュラ色計算
   float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
   float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

   float4 Color = IN.Color;

   // テクスチャ適用
   Color *= tex2D( ParticleSamp, float2(IN.Tex.x, 1.0f-IN.Tex.y) );

   // スペキュラ適用
   Color.rgb += Specular;
#else
   // テクスチャ適用
   float4 Color = tex2D( ParticleSamp, float2(IN.Tex.x, 1.0f-IN.Tex.y) );
#endif
   return Color;
}


/////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウOFF）

technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=Butterfly_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosInit;"
        "RenderColorTarget0=Butterfly_VelocityTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcVelocity;"
        "RenderColorTarget0=Butterfly_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PotentialInit;"
        "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        "RenderColorTarget0=Butterfly_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=Butterfly_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "Pass=DrawObject;";
>{
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosInit_PS();
    }
    pass CalcVelocity < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Velocity_PS();
    }
    pass PotentialInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PotentialInit_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosButterfly_PS();
    }
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
    pass DrawObject {
        ZENABLE = TRUE;
        #if(WriteZBuffer == 0)
        ZWRITEENABLE = FALSE;
        #endif
        #if(TEX_ADD_FLG == 1)
        DestBlend = ONE;
        SrcBlend = ONE;
        #else
        DestBlend = INVSRCALPHA;
        SrcBlend = SRCALPHA;
        #endif
        AlphaBlendEnable = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
   }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;            // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;  // Zバッファテクスチャ
    float2 Tex : TEXCOORD1;           // テクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0, int index: _INDEX )
{
   VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

   int Index = round( -Pos.y * 100.0f );
   int Index2 = round( fmod(index, 8.0f) );
   Pos.y = 0.0f;
   float2 texCoord = float2(0.5f/TEX_WIDTH, (Index+0.5f)/TEX_HEIGHT);

   // 蝶の基点座標
   float4 Pos0 = tex2Dlod(Butterfly_SmpCoord, float4(texCoord, 0, 0));

   // 蝶の方向ベクトル
   float3 Angle = tex2Dlod(Butterfly_SmpVelocity, float4(texCoord, 0, 0)).xyz;

   // 蝶の羽ばたき
   float rot = 0.0f;
   if(Index2 < 4){
      rot = lerp(radians(30.0f), radians(-85.0f), Pos0.w);
   }else{
      rot = lerp(radians(-30.0f), radians(85.0f), Pos0.w);
   }
   Pos.xy = Rotation2D(Pos.xy, rot);
   Pos.y -= FlapAmp * (Pos0.w-0.5f) * 0.1f;

   // 蝶の大きさ
   Pos.xyz *= ButterflySize * 10.0f;

   // 蝶の回転
   float4x4 rotMat = RoundMatrix(Angle);
   Pos = mul( Pos, rotMat );

   // 蝶のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(Index, Count);
   Pos.w = 1.0f;

   // ライトの目線によるビュー射影変換
   Out.Pos = mul( Pos, LightViewProjMatrix );

   // テクスチャ座標を頂点に合わせる
   Out.ShadowMapTex = Out.Pos;

   // テクスチャ座標
   int texIndex = Index % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( VS_ZValuePlot_OUTPUT IN ) : COLOR
{
   // テクスチャ適用
   float4 Color = tex2D( ParticleSamp, float2(IN.Tex.x, 1.0f-IN.Tex.y) );
   float alpha = Color.a * AcsTr;
   float s = (alpha >= 0.01f) ? IN.ShadowMapTex.z/IN.ShadowMapTex.w : 1.0f;
   float a = (alpha >= 0.01f) ? 1.0f : 0.0f;

   // R色成分にZ値を記録する
   return float4(s, 0.0f, 0.0f, a);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; >
{
    pass ZValuePlot {
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT ParticleSS_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, int index: _INDEX)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

   int Index = round( -Pos.y * 100.0f );
   int Index2 = round( fmod(index, 8.0f) );
   Pos.y = 0.0f;
   float2 texCoord = float2(0.5f/TEX_WIDTH, (Index+0.5f)/TEX_HEIGHT);

   // 蝶の基点座標
   float4 Pos0 = tex2Dlod(Butterfly_SmpCoord, float4(texCoord, 0, 0));

   // 蝶の方向ベクトル
   float3 Angle = tex2Dlod(Butterfly_SmpVelocity, float4(texCoord, 0, 0)).xyz;

   // 蝶の羽ばたき
   float rot = 0.0f;
   if(Index2 < 4){
      rot = lerp(radians(30.0f), radians(-85.0f), Pos0.w);
   }else{
      rot = lerp(radians(-30.0f), radians(85.0f), Pos0.w);
   }
   Pos.xy = Rotation2D(Pos.xy, rot);
   Pos.y -= FlapAmp * (Pos0.w-0.5f) * 0.1f;
   Normal.xy = Rotation2D(Normal.xy, rot);

   // 蝶の大きさ
   Pos.xyz *= ButterflySize * 10.0f;

   // 蝶の回転
   float4x4 rotMat = RoundMatrix(Angle);
   Pos = mul( Pos, rotMat );
   Out.Normal = normalize( mul( Normal, (float3x3)rotMat ) );

   // 蝶のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(Index, Count);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // カメラとの相対位置
   Out.Eye = CameraPosition - Pos.xyz;

   // ライト視点によるビュー射影変換
   Out.ZCalcTex = mul( Pos, LightViewProjMatrix );

   // ディフューズ色＋アンビエント色 計算
   Out.Color.rgb = AmbientColor;
   Out.Color.rgb += max(0.0f, dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
   Out.Color.a = AcsTr*step(Index, Count);
   Out.Color = saturate( Out.Color );

   // テクスチャ座標
   int texIndex = Index % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   return Out;
}

// ピクセルシェーダ
float4 ParticleSS_PS(BufferShadow_OUTPUT IN) : COLOR
{
#if(MMD_LIGHT==1)
   // スペキュラ色計算
   float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
   float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

   float4 Color = IN.Color;
   float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色

   // テクスチャ適用
   float4 TexColor = tex2D( ParticleSamp, float2(IN.Tex.x, 1.0f-IN.Tex.y) );
   Color *= TexColor;
   ShadowColor *= TexColor;

   // スペキュラ適用
   Color.rgb += Specular;

   // テクスチャ座標に変換
   IN.ZCalcTex /= IN.ZCalcTex.w;
   float2 TransTexCoord;
   TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
   TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;

   if( any( saturate(TransTexCoord) - TransTexCoord ) ) {
       // シャドウバッファ外
       return Color;
   } else {
       float comp;
       if(parthf) {
           // セルフシャドウ mode2
           comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
       } else {
           // セルフシャドウ mode1
           comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
       }
       float4 ans = lerp(ShadowColor, Color, comp);
       if( transp ) ans.a = 0.5f;
       return ans;
   }
#else
   // テクスチャ適用
   float4 Color = tex2D( ParticleSamp, float2(IN.Tex.x, 1.0f-IN.Tex.y) );
   return Color;
#endif
}

/////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウON）

technique MainTec1 < string MMDPass = "object_ss";
    string Script = 
        "RenderColorTarget0=Butterfly_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosInit;"
        "RenderColorTarget0=Butterfly_VelocityTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcVelocity;"
        "RenderColorTarget0=Butterfly_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PotentialInit;"
        "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        "RenderColorTarget0=Butterfly_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=Butterfly_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "Pass=DrawObject;";
>{
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosInit_PS();
    }
    pass CalcVelocity < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Velocity_PS();
    }
    pass PotentialInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PotentialInit_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosButterfly_PS();
    }
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
    pass DrawObject {
        ZENABLE = TRUE;
        #if(WriteZBuffer == 0)
        ZWRITEENABLE = FALSE;
        #endif
        AlphaBlendEnable = TRUE;
        #if(TEX_ADD_FLG == 1)
        DestBlend = ONE;
        SrcBlend = ONE;
        #else
        DestBlend = INVSRCALPHA;
        SrcBlend = SRCALPHA;
        #endif
        CullMode = NONE;
        VertexShader = compile vs_3_0 ParticleSS_VS();
        PixelShader  = compile ps_3_0 ParticleSS_PS();
   }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 非セルフシャドウ地面影は非表示
technique ShadowTec < string MMDPass = "shadow"; > { }

