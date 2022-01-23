// BlackOut.fx ver0.0.1  画面を暗くするだけ(Trで調整, 描画順序は先頭にすること)
// 作成: 針金P

float Script : STANDARDSGLOBAL
    < string ScriptOutput="color"; string ScriptClass="scene"; string ScriptOrder="postprocess"; > = 0.8;

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#ifndef MIKUMIKUMOVING

float4 VS_Draw( float4 Pos : POSITION ) : POSITION { return Pos; }
float4 PS_Draw() : COLOR { return float4(Tr, Tr, Tr, 1); }

technique Tech < string Script = "RenderColorTarget0=; RenderDepthStencilTarget=; ScriptExternal=Color; Pass=Draw;"; >
{
    pass Draw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SrcBlend = ZERO;
        DestBlend = INVSRCCOLOR;
        VertexShader = compile vs_1_1 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

#else

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

VS_OUTPUT VS_pass( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

float4 PS_Draw(float2 Tex: TEXCOORD0) : COLOR {
    float4 Color = tex2D(ScnSamp,Tex);
    return float4(Color.rgb * (1-Tr), 1);
}

technique Tech < string Script =
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

 "RenderColorTarget0=; RenderDepthStencilTarget=; Pass=Draw;"; >
{
    pass Draw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_pass();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

#endif

