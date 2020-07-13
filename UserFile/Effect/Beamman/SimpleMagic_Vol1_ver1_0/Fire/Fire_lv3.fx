//メイン色設定
float3 MainColor = float3(2,0.75,0);

#define CONTROLLER "Fire_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;
int ParticleNum = 512;
int SmokeNum = 256;
int FireNum = 64;
int FlashNum = 1;
int LightNum = 1;
int WaveNum = 8;


int index;
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

VS_OUTPUT ParticleFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float t = smoothstep(0,0.25,1-Tr);
	
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
	
	float len = 3+rnd.x*32;
	float3 r_rnd = getRandom(index+123);
	
	//Y軸回転 
	float3 add=float3(1,0,0);;
	float rady = r_rnd.y*2*3.1415;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	rad = r_rnd.x*2*3.1415;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	Pos.xyz += add*lerp(len,0,saturate(t+r_rnd.z));//(pow(t,r_rnd.z*2)));
    Pos.xyz *= 3;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
    Out.Alpha = 1-t;
	Out.Alpha = saturate(lerp(0,Out.Alpha,t*10));
    return Out;
}
VS_OUTPUT FireFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0.2,0.7,1-Tr);
	Out.t = t;
    Out.Alpha = pow(1-t,8);
	float3 r_rnd = getRandom(index+123.4);
    float addt = r_rnd.x*0.1;
    Out.Alpha *= smoothstep(0.3+addt,0.4+addt,1-Tr);
	Pos.x *= 0.25;
	
	Pos.y *= 3*(1-pow(1-smoothstep(0.2,0.7,1-Tr),4));
	
    Pos.z = 0;
    float3 vec = float3(0,1,0);
	//通常回転
	//回転行列の作成
	float rad = (3.1415*2)*r_rnd.x;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	vec = mul(vec,matRot);
	
	//Y軸回転 
	float rady = r_rnd.y*2*3.1415*180.0;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 

	Pos.xyz = mul(Pos.xyz,matRot);
	vec = normalize(mul(vec,matRot));
	
	Pos.xyz *= 32+(r_rnd*5);
	//Pos.xyz *= lerp(2,1,1-pow(1-t,8));

	float3 rnd = getRandom(index);
	float3 add;
	add = vec*r_rnd.z*1;
	Pos.xyz += add*(1-pow(1-t,9))+vec*0.5;
    
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	int Index0 = index;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0.25,0.5,1-Tr);
	Out.t = t;
	//index += ParticleNum;
	
	Pos.z = 0;
	Pos.xyz *= 5+(1-pow(1-t,16))*128;

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
	float t = smoothstep(0,0.25,1-Tr);
	Out.t = t;
	//index += ParticleNum;
	
    Out.Alpha = 1-pow(t,9);
    Pos.z = 0;
	Pos.xyz *= 5+(1-pow(1-t,16))*16;
	
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
	float t = smoothstep(0.25,1,1-Tr);
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
	float3 add=float3(1,0,0);
	float rady = rnd.y*2*3.1415;
	float4x4 matRot;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	rad = rnd.x*2*3.1415;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	add = mul(add,matRot);
	
	add = add*rnd.z*8;
	
	Pos.xyz *= 5*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10);
	
	Pos.xyz += lerp(0,add,(1-pow(1-t,24)));
    Pos.y += 0.5;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= t;

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
    float addt = index;
    addt /= WaveNum;
    addt *= 0.1;
	float t = smoothstep(0.25+addt,0.8+addt,1-Tr);
	
	float3 PosBuf = Pos;
	
	float in_t = 1-pow(1-t,16);
	t = 1-pow(1-t,32);
	float OutSize = t*10;//((PosBuf.x*0.5+0.5)*0.5);
	float InSize = lerp(0,OutSize,in_t);
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
	}
	Pos.y = 0;
	
	float3 rnd = getRandom(index+12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*8;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	float rad = rnd.x*2*3.1415;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos.xyz = mul(Pos.xyz,matRot);
	
	rady = rnd.z*2*3.1415*180.0;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	
	Pos.xyz = mul(Pos.xyz,matRot);
	
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	int Index0 = index;
	
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
	    
		if(FireNum-1 < index)
		{
			Out.Pos.z = -2;
		}
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
		Col = tex2D(SampFire,(IN.Tex*0.5)+IN.AddTex);
		Col.rgb *= 8*MainColor;
		Col.a *= length(Col.rgb);
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
		Col.rgb *= 0.25;
		Col.rgb += MainColor*8*pow(Col.a,4);
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
		Col.rgb *= MainColor*2;
		
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
	    "Pass=Light;"
	    "Pass=Smoke;"
	    "Pass=Fire;"
	    "Pass=Flash;"
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
    pass Flash {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
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
		"LoopGetIndex=index;"
	    "Pass=MainPass;"
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