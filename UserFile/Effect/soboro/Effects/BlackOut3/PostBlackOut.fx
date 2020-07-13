////////////////////////////////////////////////////////////////////////////////////////////////

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// マテリアル色
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//スケール
float scaling0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float scaling = scaling0 * 0.1;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);


float4 Color_White = {1,1,1,1};
float4 Color_Black = {0,0,0,1};

////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_BlackOut( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color = Color_Black;
    
    Color.a *= alpha1;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique BlackOut <
    string Script = 
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "Pass=BlackOut;"
        
    ;
    
> {
    pass BlackOut < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_BlackOut();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
