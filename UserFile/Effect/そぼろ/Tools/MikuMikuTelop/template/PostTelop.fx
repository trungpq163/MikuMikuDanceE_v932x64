////////////////////////////////////////////////////////////////////////////////////////////////
// 編集禁止

bool flag1 : CONTROLOBJECT < string name = "MikuMikuTelop.x"; >;

texture TelopDraw: OFFSCREENRENDERTARGET <
    string Description = "PostTelopDraw for MikuMikuTelop.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "MikuMikuTelop.x = MikuMikuTelop.fx;"
        "* = hide;" 
    ;
>;

sampler sampTelop = sampler_state {
    texture = <TelopDraw>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_passDraw( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    
    Color = tex2D( sampTelop, Tex );
    
    Color.rgb /= Color.a;
    
    Color = flag1 ? Color : float4(1,0,0,1);
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique PostTelop <
    string Script = 
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "Pass=DrawTelop;"
        
    ;
    
> {
    
    pass DrawTelop < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = true;
        ZEnable = false;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passDraw();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
