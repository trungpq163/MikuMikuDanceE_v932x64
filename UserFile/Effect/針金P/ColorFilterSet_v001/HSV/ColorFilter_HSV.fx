////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ColorFilter_HSV ver0.0.1  画面の色をHSVで色調変更するエフェクト
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
static float H_Shift = AcsXYZ.x * 0.1f * AcsSi;
static float S_Shift = clamp(AcsXYZ.y, -100.0, 100.0) * 0.001f * AcsSi;
static float V_Shift = clamp(AcsXYZ.z, -100.0, 100.0) * 0.001f * AcsSi;
#else
static float H_Shift = clamp(AcsXYZ.x, -20.0, 20.0) * 18.0f;
static float S_Shift = clamp(AcsXYZ.y, -20.0, 20.0) * 0.05f;
static float V_Shift = clamp(AcsXYZ.z, -20.0, 20.0) * 0.05f;
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
// 整数除算
int div(int a, int b) {
    return floor((a+0.1f)/b);
}

// 整数剰余算
int mod(int a, int b) {
    return (a - div(a,b)*b);
};

////////////////////////////////////////////////////////////////////////////////////////////////

// RGBからHSVへの変換 H:0.0～360.0, S:0.0～1.0, V:0.0～1.0
void RGBtoHSV(float3 rgbColor, out float h, out float s, out float v)
{
    float Min = min( rgbColor.r, min(rgbColor.g, rgbColor.b) );
    float Max = max( rgbColor.r, max(rgbColor.g, rgbColor.b) );

    // H(色相)
    if(Max == Min){
        h = 0.0;
    }else if(Max == rgbColor.r){
        h = fmod( 60.0 * (rgbColor.g - rgbColor.b) / (Max - Min) + 360.0, 360.0);
    }else if(Max == rgbColor.g){
        h = (60.0 * (rgbColor.b - rgbColor.r) / (Max - Min)) + 120.0;
    }else if(Max == rgbColor.b){
        h = (60.0 * (rgbColor.r - rgbColor.g) / (Max - Min)) + 240.0;   
    }

    // S(彩度)
    if(Max == 0.0){
        s = 0.0;
    }else{
        s = (Max - Min) / Max;
    }

    // V(明度)
    v = Max;
}

// HSVからRGBへの変換 H:0.0～360.0, S:0.0～1.0, V:0.0～1.0
float3 HSVtoRGB(float h, float s, float v)
{
    h = fmod(h, 360.0);
    int hi = mod(floor(h / 60.0), 6);
    float f = frac(h / 60.0);
    float p = v*(1.0 - s);
    float q = v*(1.0 - f*s);
    float t = v*(1.0 - (1.0-f)*s);
    float3 Color;
    if(hi == 0){
       Color = float3(v, t, p);
    }else if(hi == 1){
       Color = float3(q, v, p);
    }else if(hi == 2){
       Color = float3(p, v, t);
    }else if(hi == 3){
       Color = float3(p, q, v);
    }else if(hi == 4){
       Color = float3(t, p, v);
    }else if(hi == 5){
       Color = float3(v, p, q);
    }
    return Color;
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
    float4 Color0 = tex2D( ScnSamp, Tex );

    // RGBからHSVへの変換
    float h, s, v;
    RGBtoHSV(Color0.rgb, h, s, v);

    // HSV値の変更
    h += H_Shift;
    s = (S_Shift < 0.0) ? ((1.0 + S_Shift) * s) : (1.0 - (1.0 - S_Shift) * (1.0 - s));
    v = (V_Shift < 0.0) ? ((1.0 + V_Shift) * v) : (1.0 - (1.0 - V_Shift) * (1.0 - v));

    // HSVからRGBへの変換
    float4 Color = float4( HSVtoRGB( h, s, v ), Color0.a );

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
        VertexShader = compile vs_3_0 VS_ColorChange();
        PixelShader  = compile ps_3_0 PS_ColorChange();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
