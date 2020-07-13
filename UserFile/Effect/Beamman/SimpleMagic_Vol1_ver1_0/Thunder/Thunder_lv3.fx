//メイン色設定
float3 MainColor = float3(0.3,0.75,2);

int ParticleNum = 64;
int LineNum = 32;
int FlashNum = 8;
int WaveNum = 6;

#define CONTROLLER "Thunder_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;


int g_index;
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

//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "../Texture/random256x256.bmp";
>;

texture TexLine<
    string ResourceName = "../Texture/Line.png";
>;
sampler SampLine = sampler_state {
    texture = <TexLine>;
    Filter = ANISOTROPIC;
    MaxAnisotropy = 8;
    AddressU  = WRAP;
    AddressV  = WRAP;
}; 
texture TexParticle<
    string ResourceName = "../Texture/Particle.png";
>;
sampler SampParticle = sampler_state {
    texture = <TexParticle>;
    Filter = ANISOTROPIC;
    MaxAnisotropy = 8;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexThunder<
    string ResourceName = "../Texture/Thunder.png";
>;
sampler SampThunder = sampler_state {
    texture = <TexThunder>;
    Filter = ANISOTROPIC;
    MaxAnisotropy = 8;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
texture TexWave<
    string ResourceName = "../Texture/ShockWave.png";
>;
sampler SampWave = sampler_state {
    texture = <TexWave>;
    Filter = ANISOTROPIC;
    MaxAnisotropy = 8;
    AddressU  = WRAP;
    AddressV  = CLAMP;
};

float Tr : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;
float Si : CONTROLOBJECT < string name = "(self)";string item = "Si";>;



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


struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float t		  : TEXCOORD4;
    float2 AddTex	  : TEXCOORD5;
    float Alpha		  : TEXCOORD6;
	float3 WPos		: TEXCOORD7;
	float4 LastPos	: TEXCOORD8;
};


// 座法変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;
float4x4 ViewProjMatrix    		: VIEWPROJECTION;

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
float4x4 view_trans_matrix : ViewTranspose;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightSpecular + MaterialEmmisive*1);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

float Time : TIME;

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

float inv_pow(float x,float p)
{
	return 1-pow(1-x,p);
}

VS_OUTPUT ParticleFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float l_index = Pos.z*0.01;
	float t = smoothstep(0.0+l_index*0.1,0.6+l_index*0.1,1-Tr);
	Out.t = t;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float3 rnd2 = getRandom(l_index*123456+1234);
	float rad = (rnd2.y)*2*31415;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 0+rnd2.x*5;

	float3 rnd = getRandom(l_index*123456);
	
	float len = rnd.x*5;
	
	//Y軸回転 
	float3 add=float3(1,0,0);
	float rady = rnd.y*2*3.1415;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	Pos.xyz += add*len;
	
	Pos.y += lerp(0,2*rnd.z,t);
	
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex*1;
    Out.AddTex = float2(0.5,0);
    Out.Alpha = t;
    Out.Alpha *= inv_pow(1-t,32);
    //Out.Alpha = inv_pow(1-inv_pow(t,3+rnd.z*10),8);
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	float3 index_rnd = getRandom(g_index*2);
	float at2 = 0.5;
	
	float t = smoothstep(at2+0+index_rnd.y*0.3,at2+0.05+index_rnd.y*0.3,1-Tr);
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;
    
	Pos.z = 0;

    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 512*pow(1-t,2);
	Out.Alpha = t;

	Out.t = t;

	float rady = index_rnd.y*2*3.1415*180.0*12.345;
	float4x4 matRot;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1);
	float3 Add = float3(5,0,0)*(0.5+index_rnd.x*0.5); 
	Add = mul(Add,matRot);
	
	float rad = index_rnd.x*2*3.1415*180.0*12.345;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	Add = mul(Add,matRot);
	
	Add.y = abs(Add.y);
	Add.xz *= 2;
	Pos.xyz += Add;
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT LightFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	float t = smoothstep(0,1,1-Tr);
	
	Pos.z = 0;
	Pos.xyz = Pos.xzy;
	Pos.y += 0.01;
	Pos.xz *= 32+inv_pow(t,32)*16;
	Pos.xz *= 1+smoothstep(0.6,0.65,t)*2;
	Out.Alpha = inv_pow(t,32)*(0.1+(1-smoothstep(0.66,0.7,t))*0.9);
	Out.Alpha *= 1-smoothstep(0.65,1,pow(t,8));
	Out.t = t;

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT WaveFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

	float t = smoothstep(0.55+g_index*0.01,0.65+g_index*0.01,1-Tr);
	Out.t = t;
	
	
	float3 PosBuf = Pos;
	
	float in_t = 1-pow(1-t,16);
	float OutSize = 1+t*8;
	float InSize = OutSize;
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
		Pos.y = 8*pow(1-t,4)+0.01;
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
		Pos.y = 0.0+0.01;
	}
	
	float3 rnd = getRandom(g_index+12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*1;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	rady = 2*3.1415*180.0*12.345;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	Pos.xyz *= 2;
	Pos.y *= 0.5;
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Tex.x = 1-Out.Tex.x;
	int Index0 = g_index;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
	Out.Alpha = inv_pow(t,32);
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}

VS_OUTPUT WaveFunc2(float4 Pos,float3 Normal,float2 Tex)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
    
    float add = 0.285;
    float t = smoothstep(0.25+add,0.8+add,1-Tr);
	
	float3 PosBuf = Pos;
	
	float in_t = 1-pow(1-t,8);
	t = 1-pow(1-t,16);
	float OutSize = t*15;//((PosBuf.x*0.5+0.5)*0.5);
	float InSize = lerp(0,OutSize,in_t);
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
	}
	Pos.y = 0.01;
	
	float3 rnd = getRandom(12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*8;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	int Index0 = 0;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
	Out.Alpha = 1;
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}

VS_OUTPUT LineFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 index_rnd = getRandom(g_index*2);
	float t = smoothstep(0.8+index_rnd.y*0.02,0.99+index_rnd.y*0.02,1-Tr);
	Out.t = t;
    
    float3 PosBuf = Pos;
    
	float3 rnd_pos = getRandom(g_index*123.4567+PosBuf.z*10000);
	float3 rnd_pos_n = getRandom(g_index*123.4567+PosBuf.z*10000+0.0001);
	
	float3 rnd = getRandom(g_index*123.456+123.456+PosBuf.z*10000);
	
	rnd_pos = 0;
	rnd_pos_n = 0;
	
    float3 Center = -0.5+rnd_pos;
    float3 NextCenter = -0.5+rnd_pos_n;
    
	float4x4 matRot;
	float rady = Center.y*2*3.1415*180.0;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	float3 CenterPos = float3(0,0,1);
	CenterPos = mul(CenterPos,matRot);
	
	rady = NextCenter.y*2*3.1415*180.0;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	
	float3 NextCenterPos = float3(0,0,1);
	NextCenterPos = mul(NextCenterPos,matRot);
	
	float scale = PosBuf.z*256;
	

	CenterPos *= Center.x * scale;
	CenterPos.y += PosBuf.z * 2000 * (0.25+index_rnd.z*0.75);
	NextCenterPos *= NextCenter.x * scale;
	NextCenterPos.y += (PosBuf.z+0.0001) * 2000 * (0.25+index_rnd.z*0.75);
	
	float mt = inv_pow(1-Tr,2)*0;
	Center.y = abs(Center.y)*2;
	NextCenter.y = abs(NextCenter.y)*2;
	
	//Center.xz *= 5;
	//NextCenter.xz *= 5;
	
	CenterPos.xyz += normalize(Center)*mt;
	NextCenterPos.xyz += normalize(NextCenter)*mt;
	
	index_rnd.x = index_rnd.x;

	float rad = index_rnd.x*2*3.1415;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	
	
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos.xyz = mul(NextCenterPos,matRot);
	
    Out.Alpha = inv_pow(1-saturate(PosBuf.z*256),32);
    Out.Alpha *= 1-saturate(inv_pow(t,4) > saturate(PosBuf.z*256+index_rnd.z*0.2));
	Out.Alpha *= inv_pow(1-t,4);
	Out.Alpha *= inv_pow(t,16);

	
    CenterPos.xyz *= 2;
    NextCenterPos.xyz *= 2;
    
	
	CenterPos.xyz = CenterPos.xzy;    
	NextCenterPos.xyz = NextCenterPos.xzy;
	
	CenterPos.y = 0.1;
	NextCenterPos.y = 0.1;
	
	
    
    
	CenterPos = mul(CenterPos,WorldMatrix);
	NextCenterPos = mul(NextCenterPos,WorldMatrix);
	CenterPos += WorldMatrix[3].xyz;
	NextCenterPos += WorldMatrix[3].xyz;
    
    
    float3 V = normalize(CenterPos - NextCenterPos);
    float3 E = normalize(CameraPosition - CenterPos);
	float3 side = normalize(cross(E,V))*1.5*10*length(WorldMatrix[1])*0.05;

    Pos.xyz = CenterPos.xyz;
    
	if(PosBuf.x > 0)
	{
		Pos.xyz += side;
	}else{
		Pos.xyz -= side;
	}
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	Out.Tex.y += index_rnd.x*32;
    Out.Tex.y *= 200; 
	int Index0 = g_index;
	Out.AddTex.y = 0.25*3;
    
    Out.WPos = Pos;
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SphereLineFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 index_rnd = getRandom(g_index*512);
	float t = smoothstep(0.65+index_rnd.y*0.1,0.75+index_rnd.y*0.1,1-Tr);
	Out.t = t;
    
    float3 PosBuf = Pos;
    
	float3 rnd_pos = 0;//getRandom(g_index*123.4567+PosBuf.z*10000);
	float3 rnd_pos_n = 0;//getRandom(g_index*123.4567+PosBuf.z*10000+0.0001);
	
	float3 rnd = getRandom(g_index*123.456+123.456+PosBuf.z*10000);
	
    float3 Center = 1;
    float3 NextCenter = 1;
    
	float3 CenterPos = float3(0,0,1);	
	float3 NextCenterPos = float3(0,0,1);
	
	float scale = 0;
	

	CenterPos *= Center.x * scale;
	CenterPos.x += 2+inv_pow(t,2);
	
	NextCenterPos *= NextCenter.x * scale;
	NextCenterPos.x += 2+inv_pow(t,2);

	float4x4 matRot;

	float rad;
	
	rad = PosBuf.z*1+t*0.1;
	rad *= PosBuf.z+1;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	
	CenterPos = mul(CenterPos,matRot);
	
	rad = (PosBuf.z+0.0001)*1+t*0.1;
	rad *= (PosBuf.z+0.0001)+1;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	
	NextCenterPos = mul(NextCenterPos,matRot);
	
	float rady = index_rnd.y*2*3.1415;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos.xyz = mul(NextCenterPos,matRot);

	
	rad = index_rnd.z*2*3.1415;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos.xyz = mul(NextCenterPos,matRot);
	
	index_rnd.x = index_rnd.x;

	//CenterPos.xyz = mul(CenterPos.xyz,matRot);
	//NextCenterPos.xyz = mul(NextCenterPos,matRot);
	
	
	Out.Alpha = inv_pow(t,16);
	Out.Alpha *= inv_pow(1-t,4);
	
	CenterPos.xyz *= 1.5;
	NextCenterPos *= 1.5;
	
	CenterPos = mul(CenterPos,WorldMatrix);
	NextCenterPos = mul(NextCenterPos,WorldMatrix);
    
	CenterPos += WorldMatrix[3].xyz;
	NextCenterPos += WorldMatrix[3].xyz;
	
    float3 V = normalize(CenterPos - NextCenterPos);
    float3 E = normalize(CameraPosition - CenterPos);
	float3 side = normalize(cross(E,V))*1.5*10*length(WorldMatrix[1])*0.05;

    Pos.xyz = CenterPos.xyz;
	if(PosBuf.x > 0)
	{
		Pos.xyz += side;
	}else{
		Pos.xyz -= side;
	}
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Tex.y *= 2;
	int Index0 = g_index;
	Out.AddTex.y = 0.25*2;
    
    Out.WPos = Pos;
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SphereFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = 1-Tr;
	t = smoothstep(0.55,0.9,t);
	Out.t = t;
	Pos.xyz *= 0.75;
	Pos.xyz *= smoothstep(0,0.2,inv_pow(t,2))*3;
	Pos.xyz *= 1 + t*0.5;
	Pos.xyz *= (1+smoothstep(0.8,0.9,t)*5);
	Pos.xyz *= 1.5;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha = t>0;
    return Out;
}
VS_OUTPUT MainThunderFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Pos.xyz = Pos.xzy;
	float t = smoothstep(0.0,0.7,1-Tr);
	Out.t = t;
	
	//ローカル座標を0点に初期化
	Out.Pos = float4(0,0,0,1);
	float3 AddPos = float3(0,0,0);
	
	//ワールド座標
	float3 world_pos = WorldMatrix[3].xyz;

	

	//ワールドの進行ベクトル
	float3 vec = normalize(WorldMatrix[1].xyz);

	//カメラの位置
	float3 eyepos = view_trans_matrix[3].xyz;

	//カメラからのベクトル
	float3 eyevec = view_trans_matrix[2].xyz;//normalize(world_pos - eyepos);

	//進行ベクトルとカメラベクトルの外積で横方向を得る
	float3 side = normalize(cross(vec,eyevec))*3;

	side *= lerp(pow(1-t,8)+0.01,1,t>0.90);
	
	//横幅に合わせて拡大
	side *= 10;
	
	float len = 150;
	
	side *= Si*0.1;
	len *= Si*0.1;
	
	//入力座標のX値でローカルな左右判定
	if(Pos.x > 0)
	{
	    //左側
	    Out.Pos += float4(side,0);
	}else{
	    //右側
	    Out.Pos -= float4(side,0);
	}

	//長さに合わせて進行ベクトルを伸ばす

	//ローカルのZ値が＋の場合、進行ベクトルを加える
	if(Pos.z > 0)
	{
	    Out.Pos += float4(vec*len,0);
	}
	Out.Pos += float4(world_pos,0);
	
	Pos = Out.Pos;
	
	AddPos = mul(AddPos,WorldMatrix);
	Pos.xyz += AddPos/Si;
	
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
    Out.WPos = Pos;
    Out.LastPos = Out.Pos;
    
    Out.Alpha = inv_pow(1-t,16);
    Out.Alpha *= inv_pow(t,8);
    return Out;
}
// 頂点シェーダ
VS_OUTPUT Main_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,uniform int mode)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    int index = Pos.z+0.1;
    Out.Alpha = 1.0;
   
    if(mode == 0)
	{
	    Out = ParticleFunc(index,Pos,Normal,Tex);
	    
		if(ParticleNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 1)
	{
	    Out = FlashFunc(index,Pos,Normal,Tex);
	    
		if(FlashNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 2)
	{
	    Out = LineFunc(Pos,Normal,Tex);
    }
    if(mode == 5)
	{
	    Out = SphereLineFunc(Pos,Normal,Tex);
    }
    if(mode == 3)
	{
	    Out = WaveFunc(Pos,Normal,Tex);
    }
    if(mode == 4)
	{
	    Out = SphereFunc(Pos,Normal,Tex);
    }
    if(mode == 6)
	{
	    Out = MainThunderFunc(Pos,Normal,Tex);
		if(0 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 7)
	{
	    Out = LightFunc(Pos,Normal,Tex);
		if(0 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 9)
	{
	    Out = WaveFunc2(Pos,Normal,Tex);
    }
	return Out;
}

// ピクセルシェーダ
float4 Main_PS(VS_OUTPUT IN,uniform int mode) : COLOR0
{
	float t = IN.t;
	float4 Col = 1;	
	
	if(bController)
	{
		MainColor.rgb = float3(morph_r,morph_g,morph_b)*(1+morph_add_si);
	}	
	
	if(mode == 0)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.rgb *= MainColor*5;
	}
	if(mode == 7)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);

		Col.rgb *= MainColor;
	}
	if(mode == 1)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+float2(0.5,0.0));
		Col.rgb *= MainColor;
	}
	if(mode == 2)
	{
		IN.Tex.xy = IN.Tex.yx;
		float4 ColA = tex2D(SampLine,(IN.Tex*float2(1,0.25))+IN.AddTex);
		ColA.a *= 0.25;
		IN.AddTex.y = 0.25*1;
		float4 ColB = tex2D(SampLine,(IN.Tex*float2(1,0.25))+float2(0,0.25*2));
		
		Col = ColB;
		Col.a *= Col.r;
		Col.a = saturate(Col.a);
		Col.rgb *= MainColor;
	}
	if(mode == 5)
	{
		IN.Tex.xy = IN.Tex.yx;
		Col = tex2D(SampLine,(IN.Tex*float2(1,0.25))+IN.AddTex);
		Col.rgb *= Col.a;
		Col.rgb *= MainColor;
	}
	if(mode == 3)
	{
		Col = tex2D(SampWave,IN.Tex.yx);
		Col.a = Col.r;
	}
	if(mode == 4)
	{
		Col = 1;
		
		float d = abs(dot(normalize(IN.Eye),normalize(IN.Normal)));
		
		
		Col.rgb *= 1-inv_pow(saturate(d),2);
		Col.rgb *= 1-smoothstep(0.9,1,inv_pow(t,2));
		
		Col.rgb += pow(d,(0.25+abs(cos(t*128))*0.75)*16)*(1+smoothstep(0.9,1,inv_pow(t,2))*32);

		
		Col.rgb *= MainColor;
		Col.a *= 1-smoothstep(0.9,1,inv_pow(t,2));
	}
	if(mode == 6)
	{
		if(t<=0.90)
		{
			IN.Tex = IN.Tex.yx*float2(1,0.25);
			IN.Tex.x = 0;
			Col = tex2D(SampLine,IN.Tex);
			Col.rgb *= MainColor*(1+t);
		}else{
			Col = tex2D(SampThunder,IN.Tex);
			float a = Col.b;
			Col.rgb = Col.g;
			Col.rgb *= MainColor*16;
			IN.Alpha -= a*0.5;
		}
	}
	if(mode == 8)
	{
		if(t>0.90)
		{
			Col = tex2D(SampThunder,IN.Tex);
			//float a = pow(Col.b,1);
			//IN.Alpha -= a;
			Col.r *= smoothstep(0.91,1,t);
			
			Col.rgb = Col.r;
			Col.a = Col.r*32;
			Col.rgb *= 1*8;
			IN.Alpha *= 1-smoothstep(0.9,0.98,t);
		}else{
			IN.Alpha = 0;
		}
	}
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
	Col.a *= inv_pow(Tr,32);
	/*
	if(use_spe)
	{
		float2 ScTex = IN.LastPos.xyz/IN.LastPos.w;
		ScTex.y *= -1;
		ScTex.xy += 1;
		ScTex.xy *= 0.5;
		
	    // 深度
	    float dep = length(CameraPosition - IN.WPos);
	    float scrdep = tex2D(SPE_DepthSamp,ScTex).r;
	    
	    float adddep = 1-saturate(length(abs(frac(IN.Tex*4)-0.5)));
	    dep = length(dep-scrdep);
	    dep = smoothstep(0,10,dep);
	    //return float4(dep,0,0,1);
	    Col.a *= dep;
    }
    */
    Col.a *= 1-morph_a;
	
    return Col;
}

float4 Clear_VS() : POSITION
{
	return float4(0,0,0,0);
}

float4 Clear_PS() : COLOR0
{
    return 0;
}

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0"; 
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Light;"
	    
	    "Pass=MainThunder;"
	    "Pass=InvMainThunder;"
		"LoopByCount=FlashNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Flash;"
		"LoopEnd=;"
	    "Pass=Paritcle;"
    ;
> {
    pass Light {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(7);
        PixelShader  = compile ps_3_0 Main_PS(7);
    }
    pass MainThunder {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(6);
        PixelShader  = compile ps_3_0 Main_PS(6);
    }
    pass InvMainThunder {
    	BLENDOP = REVSUBTRACT;
    	SRCBLEND = ZERO | SRCALPHA;
    	DESTBLEND = INVSRCCOLOR | INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(6);
        PixelShader  = compile ps_3_0 Main_PS(8);
    }
    pass Paritcle {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
    }
    pass Flash {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
}
technique MainTec1 < string MMDPass = "object"; string Subset = "1";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=LineNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Line;"
	    "Pass=SphereLine;"
		"LoopEnd=;"
		
		"LoopByCount=WaveNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Wave;"
		"LoopEnd=;"
	    "Pass=Wave2;"
    ;
> {
    pass Line {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(2);
        PixelShader  = compile ps_3_0 Main_PS(2);
    }
    pass SphereLine {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
    }
    pass Wave {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	//DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(3);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
    pass Wave2 {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	//DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(9);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "2"; > {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	//DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(4);
        PixelShader  = compile ps_3_0 Main_PS(4);
    }
}
technique MainTecBS0  < string MMDPass = "object_ss";> {
    pass MainPass {
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}