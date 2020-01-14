//設定用パラメータ

// パーティクル数(0～1024)
#define PARTICLE_COUNT 1024
//スピード
float particleSpeed = 0.1;
//パーティクル大きさ最大値
float particleSizeMax = 1;
//最小値
float particleSizeMin = 0.5;
//色
float4 LotionColor = float4(1,1,1,0.1);
//スペキュラ色
float3 LotionSpecularColor = float3(1,1,1);
//重力
float3 Grv = float3(0,-50,0);
//歪み係数
float DistParam = 0.1;


//よくわからない人はここから触らない

//深度マップ保存テクスチャ
shared texture2D SPE_DepthTex : RENDERCOLORTARGET;
sampler2D SPE_DepthSamp = sampler_state {
    texture = <SPE_DepthTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ソフトパーティクルエンジン使用フラグ
bool use_spe : CONTROLOBJECT < string name = "SoftParticleEngine.x"; >;

float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

#define VPBUF_WIDTH  256
#define VPBUF_HEIGHT 256
//頂点座標バッファサイズ
static float2 VPBufSize = float2(VPBUF_WIDTH, VPBUF_HEIGHT);
static float2 VPBufOffset = float2(0.5 / VPBUF_WIDTH, 0.5 / VPBUF_HEIGHT);

texture VertexPosRT: OFFSCREENRENDERTARGET <
    string Description = "SaveVertexPos for aura_particle.fx";

    int width = VPBUF_WIDTH;
    int height = VPBUF_HEIGHT;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string Format="A32B32G32R32F";
    string DefaultEffect = 
        "* = hide;"
    ;
>;

sampler PosSamp = sampler_state {
    texture = <VertexPosRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture VertexPos_MaskRT: OFFSCREENRENDERTARGET <
    string Description = "SaveVertexPos_Mask for aura_particle.fx";

    int width = VPBUF_WIDTH;
    int height = VPBUF_HEIGHT;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "* = hide;"
    ;
>;

sampler MaskSamp = sampler_state {
    texture = <VertexPos_MaskRT>;
   ADDRESSU = Clamp;
   ADDRESSV = Clamp;
   MAGFILTER = Point;
   MINFILTER = Point;
   MIPFILTER = Point;
};

texture SelfLotion_DistRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for SelfLotion.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;";
>;
sampler DistortionView = sampler_state {
    texture = <SelfLotion_DistRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



//W付きスクリーン座標を0～1に正規化
float2 ScreenPosNormalize(float4 ScreenPos){
    return float2((ScreenPos.xy / ScreenPos.w + 1) * 0.5);
}

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

//モデルの頂点数
int VertexCount;

//頂点座標バッファ取得
float4 getVertexPosBuf(int index)
{
    float4 Color = 0;
    float2 tpos = 0;
	tpos.x = modf((float)index / VPBUF_WIDTH, tpos.y);
	tpos.y /= VPBUF_HEIGHT;
	tpos += VPBufOffset;
	    
	Color = tex2D(PosSamp, tpos)*tex2D(MaskSamp, tpos).a;
	
	return Color;
}
float4 getVertexPosBuf_VS(int index)
{
    float4 Color = 0;
    float2 tpos = 0;
	tpos.x = modf((float)index / VPBUF_WIDTH, tpos.y);
	tpos.y /= VPBUF_HEIGHT;
	tpos += VPBufOffset;
	    
	Color = tex2Dlod(PosSamp, float4(tpos,0,0))*tex2Dlod(MaskSamp, float4(tpos,0,0)).a;
	
	return Color;
}
//頂点数取得
int getVertexNum()
{
    float4 Color;
    
    Color = tex2D(PosSamp, 0).a;
    return Color;
}
int getVertexNum_VS()
{
    float4 Color;
    
    Color = tex2Dlod(PosSamp, 0).a;
    return Color;
}
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
float4 getRandomPS(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2D(rnd, tpos);
}

//--------------------------------------------------------------//
// FireParticleSystem
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// ParticleSystem
//--------------------------------------------------------------//

//--------------------------------------------------------------//

#define TEX_HEIGHT  PARTICLE_COUNT
#define TEX_WIDTH 63

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
static float scaling = length(world_matrix[0]);

float time_0_X : Time;



// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles


texture ParticleBaseTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseTex2 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
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
sampler ParticleBase2_Linear = sampler_state
{
   Texture = (ParticleBaseTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float id: TEXCOORD2;
   float4 LastPos: TEXCOORD3;
   float3 WPos: TEXCOORD4;
   float3 Eye: TEXCOORD5;
   float3 Normal: TEXCOORD6;
};

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
   int idx = round(Pos.z);
   Pos.z = float(idx)/PARTICLE_COUNT;
   
   float t = frac(Pos.z + particleSpeed * time_0_X);
   
   float rnd = getRandom(idx*123);
   float rady = cos(getRandom(idx)*257)*2*3.14159265;

   
   float3 pos;
 
   float4 Base = Pos;
   Base.w = 0;
   
   Pos.w = 1;
   pos = 0;
   Base.z = 0;

   float2 base_tex_coord = float2( 1-(Pos.y*10*0.5+0.5), float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
   float4 base_pos = tex2Dlod(ParticleBase2_Linear, float4(base_tex_coord,0,1));
   
   Base.x *= saturate(pow(t,2))*(particleSizeMax*rnd+particleSizeMin)*(1-pow(base_pos.w,2));
   //Base.y *= 1+pow(t,2)*-Grv.y*2;

   float4x4 matRot;
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
   
   Base = mul(Base,matRot);
   Out.Normal = mul(float3(0,0,1),matRot);
   
   pos += Base;//particleSize * pow(rnd,5) *  1 * Base;
   pos.y -= abs(Pos.x);
   pos *= scaling / 2;
   
   pos += base_pos.xyz;
   
   Out.Eye = CameraPosition - float4(pos, 1);
   Out.WPos = pos;
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   Out.LastPos = Out.Pos;
   Out.texCoord = -1*Pos.xy;
   Out.color = base_pos.w;
   /*
   Out.color = saturate(1-t);
   if(Out.color >= 0.999)
   {
   		Out.color = 0;
   }
   */
   //Out.color = t*len;
   
   Out.id = 1-saturate(pow(Pos.y*10*0.5+0.5,4)+0.1);
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

float4 FireParticleSystem_Pixel_Shader_main(VS_OUTPUT IN) : COLOR {
	//return float4(IN.color,0,0,1);
	// Fade the particle to a circular shape
	float4 col = tex2D(Particle,(IN.texCoord*10)*0.5+0.5);

//	col.a *= IN.color;

	float2 ScrTex;
	ScrTex.x = (IN.LastPos.x / IN.LastPos.w)*0.5+0.5;
	ScrTex.y = (-IN.LastPos.y / IN.LastPos.w)*0.5+0.5;
	
	ScrTex += (col.rg-0.5)*DistParam;
	
	float4 ret = tex2D(DistortionView,ScrTex);
	//ret.rgb += 0.5*col.a;
	
    // スペキュラ色計算
    float3 normal = normalize((col.rgb-0.5)*2);
    normal = normalize(IN.Normal+normal);
	
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float LotionPow = pow( max(0,dot( HalfVector, normalize(normal) )), 1 );
    float3 Specular = LotionPow * LotionSpecularColor * LightSpecular;
	
	ret.rgb = lerp(ret.rgb,LotionColor.rgb*(LightAmbient+1),LotionColor.a);
    ret.rgb += Specular;
    ret.a = col.a;
    
	if(use_spe)
	{
		float2 ScTex = IN.LastPos.xyz/IN.LastPos.w;
		ScTex.y *= -1;
		ScTex.xy += 1;
		ScTex.xy *= 0.5;
	    // 深度
	    float dep = length(CameraPosition - IN.WPos);
	    float scrdep = tex2D(SPE_DepthSamp,ScTex).r;

	    //return float4(smoothstep(0,59,scrdep),0,0,1);
	    //return float4(smoothstep(0,59,dep),0,0,1);
	    
	    dep = length(dep-scrdep);
	    dep = smoothstep(0,1,dep);
	    ret.a *= dep;
    }
	
	return ret;
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
   texCoord += float2(0.5/TEX_WIDTH, 0.5/TEX_HEIGHT);
   float4 old_color;
	float rnd = (getRandomPS(idx))*65535;
	float4 work = getVertexPosBuf(rnd%getVertexNum());

   if(texCoord.x < 0.5/TEX_WIDTH)
   {
   		old_color = work;
   }else{
		float rnd = (getRandomPS(idx))*65535;
		float4 work = getVertexPosBuf(rnd%getVertexNum());
		
		old_color = tex2D(ParticleBase2, texCoord-float2(0.5/TEX_WIDTH,0));
   		old_color.xyz += (1-texCoord.x)*pow(t,10)*Grv*0.025;
   		work.xyz += (1-texCoord.x)*pow(t,10)*Grv*1;
   		old_color.xyz = lerp(work.xyz,old_color.xyz,saturate(t*1));
   }
   if ( old_color.a <= t ) {
      old_color.a = t;
      return old_color;
   } else {
		float rnd = (getRandomPS(idx))*65535;
		float4 work = getVertexPosBuf(rnd%getVertexNum());
		world_matrix[3].xyz = work.xyz;

      if(!(MaterialDiffuse.a*work.a*length(work.xyz)))
      {
      		t = 1;
      }

      return float4(world_matrix._41_42_43, t);
   }
}

VS_OUTPUT2 ParticleBase2_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5/TEX_WIDTH, 0.5/TEX_HEIGHT);
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
	//return float4(tex2Dlod(MaskSamp, float4(texCoord,0,0)).a,0,0,1);
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
      VertexShader = compile vs_3_0 ParticleBase_Vertex_Shader_main();
      PixelShader = compile ps_3_0 ParticleBase_Pixel_Shader_main();
   }
  pass ParticleBase2 < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_3_0 ParticleBase2_Vertex_Shader_main();
      PixelShader = compile ps_3_0 ParticleBase2_Pixel_Shader_main();
   }
  pass SavePos < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE= FALSE;
      VertexShader = compile vs_3_0 SavePosVS();
      PixelShader = compile ps_3_0 SavePosPS();
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
   pass ParticleSystem_alpha
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;
      VertexShader = compile vs_3_0 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 FireParticleSystem_Pixel_Shader_main();
   }
}

