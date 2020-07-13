//簡易ライトブルームエフェクト
//作成者：ビームマンP
//ベース：ガウスフィルタ（舞力介入P）

float4x4 matWorld : WORLD;

//輝度抽出用パラメータ
float LuminanceParamBase = 0.95;
float LuminancePowBase = 5;
//全体の明度調整用パラメータ
float AddLuminanceBase = 0;

//ぼかし係数
float GauseParam = 2.0;
//トーンマップの強さ
float ToneParam = 1;

//トーンマップ速度
float ToneSpd = 0.25;

float3 pos : CONTROLOBJECT < string name = "(self)";>;
//高輝度部判定の閾値
static const float LuminanceParam = (-pos.x)*0.01 + LuminanceParamBase;
//画面全体に足す値
static const float AddLuminance = pos.y*0.01+0.25*LuminanceParam+AddLuminanceBase;
//高輝度部に掛ける値、高輝度部の倍率
static const float LuminancePow = 1+pos.z+LuminancePowBase;

////////////////////////////////////////////////////////////////////////////////////////////////

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(GauseParam,GauseParam)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float4 ClearBuff = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
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
   string Format="A32B32G32R32F";
>;
sampler2D ToneSamp = sampler_state {
    texture = <ToneTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//明るさ計算用テクスチャ3段階.
texture2D ToneWork1 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {0.75,0.75};
	string Format="A8R8G8B8";
>;
sampler2D ToneWork1Samp = sampler_state {
    texture = <ToneWork1>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {0.5,0.5};
	string Format="A8R8G8B8";
>;
sampler2D ToneWork2Samp = sampler_state {
    texture = <ToneWork2>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork3 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {0.25,0.25};
	string Format="A8R8G8B8";
>;
sampler2D ToneWork3Samp = sampler_state {
    texture = <ToneWork3>;
    Filter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D ToneWork4 : RENDERCOLORTARGET <
	int Width=16;
	int Height=16;
	string Format="A8R8G8B8";
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
	string Format="A8R8G8B8";
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
	string Format="A8R8G8B8";
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
// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D WorkTex1 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D Work1Samp = sampler_state {
    texture = <WorkTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D WorkTex2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D Work2Samp = sampler_state {
    texture = <WorkTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

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
//トーンマップから明るさ取得
float GetTone()
{
	return tex2D(ToneSamp,0.5);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 高輝度部抽出

float4 PS_passLuminance( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

	Color = tex2D( ScnSamp,Tex);
	Color = saturate(Color - LuminanceParam)*LuminancePow;
	Color.a = 1;
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float Tone = GetTone();
	//SampStep *= Tone;
	
	Color  = WT_0 *   tex2D( Work2Samp, Tex );
	Color += WT_1 * ( tex2D( Work2Samp, Tex+float2(SampStep.x  ,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*2,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*3,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*4,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*5,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*6,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( Work2Samp, Tex+float2(SampStep.x*7,0) ) + tex2D( Work2Samp, Tex-float2(SampStep.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float Tone = tex2D(ToneSamp,0.5).r;
	//SampStep *= Tone;
	
	Color  = WT_0 *   tex2D( Work1Samp, Tex );
	Color += WT_1 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y  ) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*2) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*3) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*4) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*5) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*6) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( Work1Samp, Tex+float2(0,SampStep.y*7) ) + tex2D( Work1Samp, Tex-float2(0,SampStep.y*7) ) );

    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// ぼかしと元画像を合成

float4 PS_passMix(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float Tone = (GetTone()+0.5*1);
    float4 ScnCol = tex2D(ScnSamp, Tex);
    Color = tex2D( Work2Samp, Tex) + tex2D( ToneWork1Samp, Tex)
     + tex2D( ToneWork2Samp, Tex) + tex2D( ToneWork3Samp, Tex);
    //Color /= 4;
    Color *= Tone;
	Color += ScnCol;
	Color.rgb -= (Tone*0.5);
    Color.rgb += AddLuminance;
    Color = saturate(Color);
    Color.a = 1;
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
	float luminance = ( 0.298912 * col.r + 0.586611 * col.g + 0.114478 * col.b );
	col.r = luminance;
	col.a = ToneSpd;
	if(Time == 0)
	{
		col = float4(0,0,0,1);
	}
	
    return col;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"

        "RenderColorTarget0=WorkTex2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=CalcLuminance;"

        "RenderColorTarget0=WorkTex1;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
	    
		"RenderColorTarget0=WorkTex2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=Gaussian_Y;"

        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Mix;"
	    
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
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passLuminance();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass Mix < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passMix();
    }
    pass RenderTone_Calc1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(Work2Samp);
    }
    pass RenderTone_Calc2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(ToneWork1Samp);
    }
    pass RenderTone_Calc3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(ToneWork2Samp);
    }
    pass RenderTone_Calc4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(ToneWork3Samp);
    }
    pass RenderTone_Calc5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(ToneWork4Samp);
    }
    pass RenderTone_Calc6 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passSimple();
        PixelShader  = compile ps_2_0 PS_passCpy(ToneWork5Samp);
    }
    pass RenderTone_Draw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passTone();
        PixelShader  = compile ps_2_0 PS_passTone();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
