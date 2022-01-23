////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DiscoLightBall.fx : DiscoLightEx ライトボール描画
//  作成: 針金P( 舞力介入P氏のDiscoLighting改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
//(DLEX_Object.fxsubと同名パラメータは同じ値に設定してください)

#define  MODEL_FILE_NAME   "DiscoLightEx.pmx"

float BallRotateMax = 1.5; // ライト回転最大値

#define LightTexNum   6    // ライトテクスチャ種類数(最大6まで)

// ライトに貼るテクスチャファイル名
#define LightTexFile1   "LightTex01.png"
#define LightTexFile2   "LightTex02.png"
#define LightTexFile3   "LightTex03.png"
#define LightTexFile4   "LightTex04.png"
#define LightTexFile5   "LightTex05.png"
#define LightTexFile6   "LightTex06.png"

// テクスチャにキューブベース色の乗算を、1:行う, 0:行わない
#define CubeBackColor1   1
#define CubeBackColor2   1
#define CubeBackColor3   1
#define CubeBackColor4   0
#define CubeBackColor5   1
#define CubeBackColor6   0


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// ライトの表示のON/OFF
bool LightOn: CONTROLOBJECT < string Name = MODEL_FILE_NAME; >;
// ライトの位置
float3 LightPosition: CONTROLOBJECT < string Name = MODEL_FILE_NAME; string item = "光源位置"; >;

float lpower : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "発光強度"; >;
float NowLightTex : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "ﾗｲﾄ種類"; >;

float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 WMat           : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;
static float4x4 WorldMatrix = float4x4(WMat[0], WMat[1], WMat[2], LightPosition, 1);
static float4x4 WorldViewProjMatrix = mul(WorldMatrix, ViewProjMatrix);

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

#define CUBECOLOR1  float3(0.5, 1.0, 0.5);
#define CUBECOLOR2  float3(1.0, 0.5, 0.5);
#define CUBECOLOR3  float3(1.0, 1.0, 0.5);
#define CUBECOLOR4  float3(0.5, 0.5, 1.0);
#define CUBECOLOR5  float3(0.5, 1.0, 1.0);
#define CUBECOLOR6  float3(1.0, 0.5, 1.0);

float pmdRotX1 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "+X回転"; >;
float pmdRotY1 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "+Y回転"; >;
float pmdRotZ1 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "+Z回転"; >;
float pmdRotX2 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "-X回転"; >;
float pmdRotY2 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "-Y回転"; >;
float pmdRotZ2 : CONTROLOBJECT < string name = MODEL_FILE_NAME; string item = "-Z回転"; >;

static float ballRotX = (pmdRotX1 - pmdRotX2) * BallRotateMax;
static float ballRotY = (pmdRotY1 - pmdRotY2) * BallRotateMax;
static float ballRotZ = (pmdRotZ1 - pmdRotZ2) * BallRotateMax;

// ボール回転行列
float BallTime : TIME;
float3x3 CalcRotateMatrix(float time)
{
   float cosX, sinX;
   float cosY, sinY;
   float cosZ, sinZ;

   sincos(ballRotX * time, sinX, cosX);
   sincos(ballRotY * time, sinY, cosY);
   sincos(ballRotZ * time, sinZ, cosZ);

   return float3x3(
      cosY * cosZ + sinX * sinY * sinZ,  cosY * sinZ - sinX * sinY * cosZ, cosX * sinY,
     -cosX * sinZ,                       cosX * cosZ,                      sinX, 
      sinX * cosY * sinZ - sinY * cosZ, -sinY * sinZ - sinX * cosY * cosZ, cosX * cosY
   );
}
static float3x3 BallRotateMatrix = CalcRotateMatrix(BallTime);

// ライトボールテクスチャ
texture2D LightTex1
<
   string ResourceName = LightTexFile1;
>;
sampler LightTexSmp1 = sampler_state
{
    Texture = (LightTex1);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};

#if LightTexNum > 1
texture2D LightTex2
<
   string ResourceName = LightTexFile2;
>;
sampler LightTexSmp2 = sampler_state
{
    Texture = (LightTex2);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 2
texture2D LightTex3
<
   string ResourceName = LightTexFile3;
>;
sampler LightTexSmp3 = sampler_state
{
    Texture = (LightTex3);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 3
texture2D LightTex4
<
   string ResourceName = LightTexFile4;
>;
sampler LightTexSmp4 = sampler_state
{
    Texture = (LightTex4);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 4
texture2D LightTex5
<
   string ResourceName = LightTexFile5;
>;
sampler LightTexSmp5 = sampler_state
{
    Texture = (LightTex5);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 5
texture2D LightTex6
<
   string ResourceName = LightTexFile6;
>;
sampler LightTexSmp6 = sampler_state
{
    Texture = (LightTex6);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

static const float lightNum = 1.0f / max(2.0*(LightTexNum-1), 1.0f);

// ライトボール色計算(2Dテクスチャをキューブ配置にして参照)
float3 GetTexCubeColor( float3 dir )
{
   float3 absDir = abs(dir);
   float2 uv;
   float3 color;

   if(absDir.x >= absDir.y && absDir.x >= absDir.z){
      if(dir.x > 0){
         uv = float2(-dir.y, dir.z) / dir.x;
         color = CUBECOLOR1;
      }else{
         uv = float2(dir.y, dir.z) / dir.x;
         color = CUBECOLOR2;
      }
   }else if(absDir.y >= absDir.x && absDir.y >= absDir.z){
      if(dir.y > 0){
         uv = float2(dir.z, -dir.x) / dir.y;
         color = CUBECOLOR3;
      }else{
         uv = float2(-dir.z, -dir.x) / dir.y;
         color = CUBECOLOR4;
      }
   }else{
      if(dir.z > 0){
         uv = float2(-dir.x, dir.y) / dir.z;
         color = CUBECOLOR5;
      }else{
         uv = float2(dir.x, dir.y) / dir.z;
         color = CUBECOLOR6;
      }
   }

   uv = 0.5*(uv + 1.0);

   #if LightTexNum > 1
   if(NowLightTex < lightNum)
   #endif
   {
      return tex2D(LightTexSmp1, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor1);
   }
#if LightTexNum > 1
   else
   #if LightTexNum > 2
   if(NowLightTex < lightNum*3.0f)
   #endif
   {
      return tex2D(LightTexSmp2, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor2);
   }
#endif
#if LightTexNum > 2
   else
   #if LightTexNum > 3
   if(NowLightTex < lightNum*5.0f)
   #endif
   {
      return tex2D(LightTexSmp3, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor3);
   }
#endif
#if LightTexNum > 3
   else
   #if LightTexNum > 4
   if(NowLightTex < lightNum*7.0f)
   #endif
   {
      return tex2D(LightTexSmp4, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor4);
   }
#endif
#if LightTexNum > 4
   else
   #if LightTexNum > 5
   if(NowLightTex < lightNum*9.0f)
   #endif
   {
      return tex2D(LightTexSmp5, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor5);
   }
#endif
#if LightTexNum > 5
   else{
      return tex2D(LightTexSmp6, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor6);
   }
#endif

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT 
{
   float4 Pos: POSITION;
   float3 dir: TEXCOORD0;
};

VS_OUTPUT Basic_VS(float4 Pos: POSITION)
{
   VS_OUTPUT Out;

   float3 dir = normalize(Pos.xyz);

   // 頂点座標
   #ifndef MIKUMIKUMOVING
   Out.Pos = mul(Pos, WorldViewProjMatrix);
   #else
   if (MMM_IsDinamicProjection)
   {
       float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, length(CameraPosition - mul(Pos, WorldMatrix).xyz)));
       Out.Pos = mul( Pos, wvpmat );
   }
   else
   {
       Out.Pos = mul( Pos, WorldViewProjMatrix );
   }
   #endif

   Out.dir = mul(dir, BallRotateMatrix);

   return Out;
}


float4 Basic_PS(float3 dir: TEXCOORD0) : COLOR 
{

   float4 Color = float4( GetTexCubeColor( dir ), 1.0f );
   Color.rgb *= (1.0f - lpower);
   return Color;
}



///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique DiscoLightBall
{
   pass DrawObject
   {
      VertexShader = compile vs_2_0 Basic_VS();
      PixelShader  = compile ps_2_0 Basic_PS();
   }

}

