//設定用パラメータ

//↓を有効にすると加算合成、無効にすると半透明合成
#define ADD_FLG
//無効にする時は //#define ADD_FLG というように、左端に//をつける

//ビルボード処理の有無
#define BILLBOARD
//無効にする時は //#define BILLBOARD というように、左端に//をつける

// パーティクル数(0～1024)
#define PARTICLE_COUNT 128
//生成制限速度
float CutSpeed = 0;
//色
float3 ParticleColor = float3(2,0.5,0.1);
//バラけ具合
float particleSpread = 0.05;
//再生スピード
float particleSpeed = 1;
//パーティクル大きさ最大値
float particleSize = 0.25;
//重力
float3 Grv = float3(0,-30,0);
//推進力
float MinMoveSpd = 20;
float MaxMoveSpd = 30;
//減衰力(空気抵抗）
float Air = 0.5;


//モデルの回転に追従するかフラグ
#define LOCAL_ROTATE = TRUE;

//よくわからない人はここから触らない

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
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
static float scaling = length(world_matrix[0]);

float time_0_X : Time;



// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles


float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

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

float3 calcParticle(int idx,float3 Pos,float t)
{
   float fid = float(idx)/PARTICLE_COUNT;
   
   float3 pos;
   
   // Determine the shape of the system

   
   float rad = getRandom(idx*31)*2*3.14159265;
   float len = getRandom(idx*63);
   float rady = cos(getRandom(idx)*257)*2*3.14159265;
   float radx = getRandom(idx*31)*3.1415*2*particleSpread;
   float radz = getRandom(idx*63)*3.1415*2*particleSpread;

   len = (len*(MaxMoveSpd-MinMoveSpd))+MinMoveSpd;

   pos.x = 0;
   Air += 0.01;
   pos.y = len*t*pow(Air,t);
   pos.z = 0;
      
   float4x4 matRot;
	
   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(radx),sin(radx),0); 
   matRot[2] = float4(0,-sin(radx),cos(radx),0); 
   matRot[3] = float4(0,0,0,1); 
   
   pos = mul(pos,matRot);
 
   //Z軸回転
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   
   //pos = mul(pos,matRot);
   
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
 
   pos = mul(pos,matRot);


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
   

   pos += Grv*pow(t,2);
   
   return pos;
}

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
   int idx = round(Pos.z);
   Pos.z = float(idx)/PARTICLE_COUNT;

   float rnd = getRandom(Pos.z*123);
   
   float t = frac(Pos.z + particleSpeed * time_0_X);
   float a = t+pow(t,2);
   t = lerp(0,t,(1-(Pos.y*10*0.5+0.5)));
   //パーティクルの現在座標を計算
   float3 pos = calcParticle(idx,Pos,t);


   
   float4 Base = Pos;
   Base.w = 0;
   //Z軸回転
   float4x4 matRot;
   float radz = time_0_X+idx*0.1;
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   Base = mul(Base, matRot);
   
   #ifdef BILLBOARD
	   
	   //前の座標を取得
	   float3 prev_pos = calcParticle(idx,Pos,t+0.1);
	   
	   //前の座標と今の座標からフロントベクトルベクトルを計算
	   float3 Front = normalize(pos - prev_pos);
	   
		//カメラからのベクトル
		float3 Eye = normalize(view_trans_matrix[2].xyz);
		
	   //フロントベクトルと視線ベクトルの外積でサイドベクトルを計算
	   float3 Side = normalize(cross(Front,Eye));
	   	   
	   //Xがマイナスだったら左、プラスだったら右に頂点を配置
	   Base.xyz = 0;
	   Base.xyz += (Pos.x * 10)*Side*0.1*particleSize;
	   
	   
	   //位置座標に加算
	   pos += Base.xyz;
	   pos *= scaling / 2;
	   
   #else
	   pos += particleSize * pow(rnd,5) *  1 * (Base.x * view_trans_matrix[0] + Base.y * view_trans_matrix[1]);
	   pos *= scaling / 2;
   #endif
   

   float2 base_tex_coord = float2( 0, float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
   float4 base_pos = tex2Dlod(ParticleBase2, float4(base_tex_coord,0,1));
   
   
   //base_pos = lerp(base_pos,world_matrix[3],Pos.y*10*0.5+0.5);
   
   pos += base_pos.xyz;
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   Out.texCoord = Pos.yx;
   Out.color = saturate(1-a);
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
   col.rgb *= ParticleColor;
   col.a *= color;
      
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
   int idx = round(texCoord.y*TEX_HEIGHT);
   if ( idx >= PARTICLE_COUNT ) idx -= PARTICLE_COUNT;
   
   float t = frac(float(idx)/PARTICLE_COUNT + particleSpeed * time_0_X);
   texCoord += float2(0.5, 0.5/TEX_HEIGHT);
   float4 old_color = tex2D(ParticleBase2, texCoord);
   
   if(time_0_X == 0)
   {
   		return float4(65535,65535,65535,0);
   }else{
	   if ( old_color.a <= t ) {
	      old_color.a = t;
	      return old_color;
	   } else {
	      if(length(world_matrix._41_42_43 - tex2D(SavePosSamp,0).xyz) < CutSpeed || MaterialDiffuse.a == 0)
	      {
	      	world_matrix._41_42_43 = 65535;
	      }
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
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    //"Pass=ParticleBase2;"
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

