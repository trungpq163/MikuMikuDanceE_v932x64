////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgPointLight.fx ver0.0.2  点光源エフェクト(アクセ版,セルフシャドウなし)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// オフスクリーン点光源ライティングバッファ
texture HgPL_DrawRT: OFFSCREENRENDERTARGET <
    string Description = "HgPointLight.fxのモデルの点光源ライティング結果";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = {0, 0, 0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = HgPL_Object.fxsub;";
>;
sampler LightDrawSamp = sampler_state {
    texture = <HgPL_DrawRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// ライティング描画の加算合成

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Draw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color = tex2D( LightDrawSamp, Tex );
    Color.rgb *= AcsTr;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ScriptExternal=Color;"
            "Pass=PostDraw;"
    ;
> {
    pass PostDraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
