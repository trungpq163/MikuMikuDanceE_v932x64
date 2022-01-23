////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Hologram.fx ver0.0.4  モデルのホログラム表現
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ホログラム表示するモデルファイル名(とりあえず10体まで定義可能)
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

// 縞ノイズテクスチャ, Stripe0.png ～ Stripe8.png で指定
#define NoiseTexFile "Stripe6.png" 


// ノイズ関連パラメータ
float StripeThick <  // 縞太さ
   string UIName = "縞太さ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.01;
   float UIMax = 10.0;
> = 4.0;

float NoiseSpeed <  // ノイズ速度
   string UIName = "ノイズ速度";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = 5.7;

float NoiseDens <  // ノイズ密度
   string UIName = "ノイズ密度";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = 2.0;

float GaussianVal <  // 発光にじみ度
   string UIName = "発光にじみ度";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = 1.3;

float3 LightColor <      // 発光色
   string UIName = "発光色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.0, 0.7, 0.7);

bool flagGainColor <     // モデル色のブレンドon/off
   string UIName = "モデル色混合";
   bool UIVisible =  true;
> = false;  // MMEでは[影]のon/offで切り替え可能


// フェード関連パラメータ
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
    #define OFFSCREEN_FX_MASK1  "Hologram_Mask1.fx"    // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Hologram_Mask2.fx"    // オフスクリーンマスクエフェクト2
#else
    #define OFFSCREEN_FX_HIDE   "Hide.fxsub"
    #define OFFSCREEN_FX_NONE   "SampleBase.fxsub"
    #define OFFSCREEN_FX_MASK1  "Hologram_Mask1_MMM.fxm"    // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Hologram_Mask2_MMM.fxsub"  // オフスクリーンマスクエフェクト2
#endif


// モデル描画のオフスクリーンバッファ
texture HologramRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Hologram.fx";
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
// モデルのマスクに使うオフスクリーンバッファ
texture MaskHologramRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of Hologram.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format="A32B32G32R32F";
    bool AntiAlias = false;
    int Miplevels = 1;
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


sampler HologramView = sampler_state {
    texture = <HologramRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

sampler MaskHologram = sampler_state {
    texture = <MaskHologramRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// モアレトーンテクスチャ(ミップマップも生成)
texture2D screen_tex1 <
    string ResourceName = NoiseTexFile;
    int MipLevels = 0;
>;
sampler TexSampler1 = sampler_state {
    texture = <screen_tex1>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    MaxAnisotropy = 5;
    AddressU  = WRAP;
    AddressV = WRAP;
};

float time : Time;

// アクセサリパラメータ
float3 AcsPos : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float AcsHmin = AcsPos.x + HeightMin; 
static float AcsHmax = AcsPos.y + HeightMax; 
static float AcsGain = saturate(1.0f - AcsPos.z) * GaussianVal; 
static float AcsScaling = AcsSi*0.1f; 
static float AcsAlpha = AcsTr;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(2,2)/ViewportSize*AcsGain);

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

// レンダリングターゲットのクリア値
float4 ClearColor = float4(1.0f, 1.0f, 1.0f, 0.0f);
float ClearDepth  = 1.0f;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
struct VS_OUTPUT {
   float4 Pos  : POSITION;
   float2 Tex  : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT VS_Common(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 発光元描画

float4 PS_Light(float2 Tex: TEXCOORD0, uniform bool flag) : COLOR
{
    // オフスクリーンバッファの色
    float4 Color = tex2D(MaskHologram, Tex);
    float alpha = Color.r;
    float height = Color.g;

    Color.rgb = LightColor * alpha * 0.8;
    if( flag || flagGainColor ){
        Color.rgb = 0.5f * alpha * tex2D(HologramView, Tex).rgb + 0.5f * Color.rgb;
    }
    Color.a = 1.0f;

    // フェード透過値計算
    float v = 1.0f-saturate( ( height - AcsHmin ) / ( AcsHmax - AcsHmin ) );
    float a = (1.0+Threshold)*AcsScaling - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.rgb *= AcsAlpha*saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);

    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color;

    Color  = WT_0 *   tex2D( ScnSamp, Tex );
    Color += WT_1 * ( tex2D( ScnSamp, Tex+float2(SampStep.x  ,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x  ,0) ) );
    Color += WT_2 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*2,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*2,0) ) );
    Color += WT_3 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*3,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*3,0) ) );
    Color += WT_4 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*4,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*4,0) ) );
    Color += WT_5 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*5,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*5,0) ) );
    Color += WT_6 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*6,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*6,0) ) );
    Color += WT_7 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*7,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*7,0) ) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);

    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;

    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*2) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*3) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*4) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*5) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*6) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*7) ) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//ホログラム描画

float4 PS_Hologram(float2 Tex: TEXCOORD0) : COLOR
{
    // オフスクリーンバッファの色
    float4 Color = tex2D(HologramView, Tex);
    float4 Color2 = tex2D(MaskHologram, Tex);

    float height = Color2.g;

    // ノイズ
    if(NoiseSpeed > 0.0001f){
       float ah = 50.0f*frac(NoiseSpeed*time);
       float ax = smoothstep(-NoiseDens, NoiseDens, abs(height-ah));
       Color = tex2D(HologramView, float2(Tex.x+3.0f*(1.0f-ax)*SampStep.x, Tex.y));
       Color.a *= ax;
       Color.a *= lerp(0.8f, 1.0f, abs(0.6f*sin(35 * 7*time + 13) + 0.4f*cos(73 * 7*time + 17)));
    }

    // 縞透過
    float rand = 0.6f*sin(37 * time + 13) + 0.4f*cos(71 * time + 17);
    Color.a *= Color2.r;
    Color.a *= tex2D(TexSampler1, float2((Tex.x+rand)/StripeThick*Color2.b, Tex.y/StripeThick*Color2.b))*1.2f;
    Color.a = saturate(Color.a);

    // フェード透過値計算
    float v = 1.0f-saturate( ( height - AcsHmin ) / ( AcsHmax - AcsHmin ) );
    float a = (1.0+Threshold)*AcsScaling - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.a *= AcsAlpha*saturate( (maxLen - v)/(maxLen - minLen) ) * saturate(1.0f - AcsPos.z);;

    return Color;
}

// 発光描画
float4 PS_HologramLight(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color = tex2D(ScnSamp, Tex);
    Color.rgb *= saturate(1.0f - AcsPos.z);
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=LightSource;"
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
            "Pass=DrawLight;"
    ;
> {
    pass LightSource < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_Light(false);
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_Hologram();
    }
    pass DrawLight < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = TRUE;
        SRCBLEND=ONE;
        DESTBLEND=ONE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_HologramLight();
    }

}

#ifndef MIKUMIKUMOVING

technique MainTec2 < string MMDPass = "object_ss";
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=LightSource;"
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
            "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
            "Pass=DrawLight;"
    ;
> {
    pass LightSource < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_Light(true);
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_Hologram();
    }
    pass DrawLight < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = TRUE;
        SRCBLEND=ONE;
        DESTBLEND=ONE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_HologramLight();
    }
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////

//描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }



