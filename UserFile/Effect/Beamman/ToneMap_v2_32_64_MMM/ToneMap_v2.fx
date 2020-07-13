float4x4 matWorld : WORLD;

//トーンマップの強さ
float ToneParam <
   string UIName = "ToneParam";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 5;
> = 1;
//トーンマップ速度
float ToneSpd <
   string UIName = "ToneSpd";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 1;
> = 0.025;

float3 pos : CONTROLOBJECT < string name = "(self)";>;

//テクスチャフォーマット
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"

//良くわからない人はここから触らない

// スケール値取得
float scale : CONTROLOBJECT < string name = "(self)"; >;

static float ToneParam_use = ToneParam*scale*0.1;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//明るさ保存用
texture2D ToneTex : RENDERCOLORTARGET <
	int Width=1;
	int Height=1;
   string Format= TEXFORMAT;
>;
sampler2D ToneSamp = sampler_state {
    texture = <ToneTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//明るさ計算用テクスチャ7段階
texture2D ToneWork0 : RENDERCOLORTARGET <
	int Width=128;
	int Height=128;
	string Format="R32F";
>;
sampler2D ToneWork0Samp = sampler_state {
    texture = <ToneWork0>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork1 : RENDERCOLORTARGET <
	int Width=64;
	int Height=64;
	string Format="R32F";
>;
sampler2D ToneWork1Samp = sampler_state {
    texture = <ToneWork1>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork2 : RENDERCOLORTARGET <
	int Width=32;
	int Height=32;
	string Format="R32F";
>;
sampler2D ToneWork2Samp = sampler_state {
    texture = <ToneWork2>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork3 : RENDERCOLORTARGET <
	int Width=16;
	int Height=16;
	string Format="R32F";
>;
sampler2D ToneWork3Samp = sampler_state {
    texture = <ToneWork3>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork4 : RENDERCOLORTARGET <
	int Width=8;
	int Height=8;
	string Format="R32F";
>;
sampler2D ToneWork4Samp = sampler_state {
    texture = <ToneWork4>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork5 : RENDERCOLORTARGET <
	int Width=4;
	int Height=4;
	string Format="R32F";
>;
sampler2D ToneWork5Samp = sampler_state {
    texture = <ToneWork5>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork6 : RENDERCOLORTARGET <
	int Width=2;
	int Height=2;
	string Format="R32F";
>;
sampler2D ToneWork6Samp = sampler_state {
    texture = <ToneWork6>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

//汎用VS

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passSimple( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

VS_OUTPUT VS_passToneCalc( float4 Pos : POSITION, float4 Tex : TEXCOORD0,uniform float2 add ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + add;
    
    return Out;
}
//トーンマップから明るさ取得
float GetTone()
{
	return tex2D(ToneSamp,0.5).r;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 高輝度部抽出

float4 PS_passLuminance( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

	Color = tex2D( ScnSamp,Tex);
	//各色の1.0を超える部分の合計値を出力
	Color = max(Color - 1,0);
	float luminance = ( 0.298912 * Color.r + 0.586611 * Color.g + 0.114478 * Color.b );
	Color.r = luminance;
	Color.a = 1;
    return Color;
}

//明るさ調節
float4 PS_passMain(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float Tone = (GetTone())*ToneParam_use;
    float4 ScnCol = tex2D(ScnSamp, Tex);
    
    Color.rgb = saturate(ScnCol.rgb-Tone);
    Color.a = ScnCol.a;
    return Color;
}

//トーン用　コピー
float4 PS_passCpy(float2 Tex: TEXCOORD0,uniform sampler2D samp) : COLOR
{   
	float4 color = tex2D(samp, Tex);
    return color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// トーン保存
struct VS_TONE_OUT {
    float4 Pos			: POSITION;
};

VS_TONE_OUT VS_passTone( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_TONE_OUT Out = (VS_TONE_OUT)0; 
    Out.Pos = Pos;
    
    return Out;
}
float Time : TIME;

float4 PS_passTone(VS_TONE_OUT IN) : COLOR
{   
	float4 col = tex2D(ToneWork6Samp,0.5);
	col.gb = 0;
	col.a = ToneSpd;
	
	if(Time == 0)
	{
		col = float4(0,0,0,1);
	}
	
    return col;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique ToneMap <
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
	    
        "RenderColorTarget0=ToneWork0;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=CalcLuminance;"

        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Tone;"
	    
		"RenderColorTarget0=ToneWork1;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc1;"
		"RenderColorTarget0=ToneWork2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc2;"
		"RenderColorTarget0=ToneWork3;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc3;"
		"RenderColorTarget0=ToneWork4;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc4;"
		"RenderColorTarget0=ToneWork5;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc5;"
		"RenderColorTarget0=ToneWork6;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=RenderTone_Calc6;"
	    
		"RenderColorTarget0=ToneTex;"
		"RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=RenderTone_Draw;"
    ;
> {
    pass CalcLuminance < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passSimple();
        PixelShader  = compile ps_3_0 PS_passLuminance();
    }
    pass Tone < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passSimple();
        PixelShader  = compile ps_3_0 PS_passMain();
    }
    
    pass RenderTone_Calc1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 64.0);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork0Samp);
    }
    pass RenderTone_Calc2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 32);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork1Samp);
    }
    pass RenderTone_Calc3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 16);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork2Samp);
    }
    pass RenderTone_Calc4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 8);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork3Samp);
    }
    pass RenderTone_Calc5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 4);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork4Samp);
    }
    pass RenderTone_Calc6 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passToneCalc(0.5 / 2);
        PixelShader  = compile ps_3_0 PS_passCpy(ToneWork5Samp);
    }
    pass RenderTone_Draw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passTone();
        PixelShader  = compile ps_3_0 PS_passTone();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
