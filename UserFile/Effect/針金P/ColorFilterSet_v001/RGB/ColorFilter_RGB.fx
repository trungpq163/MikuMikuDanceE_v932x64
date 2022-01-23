////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ColorFilter_RGB ver0.0.1  画面の色をRGBで色調変更するエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float3 AcsXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
#ifndef MIKUMIKUMOVING
static float R_Shift = clamp(AcsXYZ.x, -100.0, 100.0) * 0.001f * AcsSi;
static float G_Shift = clamp(AcsXYZ.y, -100.0, 100.0) * 0.001f * AcsSi;
static float B_Shift = clamp(AcsXYZ.z, -100.0, 100.0) * 0.001f * AcsSi;
#else
static float R_Shift = clamp(AcsXYZ.x, -20.0, 20.0) * 0.05f;
static float G_Shift = clamp(AcsXYZ.y, -20.0, 20.0) * 0.05f;
static float B_Shift = clamp(AcsXYZ.z, -20.0, 20.0) * 0.05f;
#endif

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

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
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 色調変化処理

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_ColorChange( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

// ピクセルシェーダ
float4 PS_ColorChange( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color0 = tex2D( ScnSamp, Tex );

    // RGB成分
    float r = Color0.r;
    float g = Color0.g;
    float b = Color0.b;

    // RGB値の変更
    r = (R_Shift < 0.0) ? ((1.0 + R_Shift) * r) : (1.0 - (1.0 - R_Shift) * (1.0 - r));
    g = (G_Shift < 0.0) ? ((1.0 + G_Shift) * g) : (1.0 - (1.0 - G_Shift) * (1.0 - g));
    b = (B_Shift < 0.0) ? ((1.0 + B_Shift) * b) : (1.0 - (1.0 - B_Shift) * (1.0 - b));

    // 変換後の色
    float4 Color = float4( r, g, b , Color0.a );

    // 合成
    return lerp(Color0, Color, AcsTr);
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTech <
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
            "Pass=PostColorChange;"
    ;
> {
    pass PostColorChange < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_ColorChange();
        PixelShader  = compile ps_2_0 PS_ColorChange();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
