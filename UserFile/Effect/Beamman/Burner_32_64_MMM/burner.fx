//設定用パラメータ

//↓を有効にすると加算合成、無効にすると半透明合成
#define ADD_FLG
//無効にする時は //#define ADD_FLG というように、左端に//をつける

//ビルボード処理の有無
#define BILLBOARD
//無効にする時は //#define BILLBOARD というように、左端に//をつける

// パーティクル数(0～1024)
#define PARTICLE_COUNT 1024
//生成制限速度
float CutSpeed = 0;
//色
//フィルライト色
float3 ParticleColor
<
   string UIName = "ParticleColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float3(0.1,0.5,1);
//バラけ角度
float particleSpread <
   string UIName = "particleSpread";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 360;
> = 120;

//再生スピード
float particleSpeed <
   string UIName = "particleSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 5;

//パーティクル大きさ最大値
float particleSize <
   string UIName = "particleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 5;

//重力
float3 Grv = float3(0,0,0);

//推進力
float MinMoveSpd <
   string UIName = "MinMoveSpd";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 1;

float MaxMoveSpd <
   string UIName = "MaxMoveSpd";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 3;

//--噴出部分
float MinMoveSpd2 <
   string UIName = "MinMoveSpd2";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 1;

float MaxMoveSpd2 <
   string UIName = "MaxMoveSpd2";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 5;

float particleSpread2 <
   string UIName = "particleSpread2";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 360;
> = 2;
float particleSize2 <
   string UIName = "particleSize2";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 4;

//よくわからない人はここから触らない

//パーティクル画像テクスチャ
texture Particle_Tex
<
   string ResourceName = "Particle.png";
>;
sampler Particle = sampler_state
{
   Texture = (Particle_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
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

//パラメータ宣言
float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
static float scaling = length(world_matrix[0]);

float time_0_X : Time;

//Tr値取得
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

//頂点シェーダ
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float id: TEXCOORD2;
};

float3 calcParticle(int idx,float t)
{
   if((idx % 2) == 0)
   {
		MinMoveSpd = MinMoveSpd2;
		MaxMoveSpd = MaxMoveSpd2;
		particleSpread = particleSpread2;
		particleSize = particleSize2;
   }
   float fid = float(idx)/PARTICLE_COUNT;
   
   float4x4 ret_mat = 0;
   ret_mat[0] = float4(1,0,0,0); 
   ret_mat[1] = float4(0,1,0,0); 
   ret_mat[2] = float4(0,0,1,0); 
   ret_mat[3] = float4(0,0,0,1); 
   
   
   //度→ラジアン変換
   particleSpread = particleSpread*3.14159265/180.0;
   particleSpread *= 0.5;
   
   float3 rnd = getRandom(idx)*2-1;
   
   float len = getRandom(idx*63);
   float radx = rnd.x*particleSpread;
   float rady = rnd.y*particleSpread;
   float radz = rnd.z*particleSpread;

   len = (len*(MaxMoveSpd-MinMoveSpd))+MinMoveSpd;
   ret_mat[3].z = -len*t;
   
   
   float4x4 matRot;
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
 
   ret_mat = mul(ret_mat,matRot);
   
   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(radx),sin(radx),0); 
   matRot[2] = float4(0,-sin(radx),cos(radx),0); 
   matRot[3] = float4(0,0,0,1); 
   
   ret_mat = mul(ret_mat,matRot);

   //行列を取得
   float4x4 PatWorld = world_matrix;
   ret_mat = mul(ret_mat, PatWorld);
   //ret_mat = mul(ret_mat,world_matrix);
   return ret_mat[3].xyz;
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
   float3 pos = calcParticle(idx,t);


   
   float4 Base = Pos;
   Base.w = 0;
   
   //前の座標を取得
   float3 prev_pos = calcParticle(idx,t+0.1);
   
   //前の座標と今の座標からフロントベクトルベクトルを計算
   float3 Front = normalize(pos - prev_pos);
   
	//カメラからのベクトル
	float3 Eye = normalize(view_trans_matrix[2].xyz);
	
   //フロントベクトルと視線ベクトルの外積でサイドベクトルを計算
   float3 Side = normalize(cross(Front,Eye))*scaling*0.1*MaterialDiffuse.a;
   	   
   //Xがマイナスだったら左、プラスだったら右に頂点を配置
   Base.xyz = 0;
   Base.xyz += (Pos.x * 10)*Side*0.1*particleSize;
      
   //位置座標に加算
   pos += Base.xyz;
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   Out.texCoord = Pos.yx;
   Out.color = saturate(1-a);
   if(Out.color >= 0.999)
   {
   		Out.color = 0;
   }
   
   Out.id = idx;
   if ( idx >= PARTICLE_COUNT ) Out.Pos.z=-2;
   return Out;
}



float4 FireParticleSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0, float color: TEXCOORD1,float id: TEXCOORD2) : COLOR {

   float4 col = tex2D(Particle,(texCoord*10)*0.5+0.5);
   col.rgb *= ParticleColor;
   col.a *= color;
      
   return col;
   
}

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem <
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=ParticleSystem;"
    ;
> {
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

