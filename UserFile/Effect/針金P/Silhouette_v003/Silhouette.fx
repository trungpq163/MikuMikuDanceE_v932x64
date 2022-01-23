////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Silhouette.fx ver0.0.3  モデルをシルエット描画します
//  作成: 針金P( 舞力介入P氏のMirror.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// シルエット化するモデルファイル名(とりあえず10体まで定義可能)
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


#define UseTex  1                 // シルエット映像が，0:単色，1:テクスチャ, 2:アニメGIF･APNG, 3:Screen.bmpアニメ
#define TexFile  "sample.png"     // 画面に貼り付けるテクスチャファイル名(単色･Screen.bmpの場合は無視)
#define AnimeStart 0.0            // アニメGIF･APNGの場合のアニメーション開始時間(単位：秒)(アニメGIF･APNG以外では無視)

#define AlphaType  0              // 0:半透明合成, 1:加算合成

#define MaskFile "sampleMask.png" // フェードマスクに用いるテクスチャファイル名
float Threshold = 0.2;            // フェードの閾値(値が小さいとフェードの変化がシャープで大きいとマイルドになります)

float TexWidthSize  = 1.0;       // 画面に対するテクスチャ画像の幅比率(単色の場合は無視)
float TexHeightSize = 1.0;       // 画面に対するテクスチャ画像の高さ比率(単色の場合は無視)


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX_MASK1  "Silhouette_Obj.fx"          // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Silhouette_Mask.fxsub"      // オフスクリーンマスクエフェクト2
#else
    #define OFFSCREEN_FX_MASK1  "Silhouette_Obj_MMM.fxm"     // オフスクリーンマスクエフェクト1
    #define OFFSCREEN_FX_MASK2  "Silhouette_Mask_MMM.fxsub"  // オフスクリーンマスクエフェクト2
#endif


// モデルのマスクに使うオフスクリーンバッファ
texture SilhouetteRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Silhouette.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
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
sampler SilhouetteView = sampler_state {
    texture = <SilhouetteRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


float time : TIME;

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
float3 AcsRound : CONTROLOBJECT < string name = "Silhouette.x"; string item = "Rxyz"; >;
static float3 AcsOffset = WorldMatrix._41_42_43;
static float AcsScaling = length(WorldMatrix._11_12_13)*0.1f; 
static float AcsAlpha = MaterialDiffuse.a;
static float TexScaling = abs(WorldMatrix._43)<1.0f ? 1.0f : (WorldMatrix._43>0.0f ? 1.0f/WorldMatrix._43 : abs(WorldMatrix._43));

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;


#if(UseTex == 1)
// 画面に貼り付けるテクスチャ
texture2D screen_tex <
    string ResourceName = TexFile;
    int MipLevels = 0;
>;
#endif

#if(UseTex == 2)
// 画面に貼り付けるアニメーションテクスチャ
texture screen_tex : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    int MipLevels = 1;
    float Offset = AnimeStart;
>;
#endif

#if(UseTex == 3)
// オブジェクトのテクスチャ
texture screen_tex: MATERIALTEXTURE;
#endif

#if(UseTex > 0)
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MagFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};
#endif

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
//床面鏡像描画シェーダ
struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float4 PS_Mirror(float2 Tex: TEXCOORD0) : COLOR
{
    // オフスクリーンバッファの色
    float4 ColorOff = tex2D(SilhouetteView, Tex);

#if(UseTex == 0)
    // 単色指定の場合の色
    float4 Color = saturate( float4(degrees(AcsRound), 1.0f) );
#else
    // 貼り付けるテクスチャの色
    float2 texCoord = float2( Tex.x/TexWidthSize + AcsOffset.x*time,
                              Tex.y/TexHeightSize + AcsOffset.y*time ) * TexScaling;
    float4 Color = tex2D(TexSampler, texCoord);
#endif

    Color.a *= ColorOff.r;

    // マスクするテクスチャの色
    float4 MaskColor = tex2D( MaskSamp, Tex );

    // グレイスケール計算
    float v = (MaskColor.r + MaskColor.g + MaskColor.b)*0.333333f;

    // フェード透過値計算
    float a = (1.0+Threshold)*AcsScaling - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.a *= AcsAlpha*saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    pass DrawObject < string Script= "Draw=Buffer;"; > {
#if(AlphaType == 1)
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
#endif
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////



