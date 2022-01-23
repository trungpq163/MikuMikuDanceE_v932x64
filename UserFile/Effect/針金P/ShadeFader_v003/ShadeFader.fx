////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ShadeFader.fx ver0.0.3  シェーダ系エフェクトのON/OFFをスムーズに切り替える
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// フェードするモデルファイル名(とりあえず10体まで定義可能)
//#define ModelFileName01  "初音ミクVer2.pmd"  // ←こんな風に未定義の代わりに "" の間にモデルファイル名を書く(行先頭の // は削除)
//#define ModelFileName02  "未定義"
//#define ModelFileName03  "未定義"
//#define ModelFileName04  "未定義"
//#define ModelFileName05  "未定義"
//#define ModelFileName06  "未定義"
//#define ModelFileName07  "未定義"
//#define ModelFileName08  "未定義"
//#define ModelFileName09  "未定義"
//#define ModelFileName10  "未定義"

#define MaskFile "sampleMask.png"   // フェードマスクに用いるテクスチャファイル名

float Threshold <  // フェードの閾値(値が小さいとフェードの変化がシャープで大きいとマイルドになります)
   string UIName = "フェードの閾値";
   string UIHelp = "値が小さいとフェードの変化がシャープで大きいとマイルドになります";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 0.2;


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX_HIDE   "hide"
    #define OFFSCREEN_FX_NONE   "none"
    #define OFFSCREEN_FX_MASK1  "SF_Mask1.fx"       // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "SF_Mask2.fxsub"    // オフスクリーンマスクエフェクト2
#else
    #define OFFSCREEN_FX_HIDE   "Hide.fxsub"
    #define OFFSCREEN_FX_NONE   "SampleBase.fxsub"
    #define OFFSCREEN_FX_MASK1  "SF_Mask1_MMM.fxm"    // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "SF_Mask2_MMM.fxsub"  // オフスクリーンマスクエフェクト2
#endif


// モデルのマスクに使うオフスクリーンバッファ
texture MaskShadeFaderRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of ShadeFader.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = " OFFSCREEN_FX_HIDE ";"
        #ifdef ModelFileName01
        ModelFileName01 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName02
        ModelFileName02 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName03
        ModelFileName03 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName04
        ModelFileName04 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName05
        ModelFileName05 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName06
        ModelFileName06 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName07
        ModelFileName07 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName08
        ModelFileName08 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName09
        ModelFileName09 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        #ifdef ModelFileName10
        ModelFileName10 "=" OFFSCREEN_FX_MASK1 ";"
        #endif
        "* = " OFFSCREEN_FX_MASK2 ";" ;
>;
sampler MaskShadeFader = sampler_state {
    texture = <MaskShadeFaderRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// MMD標準描画のオフスクリーンレンダ
texture ShadeFaderRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for ShadeFader.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = " OFFSCREEN_FX_HIDE ";"
        #ifdef ModelFileName01
        ModelFileName01 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName02
        ModelFileName02 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName03
        ModelFileName03 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName04
        ModelFileName04 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName05
        ModelFileName05 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName06
        ModelFileName06 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName07
        ModelFileName07 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName08
        ModelFileName08 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName09
        ModelFileName09 "=" OFFSCREEN_FX_NONE ";"
        #endif
        #ifdef ModelFileName10
        ModelFileName10 "=" OFFSCREEN_FX_NONE ";"
        #endif
        "* = " OFFSCREEN_FX_HIDE ";" ;
>;
sampler ShadeFaderView = sampler_state {
    texture = <ShadeFaderRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
static float AcsScaling = length(WorldMatrix._11_12_13)*0.1f; 
// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
static float AcsAlpha = MaterialDiffuse.a;

// マスクに用いるテクスチャ
texture2D mask_tex <
    string ResourceName = MaskFile;
    int MipLevels = 1;
>;
sampler MaskSamp = sampler_state {
    texture = <mask_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// MMD標準描画の上書き

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Shader(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float4 PS_Shader(float2 Tex: TEXCOORD0) : COLOR
{
    // オフスクリーンバッファの色
    float4 Color = tex2D(ShadeFaderView, Tex);
    float4 Color2 = tex2D(MaskShadeFader, Tex);
    Color.a *= Color2.r;

    // マスクするテクスチャの色
    float4 MaskColor = tex2D( MaskSamp, Tex );

    // グレイスケール計算
    float v = (MaskColor.r + MaskColor.g + MaskColor.b)*0.333333f;

    // フェード透過値計算
    float a = (1.0+Threshold)*AcsScaling - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.a *= (1.0f-AcsAlpha)*saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Shader();
        PixelShader  = compile ps_2_0 PS_Shader();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////



