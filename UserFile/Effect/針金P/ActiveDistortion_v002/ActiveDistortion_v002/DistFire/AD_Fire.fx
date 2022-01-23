////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Fire.fx 空間歪みエフェクト(FireParticleSystemEx.fxを改変, 法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
//**************************************************************//
//  Effect File exported by RenderMonkey 1.6
//
//  - Although many improvements were made to RenderMonkey FX  
//    file export, there are still situations that may cause   
//    compilation problems once the file is exported, such as  
//    occasional naming conflicts for methods, since FX format 
//    does not support any notions of name spaces. You need to 
//    try to create workspaces in such a way as to minimize    
//    potential naming conflicts on export.                    
//    
//  - Note that to minimize resulting name collisions in the FX 
//    file, RenderMonkey will mangle names for passes, shaders  
//    and function names as necessary to reduce name conflicts. 
//**************************************************************//

//--------------------------------------------------------------//
// FireParticleSystem
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// ParticleSystem
//--------------------------------------------------------------//

// 粒子パラメータスイッチ
#define NORMAL_TYPE  2    // 粒子テクスチャの種類(とりあえず1,2で選択,1:ノーマルマップ粒小,2:ノーマルマップ粒大)

// パーティクル数の上限（Xファイルと連動しているので、変更不可）
#define PARTICLE_MAX_COUNT  1024

// パーティクル数
#define PARTICLE_COUNT 100

// 炎の方向を固定するか否か(0 or 1)
#define FIX_FIRE_DIRECTION  1

// 炎の方向　（FIX_FIRE_DIRECTIONに 1 を指定した場合のみ有効）
float3 fireDirection = float3( 0.0, 1.0, 0.0 );

// 以下のように指定すれば、別オブジェクトのY方向によって、炎の向きを制御できる。
//float4x4 control_object : CONTROLOBJECT < string Name = "negi.x"; >;
//static float3 fireDirection  = control_object._21_22_23;

//--------------------------------------------------------------//

float particleSystemShape
<
   string UIName = "particleSystemShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 1.00 );

float particleSpread
<
   string UIName = "particleSpread";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 50.00;
> = float( 20.00 );

float particleSpeed
<
   string UIName = "particleSpeed";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 0.40 );

float particleSystemHeight
<
   string UIName = "particleSystemHeight";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 160.00;
> = float( 25.00 );

float particleSize
<
   string UIName = "particleSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 200.00;
> = float( 70.0 );


// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles

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

#if FIX_FIRE_DIRECTION
#define TEX_HEIGHT  PARTICLE_COUNT
#else
#define TEX_HEIGHT  (PARTICLE_COUNT*2)
#endif

#define DEPTH_FAR  5000.0f   // 深度最遠値

float4x4 world_matrix : World;
float4x4 view_matrix : View;
float4x4 proj_matrix : Projection;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
static float scaling = length(world_matrix[0])*0.5;

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

texture Flame_Tex
<
   string ResourceName = TEX_FileName;
>;
sampler Flame = sampler_state
{
   Texture = (Flame_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

texture ParticleBaseTex : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseTex2 : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
sampler ParticleBase = sampler_state
{
   Texture = (ParticleBaseTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler ParticleBase2 = sampler_state
{
   Texture = (ParticleBaseTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 時間設定

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

float time1 : Time;
float time2 : Time < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_G32R32F" ;
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
static float time_0_X = tex2Dlod(TimeTexSmp, float4(0.5f,0.5f,0,0)).y;

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   float2 timeDat = tex2D(TimeTexSmp, float2(0.5f,0.5f)).xy;
   float etime = timeDat.y + clamp(time - timeDat.x, 0.0f, 0.1f) * TimeRate;
   if(time < 0.001f) etime = 0.0;
   return float4(time, etime, 0, 1);
}

///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (view_proj_matrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(view_matrix, MMM_DynamicFov(proj_matrix, length(CameraPosition-p.xyz))) : view_proj_matrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////////////
struct VS_OUTPUT {
   float4 Pos   : POSITION;
   float2 Tex   : TEXCOORD0;
   float4 VPos  : TEXCOORD1;   // ビュー座標
   float  color : TEXCOORD2;
};

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex : TEXCOORD0){
   VS_OUTPUT Out;

   int idx = round(Pos.z*100);
   Pos.z = float(idx)/PARTICLE_COUNT;
   
   // Loop particles
   float t = frac(Pos.z + particleSpeed * time_0_X);
   // Determine the shape of the system
   float s = pow(t, particleSystemShape);

   float3 pos;
   // Spread particles in a semi-random fashion
   pos.x = particleSpread * s * cos(62 * Pos.z);
   pos.z = particleSpread * s * sin(163 * Pos.z);
   // Particles goes up
   pos.y = particleSystemHeight * 2.0f * t;
   
#if FIX_FIRE_DIRECTION
   float3 dirY = fireDirection;
#else
   float2 dir_tex_coord = float2( 0.5, float(idx)/TEX_HEIGHT+ 0.5 + 0.5/TEX_HEIGHT);
   float3 dirY = tex2Dlod(ParticleBase2, float4(dir_tex_coord,0,1)).xyz;
#endif
   dirY = normalize(dirY);
   float3 dirX = normalize( float3(dirY.y, -dirY.x, 0) );
   float3 dirZ = cross(dirX, dirY);
   float3x3 rotMat = { dirX, dirY, dirZ };
   pos = mul(pos, rotMat);
   
   // Billboard the quads.
   // The view matrix gives us our right and up vectors.
   pos += particleSize * (Pos.x * view_trans_matrix[0].xyz + Pos.y * view_trans_matrix[1].xyz);
   pos *= scaling / 10;
   
   float2 base_tex_coord = float2( 0.5, float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
   float4 base_pos = tex2Dlod(ParticleBase2, float4(base_tex_coord,0,1));
   pos += base_pos.xyz;
   
   Out.Pos = mul(float4(pos, 1), GET_VPMAT(float4(pos, 1)));
   Out.color = 1 - t;

   // カメラ視点のビュー変換
   Out.VPos = mul( Pos, view_matrix );

   // テクスチャ座標
   int texIndex = idx % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
   int tex_i = texIndex % TEX_PARTICLE_XNUM;
   int tex_j = texIndex / TEX_PARTICLE_XNUM;
   Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

   if ( idx >= PARTICLE_COUNT ) Out.Pos.z=-2;
   return Out;
}

float4 FireParticleSystem_Pixel_Shader_main(VS_OUTPUT IN) : COLOR {
    // 粒子テクスチャ(ノーマルマップ)の法線
    float4 Color = tex2D(Flame, IN.Tex);
    // 透明部位は描画しない
    clip( Color.a - 0.5f );

    // 法線(0～1になるよう補正)
    float3 Normal =  normalize(float3(2.0f * Color.r - 1.0f, 1.0f - 2.0f * Color.g,  -Color.b));
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, IN.color*AcsTr*0.7f);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);


   return tex2D(Flame, IN.Tex);
}

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

VS_OUTPUT2 ParticleBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex ;
   return Out;
}

float4 ParticleBase_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   int idx = round(texCoord.y*TEX_HEIGHT);
   if ( idx >= PARTICLE_COUNT ) idx -= PARTICLE_COUNT;
   
   float t = frac(float(idx)/PARTICLE_COUNT + particleSpeed * time_0_X);
   texCoord += float2(0.5, 0.5/TEX_HEIGHT);
   
   float4 old_color = tex2D(ParticleBase2, texCoord);
   if ( old_color.a <= t ) {
      old_color.a = t;
      return old_color;
   } else {

#if !FIX_FIRE_DIRECTION
      if ( texCoord.y < 0.5 ) {
         return float4(world_matrix._41_42_43, t);
      } else {
         return float4(world_matrix._21_22_23, t);
      }
#else
      return float4(world_matrix._41_42_43, t);
#endif
   }
}

VS_OUTPUT2 ParticleBase2_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(ParticleBase, texCoord);
}

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem <
    string Script = 
       "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
        "RenderColorTarget0=ParticleBaseTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=ParticleBase;"
        "RenderColorTarget0=ParticleBaseTex2;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=ParticleBase2;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=ParticleSystem;"
    ;
> {
  pass UpdateTime < string Script= "Draw=Buffer;"; > {
      ZEnable = FALSE;
      AlphaBlendEnable = FALSE;
      AlphaTestEnable = FALSE;
      VertexShader = compile vs_1_1 UpdateTime_VS();
      PixelShader  = compile ps_2_0 UpdateTime_PS();
  }
  pass ParticleBase < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_3_0 ParticleBase_Vertex_Shader_main();
      PixelShader = compile ps_3_0 ParticleBase_Pixel_Shader_main();
   }
  pass ParticleBase2 < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_1_1 ParticleBase2_Vertex_Shader_main();
      PixelShader = compile ps_2_0 ParticleBase2_Pixel_Shader_main();
   }

   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      ALPHABLENDENABLE = FALSE;
      VertexShader = compile vs_3_0 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 FireParticleSystem_Pixel_Shader_main();
   }
}

