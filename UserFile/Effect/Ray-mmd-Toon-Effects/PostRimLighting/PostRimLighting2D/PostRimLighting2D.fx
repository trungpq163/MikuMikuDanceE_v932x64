////////////////////////////////////////////////////////////////////////////////
//
//  PostRimLighting2D.fx
//  作成: ミーフォ茜
//
////////////////////////////////////////////////////////////////////////////////

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL
<
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float3 LightAmbient : AMBIENT < string Object = "Light"; >;
float3 DefaultRimLightingColor : CONTROLOBJECT < string name = "(self)"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

#define WT_0 0.0920246
#define WT_1 0.0902024
#define WT_2 0.0849494
#define WT_3 0.0768654
#define WT_4 0.0668236
#define WT_5 0.0558158
#define WT_6 0.0447932
#define WT_7 0.0345379
#define DefaultBlurSize 1

static float2 SampStep = float2(DefaultBlurSize, DefaultBlurSize) / ViewportSize * Si * 0.1;

////////////////////////////////////////////////////////////////
// 作業用テクスチャ
texture PRL_AdditiveRT : OFFSCREENRENDERTARGET
<
	string Description = "Additive Render Target for PostRimLighting.fx";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect =
	    "self = hide;"
	    "* = PRL_VisibleMask.fx;";
>;
sampler AdditiveSampler = sampler_state
{
	texture = <PRL_AdditiveRT>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
<
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
texture2D ScnMap2 : RENDERCOLORTARGET
<
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state
{
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

/////////////////////////////
// X ぼかし

struct VS_OUTPUT
{
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT VS_passX(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;
	
	Color  = WT_0 *   tex2D( AdditiveSampler, Tex );
	Color += WT_1 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x  ,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*2,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*3,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*4,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*5,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*6,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( AdditiveSampler, Tex+float2(SampStep.x*7,0) ) + tex2D( AdditiveSampler, Tex-float2(SampStep.x*7,0) ) );
	
	float3 light = DefaultRimLightingColor;
	
	if (light.r == 0 &&
		light.g == 0 &&
		light.b == 0)
		light = LightAmbient * 2;
	
	Color = float4(light * (1 - Color.a), 1);
	
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// Y ぼかし + 合成

VS_OUTPUT VS_passY(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = WT_0 *   tex2D( ScnSamp2, Tex );
	Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*7) ) );
	
    return Color * float4(1, 1, 1, Tr * tex2D(AdditiveSampler, Tex).a);
}

////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float4 ClearColor = { 0, 0, 0, 0 };
float ClearDepth = 1;

technique PostEffectTec
<
	string Script =
		"ScriptExternal=Color;"
		"RenderColorTarget0=ScnMap2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=PassX;"
	    
	    "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=PassY;";
>
{
	pass PassX < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = false;
		VertexShader = compile vs_2_0 VS_passX();
		PixelShader  = compile ps_2_0 PS_passX();
	}
	pass PassY < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = true;
      	SRCBLEND = SRCALPHA;
        DESTBLEND = ONE;
		VertexShader = compile vs_2_0 VS_passY();
		PixelShader  = compile ps_2_0 PS_passY();
	}
};
