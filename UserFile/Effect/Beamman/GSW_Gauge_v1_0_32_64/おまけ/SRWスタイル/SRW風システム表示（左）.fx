float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//体力が?????になる値
#define SECRET_HP 10000

#define BASE	0
#define HP		1

#define NUMBER_HP0	2
#define NUMBER_HP1	3
#define NUMBER_HP2	4
#define NUMBER_HP3	5
#define NUMBER_HP4	6

#define NUMBER_MP0	7
#define NUMBER_MP1	8
#define NUMBER_MP2	9

#define NUMBER_MAXHP0	10
#define NUMBER_MAXHP1	11
#define NUMBER_MAXHP2	12
#define NUMBER_MAXHP3	13
#define NUMBER_MAXHP4	14

#define NUMBER_MAXMP0	15
#define NUMBER_MAXMP1	16
#define NUMBER_MAXMP2	17

#define MAX			18

#define HP_WIDTH 5
#define MP_WIDTH 3

int index = 0;    //ループ変数
int count = MAX; //複製数

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float4x4 wvp : WorldViewProjection;
float morph_HP : CONTROLOBJECT < string name = "(self)"; string item = "簡易HP"; >;
float morph_MP : CONTROLOBJECT < string name = "(self)"; string item = "簡易MP"; >;
float3 Max_HP : CONTROLOBJECT < string name = "(self)"; string item = "HPMAX"; >;
float3 Max_MP : CONTROLOBJECT < string name = "(self)"; string item = "MPMAX"; >;
float3 Now_HP : CONTROLOBJECT < string name = "(self)"; string item = "現在HP"; >;
float3 Now_MP : CONTROLOBJECT < string name = "(self)"; string item = "現在MP"; >;
float3 Center : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;

texture BaseTex
<
   string ResourceName = "Tex/Base_l.png";
>;
sampler BaseSamp = sampler_state
{
   Texture = (BaseTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
texture GaugeMask
<
   string ResourceName = "Tex/GaugeMask_l.png";
>;
sampler GaugeMaskSamp = sampler_state
{
   Texture = (GaugeMask);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
texture SlashTex
<
   string ResourceName = "Tex/Slash_l.png";
>;
sampler SlashSamp = sampler_state
{
   Texture = (SlashTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
texture GaugeColor
<
   string ResourceName = "Tex/GaugeColor.png";
   int Width = 256;
   int Height = 3;
>;
sampler GaugeColorSamp = sampler_state
{
   Texture = (GaugeColor);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = NONE;
};
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
	float  Parcent		: TEXCOORD1;
};

VS_OUTPUT VS_passMain( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Pos.x = Tex.x-0.5;
	Pos.y = 1-(Tex.y+0.5);
	Pos.z = 0;
	//Pos.xy = (Tex)*0.1;
    Out.Pos = Pos;
    //比率を1:1に
    Out.Pos.y *= (ViewportSize.x/ViewportSize.y);
    Out.Parcent = 1.0;
    Max_HP += 0.01;
    Now_HP += 0.01;
    
    float ratio = (ViewportSize.x/ViewportSize.y);
    
	if((index >= NUMBER_HP0 && index < NUMBER_MP0) || (index >= NUMBER_MAXHP0 && index < NUMBER_MAXMP0))
	{
		bool bMax = (index >= NUMBER_MAXHP0 && index < NUMBER_MAXMP0);
		int local_index = index - (!bMax ? NUMBER_HP0 : NUMBER_MAXHP0);
		Out.Pos.xy *= 0.07;
		float2 AddPos = 0;
		AddPos.x -= 0.05;
		AddPos.y += 0.18;
		Now_HP.x = min(Max_HP,max(0,Now_HP));
		
		//現在HP
		float Now = Now_HP.x*(1-morph_HP);
		
		if(!bMax)
		{
			AddPos.x -= 0.32;
			float MaxHPBuff = Max_HP.x;
						
						
			Out.Parcent = Now/MaxHPBuff;
		}
		AddPos.y -= 0.15;
		AddPos.x += 0.045 * ((HP_WIDTH-1) - local_index);
		Tex.x /= 16.0;
		
		AddPos.y *= ratio;
		Out.Pos.xy += AddPos;
		
		float fMaxHP; 
		if(bMax)
			fMaxHP = max(0,min(99999,Max_HP.x));
		else
			fMaxHP = Now;
		
		if(Now > SECRET_HP)
		{
			Tex.x += 10 / 16.0;
		}else{
			int nMaxHPBuff = fMaxHP;
			for(int i=0;i<local_index;i++)
			{
				if(fMaxHP <= 0)
				{
					break;
				}
				fMaxHP/=10;
			}
			int nNowHP = fMaxHP % 10;
			if(nNowHP == 0 && fMaxHP < 10)
			{
				if(nMaxHPBuff != 0 || local_index > 0)
					Tex.x += 1.0;
			}else{
				Tex.x += nNowHP / 16.0;
			}
		}
		Tex.y *= 0.06125;
		
	}else if((index >= NUMBER_MP0 && index < NUMBER_MAXHP0) || (index >= NUMBER_MAXMP0 && index < MAX))
	{
		bool bMax = (index >= NUMBER_MAXMP0 && index < MAX);
		int local_index = index - (!bMax ? NUMBER_MP0 : NUMBER_MAXMP0);
		Out.Pos.xy *= 0.09;
		
		float2 AddPos = 0;
		
		AddPos.x -= 0.22;
		AddPos.y -= 0.045;
		Now_MP.x = min(Max_MP,max(0,Now_MP));
		
		//現在MP
		float Now = Now_MP.x*(1-morph_MP);
		
		if(!bMax)
		{
			AddPos.x -= 0.16;
			float MaxMPBuff = Max_MP.x;
				
			Out.Parcent = Now/MaxMPBuff;
		}
		AddPos.y -= 0.03;
		AddPos.x += 0.034 * ((MP_WIDTH-1) - local_index);
		Tex.x /= 16.0;

		local_index = min(local_index,10);
		
		float fMaxMP;
		if(bMax)
			fMaxMP = max(0,min(999,Max_MP.x));
		else
			fMaxMP = Now;
		
		int nMaxMPBuff = fMaxMP;
		
		//local_index = local_index;
		
		for(int i=0;i<local_index;i++)
		{
			if(fMaxMP <= 0)
			{
				break;
			}
			fMaxMP/=10;
		}
		
		int nNowMP = fMaxMP % 10;
		if(nNowMP == 0 && fMaxMP < 10)
		{
			if(nMaxMPBuff != 0 || local_index > 0)	Tex.x += 1.0;
		}else{
			Tex.x += nNowMP / 16.0;
		}
		Tex.y *= 0.06125;
		Tex.y += 0.06125;

		
		AddPos.y *= ratio;
		Out.Pos.xy += AddPos;
		
	}else{
	
		//Out.Pos.y *= 0.5625;
		//Out.Pos.y -= 0.5;
		Out.Pos.xy *= 1.25;

		Out.Pos.y -= 0.5*(ViewportSize.x/ViewportSize.y);
		
		/*
		Out.Pos.x /= 2;
		Out.Pos.y /= 2;
		*/
    }
    Out.Pos.xy *= 1+Center.z*0.1;


    //Out.Pos.y += lerp(0.5,0,ViewportSize.x/ViewportSize.y);
    Out.Pos.xy += Center.xy*0.1;
    Out.Tex = Tex;
    return Out;
}
float4 PS_passMain(VS_OUTPUT IN) : COLOR
{   
	Now_HP.x = min(Max_HP.x,max(0,Now_HP.x));
	Now_MP.x = min(Max_MP.x,max(0,Now_MP.x));
	
	float4 col = 0;
	if(index == BASE)
	{
		col = tex2D(BaseSamp,IN.Tex);
	}else if(index == HP)
	{
		col = tex2D(GaugeMaskSamp,IN.Tex);
		col.rgb *= col.a;
		if(col.r == 1)
		{
			float b = min(max(0,col.b - (1-(1-morph_HP)*Now_HP.x / Max_HP.x)),1);
			col = tex2D(GaugeColorSamp,float2(1-col.b,0));
			col.a = lerp(0,col.a,(b > 0));
		}else if(col.g == 1){
			float b = min(max(0,col.b - (1-(1-morph_MP)*Now_MP.x / Max_MP.x)),1);
			col = tex2D(GaugeColorSamp,float2(1-col.b,1));
			col.a = lerp(0,col.a,(b > 0));
		}else{
			col = 0;
		}
		float4 slash = tex2D(SlashSamp,IN.Tex);
		col = lerp(col,slash,slash.a);
	}else if(index >= NUMBER_HP0)
	{
		col = tex2D(NumberSamp,IN.Tex);
		if(IN.Parcent < 0.5)	col.b = 0;
		if(IN.Parcent < 0.1)	col.g = 0;

		
	}
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
