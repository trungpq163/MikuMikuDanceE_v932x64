////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FloorLightArt.fx ver0.0.2 床にライト絵を描いて動かします．ステージ演出用
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile  "sample.png" // オブジェクトに貼るテクスチャファイル名
int TexTypeCount = 4;         // テクスチャ種類数
float TexChangeTime = 10.0;   // テクスチャ変更時間間隔(秒)

int UnitCount = 7;            // 描画オブジェクト数
float UnitSize = 1.0;         // 描画サイズ
float RotRadius = 15.0;       // 平均回転半径
float LocalRotSpeed = 0.2;    // ローカル回転速度(cycle/秒)
float GlobalRotSpeed = 0.1;   // 周辺回転速度(cycle/秒)
float RadiusRange = 0.4;      // 内外移動振幅(RotRadiusとの比)
float IOMoveFreq = 18.0;      // 内外移動周期(秒)
float Distortion = 0.0;       // 回転に変化を与えるパラメータ
float zAdjust = 0.0;          // 地面影と重なってちらつく場合の補正値
float InitAlpha = 0.3;        // Tr=1の時の透過度
float3 LightColor = {1.0, 1.0, 0.7}; // テクスチャの乗算色(RBG)

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float time : TIME;

#define PAI 3.14159265f   // π

int Index;

// 座標変換行列
float4x4 WorldMatrix        : WORLD;
float4x4 ViewMatrix         : VIEW;
float4x4 ProjMatrix         : PROJECTION;
float4x4 ViewProjMatrix     : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

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


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float3 Rotation2D(float3 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.z * sin(rot);
    float z = pos.x * sin(rot) + pos.z * cos(rot);

    return float3(x, pos.y, z);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
   float4 Pos   : POSITION;    // 射影変換座標
   float2 Tex   : TEXCOORD1;   // テクスチャ
   float4 Color : COLOR0;      // 乗算色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT Out = (VS_OUTPUT)0;

   // ワールド座標変換
   Pos.xyz = mul( Pos.xyz, (float3x3)WorldMatrix );

   // オブジェクトサイズ
   Pos.x *= 8.0f * UnitSize;
   Pos.z *= 8.0f * UnitSize;
   Pos.y += zAdjust + 0.005f*Index; // 重なってちらつかないための補正

   // オブジェクトローカル回転
   Pos.xyz = Rotation2D(Pos.xyz, time*LocalRotSpeed*2.0f*PAI);

   // オブジェクト周辺回転
   Pos.z += RotRadius * (1.0f + RadiusRange * clamp( sin(time*2.0f*PAI/IOMoveFreq)+0.3f, -0.5f, 0.5f) * 2.0f );
   Pos.xyz = Rotation2D(Pos.xyz,  (time*GlobalRotSpeed + (float)Index/(float)UnitCount)*2.0f*PAI );

   // オブジェクト回転の変化
   float3 pos = float3(0.0f, 0.0f, Distortion);
   Pos.xyz += Rotation2D(pos, ((float)Index/(float)UnitCount)*2.0f*PAI);

   // ワールド座標
   Pos.xyz += WorldMatrix._41_42_43;

#ifndef MIKUMIKUMOVING
   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );
#else
   // 頂点座標
   if (MMM_IsDinamicProjection)
   {
       float dist = length(CameraPosition - Pos.xyz);
       Pos.y += MMM_GetDynamicFovEdgeRate(dist);
       float4x4 vpmat = mul( ViewMatrix, MMM_DynamicFov(ProjMatrix, dist) );
       Out.Pos = mul( Pos, vpmat );
   }
   else
   {
       Out.Pos = mul( Pos, ViewProjMatrix );
   }
#endif

   // テクスチャ座標
   float LType = (float)floor( (time/TexChangeTime) % (float)TexTypeCount );
   Tex.x = (Tex.x +  LType) / (float)TexTypeCount;
   Out.Tex = Tex;

   // テクスチャの乗算色
   float a = (0.5f - abs( frac( time / TexChangeTime ) - 0.5f) ) * TexChangeTime;
   Out.Color = float4( LightColor*smoothstep( 0.0f, 1.0f, a )*AcsTr, 1.0f);

   return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
   float4 Color = tex2D( ParticleSamp, IN.Tex );
   Color.rgb *= InitAlpha;
   Color *= IN.Color;

   return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec0 < string MMDPass = "object";
    string Script = "LoopByCount=UnitCount;"
                    "LoopGetIndex=Index;"
                        "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
   pass DrawObject {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      AlphaBlendEnable = TRUE;
      SrcBlend = ONE;
      DestBlend = ONE;
      VertexShader = compile vs_2_0 Basic_VS();
      PixelShader  = compile ps_2_0 Basic_PS();
   }
}




