//メイン色設定
float3 MainColor = float3(0.5,0.8,1.7);

int MainIceNum = 16;
int ParticleNum = 32;
int SmokeNum = 128;
int FireNum = 8;
int FlashNum = 1;
int LightNum = 1;

#define CONTROLLER "Ice_ColorController.pmx"

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

texture TexIce<
    string ResourceName = "../Texture/Ice.png";
>;
sampler SampIce = sampler_state {
    texture = <TexIce>;
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
	float addt = Pos.z/ParticleNum;
	addt *= 0.05;
	float t = smoothstep(0.2+addt,0.8+addt,1-Tr);
	
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
	float rady = r_rnd.y*2*3.1415;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	//add.y += r_rnd.z*4+t*5;
	//add.xz *= 2+(0.5+add.y*0.5);
	//add = lerp(add*float3(0.25,1,0.25),add,1-pow(1-t,5));
	add.y += inv_pow(t,16)*3;
	add.y += t*0.5;
	add.y *= r_rnd.z;
	add *= 2;
	Pos.xyz += add*(0.5+r_rnd.x*0.5);//*lerp(len,0,saturate(1-t+r_rnd.z));//(pow(t,r_rnd.z*2)));
    Pos.xyz *= 1;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
    Out.Alpha = 1-pow(1-t,32);
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
float4 IceInit(float4 Pos,int i)
{
	float4 rnd = getRandom(i);
	float4 Out = Pos;
	
	int type = g_index % 4;
	
	Out.z += 7;
	Out.z -= 16*type;
	Out.xyz *= Out.z > 0;
	Out.xyz *= Out.z < 16;
	Out.xyz *= 0.1;
	Out.yz -= 0.75;
	Out.y -= 0.25;
	
	return Out;
}
VS_OUTPUT MainIceFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Pos = IceInit(Pos,g_index);
    Pos.xz *= 0.25;
    Pos.xyz *= 3;
    
	float3 rnd = getRandom(g_index+12.345);
	
	float addt = g_index*0.005;
	float t = smoothstep(0.23+addt,1+addt,1-Tr);

	Pos.y *= inv_pow(t,32);
	if(g_index == 1)
	{
		t = smoothstep(0.15,1,1-Tr);
		Pos.y *= 0.01;
		Pos.xz *= 3;
		Pos.y += 0.1;
		Pos.xz *= inv_pow(t,16);
	}
    if(g_index > 1)
    {
    	Pos.xyz *= 0.5;
    	Pos.y *= 1.25;
    	
    	float rad;
    	float4x4 matRot;
    	
    	rad = rnd.x*1.2;
		matRot[0] = float4(cos(rad),sin(rad),0,0); 
		matRot[1] = float4(-sin(rad),cos(rad),0,0); 
		matRot[2] = float4(0,0,1,0); 
		matRot[3] = float4(0,0,0,1); 
		Pos = mul(Pos,matRot);
    	
    	rad = rnd.y * 2 * 3.1415;
		matRot[0] = float4(cos(rad),0,-sin(rad),0); 
		matRot[1] = float4(0,1,0,0); 
		matRot[2] = float4(sin(rad),0,cos(rad),0); 
		matRot[3] = float4(0,0,0,1); 
		Pos = mul(Pos,matRot);
    }
    if(Pos.y < 0)
    {
    	Pos.y *= 0.05;
    }
	
	float rad = t*4;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),0,-sin(rad),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rad),0,cos(rad),0); 
	matRot[3] = float4(0,0,0,1); 
	Normal = mul(Normal,matRot);
	Normal.y *= 0.5;
	
    Out.Alpha = inv_pow(t,8)*inv_pow(1-Tr,8);
    Out.t = t;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    
    return Out;
}
VS_OUTPUT SmokeFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= SmokeNum;
    addt *= 0.1;
    
	float t = smoothstep(0.2+addt,0.9+addt,1-Tr);
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
	float rady = rnd.y*2*3.1415*64;
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
VS_OUTPUT SmokeFunc2(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= SmokeNum;
    addt *= 0.1;
    
	float t = smoothstep(0.0+addt,0.8+addt,1-Tr);
	Out.t = t;
	
    Out.Alpha = 0.1 * smoothstep(0,0.2,1-Tr);
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
	float rady = rnd.x*3.1415*2+cos(rnd.y*2*3.1415*1235)*t*1;
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
	
	
	add = add*5;
	
	Pos.xyz *= 2+4*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10);
	
	Pos.xyz += add;
    
    Pos.xyz *= 0.25;
    Pos.y += 0.25;
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
    	Out = MainIceFunc(Pos,Normal,Tex);
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
	    Out = SmokeFunc2(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
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
		Col = tex2D(SampIce,IN.Tex);
		Col.rgb *= 1+(pow(saturate(dot(IN.Normal,normalize(IN.Eye))),32)>0.2)*2;
		Col.rgb *= MainColor;
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
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a *= (pow(1-t,2));
		Col.rgb *= 1;
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
	    "Pass=Smoke2;"
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
    pass Smoke2 {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
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
technique MainTec1 < string MMDPass = "object"; string Subset = "3,4";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=MainIceNum;"
		"LoopGetIndex=g_index;"
	    "Pass=MainPass;"
		"LoopEnd=;"
    ;
> {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
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