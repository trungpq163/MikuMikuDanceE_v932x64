
//パーティクル生成数（最大15000)
int ParticleNum = 2000;

//歪み係数
float DistParam = 1.0;

//スペキュラ強さ
float SpecularScale = 5.0;

//スペキュラ強度
float SpecularPow = 8.0;

//テクスチャの回転速度
float RotationSpeed
<
   string UIName = "RotationSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = 1.0;

//良くわかんない人はここから触らない


texture FallGlass_DistRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for GlassBom.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;";
>;
sampler DistortionView = sampler_state {
    texture = <FallGlass_DistRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    FILTER = LINEAR;
};

texture FallGlass_DepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for GlassBom.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    string Format="R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler DepthView = sampler_state {
    texture = <FallGlass_DepthRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    FILTER = LINEAR;
};

float morph_Anm : CONTROLOBJECT < string name = "(self)"; string item = "再生"; >;
float morph_Rot : CONTROLOBJECT < string name = "(self)"; string item = "回転速度"; >;
float morph_Height : CONTROLOBJECT < string name = "(self)"; string item = "幅"; >;
float morph_Width : CONTROLOBJECT < string name = "(self)"; string item = "高さ"; >;
float morph_Scale_p : CONTROLOBJECT < string name = "(self)"; string item = "スケール+"; >;
float morph_Scale_m : CONTROLOBJECT < string name = "(self)"; string item = "スケール-"; >;
float morph_Pat : CONTROLOBJECT < string name = "(self)"; string item = "ﾊﾟｰﾃｨｸﾙSi"; >;
float morph_Grv : CONTROLOBJECT < string name = "(self)"; string item = "重力"; >;
float morph_Air : CONTROLOBJECT < string name = "(self)"; string item = "空気抵抗"; >;
float morph_H : CONTROLOBJECT < string name = "(self)"; string item = "色相"; >;
float morph_S : CONTROLOBJECT < string name = "(self)"; string item = "彩度"; >;
float morph_B : CONTROLOBJECT < string name = "(self)"; string item = "明度"; >;
float morph_A : CONTROLOBJECT < string name = "(self)"; string item = "透明度"; >;
float morph_Spd : CONTROLOBJECT < string name = "(self)"; string item = "初速加算"; >;
float morph_r : CONTROLOBJECT < string name = "(self)"; string item = "角度幅"; >;
float morph_dist : CONTROLOBJECT < string name = "(self)"; string item = "歪み"; >;

static float morph_Scale = morph_Scale_p - morph_Scale_m*0.1;


static float AddHeight = 10*morph_Height;
static float AddWidth = 10*morph_Width;
static float AddScale = 10*morph_Scale;
static float AddPatScale = 50*morph_Pat;

float DefAlpha = 1;

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
float4x4 inv_view_matrix : WORLDVIEWINVERSE;
float4x4 world_matrix : CONTROLOBJECT < string name = "(self)";string item = "センター";>;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   LightColor      : SPECULAR   < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;

float time_0_X : Time;

#define ParticleMax 15000


//パーティクルテクスチャ
texture2D ParticleTex <
    string ResourceName = "particle.png";
>;

sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
	FILTER = LINEAR;
};
texture2D Particle_AddTex <
    string ResourceName = "particle_add.png";
>;

sampler Particle_AddSamp = sampler_state {
    texture = <Particle_AddTex>;
	FILTER = LINEAR;
};
texture2D Particle_NormalTex <
    string ResourceName = "particle_n.png";
>;

sampler Particle_NormalSamp = sampler_state {
    texture = <Particle_NormalTex>;
	FILTER = LINEAR;
};
texture2D Particle_AlphaTex <
    string ResourceName = "particle_d.png";
>;

sampler Particle_AlphaSamp = sampler_state {
    texture = <Particle_AlphaTex>;
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

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float3 Normal	  : TEXCOORD1;
    float4 LastPos : TEXCOORD2;    // 射影変換座標のコピー
    float3 Eye		: TEXCOORD3;	// 視線ベクトル
    float  Alpha      : COLOR0;
};

float3 Grv = float3(0,1,0);
VS_OUTPUT BombVS(float4 Pos: POSITION,float2 Tex: TEXCOORD0,float3 Normal : NORMAL){
	VS_OUTPUT Out = (VS_OUTPUT)0;
	int index = Pos.z;
	Pos.z = 0;
	float fi = index;	fi = fi/ParticleMax;
	float3 r = getRandom(index);
	float3 r2 = getRandom(index+128);
	float t = morph_Anm;
	float tr = 1-morph_Anm;
	float3 pos = 0;

	//初速
	float sca = saturate(r.z+morph_Spd)*100;
	RotationSpeed *= 1-morph_Rot;

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
	
	
    float lo_rot_x = tr * 10 * RotationSpeed + r2.x * 3.1415;
    float lo_rot_y = tr * 10 * RotationSpeed + r2.y * 3.1415;
    float lo_rot_z = tr * 10 * RotationSpeed + r2.z * 3.1415;
	float3x3 lo_RotationX = {
	    {1,	0,	0},
	    {0, cos(lo_rot_x), sin(lo_rot_x)},
	    {0, -sin(lo_rot_x), cos(lo_rot_x)},
	};
	float3x3 lo_RotationY = {
	    {cos(lo_rot_y), 0, -sin(lo_rot_y)},
	    {0, 1, 0},
		{sin(lo_rot_y), 0,cos(lo_rot_y)},
	    };
	float3x3 lo_RotationZ = {
	    {cos(lo_rot_z), sin(lo_rot_z), 0},
	    {-sin(lo_rot_z), cos(lo_rot_z), 0},
	    {0, 0, 1},
	};
        
	float3 w = (1+AddScale)*1*(((1+r2.y*1) + 1 * AddPatScale) * float3(Pos.xy - float2(0,0),0));
    w.xyz = mul( w.xyz, lo_RotationX );
    w.xyz = mul( w.xyz, lo_RotationY );
    w.xyz = mul( w.xyz, lo_RotationZ );
			
	pos *= 0.1*(1+AddScale);
	
	pos = mul(float4(pos, 1),world_matrix);
	
	pos-=pow(Grv*t*(morph_Grv*10),2)*(0.1+pow(r.z,4));

	pos += w;
	

    //回転・サイズ変更

    
    Normal = normalize(Normal);
    Normal = mul( Normal, matRot );
    Normal = mul( Normal, lo_RotationX );
    Normal = mul( Normal, lo_RotationY );
    Normal = mul( Normal, lo_RotationZ );
    Out.Normal = Normal;
	Out.Eye = pos - CameraPosition;
	
	Out.Pos = mul(float4(pos, 1), world_view_proj_matrix);
	Out.LastPos = Out.Pos;
	Out.Alpha = saturate(sin(tr*3.1415)*2);

	//16種類のテクスチャから選択

	// テクスチャ座標
	Out.Tex = Tex*0.25;
	
	if(index >= ParticleNum) Out.Pos.z = -2;
	
	index %= 16;
	
	int tw = index%4;
	int th = index/4;

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
float4 BombPS(VS_OUTPUT IN) : COLOR {

    float4 color = tex2D( ParticleSamp, IN.Tex );
    float4 normal = tex2D( Particle_NormalSamp, IN.Tex );
    float add = tex2D( Particle_AddSamp, IN.Tex ).a;
    float alpha = tex2D( Particle_AlphaSamp, IN.Tex ).a;
	
	normal.rgb = normalize(normal.rgb+IN.Normal);
		
	float2 ScrTex;
	ScrTex.x = (IN.LastPos.x / IN.LastPos.w)*0.5+0.5;
	ScrTex.y = (-IN.LastPos.y / IN.LastPos.w)*0.5+0.5;
	
	float2 AddScr = (-0.5 + normal.xy)*0.05*(DistParam*(1-morph_dist));
	
    float depth = tex2D( DepthView, ScrTex+AddScr ).r;
    depth = saturate(depth - length(IN.Eye));
	AddScr *= depth;
	float4 ret = tex2D(DistortionView,ScrTex+AddScr);

	ret = lerp(ret,color,color.a);
    ret.a *= alpha;
	float r = 1;
	r *= 2+morph_B*10;
	float3 AddColor = tex2D(PalletSamp,float2(morph_H,1-morph_S)).rgb+0.5;
    ret.rgb *= AddColor;
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPow ) * LightSpecular * SpecularScale * AddColor;
	
    ret.rgb *= saturate(dot(normal.rgb,-LightDirection)+1.5)*(LightSpecular+0.5);
    ret.rgb += Specular*(0.5+add)*(1-morph_B);
    ret.a *= 1-morph_A;
    ret.a *= IN.Alpha;
    
    return ret;
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
