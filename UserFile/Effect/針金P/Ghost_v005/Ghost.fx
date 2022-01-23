////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ghost.fx ver0.0.5  モデルの半透明描画による幽霊表現
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 半透明にするモデルファイル名(とりあえず10体まで定義可能)
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


// フェードパラメータ
float HeightMin <  // フェード開始基準高さ
   string UIName = "フェード開始高";
   string UIHelp = "フェード開始基準高さ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = 0.0;

float HeightMax <  // フェード終了基準高さ
   string UIName = "フェード終了高";
   string UIHelp = "フェード終了基準高さ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = 20.0;

float Threshold <  // フェードの閾値(値が小さいとフェードの変化がシャープで大きいとマイルドになります)
   string UIName = "フェードの閾値";
   string UIHelp = "値が小さいとフェードの変化がシャープで大きいとマイルドになります";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 0.5;


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX_HIDE   "hide"
    #define OFFSCREEN_FX_NONE   "none"
    #define OFFSCREEN_FX_MASK1  "Ghost_Mask1.fx"    // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Ghost_Mask2.fx"    // オフスクリーンマスクエフェクト2
#else
    #define OFFSCREEN_FX_HIDE   "Hide.fxsub"
    #define OFFSCREEN_FX_NONE   "SampleBase.fxsub"
    #define OFFSCREEN_FX_MASK1  "Ghost_Mask1_MMM.fxm"    // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Ghost_Mask2_MMM.fxsub"  // オフスクリーンマスクエフェクト2
#endif


// モデルのオフスクリーンレンダ
texture GhostRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Ghost.fx";
    float2 ViewPortRatio = {1.0, 1.0};
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
sampler GhostView = sampler_state {
    texture = <GhostRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// モデルのマスクに使うオフスクリーンバッファ
texture MaskGhostRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of Ghost.fx";
    float2 ViewPortRatio = {1.0, 1.0};
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
sampler MaskGhost = sampler_state {
    texture = <MaskGhostRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f) / ViewportSize;

// アクセサリパラメータ
float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

static float Xoffset = AcsX + HeightMin;
static float Yoffset = AcsY + HeightMax;


////////////////////////////////////////////////////////////////////////////////////////////////
// モデル半透明描画

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Ghost(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float4 PS_Ghost(float2 Tex: TEXCOORD0) : COLOR
{
    // オフスクリーンバッファの色
    float4 Color = tex2D(GhostView, Tex);
    float4 Color2 = tex2D(MaskGhost, Tex);
    Color.a *= Color2.r;

    // フェード透過値計算
    float h = Color2.g * 100.0f + Color2.b * 10.0f;
    float v = 1.0f-saturate( ( h - Xoffset ) / ( Yoffset - Xoffset ) );
    float a = (1.0+Threshold)*AcsSi*0.1f - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.a *= AcsTr * saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Ghost();
        PixelShader  = compile ps_2_0 PS_Ghost();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////



