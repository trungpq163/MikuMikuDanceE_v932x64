//メイン色設定
float3 MainColor = float3(0,0.75,2);

int ParticleNum = 64;
int LineNum = 28;
int FlashNum = 1;
int WaveNum = 1;

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
texture TexWave<
    string ResourceName = "../Texture/ShockWave.png";
>;
sampler SampWave = sampler_state {
    texture = <TexWave>;
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
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 index_rnd = getRandom(g_index*2);
	float at2 = -0.25;
	float t = smoothstep(at2+0.3+index_rnd.y*0.5,at2+0.5+index_rnd.y*0.5,1-Tr);
	Out.t = t;
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;
		
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
	
	float len = rnd.x*2;
	float3 r_rnd = getRandom(index+123);
	
	//Y軸回転 
	float3 add=float3(1,0,0);;
	float rady = index_rnd.z+r_rnd.y*2*3.1415;
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
	Pos.xyz *= 0.5;
	Pos.xyz += add*lerp(0,len,inv_pow(t,8));//(pow(t,r_rnd.z*2)));
    Pos.xyz *= 3;
    
	rady = index_rnd.y*2*3.1415*180.0*12.345;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	float3 Add = float3(50,0,0)*index_rnd.x; 
	Add = mul(Add,matRot);
	Pos.xyz += Add;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
    Out.Alpha = inv_pow(1-inv_pow(t,3+rnd.z*10),8);
    Out.Alpha *= smoothstep(0,0.1,t);
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	float3 index_rnd = getRandom(g_index*2);
	float at2 = -0.19;
	
	float t0 = smoothstep(0.22+at2+index_rnd.y*0.5,0.25+at2+index_rnd.y*0.5,1-Tr);
	float t = smoothstep(0.25+at2+index_rnd.y*0.5,0.3+at2+index_rnd.y*0.5,1-Tr);
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;
    
	Pos.z = 0;

	
	if(t0 < 1.0)
	{
	    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
		Pos.xyz *= 512;
		Out.Alpha = t0;
	}else{
		Pos.xyz = Pos.xzy;
		Pos.xyz *= 128+(1-pow(1-t,16))*128+t*128;
		Pos.y += 0.01;
		Out.Alpha = (1-pow(t,9))*0.5;
    }
	Out.t = t;

	float rady = index_rnd.y*2*3.1415*180.0*12.345;
	float4x4 matRot;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1);
	float3 Add = float3(50,0,0)*index_rnd.x; 
	Add = mul(Add,matRot);
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
VS_OUTPUT WaveFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

	float3 index_rnd = getRandom(g_index*2);
	float at2 = 0.04;
	float t = smoothstep(at2+0+index_rnd.y*0.5,at2+0.4+index_rnd.y*0.5,1-Tr);
	Out.t = t;
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;
	
	
	float3 PosBuf = Pos;
	
	float in_t = 1-pow(1-t,16);
	t = 1-pow(1-t,32);
	float OutSize = t*3;//((PosBuf.x*0.5+0.5)*0.5);
	float InSize = lerp(0,OutSize,in_t);
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
	}
	Pos.y = 0.03;
	
	float3 rnd = getRandom(g_index+12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*2;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	rady = index_rnd.y*2*3.1415*180.0*12.345;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz += float3(50,0,0)*index_rnd.x;
	Pos.xyz = mul(Pos.xyz,matRot);
	
	
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
    
	Out.Alpha = 1;
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT LineFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 index_rnd = getRandom(g_index*2);
	float t = smoothstep(0+index_rnd.y*0.5,0.2+index_rnd.y*0.5,1-Tr);
	Out.t = t;
    
    float3 PosBuf = Pos;
    
	float3 rnd_pos = getRandom(g_index*123.4567+PosBuf.z*10000);
	float3 rnd_pos_n = getRandom(g_index*123.4567+PosBuf.z*10000+0.0001);
	
	float3 rnd = getRandom(g_index*123.456+123.456+PosBuf.z*10000);
	
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
	CenterPos.y += PosBuf.z * 2000;
	NextCenterPos *= NextCenter.x * scale;
	NextCenterPos.y += (PosBuf.z+0.0001) * 2000;
	
	float mt = inv_pow(1-Tr,2)*0.5;
	Center.y = 1.0;//abs(Center.y)*2;
	NextCenter.y = 1.0;//abs(NextCenter.y)*2;

	CenterPos.xyz += normalize(Center)*mt;
	NextCenterPos.xyz += normalize(NextCenter)*mt;
	
	
	
	index_rnd.x = index_rnd.x * 2 - 1;
	index_rnd.x = index_rnd.x * 0.05;

	float rad = index_rnd.x*2*3.1415;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos.xyz = mul(NextCenterPos,matRot);

	CenterPos.xyz += float3(50,0,0)*index_rnd.x;
	NextCenterPos.xyz += float3(50,0,0)*index_rnd.x;
	
	rady = index_rnd.y*2*3.1415*180.0*12.345;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	CenterPos.xyz = mul(CenterPos.xyz,matRot);
	NextCenterPos = mul(NextCenterPos,matRot);

	

    Out.Alpha = inv_pow(1-saturate(CenterPos.y*0.15),32);
    Out.Alpha *= saturate(inv_pow(t,16) > 1-saturate(CenterPos.y*0.15+index_rnd.z*0.2));
	Out.Alpha *= inv_pow(1-t,4);
    
	
	CenterPos = mul(CenterPos,WorldMatrix);
	NextCenterPos = mul(NextCenterPos,WorldMatrix);
    
	CenterPos += WorldMatrix[3].xyz;
	NextCenterPos += WorldMatrix[3].xyz;
	
    
    
    float3 V = normalize(CenterPos - NextCenterPos);
    float3 E = normalize(CameraPosition - CenterPos);
	float3 side = normalize(cross(E,V))*1.5*(1-t)*10*length(WorldMatrix[1])*0.1;

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
    Out.Tex.y *= 200; 
	Out.Tex.y -= 0.1;
	//Out.Tex.y += index_rnd.x;
	int Index0 = g_index;
	Out.AddTex.y = 0.25*3;
    
    Out.WPos = Pos;
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SphereFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = 1-Tr;
	t = smoothstep(0,0.75,t);
	Out.t = t;
	Pos.xyz *= 0.5;
	Pos.xyz *= smoothstep(0,0.1,inv_pow(t,8))*2;
	Pos.xyz *= 1+(1-t)*0.1;
	Pos.xyz *= 1+smoothstep(0.9,1,inv_pow(t,2));
	
	Pos.y += 6.8;
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha = 1;
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
    if(mode == 3)
	{
	    Out = WaveFunc(Pos,Normal,Tex);
    }
    if(mode == 4)
	{
	    Out = SphereFunc(Pos,Normal,Tex);
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
		float4 ColB = tex2D(SampLine,(IN.Tex*float2(1,0.25))+IN.AddTex);
		
		Col = ColA+ColB;
		Col.a = saturate(Col.a);
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
	    
		"LoopByCount=LineNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Paritcle;"
	    "Pass=Flash;"
		"LoopEnd=;"
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
		"LoopEnd=;"
		
		"LoopByCount=LineNum;"
		"LoopGetIndex=g_index;"
	    "Pass=Wave;"
		"LoopEnd=;"
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
}
technique MainTec2 < string MMDPass = "object"; string Subset = "2"; > {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	//DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
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