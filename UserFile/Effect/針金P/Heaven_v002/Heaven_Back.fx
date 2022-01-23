////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Heaven_Back.fx ver0.0.2  ヘブンフィルターエフェクト(モデル後面配置)
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx,FireParticleSystem.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float Xmin = -10.0;        // X範囲最小値
float Xmax = 10.0;         // X範囲最大値
float Ymin = -5.0;         // Y範囲最小値
float Ymax = 25.0;         // Y範囲最大値

int ParticleCount = 50;     // 光粒子の描画オブジェクト数
float LightScale = 1.0;     // 光粒子大きさ
float LightSpeedMin = 1.0;  // 光粒子最小スピード
float LightSpeedMax = 2.0;  // 光粒子最大スピード
float LightCross = 2.0;     // 光粒子の十字度合い

int SeedXY = 7;           // 配置に関する乱数シード
int SeedSize = 3;         // サイズに関する乱数シード
int SeedSpeed = 13;       // スピードに関する乱数シード
int SeedCross = 11;       // 十字度合いに関する乱数シード


// ボーンの鈍化追従パラメータ
bool flagMildFollow <        // 鈍化追従on/off
   string UIName = "鈍化追従on/off";
   bool UIVisible =  true;
> = true;

float ElasticFactor = 50.0;  // ボーン追従の弾性度
float ResistFactor = 20.0;   // ボーン追従の抵抗度
float MaxDistance = 8.0;     // ボーン追従の最大ぶれ幅


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int Index;

float time : Time;

// 座標変換行列
float4x4 WorldMatrix             : WORLD;
float4x4 ViewMatrix              : VIEW;
float4x4 ProjMatrix              : PROJECTION;
float4x4 ViewProjMatrix          : VIEWPROJECTION;
float4x4 WorldViewProjMatrix     : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse  : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;


texture2D BackTex <
    string ResourceName = "HeavenBack.png";
>;
sampler BackSamp = sampler_state {
    texture = <BackTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D FrameTex <
    string ResourceName = "HeavenFrame.png";
>;
sampler FrameSamp = sampler_state {
    texture = <FrameTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex1 <
    string ResourceName = "Particle1.png";
>;
sampler ParticleSamp1 = sampler_state {
    texture = <ParticleTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex2 <
    string ResourceName = "Particle2.png";
>;
sampler ParticleSamp2 = sampler_state {
    texture = <ParticleTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// オブジェクトの座標・速度記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=2;
   int Height=1;
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
   int Width=2;
   int Height=1;
   string Format = "D24S8";
>;
float4 CoordTexArray[2] : TEXTUREVALUE <
   string TextureName = "CoordTex";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトの座標・速度計算

struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 共通の頂点シェーダ
VS_OUTPUT Coord_VS(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.25f, 0.5f);

    return Out;
}

// 0フレーム再生でリセット
float4 InitCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float4 Pos = tex2D(CoordSmp, Tex);
   if( time < 0.001f ){
      Pos = Tex.x<0.5f ? float4(WorldMatrix._41_42_43, 1.0f) : float4(0.0f, 0.0f, 0.0f, 1.0f);
   }
   return Pos;
}

// 座標・速度更新
float4 Coord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float3 Pos0 = tex2D(CoordSmp, float2(0.25f, 0.5f)).xyz;

   // オブジェクトの速度
   float4 Vel = tex2D(CoordSmp, float2(0.75f, 0.5f));

   // ワールド座標
   float3 WPos = WorldMatrix._41_42_43;

   // 1フレームの時間間隔
   float Dt = clamp(time - Vel.w, 0.001f, 0.1f);

   // 加速度計算(弾性力+速度抵抗力)
   float3 Accel = (WPos - Pos0) * ElasticFactor - Vel.xyz * ResistFactor;

   // 新しい座標に更新
   float3 Pos1 = Pos0 + Dt * (Vel.xyz + Dt * Accel);

   // 速度計算
   Vel.xyz = ( Pos1 - Pos0 ) / Dt;

   // オブジェクトがワールド座標から一定距離以上離れないようにする
   if( length( WPos - Pos1 ) > MaxDistance ){
      Pos1 = WPos + normalize( Pos1 - WPos ) * MaxDistance;
   }

   // 座標・速度記録
   float4 Pos = Tex.x<0.5f ? float4(Pos1, 1.0f) : float4(Vel.xyz, time);

   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// 背景描画

struct VS_OUTPUT1
{
    float4 Pos  : POSITION;    // 射影変換座標
    float2 Tex  : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT1 Back_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT1 Out;

    Pos.xy *= float2((Xmax-Xmin)/2.0f, (Ymax-Ymin)/2.0f);
    Pos.xy += float2((Xmax+Xmin)*0.5f, (Ymax+Ymin)*0.5f)*0.1f;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos.xyz = mul( Pos.xyz, (float3x3)WorldMatrix );
    if( flagMildFollow ){
       Pos.xyz += CoordTexArray[0].xyz;
    }else{
       Pos.xyz += WorldMatrix._41_42_43;
    }

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // テクスチャ座標
    Out.Tex = Tex;
 
    return Out;
}

// ピクセルシェーダ
float4 Back_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    float4 Color = tex2D( BackSamp, Tex );
    float4 Color1 = tex2D( FrameSamp, Tex );
    Color.a *= Color1.r*AcsTr*0.9f;
    return Color;
}

// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0";
    string Script = "RenderColorTarget0=CoordTex;"
                        "RenderDepthStencilTarget=CoordDepthBuffer;"
                        "Pass=PosInit;"
                        "Pass=PosUpdate;"
                    "RenderColorTarget0=;"
                        "RenderDepthStencilTarget=;"
                        "Pass=DrawObject;"
    ;
> {
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Coord_VS();
        PixelShader  = compile ps_2_0 InitCoord_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Coord_VS();
        PixelShader  = compile ps_2_0 Coord_PS();
    }
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Back_VS();
        PixelShader  = compile ps_2_0 Back_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos    : POSITION;    // 射影変換座標
    float3 Tex    : TEXCOORD0;   // テクスチャ
    float4 Color  : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand0 = abs(0.6f*sin(37 * SeedSize * Index + 13) + 0.4f*cos(71 * SeedSize * Index + 17));
    float rand1 = abs(0.4f*sin(53 * SeedSpeed * Index + 17) + 0.6f*cos(61 * SeedSpeed * Index + 19));
    float rand2 = abs(0.7f*sin(124 * SeedXY * Index + 19) + 0.3f*cos(235 * SeedXY * Index + 23));
    float rand3 = abs(0.6f*sin(83 * SeedXY * Index + 23) + 0.4f*cos(91 * SeedXY * Index + 29));
    float rand4 = (sin(47 * SeedCross * Index + 29) + cos(81 * SeedCross * Index + 31) + 3.0f) * 0.1f;

    // パーティクルサイズ
    float scale = 0.5f + rand0;
    Pos.xy *= scale*LightScale;

    // パーティクル配置
    float speed = lerp(LightSpeedMin, LightSpeedMax, rand1);
    Pos.x += lerp(Xmin, Xmax, rand2) * 0.1f;
    float y = lerp(Ymin, Ymax, rand3);
    Pos.y += ((y+speed*time-Ymin)%(Ymax-Ymin)+Ymin) * 0.1f;

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos.xyz = mul( Pos.xyz, (float3x3)WorldMatrix );
    if( flagMildFollow ){
       Pos.xyz += CoordTexArray[0].xyz;
    }else{
       Pos.xyz += WorldMatrix._41_42_43;
    }

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 粒子の透過度
    y = abs(((y+speed*time-Ymin)%(Ymax-Ymin))/(Ymax-Ymin)-0.5f);
    float alpha = (1.0f-smoothstep(0.4f, 0.5f, y))*AcsTr;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    // テクスチャ座標
    Out.Tex = float3(Tex, 1.2f+LightCross*rand4);

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( ParticleSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= IN.Color.xyz*0.5f;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "1-1000";
    string Script = "LoopByCount=ParticleCount;"
                    "LoopGetIndex=Index;"
                        "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

