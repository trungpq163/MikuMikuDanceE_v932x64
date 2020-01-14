
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

//-----------------------------------------------------------------------------
// 深度マップ
//
//-----------------------------------------------------------------------------
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

texture DepthMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DepthMap.fx";
    float4 ClearColor = {0,0,0,1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_R32F" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        
        "NewBomb.pmx = hide;"
        "NewBomb_AC_0.x = hide;"
        "NewBombController_0.pmx = hide;"
        "SelfLotion.x = hide;"
        "Bomb.x = hide;"
        "GroundSplash.x = hide;"
        "Nuke.x = hide;"
        "SmokeBomb.x = hide;"
        "Splash.x = hide;"
        "AutoSmoke2.pmx = hide;"
        
        "* = SoftParticleEngine_DepthOut.fxsub";
>;

sampler DepthMap = sampler_state {
    texture = <DepthMapRT>;
    AddressU  = BORDER;
    AddressV = BORDER;
    Filter = NONE;
};
//深度マップ保存テクスチャ
shared texture2D SPE_DepthTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_R32F" ;
>;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


//-----------------------------------------------------------------------------
// 固定定義
//
//-----------------------------------------------------------------------------
struct VS_OUTPUT
{
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

//-----------------------------------------------------------------------------
// SSAO
//-----------------------------------------------------------------------------
VS_OUTPUT VS_Main(float4 Pos:POSITION, float4 Tex:TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset;

	return Out;
}

float4 PS_Main(float2 inTex: TEXCOORD0) : COLOR
{
	//return float4(tex2D(DepthMap,inTex).r*0.01,0,0,1);
	return tex2D(DepthMap,inTex);
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique DepthTexOut <
	string Script = 
		"ScriptExternal=Color;"

		//最終合成
		"RenderColorTarget0=SPE_DepthTex;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Pass=LastPass;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		//"Pass=LastPass;"
		
    ;
> {
	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Main();
		PixelShader  = compile ps_3_0 PS_Main();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
