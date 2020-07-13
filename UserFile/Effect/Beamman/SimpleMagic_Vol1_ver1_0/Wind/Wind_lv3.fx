//メイン色設定
float3 MainColor = float3(0.5,0.5,0.5);

int ParticleNum = 512;
int SmokeNum = 1024;
int FireNum = 8;
int FlashNum = 1;
int LightNum = 1;
int WaveNum = 128;

#define CONTROLLER "Wind_ColorController.pmx"

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

texture TexFire<
    string ResourceName = "../Texture/Fire.png";
>;
sampler SampFire = sampler_state {
    texture = <TexFire>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexParticle<
    string ResourceName = "../Texture/Particle.png";
>;
sampler SampParticle = sampler_state {
    texture = <TexParticle>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexSmoke<
    string ResourceName = "../Texture/Smoke.png";
>;
sampler SampSmoke = sampler_state {
    texture = <TexSmoke>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexGaus<
    string ResourceName = "../Texture/gausian.png";
>;
sampler SampGause = sampler_state {
    texture = <TexGaus>;
    FILTER = LINEAR;
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

float4 getGause(float rindex,float scale)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    tpos.x *= scale;
    return tex2Dlod(SampGause, float4(tpos,0,1));
}
float4 getGause(float rindex)
{
    return getGause(rindex,1);
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
	float addt = Pos.z/ParticleNum;
	addt *= 0.75;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);
	
    VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.t = t;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	//Pos.xyz = mul(Pos.xyz,matRot);

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	float3 rnd2 = getRandom(index+123);
	Pos.xyz *= 2+rnd2.x*5;

	float3 rnd = getRandom(index);
	
	float len = rnd.x*8;
	float3 r_rnd = getRandom(index+123);
	
	//Y軸回転 
	float3 add=float3(1,0,0);
	float rady = r_rnd.y*2*3.1415-Tr*r_rnd.z*32;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	add.y += r_rnd.z*4+t*5;
	add.xz *= 2+(0.5+add.y*0.5);
	add = lerp(add*float3(0.25,1,0.25),add,1-pow(1-t,5));
	Pos.xyz += add*(0.5+r_rnd.x*0.5);//*lerp(len,0,saturate(1-t+r_rnd.z));//(pow(t,r_rnd.z*2)));
    Pos.xyz *= 1;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
    Out.Alpha = 1-pow(1-t,32);
    return Out;
}
VS_OUTPUT FireFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 index_rnd = getGause(g_index*1234567.456);
	float t = smoothstep(0.01,0.7,1-Tr);
	Out.t = t;
	Out.Alpha = inv_pow(t,64);
	
    
    float3 PosBuf = Pos;
    
	//float3 rnd_pos = getGause(g_index*123.4567+PosBuf.z-Time*200,1);
	//float3 rnd_pos_n = getGause(g_index*123.4567+PosBuf.z+0.0001-Time*200,1);
	//float3 rnd_pos = float3(0,PosBuf.z,PosBuf.z);//tex2Dlod(SampGause, float4(float2((PosBuf.z)*0.3,0),0,1));
	//float3 rnd_pos_n = float3(0,PosBuf.z+0.001,PosBuf.z+0.001);//tex2Dlod(SampGause, float4(float2((PosBuf.z+0.001)*0.3,0),0,1));

	float3 rnd_pos = tex2Dlod(SampGause, float4(float2((PosBuf.z)*2+Tr*2,index_rnd.z),0,1));
	float3 rnd_pos_n = tex2Dlod(SampGause, float4(float2((PosBuf.z+0.0001)*2+Tr*2,index_rnd.z),0,1));
	
	
	float3 rnd = getGause(g_index*123.456+123.456+PosBuf.z*10000);
	
    float3 Center = (rnd_pos-0.5)*5 * pow(PosBuf.z,1);
    float3 NextCenter = (rnd_pos_n-0.5)*5 * pow(PosBuf.z+0.0001,1);
    Center.y = 0;
    NextCenter.y = 0;
    
    
	float3 CenterPos =Center;
	float3 NextCenterPos = NextCenter;
	
	float scale = 1;
	

	CenterPos.y += PosBuf.z*lerp(0,15,inv_pow(t,16));
	NextCenterPos.y += (PosBuf.z+0.0001)*lerp(0,15,inv_pow(t,16));
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;

	float4x4 matRot;
	float rad = -0.5;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos = mul(NextCenterPos,matRot);
	
    CenterPos.x += 0.5;
    NextCenterPos.x += 0.5;
    
	float rady = index_rnd.y*2*3.1415*180.0*12.345+(t*8+2)*PosBuf.z;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos = mul(NextCenterPos,matRot);

	

	Out.Alpha *= inv_pow(1-t,4);
    
	
	CenterPos = mul(CenterPos,WorldMatrix);
	NextCenterPos = mul(NextCenterPos,WorldMatrix);
    
	CenterPos += WorldMatrix[3].xyz;
	NextCenterPos += WorldMatrix[3].xyz;
	
    
    
    float3 V = normalize(NextCenterPos - CenterPos);
    float3 E = normalize(CameraPosition - CenterPos);
    float3 side = normalize(cross(E,V))*length(WorldMatrix[1])*0.5*1;

	//Pos.xyz = 0;
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
	

    
    Out.WPos = Pos;
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0,0.5,1-Tr);
	Out.t = t;
	//index += ParticleNum;
	
	Pos.z = 0;
	Pos.xyz *= 5+(1-pow(1-t,16))*128;

    Pos.xyz *= 0.25;
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    Out.Alpha = 1-pow(t,9);
    return Out;
}
VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0,0.9,1-Tr);
	Out.t = t;
	//index += ParticleNum;
	
    Out.Alpha = 1;
    Pos.z = 0;
	Pos.xyz *= (0.5+(1-pow(1-t,16))*0.5)*10;
	
	float t2 = smoothstep(0,0.001,1-pow(1-t,6));
	Pos.xyz *= lerp(10,1,t2);
	float t3 = smoothstep(0.9,0.95,t);
	Pos.xyz *= 1-t3;
	
	Out.Alpha *= t2;
	
    Pos.xyz *= 1+cos(t*12345.678)*0.2;
	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SmokeFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= SmokeNum;
    addt *= 0.5;
    
	float t = smoothstep(0+addt,0.5+addt,1-Tr);
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	float3 rnd = getRandom(index+12.345);
	Pos.xyz *= 5+5*rnd.z;

	//Y軸回転 
	float3 add=float3(1+cos(rnd.y)*0.25,0,0);
	float rady = rnd.y*2*3.1415+(1-pow(1-t,8))*(0.2+abs(cos(rnd.x*2*3.1415))*0.8);
	float4x4 matRot;
	rad = cos(rnd.x*100)*2*3.1415*0.025;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	add = mul(add,matRot);
	
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	
	add = add*10+rnd.z*2;
	
	Pos.xyz *= 2+4*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10);
	
	Pos.xyz += lerp(0,add,(1-pow(1-t,24)));
    
    Pos.xyz *= 0.25;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= 1-pow(1-t,16);

	int Index0 = index;
	
	Index0 %= 16;
	int tw = Index0%4;
	int th = Index0/4;

	Out.AddTex.x += tw*0.25;
	Out.AddTex.y += th*0.25;
	
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT WaveFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = g_index;
    addt /= WaveNum;
    addt *= 0.2;
	//float t = smoothstep(0.025+addt,0.6+addt,1-Tr);
	float t = 1-Tr;
	
	float3 PosBuf = Pos;
	
	float3 rnd = getRandom(g_index+12.345);
	float3 rnd2 = getRandom(g_index+56.789);
	//t = 1-pow(1-t,32);
	float OutSize = (rnd2.x*0.25+0.75)*5;//((PosBuf.x*0.5+0.5)*0.5);
	//OutSize += (1-pow(1-smoothstep(0.8,1,t),4))*16*rnd2.z;
	float Height = 0;
	OutSize *= 0.5+pow(rnd2.y,2)*2;
	float test = 0.5;
	//OutSize += inv_pow(smoothstep(0.6+rnd.x*0.1,1+rnd.x*0.1,t),4)*32;
	
	
	float InSize = OutSize;
	
	
	
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
		Pos.y = 1.0;
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
		Pos.y = -1;
	}
	
	Pos.y *= (1-pow(1-t,8))*3*(pow(1-smoothstep(0.8,0.9,t),1));
	Pos.y *= 1-smoothstep(0.5,1,t);
	Pos.y *= rnd.z;
	//Pos.y *= 1-inv_pow(smoothstep(0.6+rnd.x*0.05,0.8+rnd.x*0.05,t),4);
	
	float r = rnd2.x*2*3.1415+t*2*3.1415;
	Pos.x += cos(r)*rnd2.z*OutSize*0.5;
	Pos.z += sin(r)*rnd2.z*OutSize*0.5;
	
	
	Pos.y += Height+rnd2.y*inv_pow(t,8)*32;
	
	//Y軸回転 
	float4x4 matRot;
	float rad = rnd.x*0.1;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos.xyz = mul(Pos.xyz,matRot);
	
	float rady = rnd.y*2*3.1415*180.0+t*16+inv_pow(t,4)*16;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	
	
    Pos.xyz *= 0.25;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	int Index0 = g_index;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
	Out.Alpha = inv_pow(1-t,8);
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
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
	    Out = FireFunc(index,Pos,Normal,Tex);
    }
    if(mode == 2)
    {
	    Out = FlashFunc(index,Pos,Normal,Tex);
	    
		if(FlashNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 3)
    {
	    Out = SmokeFunc(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 4)
	{
	    Out = LightFunc(index,Pos,Normal,Tex);
	    
		if(LightNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 5)
	{
	    Out = WaveFunc(Pos,Normal,Tex);
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
		Col = tex2D(SampParticle,(IN.Tex*0.5)+float2(0.5,0.0));
		Col.a *= (pow(1-t,4));
		Col.rgb *= MainColor*8;
	}
	if(mode == 1)
	{
		Col = tex2D(SampFire,(IN.Tex*0.5*float2(1,0.5)+float2(0.5,0.5))+IN.AddTex);
		Col.rgb *= 1;
		Col.a *= pow(length(Col.rgb),8)*0.25;
	}
	if(mode == 2)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a *= (pow(1-t,3));
		Col.rgb *= MainColor;
	}
	if(mode == 3)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a *= (pow(1-t,2));
		Col.rgb *= 1;
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a *= (pow(1-t,4));
		Col.rgb *= MainColor*8;
	}
	if(mode == 5)
	{
		Col = tex2D(SampFire,(IN.Tex*0.5)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb *= MainColor*4;
		
	}
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
	
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
    Col.a *= Tr;
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
	    "Pass=Paritcle;"
	    //"Pass=Light;"
	    "Pass=Smoke;"
	    //"Pass=Flash;"
    ;
> {
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
    	ZENABLE = FALSE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(2);
        PixelShader  = compile ps_3_0 Main_PS(2);
    }
    pass Smoke {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(3);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
    pass Light {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(4);
        PixelShader  = compile ps_3_0 Main_PS(4);
    }
}
technique MainTec1 < string MMDPass = "object"; string Subset = "1";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=WaveNum;"
		"LoopGetIndex=g_index;"
	    "Pass=MainPass;"
		"LoopEnd=;"
		
		"LoopByCount=FireNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Fire;"
		"LoopEnd=;"
    ;
> {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
    }
    pass Fire {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "2"; > {
    pass MainPass {
        VertexShader = compile vs_3_0 Clear_VS();
        PixelShader  = compile ps_3_0 Clear_PS();
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