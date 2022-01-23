////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Homooo.fx ver0.0.3 ┌（┌＾o＾）┐ホモォ･･･
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile  "Homooo.png" // ボード貼り付けるテクスチャファイル名
float HomoooAppear = 10.0;       // ┌（┌＾o＾）┐ホモォ･･･の出現度(大きくするといっぱい┌（┌＾o＾）┐ホモォ･･･って言うよ)
float HomoooSize = 1.0;          // ┌（┌＾o＾）┐ホモォ･･･の大きさ
float HomoooSpeedMin = 40.0;     // ┌（┌＾o＾）┐ホモォ･･･の初速最小値
float HomoooSpeedMax = 120.0;    // ┌（┌＾o＾）┐ホモォ･･･の初速最大値
float HomoooInitPos = 1.0;       // ┌（┌＾o＾）┐ホモォ･･･の発生時の位置(大きくすると配置がばらつきます)
float HomoooLife = 0.8;          // ┌（┌＾o＾）┐ホモォ･･･の寿命(秒)
float HomoooDecrement = 0.2;     // ┌（┌＾o＾）┐ホモォ･･･が消失を開始する時間(0.0～1.0:HomoooLifeとの比)
float DiffusionAngle = 30.0;     // 放射拡散角(0.0～180.0)
float SpeedDampCoef = 10.0;      // 放射速度の減衰係数
float SpeedFixCoef = 0.1;        // 放射速度の固定係数
float3 HomoooColor = {1.0, 1.0, 1.0}; // テクスチャの乗算色(RBG)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ArrangeFileName "Arrange.png" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  8   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH    1   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT  64   // 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float Scale = AcsSi * 0.05f;

static float diffD = radians( clamp(90.0f - DiffusionAngle, -90.0f, 90.0f) );

// 座標変換行列
float4x4 WorldMatrix        : WORLD;
float4x4 ViewMatrix         : VIEW;
float4x4 ProjMatrix         : PROJECTION;
float4x4 ViewProjMatrix     : VIEWPROJECTION;
float4x4 ViewMatrixInverse  : VIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

texture2D HomoooTex <
    string ResourceName = TexFile;
>;
sampler HomoooSamp = sampler_state {
    texture = <HomoooTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
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

// ┌（┌＾o＾）┐ホモォ･･･座標記録用
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

// ┌（┌＾o＾）┐ホモォ･･･速度記録用
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
// 時間間隔計算(MMMでは ELAPSEDTIME はオフスクリーンの有無で大きく変わるので使わない)

float time : Time;

#ifndef MIKUMIKUMOVING

float elapsed_time : ELAPSEDTIME;
static float Dt = clamp(elapsed_time, 0.001f, 0.1f);

#else

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
    string Format = "D3DFMT_D24S8";
>;
static float Dt = clamp(time - tex2D(TimeTexSmp, float2(0.5f,0.5f)).r, 0.001f, 0.1f);


float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}

#endif

static float probable = 0.5f * (Dt / HomoooLife) * HomoooAppear * 0.004f; // 1フレーム当たりの┌（┌＾o＾）┐ホモォ･･･発生確率


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float Color2Float(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = round(d.w * 255.0f);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// クォータニオンの積算
float4 MulQuat(float4 q1, float4 q2)
{
   return float4(cross(q1.xyz, q2.xyz)+q1.xyz*q2.w+q2.xyz*q1.w, q1.w*q2.w-dot(q1.xyz, q2.xyz));
}

// クォータニオンの回転
float3 RotQuat(float3 v1, float3 v2, float3 pos)
{
   v1 = normalize( v1 );
   v2 = normalize( v2 );

   float4 q =  float4(pos, 0.0f);

   if(length(v1-v2) > 0.01f){
      float3 v = normalize( cross(v2, v1) );
      float rot = acos( dot(v1, v2) );
      float sinHD = sin(0.5f * rot);
      float cosHD = cos(0.5f * rot);
      float4 q1 = float4(v*sinHD, cosHD);
      float4 q2 = float4(-v*sinHD, cosHD);
      q = MulQuat( MulQuat(q2, q), q1);
   }

   return q.xyz;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

// ┌（┌＾o＾）┐ホモォ･･･の発生・座標計算(xyz:座標,w:経過時間)
float4 UpdatePos_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // ┌（┌＾o＾）┐ホモォ･･･の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // ┌（┌＾o＾）┐ホモォ･･･の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(time < 0.001f) Pos.w = 0.0f;
   if(Pos.w < 0.001f){
      // 未発生┌（┌＾o＾）┐ホモォ･･･の中から新たに発生させる
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float4 WPos = float4(Color2Float(i, j), Color2Float(i+1, j), 0.0f, 1.0f);
      WPos.xyz *= HomoooInitPos/AcsSi;
      WPos = mul( WPos, WorldMatrix );
      Pos.xyz = WPos.xyz / WPos.w;  // 発生初期座標
      float probable0 = Color2Float(i+7, j);
      if(Vel.w<=probable0 && probable0<Vel.w+probable){
         Pos.w = 1.0011f;  // Pos.w>1.001で┌（┌＾o＾）┐ホモォ･･･発生
      }
   }else{
      // ┌（┌＾o＾）┐ホモォ･･･の座標更新
      Pos.xyz += Vel.xyz * Dt;

      // すでに発生している┌（┌＾o＾）┐ホモォ･･･は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w-1.0f, HomoooLife); // 指定時間を超えると0
   }

   return Pos;
}

// ┌（┌＾o＾）┐ホモォ･･･の速度計算(xyz:速度,w:出現起点)
float4 UpdateVelocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // ┌（┌＾o＾）┐ホモォ･･･の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // ┌（┌＾o＾）┐ホモォ･･･の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 1.00111f){
      // 発生したての┌（┌＾o＾）┐ホモォ･･･に初速度与える
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float time1 = time + 100.0f;
      float ss, cs;
      sincos( lerp(diffD, PAI*0.5f, frac(Color2Float(i+3, j)*time1)), ss, cs );
      float st, ct;
      sincos( lerp(-PAI, PAI, frac(Color2Float(i+4, j)*time1)), st, ct );
      float3 vec  = float3( cs*ct, ss, cs*st );
      float rand = Color2Float(i+5, j);
      float speed = lerp(HomoooSpeedMin, HomoooSpeedMax, 1.0f-rand*rand);
      vec = RotQuat(float3(0,1,0), float3(0,1,-1), vec);
      Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) ) * speed;
   }else{
      // すでに発生している┌（┌＾o＾）┐ホモォ･･･の速度を減衰させる
      Vel.xyz *= (exp(-SpeedDampCoef*(Pos.w-1.0f) ) + SpeedFixCoef) /
                 (exp(-SpeedDampCoef*(Pos.w-1.0f-Dt)) + SpeedFixCoef);
   }

   // 次発生出現の起点
   Vel.w += probable;
   Vel.w *= step(Vel.w, 1.0f-probable);
   if(time < 0.001f) Vel.w = 0.0f;

   return Vel;
}

///////////////////////////////////////////////////////////////////////////////////////
// ┌（┌＾o＾）┐ホモォ･･･の描画
struct VS_OUTPUT2
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float4 Color : COLOR0;      // ボードの乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Homooo_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out;

   int Index0 = round( Pos.z * 100.0f );
   Pos.z = 0.0f;
   int i0 = Index0 / 1024;
   int i = i0 * 8;
   int j = Index0 % 1024;
   float2 texCoord = float2((i0+0.5)/TEX_WIDTH, (j+0.5)/TEX_HEIGHT);

   // ┌（┌＾o＾）┐ホモォ･･･の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 0));

   // ┌（┌＾o＾）┐ホモォ･･･経過時間
   float etime = Pos0.w - 1.0f;

   // 乱数設定
   float rand0 = 0.5f * (0.66f * sin(22.1f * Index0) + 0.33f * cos(33.6f * Index0) + 1.0f);
   float rand1 = 0.5f * (0.31f * sin(45.3f * Index0) + 0.69f * cos(73.4f * Index0) + 1.0f);

   // 経過時間に対する┌（┌＾o＾）┐ホモォ･･･拡大度
   float scale = 4.0f * sqrt(etime) + 2.0f;

   // ┌（┌＾o＾）┐ホモォ･･･の大きさ
   Pos.xy *= (0.5f + rand0) * HomoooSize * scale * 10.0f;
   Pos.y *= 0.5f;
   Pos.xy *= Scale * 0.2f;

   // ┌（┌＾o＾）┐ホモォ･･･の回転
   float rot = 6.18f * ( rand1 - 0.5f );

   // ビルボード
   Pos.xyz = mul( Pos.xyz, BillboardMatrix );

   // ┌（┌＾o＾）┐ホモォ･･･のワールド座標
   Pos.xyz += (Pos0.xyz - WorldMatrix._41_42_43) * Scale + WorldMatrix._41_42_43;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

#ifndef MIKUMIKUMOVING
   // ┌（┌＾o＾）┐ホモォ･･･のカメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );
#else
   // ┌（┌＾o＾）┐ホモォ･･･の頂点座標
   if (MMM_IsDinamicProjection)
   {
       float4x4 vpmat = mul( ViewMatrix, MMM_DynamicFov(ProjMatrix, length( CameraPosition - Pos.xyz )) );
       Out.Pos = mul( Pos, vpmat );
   }
   else
   {
       Out.Pos = mul( Pos, ViewProjMatrix );
   }
#endif

   // ┌（┌＾o＾）┐ホモォ･･･の乗算色
   float alpha = step(0.002f, etime) * smoothstep(-HomoooLife, -HomoooLife*HomoooDecrement, -etime) * AcsTr;
   Out.Color = float4(HomoooColor, alpha);

   // テクスチャ座標
   Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 Homooo_PS( VS_OUTPUT2 IN ) : COLOR0
{
   float4 Color = tex2D( HomoooSamp, IN.Tex );
   Color *= IN.Color;
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
       #ifdef MIKUMIKUMOVING
       "RenderColorTarget0=TimeTex;"
           "RenderDepthStencilTarget=TimeDepthBuffer;"
           "Pass=UpdateTime;"
       #endif
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
           "Pass=DrawObject;";
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
       ZENABLE = false;
       AlphaBlendEnable = TRUE;
       VertexShader = compile vs_3_0 Homooo_VS();
       PixelShader  = compile ps_3_0 Homooo_PS();
   }
}

