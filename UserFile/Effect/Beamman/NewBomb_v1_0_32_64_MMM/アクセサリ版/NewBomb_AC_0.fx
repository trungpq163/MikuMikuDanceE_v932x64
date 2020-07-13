//コントローラ名
#define CONTROLLER "NewBombController_0.pmx"

float morph_Anm : CONTROLOBJECT < string name = CONTROLLER; string item = "再生"; >;
float morph_Height : CONTROLOBJECT < string name = CONTROLLER; string item = "幅"; >;
float morph_Width : CONTROLOBJECT < string name = CONTROLLER; string item = "高さ"; >;
float morph_Scale_p : CONTROLOBJECT < string name = CONTROLLER; string item = "スケール+"; >;
float morph_Scale_m : CONTROLOBJECT < string name = CONTROLLER; string item = "スケール-"; >;
float morph_Pat : CONTROLOBJECT < string name = CONTROLLER; string item = "ﾊﾟｰﾃｨｸﾙSi"; >;
float morph_Grv : CONTROLOBJECT < string name = CONTROLLER; string item = "重力"; >;
float morph_Air : CONTROLOBJECT < string name = CONTROLLER; string item = "空気抵抗"; >;
float morph_H : CONTROLOBJECT < string name = CONTROLLER; string item = "色相"; >;
float morph_S : CONTROLOBJECT < string name = CONTROLLER; string item = "彩度"; >;
float morph_B : CONTROLOBJECT < string name = CONTROLLER; string item = "明度"; >;
float morph_A : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
float morph_Spd : CONTROLOBJECT < string name = CONTROLLER; string item = "初速加算"; >;
float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "角度幅"; >;

static float morph_Scale = morph_Scale_p - morph_Scale_m*0.1;

//---複製数---//

int ParticleNum = 2000;

static float AddHeight = 10*morph_Height;
static float AddWidth = 10*morph_Width;
static float AddScale = 10*morph_Scale;
static float AddPatScale = 2000*morph_Pat;

float DefAlpha = 1;

float4x4 view_proj_matrix : ViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
float4x4 inv_view_matrix : WORLDVIEWINVERSE;
float4x4 world_matrix : WORLD;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   LightColor      : SPECULAR   < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

float time_0_X : Time;

#define ParticleMax 15000

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

//HSB変換用色テクスチャ
texture2D ColorPallet <
    string ResourceName = "ColorPallet.png";
>;
sampler PalletSamp = sampler_state {
    texture = <ColorPallet>;

	ADDRESSU = CLAMP;
	ADDRESSV = CLAMP;
};

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
   float color: TEXCOORD1;
   float2 NormalTex: TEXCOORD2;
   float sca: TEXCOORD3;
   float3 Eye: TEXCOORD4;
};

float3 Grv = float3(0,1,0);
VS_OUTPUT BombVS(float4 Pos: POSITION,float2 Tex: TEXCOORD0){
	VS_OUTPUT Out = (VS_OUTPUT)0;
	int index = Pos.z*10;
	Pos.z = 0;
	float fi = index;
	fi = fi/ParticleMax;
	float3 r = getRandom(index);
	float3 r2 = getRandom(index+128);
	float t = morph_Anm;
	float tr = 1-morph_Anm;
	float3 pos = 0;

	//初速
	float sca = saturate(r.z+morph_Spd)*100;


	r.xy *= 2.0 *3.1415;

	//角度
	float theta = r.x*(1-morph_r);
	//ベクトル
	float st = 1-pow(tr,1+morph_Air*10);
	float3 Vec = float3(0,sca*sin(theta)*st*(1+AddWidth),sca*cos(theta)*-st*(1+AddHeight));

	float4x4 matRot;
	//Y軸回転 
	matRot[0] = float4(cos(r.y),0,-sin(r.y),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(r.y),0,cos(r.y),0); 
	matRot[3] = float4(0,0,0,1); 

	Vec = mul(Vec,matRot);
	pos += Vec;

	float3 w = (1+AddScale)*5*(((100*pow(t,2)) + 10 * (10+r2.y*10) + 1 * AddPatScale) * float3(Pos.xy - float2(0,0),0)) * max(0,(1-t * 0));
	//通常回転
	//回転行列の作成
	float rad = (r2.z*2-1)*2*3.1415*pow(1-tr,2)*0.5+r2.y*2*3.1415;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	w = mul(w,matRot);

	matRot[0] = float4(cos(-rad),sin(-rad),0,0); 
	matRot[1] = float4(-sin(-rad),cos(-rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
		
	Out.NormalTex =  mul(Tex*2-1,matRot).xy;
	Out.NormalTex = Out.NormalTex*0.5+0.5;
	
	//ビルボード回転
	w = mul(w,inv_view_matrix);
	pos *= (0.1*(1+AddScale));
	
	pos += w;
	pos *= 0.1;
	
	pos = mul(float4(pos, 1),world_matrix);
	pos -=  pow(Grv*t*(morph_Grv*10),2)*(0.1+pow(r.z,4));
	
	Out.Eye = pos - CameraPosition;
	
	Out.Pos = mul(float4(pos, 1), view_proj_matrix);
	Out.color = (1-pow(tr,8))*saturate(tr*r2.x);

	//16種類のテクスチャから選択

	// テクスチャ座標
	Out.Tex = Tex*0.25;
	
	if(index >= ParticleNum) Out.Pos.z = -2;
	
	index %= 16;
	
	int tw = index%4;
	int th = index/4;

	Out.Tex.x += tw*0.25;
	Out.Tex.y += th*0.25;

	Out.sca = 1-r.z;
	
	
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
float4 BombPS(VS_OUTPUT IN) : COLOR {
	float4 col = tex2D(Particle,IN.Tex);
	col.a *= IN.color * DefAlpha * (1-morph_A);
	col.rgb = col.rgb * 2.0 - 1.0;
	col.b = 0;
	float4 normal = tex2D(NormalBase,IN.NormalTex);
	normal.rgb  = normal.rgb * 2 - 1;
	normal.rgb += col.rgb;
	normal.a *= col.a;
	
	float3x3 tangentFrame = compute_tangent_frame(normalize(IN.Eye), normalize(IN.Eye), IN.NormalTex);
	normal.xyz = normalize(mul(normal.xyz, tangentFrame));
	float d = pow(saturate(dot(-LightDirection,-normal.xyz)*0.25+0.75),3);
	
	col = float4(d,d,d,normal.a);
	col.rgb *= LightColor;

	float r = 1;
	r *= morph_B*10;

	float3 AddColor = tex2D(PalletSamp,float2(morph_H,morph_S)).rgb*r;

	col.rgb += AddColor*pow(IN.color,1)*IN.sca*2;

	return col;
}
//合成方法の設定
//
//半透明合成：
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST INVSRCALPHA
//
//加算合成：
//
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST ONE

#define BLENDMODE_SRC SRCALPHA
#define BLENDMODE_DEST INVSRCALPHA

technique NewBomb < string MMDPass = "object"; > {
   pass MainPass
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_3_0 BombVS();
      PixelShader = compile ps_3_0 BombPS();
   }
} 
technique NewBomb_SS < string MMDPass = "object_ss"; > {
   pass MainPass
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_3_0 BombVS();
      PixelShader = compile ps_3_0 BombPS();
   }
}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

