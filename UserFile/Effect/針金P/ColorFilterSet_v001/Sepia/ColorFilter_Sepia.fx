////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ColorFilter_Sepia ver0.0.1  画面の色をセピア調に変更するエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

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

// セピア色変換
float4 RGBtoSEPIA(float4 rgbColor)
{
    float y = 0.298912 * rgbColor.r + 0.586611 * rgbColor.g + 0.114478 * rgbColor.b;
    // YUV->RGB変換
    float3x3 mat = { 1.000f,  1.000f,  1.000f,
                     0.000f, -0.344f,  1.714f,
                     1.402f, -0.714f,  0.000f };
    return float4( mul(float3(y, -0.091f, 0.056f), mat), rgbColor.a );
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

    // セピア色に変換
    float4 Color = RGBtoSEPIA( rgbColor );

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
