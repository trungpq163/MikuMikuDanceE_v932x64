float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//フォグ用Z深度用RT
texture ZFogRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for ZFog_post.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    string Format="R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler FogSamp = sampler_state
{
   Texture = (ZFogRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = NONE;
};
float morph_start : CONTROLOBJECT < string name = "(self)"; string item = "開始位置"; >;
float morph_end : CONTROLOBJECT < string name = "(self)"; string item = "終了位置"; >;
float morph_scale : CONTROLOBJECT < string name = "(self)"; string item = "スケール"; >;
float morph_r : CONTROLOBJECT < string name = "(self)"; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = "(self)"; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = "(self)"; string item = "青"; >;

// 定数計算
static float FogStart=morph_start*256.0*(1+morph_scale*10);
static float FogEnd=FogStart+(1-morph_end)*256.0*(1+morph_scale*10);
static float2 FogCoord = float2(FogEnd/(FogEnd-FogStart), -1/(FogEnd-FogStart));
static float4 FogColor = float4(morph_r,morph_g,morph_b, 1);


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(2,2)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    int MipLevels = 0;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passFog( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos; 
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float4 PS_passFog(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	Color = tex2D( ScnSamp, Tex );
	
	float z = tex2D( FogSamp, Tex ).r;
	
	float f = saturate(FogCoord.x + z * FogCoord.y);
	Color = lerp(FogColor, Color, f);
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique ZFogPost <
    string Script = 
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Fog;"
    ;
> {

    pass Fog < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passFog();
        PixelShader  = compile ps_2_0 PS_passFog();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
