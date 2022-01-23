////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PostClip (PreClip.fx) ver0.0.1  既存ポストエフェクトを特定領域だけクリップ（前処理）
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#include "PostClipHeader.fxh"

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float4 ClearColor2 = {0,0,0,1};
float ClearDepth  = 1.0;


// オリジナルの描画結果を記録するためのレンダーターゲット(元の画像として一時保存)
shared texture2D ScnMapSrc : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSampSrc = sampler_state {
    texture = <ScnMapSrc>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// クリップ領域を記録するためのレンダーターゲット
shared texture2D ScnClipMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "X8R8G8B8" ;
>;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// 元の画像を描画して一時保存

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
    return tex2D( ScnSampSrc, Tex );
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTech <
    string Script = 
        "RenderColorTarget0=ScnMapSrc;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        "RenderColorTarget0=ScnClipMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=PostDraw;"
    ;
> {
    pass PostDraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
