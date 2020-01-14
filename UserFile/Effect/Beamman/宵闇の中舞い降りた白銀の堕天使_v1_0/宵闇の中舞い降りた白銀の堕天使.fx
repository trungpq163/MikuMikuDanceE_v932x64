//設定用パラメータ

//ターゲットモデル名（人体モデルを想定）
#define TGT_MODEL "初音ミクVer2.pmd"



//↓を有効にすると加算合成、無効にすると半透明合成
//#define ADD_FLG
// //#define ADD_FLG というように、左端に//をつける


// パーティクル数(0～15000)
#define PARTICLE_COUNT 1500
//生成制限速度
float CutSpeed = 0;
//バラけ具合
float particleSpread = 3;
//スピード
float particleSpeed = 0.1;
//最終到達距離
float particleSystemHeight = 0.5;
//パーティクル大きさ最大値
float particleSize = 1.0;
//パーティクル大きさ最小値
float particleSizeMin = 0.5;
//パーティクル拡大速度
float particleScaleSpd = 3.0;
//全体透明度
float particleAlpha = 0.025;
//個別回転速度
float RotateSpd = 0;
//全体回転速度
float GlobalRotateSpd = 0;
//重力
float3 Grv = float3(0,10,0);
//推進力
float MoveSpdMin = 1;
float MoveSpdMax = 2;
//減衰力(空気抵抗）
float Air = 1;
//モデルの回転に追従するかフラグ
#define LOCAL_ROTATE = TRUE;

//ちょっとわかる人向け

//ターゲットモーフ　任意で変更とかすると良いと思うの
float morph_0 : CONTROLOBJECT < string name = TGT_MODEL; string item = "あ"; >;
float morph_1 : CONTROLOBJECT < string name = TGT_MODEL; string item = "い"; >;
float morph_2 : CONTROLOBJECT < string name = TGT_MODEL; string item = "う"; >;
float morph_3 : CONTROLOBJECT < string name = TGT_MODEL; string item = "え"; >;
float morph_4 : CONTROLOBJECT < string name = TGT_MODEL; string item = "お"; >;
float morph_5 : CONTROLOBJECT < string name = TGT_MODEL; string item = "わらい(口)"; >;
float morph_6 : CONTROLOBJECT < string name = TGT_MODEL; string item = "おこり(口)"; >;
float morph_7 : CONTROLOBJECT < string name = TGT_MODEL; string item = "あーれー"; >;
float morph_8 : CONTROLOBJECT < string name = TGT_MODEL; string item = "ダミー"; >;
float morph_9 : CONTROLOBJECT < string name = TGT_MODEL; string item = "ダミー"; >;

float morph_adjust : CONTROLOBJECT < string name = TGT_MODEL; string item = "吐息制御"; >;
//よくわからない人はここから触らない


float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;

texture Particle_Tex
<
   string ResourceName = "Particle.png";
>;
sampler Particle = sampler_state
{
   Texture = (Particle_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//乱数取得
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

//--------------------------------------------------------------//
// FireParticleSystem
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// ParticleSystem
//--------------------------------------------------------------//

// パーティクル数の上限（Xファイルと連動しているので、変更不可）
#define PARTICLE_MAX_COUNT  15000



// 炎の方向を固定するか否か(0 or 1)
#define FIX_FIRE_DIRECTION  0

// 炎の方向　（FIX_FIRE_DIRECTIONに 1 を指定した場合のみ有効）
float3 fireDirection = float3( 0.0, 1.0, 0.0 );

// 以下のように指定すれば、別オブジェクトのY方向によって、炎の向きを制御できる。
//float4x4 control_object : CONTROLOBJECT < string Name = "negi.x"; >;
//static float3 fireDirection  = control_object._21_22_23;

//--------------------------------------------------------------//

#if FIX_FIRE_DIRECTION
#define TEX_HEIGHT  PARTICLE_COUNT
#else
#define TEX_HEIGHT  (PARTICLE_COUNT*2)
#endif

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
static float scaling = length(world_matrix[0]);

float time_0_X : Time;



// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles


float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

texture ParticleBaseTex : RenderColorTarget
<
   int Width=2;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseTex2 : RenderColorTarget
<
   int Width=2;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=2;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
texture SavePosTex : RenderColorTarget
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler SavePosSamp = sampler_state
{
   Texture = (SavePosTex);
   FILTER = NONE;
};
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

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float id: TEXCOORD2;
};

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
   int idx = round(Pos.z);
   Pos.z = float(idx)/PARTICLE_COUNT;
   
   // Loop particles
   float t = frac(Pos.z + particleSpeed * time_0_X);
   // Determine the shape of the system

   float3 pos;
   
   float rad = getRandom(idx*31)*2*3.14159265;
   float len = getRandom(idx*63);
   float rnd = getRandom(idx*123);
   float radx = sin(getRandom(idx)*162)*2*3.14159265;
   float rady = cos(getRandom(idx)*257)*2*3.14159265+time_0_X*GlobalRotateSpd;
   float radz = cos(getRandom(idx)*510)*2*3.14159265;

   len += 0.1;
   pos.x = (cos(rad))*pow(t,1)*len*particleSystemHeight;
   pos.y = 0;
   pos.z = (sin(rad))*pow(t,1)*len*particleSystemHeight;
      
   float4x4 matRot;

   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(radx),sin(radx),0); 
   matRot[2] = float4(0,-sin(radx),cos(radx),0); 
   matRot[3] = float4(0,0,0,1); 
   
   pos = mul(pos,matRot);
   
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
 
   pos = mul(pos,matRot);
 
   //Z軸回転
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   
   pos = mul(pos,matRot);

   pos *= particleSpread;
   

   float2 base_tex_coord_alpha = float2( 0.75, float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
   float base_alpha = tex2Dlod(ParticleBase2, float4(base_tex_coord_alpha,0,1)).r;
   
   pos.y += pow(t,Air)*(MoveSpdMin+(MoveSpdMax-MoveSpdMin)*base_alpha);
   
#if FIX_FIRE_DIRECTION
   float3 dirY = fireDirection;
#else
   float2 dir_tex_coord = float2( 0.25, float(idx)/TEX_HEIGHT+ 0.5 + 0.5/TEX_HEIGHT);
   float3 dirY = tex2Dlod(ParticleBase2, float4(dir_tex_coord,0,1)).xyz;
#endif
   dirY = normalize(dirY);
   float3 dirX = normalize( float3(dirY.y, -dirY.x, 0) );
   float3 dirZ = cross(dirX, dirY);
   float3x3 rotMat = { dirX, dirY, dirZ };
   pos = mul(pos, rotMat);
   
   // Billboard the quads.
   // The view matrix gives us our right and up vectors.
   len = 1-len*0.5;
   
   float4 Base = Pos;
   Base.w = 0;
   //Z軸回転
   radz = RotateSpd*time_0_X+idx*0.1;
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   Base = mul(Base, matRot);
   
   Pos.w = 1;
   pos += (particleScaleSpd*t+particleSizeMin + (particleSize-particleSizeMin) * pow(rnd,5)) *  1 * (Base.x * view_trans_matrix[0] + Base.y * view_trans_matrix[1]);
   pos *= scaling / 2;
   
   float2 base_tex_coord = float2( 0.25, float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
   float4 base_pos = tex2Dlod(ParticleBase2, float4(base_tex_coord,0,1));
   
   base_pos.xyz += pow(t,2)*Grv*scaling*0.1;
   pos += base_pos.xyz;
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   Out.texCoord = Pos.xy;
   
   
   Out.color = saturate(1-t)*base_alpha;
   if(Out.color >= 0.999)
   {
   		Out.color = 0;
   }
   
   //Out.color = t*len;
   
   Out.id = idx%4;
   if ( idx >= PARTICLE_COUNT ) Out.Pos.z=-2;
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

float4 FireParticleSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0, float color: TEXCOORD1,float id: TEXCOORD2) : COLOR {
   // Fade the particle to a circular shape
   float fade = pow(dot(texCoord, texCoord), particleShape);

   float4 col = tex2D(Particle,(texCoord*10)*0.5+0.5);
   col.a *= color*particleAlpha;
   col.rgb *= saturate(LightAmbient+0.75);
      
   return col;
   
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
   //モーフ値計算
   float morph_sum = saturate(
   morph_0 + morph_1 + morph_2 + morph_3 + morph_4 + 
   morph_5 + morph_6 + morph_7 + morph_8 + morph_9);
   
   //Tr値で抑制
   morph_sum = saturate(morph_sum - (1-MaterialDiffuse.a));
   
   //制御モーフ
   morph_sum *= 1-morph_adjust;


   int idx = round(texCoord.y*TEX_HEIGHT);
   if ( idx >= PARTICLE_COUNT ) idx -= PARTICLE_COUNT;
   
   float t = frac(float(idx)/PARTICLE_COUNT + particleSpeed * time_0_X);
   texCoord += float2(0.5/2, 0.5/TEX_HEIGHT);
   
   float4 old_color = tex2D(ParticleBase2, texCoord);
   if ( old_color.a <= t ) {
      old_color.a = t;
      return old_color;
   } else {
      if(length(world_matrix._41_42_43 - tex2D(SavePosSamp,0).xyz) < CutSpeed || MaterialDiffuse.a == 0)
      {
      	world_matrix._41_42_43 = 65535;
      }
#if !FIX_FIRE_DIRECTION
      if ( texCoord.x > 0.5 ) {
         return float4(morph_sum,0,0, t);
      } else if ( texCoord.y < 0.5 ) {
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
   Out.texCoord = Tex + float2(0.5/2, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(ParticleBase, texCoord);
}
VS_OUTPUT2 SavePosVS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex;
   return Out;
}

float4 SavePosPS(float2 texCoord: TEXCOORD0) : COLOR {
   return float4(world_matrix._41_42_43,1);
}
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem <
    string Script = 
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
        "RenderColorTarget0=SavePosTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=SavePos;"
    ;
> {
  pass ParticleBase < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_1_1 ParticleBase_Vertex_Shader_main();
      PixelShader = compile ps_2_0 ParticleBase_Pixel_Shader_main();
   }
  pass ParticleBase2 < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_1_1 ParticleBase2_Vertex_Shader_main();
      PixelShader = compile ps_2_0 ParticleBase2_Pixel_Shader_main();
   }
  pass SavePos < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE= FALSE;
      VertexShader = compile vs_1_1 SavePosVS();
      PixelShader = compile ps_2_0 SavePosPS();
   }
   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      #ifdef ADD_FLG
      	DESTBLEND = ONE;
      #else
      	DESTBLEND = INVSRCALPHA;
      #endif
      VertexShader = compile vs_3_0 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 FireParticleSystem_Pixel_Shader_main();
   }
}

