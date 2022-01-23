////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Flocking_Multi.fx ver0.0.8  フロッキングアルゴリズムを使った群れ行動制御(多種類ユニットver)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

const int nGroup = 4;  // ユニットの種類数
int nCount = 410;  // モデル総複製数(最大1024)
//int ObjCount[] = {80, 100, 120, 110};  // モデル複製数(総和で最大1024, Flocking_ObjX.fxも対応する同じ値を設定する必要あり)
int StartCount[] = {0, 80, 180, 300};  // 各グループの先頭インデックス(StartCount[0]=0; StartCount[n]=StartCount[n-1]+Count[n-1]となる値, Flocking_ObjX.fxも対応する同じ値を設定する必要あり)

float WideViewRadius[] = {15.0, 15.0, 15.0, 15.0};     // 視認エリア半径(大きくすると他のユニットが見つかりやすくなる)
float WideViewAngle[] = {45.0, 90.0, 135.0, 60.0};     // 視認エリア角度(0～180)(大きくすると他のユニットが見つかりやすくなる)
float CohesionFactor[] = {10.0, 5.0, 1.0, 4.0};        // 結合度(大きくすると近隣ユニットどうしが一つにまとまりやすくなる)
float AlignmentFactor[] = {25.0, 20.0, 15.0, 10.0,};   // 整列度(大きくすると近隣ユニットどうしが同じ方向を向きやすくなる)
float SeparationFactor[] = {50.0, 100.0, 60.0, 70.0};  // 分離度(大きくすると隣接ユニットとの衝突回避行動をとりやすくなる)
float SeparationLength[] = {10.0, 10.0, 10.0, 10.0};   // 分離判定距離(大きくすると隣接ユニットとの衝突回避判定をしやすくなる)
float DrivingForceFactor[] = {30.0, 60.0, 40.0, 70.0}; // 推進力(大きくすると移動スピードが速くなる)
float ResistanceFactor[] = {1.0, 2.0, 3.0, 2.0};       // 抵抗力(大きくすると移動スピードが減衰しやすくなる)
float VerticalAngleLimit[] = {30.0, 35.0, 40.0, 60.0}; // 鉛直移動制限角(0～90)(大きくすると上下方向の移動が活発になる)
float PotentialOutside = 80.0;   // 移動制限外縁距離(大きくすると移動範囲が広くなる)
float PotentialFloor = 10.0;     // 移動制限床面高さ(大きくすると床に近づいた時に高い位置で回避行動をとる)
float PotentialCiel = 70.0;      // 移動制限天井高さ(大きくするとより高い位置まで移動するようになる)

#define ArrangeFileName "ArrangeData.png" // 初期配置情報画像ファイル名(TexTableEditより8pixel*1024pixelの画像として作成)

// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

float3 AcsPos : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsTr   : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi   : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static bool InitFlag = AcsTr > 0.0f ? true : false;
static float OutsideLength = PotentialOutside * AcsSi * 0.1f;
static float PotentialBottom = PotentialFloor + AcsPos.y;
static float PotentialTop = PotentialBottom + (PotentialCiel - PotentialFloor) * AcsSi * 0.1f;

#define ARRANGE_TEX_WIDTH  8       // 配置テクスチャピクセル幅
#define ARRANGE_TEX_HEIGHT 1024    // 初期配置情報画像ファイルのピクセル高さ
#define TEX_WIDTH_W   4            // ユニット配置変換行列テクスチャピクセル幅
#define TEX_WIDTH     1            // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ


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
shared texture Flocking_CoordTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Flocking_SmpCoord = sampler_state
{
   Texture = <Flocking_CoordTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 速度記録用
shared texture Flocking_VelocityTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Flocking_SmpVelocity = sampler_state
{
   Texture = <Flocking_VelocityTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ポテンシャル記録用
shared texture Flocking_PotentialTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Flocking_SmpPotential = sampler_state
{
   Texture = <Flocking_PotentialTex>;
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

// ユニット配置変換行列記録用
shared texture Flocking_TransMatrixTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH_W;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture TransMatrixDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH_W;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// 時間間隔計算(MMMでは ELAPSEDTIME はオフスクリーンの有無で大きく変わるので使わない)

float time : Time;
//float elapsed_time : ELAPSEDTIME;
//static float Dt = clamp(elapsed_time, 0.001f, 0.1f);

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_R32F" ;
>;
sampler TimeTexSmp = sampler_state
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
    string Format = "D24S8";
>;
static float Dt = clamp(time-tex2D(TimeTexSmp, float2(0.5f,0.5f)).r, 0.001f, 0.1f);


////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの回転行列
float4x4 RotMatrix(float3 Angle)
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
float4x4 InvRotMatrix(float3 Angle)
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
// 配置情報テクスチャからデータを取り出す
float ColorToFloat(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/ARRANGE_TEX_WIDTH, (j+0.5)/ARRANGE_TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = round(d.w * 255.0f);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 0フレーム再生でユニット座標・速度・ポテンシャルを初期化
// 方向・速度の計算(xyz:正規化された方向ベクトル，w:速さ)

struct PS_OUTPUT {
   float4 Pos : COLOR0;
   float4 Vel : COLOR1;
   float4 Pot : COLOR2;
};

PS_OUTPUT Init_PS(float2 Tex: TEXCOORD0)
{
   PS_OUTPUT Out;

   if( time < 0.001f && InitFlag ){
      // 0フレーム再生でリセット
      int j = floor( Tex.y*TEX_HEIGHT );
      float3 pos = float3(ColorToFloat(0, j), ColorToFloat(1, j), ColorToFloat(2, j));
      int iGroup=0;
      for(int i=0; i<nGroup; i++){ // Pos.wにグループNoを記録
         if( StartCount[i] <= j ) iGroup = i;
      }
      Out.Pos = float4(pos, float(iGroup) );

      float rx = ColorToFloat(3, j);
      float ry = ColorToFloat(4, j);
      float sinx,cosx,siny,cosy;
      sincos(rx, sinx, cosx);
      sincos(ry, siny, cosy);
      float3x3 rMat = { cosy,       0.0f,  siny,
                       -sinx*siny,  cosx,  sinx*cosy,
                       -cosx*siny, -sinx,  cosx*cosy};
      float3 ang = mul( float3(0.0f, 0.0f, -1.0f), rMat );
      Out.Vel = float4(ang, 0.0f);

      //ポテンシャルによる操舵力は1フレーム前の結果が使われるため0フレーム再生時は初期化の必要有り
      Out.Pot = float4(0.0f, 0.0f, 0.0f, 0.0f);

  }else{
      Out.Pos = tex2D(Flocking_SmpCoord, Tex);
      // 速度更新
      float4 vel0 = tex2D(Flocking_SmpVelocity, Tex);
      float3 Pos1 = (float3)tex2D(SmpCoordOld, Tex);
      float3 Pos2 = (float3)tex2D(Flocking_SmpCoord, Tex);
      float3 v = ( Pos2 - Pos1 )/Dt;
      float len = length( v );
      Out.Vel = (len > 0.0001f) ? float4( normalize(v), len ) : float4( vel0.xyz, len );

      Out.Pot =  tex2D(Flocking_SmpPotential, Tex);
   }

   return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値を1フレーム前の座標にコピー

float4 PosCopy_PS(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(Flocking_SmpCoord, Tex);
   return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値をフロッキングアルゴリズムで更新・ポテンシャル更新

struct PS_OUTPUT2 {
   float4 Pos : COLOR0;
   float4 Pot : COLOR1;
};

PS_OUTPUT2 Flocking_PS(float2 Tex: TEXCOORD0)
{
   PS_OUTPUT2 Out;

    // 1フレーム前の位置
    float4 pt0 = tex2D(SmpCoordOld, Tex);
    float3 Pos0 = pt0.xyz;
    int jGroup = round( pt0.w );

    // 方向・速度
    float4 v = tex2D(Flocking_SmpVelocity, Tex);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 回転逆行列
    float3x3 invRMat = (float3x3)InvRotMatrix(Angle);

    // 操舵力初期化
    float3 SteerForce = 0.0f;
    float3 AvgPos = 0.0f;
    float3 AvgAng = 0.0f;
    int n = 0;

    float WideViewCosA = cos( radians(WideViewAngle[jGroup]) );
    float VAngLimit = radians(VerticalAngleLimit[jGroup]);

    // フロッキングアルゴリズム(各ユニットの位置関係から操舵力を求める)
    int j = floor( Tex.y*TEX_HEIGHT );
    for(int i=0; i<nCount; i++){
       if( i != j ){
          float y = (float(i) + 0.5f)/TEX_HEIGHT;
          float4 p_i = tex2D(SmpCoordOld, float2(Tex.x, y));
          float3 pos_i = p_i.xyz;
          int iGroup = round( p_i.w );
          float3 ang_i = tex2D(Flocking_SmpVelocity, float2(Tex.x, y)).xyz;
          float len = length( pos_i - Pos0 );
          float cosa = dot( normalize(pos_i - Pos0), Angle );
          if(len < WideViewRadius[jGroup]){
             // 分離の操舵力(ユニット同士の衝突回避)
             if(len < SeparationLength[jGroup]){
                float3 pos_local = mul( pos_i-Pos0, invRMat );
                SteerForce += normalize( -pos_local ) * SeparationFactor[jGroup] / len * min(1.0f, time/5.0f);
             }
             // 視認ユニットかどうか
             if(cosa > WideViewCosA){
                if( jGroup == iGroup ){ // 同一グループのみ群れ行動をとる
                   AvgPos += pos_i;
                   AvgAng += ang_i;
                   n++;
                }
             }
          }
       }
    }
    if( n > 0){
       // 結合の操舵力(一つにまとまる力)
       AvgPos = mul( AvgPos/float(n)-Pos0, invRMat );
       AvgPos.z = 0.0f;
       SteerForce += AvgPos * CohesionFactor[jGroup];

       // 整列の操舵力(同じ方向を向かせる力)
       AvgAng = normalize( mul( AvgAng, invRMat ) );
       float a1 = acos( clamp(dot( AvgAng, float3(0.0f, 0.0f, -1.0f) ), -1.0f, 1.0f) );
       AvgAng = normalize( float3(AvgAng.x, AvgAng.y, 0.0f) );
       SteerForce +=  AvgAng * a1 * AlignmentFactor[jGroup];
    }

    // ポテンシャルによる操舵力を付加
    SteerForce += tex2D(Flocking_SmpPotential, Tex).xyz;

    // 操舵力の方向をワールド座標系に変換
    SteerForce = mul( SteerForce, (float3x3)RotMatrix(Angle) );

    // 加速度計算(推進力+抵抗力+操舵力)
    float3 Accel = DrivingForceFactor[jGroup] * Angle - ResistanceFactor[jGroup] * Vel + SteerForce;

    // 新しい座標に更新
    float3 Pos = Pos0 + Dt * (Vel + Dt * Accel);

    // 鉛直方向角度制限
    if( (PotentialBottom <= Pos.y && Pos.y <= PotentialTop) ||
        (Pos.y < PotentialBottom && Pos.y < Pos0.y) ||
        (PotentialTop < Pos.y && Pos0.y < Pos.y) ){
       float3 pos2 = Pos - Pos0;
       float3 pos3 = float3(pos2.x, 0.0f, pos2.z );
       float a = acos( min(dot( normalize(pos2), normalize(pos3) ), 1.0f) );
       if(a > VAngLimit){
          pos3.y = sign(pos2.y) * length(pos3) * tan(VAngLimit);
          Pos = Pos0 + pos3;
       }
    }
    Out.Pos = float4( Pos, float(jGroup) );

    // 以下ユニットを指定範囲内に留めるためのポテンシャルによる操舵力を計算
    // 他の障害物アクセのポテンシャルを加算してから次フレームで使用する

    // 操舵力初期化
    SteerForce = float3(0.0f, 0.0f, 0.0f);

    // 外縁ポテンシャル(遠くに行きすぎないように)
    Pos.xz -= AcsPos.xz;
    float lenP0 = length( Pos );
    float limit = (lenP0 < 2.0f*OutsideLength) ? -abs(sin(time)) : -0.9999f;

    float p = clamp(-OutsideLength-Pos.x, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(-1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos.x, 0.0f, -Pos.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos.x-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos.x, 0.0f, -Pos.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(-OutsideLength-Pos.z, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, -1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos.x, 0.0f, -Pos.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos.z-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, 1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos.x, 0.0f, -Pos.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }

    // 床面ポテンシャル(床下に潜らないように)
    p = max( PotentialBottom - Pos.y, 0.0f);
    SteerForce.y += p*p;

    // 天井ポテンシャル(昇り過ぎないように)
    p = max( Pos.y - PotentialTop, 0.0f);
    SteerForce.y -= p*p;

    Out.Pot = float4(SteerForce, 0.0f);

    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// ユニット配置変換行列の作成

VS_OUTPUT TransMatrix_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out;
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.5f/TEX_WIDTH_W, 0.5f/TEX_HEIGHT);
    return Out;
}

float4 TransMatrix_PS(float2 Tex: TEXCOORD0) : COLOR
{
    int i0 = floor( Tex.x * TEX_WIDTH_W );
    int i = i0 / 4;
    int j = floor( Tex.y * TEX_HEIGHT );

    // モデル配置座標を取得
    float3 Pos = tex2D(Flocking_SmpCoord, float2((0.5f+i)/TEX_WIDTH, Tex.y)).xyz;

    // モデル方向ベクトルを取得
    float3 Angle = tex2D(Flocking_SmpVelocity, float2((0.5f+i)/TEX_WIDTH, Tex.y)).xyz;

   // モデルの配置変換行列
   float4x4 TrMat = RotMatrix(Angle);
   float scale = ColorToFloat(i+6, j);

   TrMat._11_12_13 *= scale;
   TrMat._21_22_23 *= scale;
   TrMat._31_32_33 *= scale;
   TrMat._41_42_43 = Pos;

   return TrMat[i0 % 4];
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 時間記録

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}


/////////////////////////////////////////////////////////////////////////////////
// フロッキングアルゴリズム計算を行うテクニック
// ここの計算結果を基にFlocking_ObjX.fxでユニットの複製・描画を行う

technique MainTec0 < string MMDPass = "object";
    string Script = 
        // 0フレーム再生で初期化・速度計算
        "RenderColorTarget0=Flocking_CoordTex;"
        "RenderColorTarget1=Flocking_VelocityTex;"
        "RenderColorTarget2=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=InitPass;"
        // 1フレーム前の座標にコピー
        "RenderColorTarget0=CoordTexOld;"
        "RenderColorTarget1=;"
        "RenderColorTarget2=;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        // フロッキングアルゴリズム
        "RenderColorTarget0=Flocking_CoordTex;"
        "RenderColorTarget1=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=FlockingPass;"
        // 配置変換行列作成
        "RenderColorTarget0=Flocking_TransMatrixTex;"
        "RenderColorTarget1=;"
	    "RenderDepthStencilTarget=TransMatrixDepthBuffer;"
	    "Pass=SetTransMatrix;"
        // 時間更新
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;";
>{
    pass InitPass < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Init_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass FlockingPass < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Flocking_PS();
    }
    pass SetTransMatrix < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 TransMatrix_VS();
        PixelShader  = compile ps_3_0 TransMatrix_PS();
    }
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
}


