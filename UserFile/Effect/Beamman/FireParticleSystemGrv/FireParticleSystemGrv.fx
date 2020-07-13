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

float4x4 inv_world_matrix : WORLDINVERSE;
float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_matrix : World;
float4x4 view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);

float time_0_X : Time;
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
> = float( 0.48 );
float particleSystemHeight
<
   string UIName = "particleSystemHeight";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 160.00;
> = float( 80.00 );
float particleSize
<
   string UIName = "particleSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 7.80 );
//重力の向き
float3 particleGravityVec
<
   string UIName = "particleGravityVec";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float3 UIMin = float3(0,0,0);
   float3 UIMax = float3(1,1,1);
> = float3( 0,1,0 );
//重力の強さ
float particleGravity
<
   string UIName = "particleGravity";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = -1000.0;
   float UIMax = 1000.0;
> = float( 10 );
//重力曲線の係数
int particleGravityPow
<
   string UIName = "particleGravityPow";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 256;
> = int( 3 );
// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   // Loop particles
   float t = frac(Pos.z + particleSpeed * time_0_X);
   // Determine the shape of the system
   float s = pow(t, particleSystemShape);

   float3 pos;
   // Spread particles in a semi-random fashion
   pos.x = particleSpread * s * cos(62 * Pos.z);
   pos.z = particleSpread * s * sin(163 * Pos.z);
   // Particles goes up
   pos.y = particleSystemHeight * t;

   // Billboard the quads.
   // The view matrix gives us our right and up vectors.
   //pos += particleSize * (Pos.x * view_trans_matrix[0] + Pos.y * view_trans_matrix[1]);
   pos += particleSize * (Pos.x * billboard_vec_x + Pos.y * billboard_vec_y);
   pos /= 10;
   
   //--重力を受ける部分--追加・ロベリア//
   //ワールドの逆行列を取得
   float4x4 rot = inv_world_matrix;
   //移動を0にして回転拡大行列のみに
   rot[3].xyz = 0;
   //下方向を取得
   float3 DownVec = normalize(mul(particleGravityVec,rot));
   //生成されてからの時間で下方向に加速度を与える
   pos -= DownVec * pow(t,particleGravityPow) * particleGravity;
   
   
   Out.Pos = mul(float4(pos,1), world_view_proj_matrix);
   Out.texCoord = Pos.xy;
   Out.color = 1 - t;

   return Out;
}


float particleShape
<
   string UIName = "particleShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.37 );
texture Flame_Tex
<
   string ResourceName = "Flame.png";
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
float4 FireParticleSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0, float color: TEXCOORD1) : COLOR {
   // Fade the particle to a circular shape
   float fade = pow(dot(texCoord, texCoord), particleShape);
   return (1 - fade) * tex2D(Flame, float2(color,0.5f));
}


//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem
{
   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = ONE;
      DESTBLEND = ONE;

      VertexShader = compile vs_1_1 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 FireParticleSystem_Pixel_Shader_main();
   }

}

