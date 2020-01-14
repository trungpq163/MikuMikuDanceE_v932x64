float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

#define MAX			5

int index = 0;    //ループ変数
int count = MAX; //複製数

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float4x4 wvp : WorldViewProjection;
float morph_Move : CONTROLOBJECT < string name = "(self)"; string item = "進行"; >;
float3 Max_Dmg : CONTROLOBJECT < string name = "(self)"; string item = "ダメージ"; >;
float3 Center : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;

texture NumberTex
<
   string ResourceName = "Tex/Number.png";
>;
sampler NumberSamp = sampler_state
{
   Texture = (NumberTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
	float  Alpha		: TEXCOORD1;
};

VS_OUTPUT VS_passMain( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Alpha = ((((float)(MAX-index)/MAX)-0.5)+morph_Move*2);
    Out.Alpha = saturate(pow(Out.Alpha,8));
    
    
    Pos.x = Tex.x-0.5;
	Pos.y = 1-(Tex.y+0.5);
	
    
    Pos.xy *= 1+(1-Out.Alpha);
	
	Pos.x *= 0.75;
	Pos.z = 0;
    Out.Pos = Pos;
    //比率を1:1に
    Out.Pos.y *= (ViewportSize.x/ViewportSize.y);

	Out.Pos.xy *= 0.2;
	Out.Pos.x -= 0.09 * index;
	Out.Pos.xy *= 0.8;
	Tex.x /= 16.0;

	
	float nMaxDmg = max(0,min(99999,Max_Dmg.x));
	int nMaxDmgBuff = nMaxDmg;
	for(int i=0;i<index;i++)
	{
		if(nMaxDmg <= 0)
		{
			break;
		}
		nMaxDmg/=10;
	}
	int nNowDmg = fmod(nMaxDmg,10);
	if(nNowDmg == 0 && nMaxDmg < 10)
	{
		if(nMaxDmgBuff != 0 || index > 0)
			Tex.x += 1.0;
	}else{
		Tex.x += nNowDmg / 16.0;
	}
	Tex.y *= 0.06125;
	Tex.y += 0.06125*2;
		
    Out.Pos.xy *= 1+Center.z*0.1;

    Out.Pos.xy += Center.xy*0.05;
    Out.Tex = Tex;
        
    return Out;
}
float4 PS_passMain(VS_OUTPUT IN) : COLOR
{   
	float4 col = 0;

	col = tex2D(NumberSamp,IN.Tex);
	col.a *= IN.Alpha;
	return col;
}
////////////////////////////////////////////////////////////////////////////////////////////////
technique Gauge < string MMDPass = "object";
    string Script = 
	    "ScriptExternal=Color;"
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawMain;"
        "LoopEnd=;"
    ;
> {

    pass DrawMain< string Script= "Draw=Buffer;"; >{
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain();
    }
}
technique Gauge_ss < string MMDPass = "object_ss";
    string Script = 
	    "ScriptExternal=Color;"
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawMain;"
        "LoopEnd=;"
    ;
> {

    pass DrawMain< string Script= "Draw=Buffer;"; >{
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
