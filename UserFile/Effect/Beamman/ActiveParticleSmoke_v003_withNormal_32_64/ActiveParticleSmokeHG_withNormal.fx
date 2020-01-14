//Beam追加
//炎部分の色
float3 FireColor = {1.0,0.5,0.0};

////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ActiveParticleSmokeHG.fx ver0.0.3 納豆ミサイルっぽいエフェクトHG版
//  オブジェクトの移動に応じて煙が尾を引きます(粒子数16384のハイグレード版)  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float3 ParticleColor = {1.0, 1.0, 1.0}; // テクスチャの乗算色(RBG)
float ParticleSize = 1.0;          // 粒子大きさ
float ParticleSpeed = 1.0;         // 粒子スピード
float ParticleInitPos = 0.5;       // 粒子発生時の相対位置(大きくすると粒子の配置がばらつきます)
float ParticleLife = 1.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.3;     // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleDiffusion = 2.0;     // 粒子発生後の拡散度
float CoefProbable = 0.001;       // オブジェクト移動量に対する粒子発生度(大きくすると粒子が出やすくなる)
float ObjVelocityRate = -2.0;      // オブジェクト移動方向に対する粒子速度依存度

float3 GravFactor = {0.0, 0.0, 0.0};   // 重力定数
float ResistFactor = 1.0;              // 速度抵抗係数

// (風等の)空間の流速場を定義する関数
// 粒子位置ParticlePosにおける空気の流れを記述します。
// 戻り値が0以外の時はオブジェクトが動かなくても粒子を放出します。
// 速度抵抗係数がResistFactor>0でないと粒子の動きに影響を与えません。
float3 VelocityField(float3 ParticlePos)
{
   float3 vel = float3( 0.0, 0.0, 0.0 );
   return vel;
}


// 解らない人はここから下はいじらないでね

texture Particle_Tex
<
   string ResourceName = "Tex.png";
>;
sampler Particle = sampler_state
{
   Texture = (Particle_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};

texture NormalBase_Tex
<
   string ResourceName = "NormalBase.png";
>;
sampler NormalBase = sampler_state
{
   Texture = (NormalBase_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define TexFile  "Smoke.png" // 粒子に貼り付けるテクスチャファイル名
#define ArrangeFileName "ArrangeHG.png" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A 128   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH    16   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 1024   // 配置･乱数情報テクスチャピクセル高さ

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float time : TIME;
float elapsed_time : ELAPSEDTIME;
static float Dt = (elapsed_time < 0.2f) ? clamp(elapsed_time, 0.001f, 1.0f/15.0f) : 1.0f/30.0f;

// 座標変換行列
float4x4 WorldMatrix          : WORLD;
float4x4 ViewProjMatrix       : VIEWPROJECTION;
float4x4 ViewMatrixInverse    : VIEWINVERSE;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   LightColor      : SPECULAR   < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;


static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

texture2D ParticleTex <
    string ResourceName = TexFile;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
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

// 粒子座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp = sampler_state
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
float Color2Float(int i, int j)
{
    float4 d = tex2Dlod(ArrangeSmp, float4((i+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT, 0, 1));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

float Color2FloatPS(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
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

struct VS_OUTPUT {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT Out = (VS_OUTPUT)0;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////
// 現座標値を1ステップ前の座標にコピー

float4 PosCopy_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(CoordSmp, texCoord);
   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////
// 粒子の発生・座標更新計算(xyz:座標,w:経過時間)

float4 UpdatePos_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 0.001f){
   // 未発生粒子の中から移動距離に応じて新たに粒子を発生させる
      // 現在のオブジェクト座標
      float3 WPos1 = WorldMatrix._41_42_43;

      // 1ステップ前のオブジェクト座標
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      WPos0.xyz -= VelocityField(WPos1) * Dt; // 流体速度場位置補正

      // 粒子発生確率
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float probable = length( WPos1 - WPos0.xyz ) * CoefProbable * AcsSi*0.1f;

      // 新たに粒子を発生させるかどうかの判定
      float probable0 = Color2FloatPS(i+7, j);
      if(WPos0.w<probable0 && probable0<WPos0.w+probable){
         // 粒子発生座標
         float s = (probable0 - WPos0.w) / probable;
         Pos.xyz = lerp(WPos0.xyz, WPos1, s) + Vel.xyz * ParticleInitPos;
         Pos.w = 0.0011f;  // Pos.w>0.001で粒子発生
      }else{
         Pos.xyz = WPos1;
      }
   }else{
   // 発生中粒子の座標を更新
      // 1ステップ前の位置
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);

      // 加速度計算(速度抵抗力+重力)
      float3 Accel = ( VelocityField(Pos0.xyz) - Vel.xyz ) * ResistFactor + GravFactor;

      // 新しい座標に更新
      Pos.xyz = Pos0.xyz + Dt * (Vel.xyz + Dt * Accel);

      // すでに発生している粒子は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w, ParticleLife); // 指定時間を超えると0(粒子消失)
   }

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////
// 粒子の速度計算

float4 UpdateVelocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 0.00111f){
      // 発生したての粒子に初速度を与える
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float3 pVel = float3(Color2FloatPS(i, j), Color2FloatPS(i+1, j), Color2FloatPS(i+2, j))*ParticleSpeed;
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      float3 WPos1 = WorldMatrix._41_42_43;
      float3 wVel = normalize(WPos1-WPos0.xyz)*ObjVelocityRate; // オブジェクト移動方向を付加する
      Vel = float4( wVel+pVel, 1.0f )  ;
   }else{
      // 発生中粒子の速度計算
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);
      Vel.xyz = ( Pos.xyz - Pos0.xyz ) / Dt;
   }

   return Vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトのワールド座標記録

VS_OUTPUT WorldCoord_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.texCoord = float2(0.5f, 0.5f);

    return Out;
}

float4 WorldCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトのワールド座標
   float3 Pos1 = WorldMatrix._41_42_43;
   float4 Pos0 = tex2D(WorldCoordSmp, Tex);
   Pos0.xyz -= VelocityField(Pos1) * Dt; // 流体速度場位置補正

   // 次発生粒子の起点
   float probable = length( Pos1 - Pos0.xyz )*CoefProbable * AcsSi*0.1f;
   float w = Pos0.w + probable;
   w *= step(w, 1.0f);
   if(time < 0.001f) w = 0.0;

   float4 Pos = float4(WorldMatrix._41_42_43, w);

   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
	float2 NormalTex  : TEXCOORD1;
	float3 Eye		  : TEXCOORD2;
	float  LocalTime  : TEXCOORD3;
    float4 Color      : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out;

   int Index0 = round( Pos.z * 100.0f );
   Pos.z = 0.0f;
   int i0 = Index0 / 1024;
   int i = i0 * 8;
   int j = Index0 % 1024;
   float2 texCoord = float2((i0+0.5)/TEX_WIDTH, (j+0.5)/TEX_HEIGHT);

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 1));

   // 経過時間に対する粒子拡大度
   float scale = ParticleDiffusion * sqrt(Pos0.w) + 2.0f;
   // 粒子の大きさ
   Pos.xy *= (0.5f+Color2Float(i+3, j)) * ParticleSize * scale * 10.0f;

   // 粒子の回転
   float rot = 6.18f * ( Color2Float(i+5, j) - 0.5f );
   Pos.xy = Rotation2D(Pos.xy, rot);
		
	Out.NormalTex =  Rotation2D(Tex*2-1,-rot);
	Out.NormalTex = Out.NormalTex*0.5+0.5;

   // ビルボード
   Pos.xyz = mul( Pos.xyz, BillboardMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.w = 1.0f;
   
   
   Out.Eye = Pos.xyz - CameraPosition;
   

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の乗算色
   float alpha = step(0.01f, Pos0.w) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -Pos0.w) * AcsTr;
   Out.Color = float4(ParticleColor, alpha);
   Out.LocalTime = pow(smoothstep(1, 0,Pos0.w),1);

   // テクスチャ座標
   Out.Tex = Tex*0.25;
   	
	Index0 %= 16;
	
	int tw = Index0%4;
	int th = Index0/4;

	Out.Tex.x += tw*0.25;
	Out.Tex.y += th*0.25;

   return Out;
}
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View); 
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}
// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
	float4 col = tex2D(Particle,IN.Tex);
	col *= IN.Color;
	col.rgb = col.rgb * 2.0 - 1.0;
	col.b = 0;
	float4 normal = tex2D(NormalBase,IN.NormalTex);
	normal.rgb  = normal.rgb * 2 - 1;
	normal.rgb += col.rgb*0.5;
	normal.a *= col.a;
	IN.Eye.y = -IN.Eye.y;
	float3x3 tangentFrame = compute_tangent_frame(normalize(IN.Eye), normalize(IN.Eye), IN.NormalTex);
	normal.xyz = normalize(mul(normal.xyz, tangentFrame));
	float d = pow(saturate(dot(-LightDirection,-normal.xyz)*0.5+0.5),1);
	
	col = float4(d,d,d,normal.a);
	col.rgb *= LightColor;
	col.a *= 0.5;
	
	col.rgb += FireColor*IN.LocalTime*2;
	
	return col;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=PosCopy;"
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
            "Pass=DrawObject;";
>{
   pass PosCopy < string Script = "Draw=Buffer;";>{
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_1_1 Common_VS();
       PixelShader  = compile ps_2_0 PosCopy_PS();
   }
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
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}

