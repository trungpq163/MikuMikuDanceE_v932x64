////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ColorFilter_Brightness ver0.0.1  画面の色を輝度による色調変更するエフェクト
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
static float Btm = clamp(AcsXYZ.x, 0.0, 100.0) * 0.001f * AcsSi;
static float Top = clamp(AcsXYZ.y, 0.0, 100.0) * 0.001f * AcsSi;
#else
static float Btm = saturate(AcsXYZ.x * 0.05f);
static float Top = saturate(AcsXYZ.y * 0.05f);
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

// RGBからYCbCrへの変換
void RGBtoYCbCr(float3 rgbColor, out float Y, out float Cb, out float Cr)
{
    Y  =  0.298912f * rgbColor.r + 0.586611f * rgbColor.g + 0.114478f * rgbColor.b;
    Cb = -0.168736f * rgbColor.r - 0.331264f * rgbColor.g + 0.5f      * rgbColor.b;
    Cr =  0.5f      * rgbColor.r - 0.418688f * rgbColor.g - 0.081312f * rgbColor.b;
}


// YCbCrからRGBへの変換
float3 YCbCrtoRGB(float Y, float Cb, float Cr)
{
    float R = Y - 0.000982f * Cb + 1.401845f * Cr;
    float G = Y - 0.345117f * Cb - 0.714291f * Cr;
    float B = Y + 1.771019f * Cb - 0.000154f * Cr;
    return float3( R, G, B );
}


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
    // 元画像の色
    float4 rgbColor = tex2D( ScnSamp, Tex );

    // RGBからYCbCrへの変換
    float Y, Cb, Cr;
    RGBtoYCbCr( rgbColor.rgb, Y, Cb, Cr);

    // 輝度変更(レベル補正)
    Y = saturate( (Y - Btm) / max(1.0f - Top - Btm, 0.001f) );

    // YCbCrからRGBへの変換
    float4 Color = float4( YCbCrtoRGB( Y, Cb, Cr), rgbColor.a );

    // 合成
    return lerp(rgbColor, Color, AcsTr);
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
