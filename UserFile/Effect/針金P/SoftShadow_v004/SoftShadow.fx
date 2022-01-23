////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SoftShadow.fx ver0.0.4 地面影をぼかしてから投影できるようにします
//  作成: 針金P( 舞力介入P氏のMirror.fx, Gaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define SampCount  8    // ぼかしに用いるサンプリング数
#define TEXSIZE    512  // 地面テクスチャのサイズ


float3 MaterialAmbient <      // 地面影のAmbient色(RBG)
   string UIName = "影Ambient";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.3,0.3,0.3);

float3 MaterialEmmisive <      // 地面影のEmmisive色(RBG)
   string UIName = "影Emmisive";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.2,0.2,0.2);

float GaussianLangth < // 地面影ぼかし距離
   string UIName = "影ぼかし基準値";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = float( 30.0 );


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE < string Object = "Geometry"; >;

// ライト色
float3 LightAmbient : AMBIENT < string Object = "Light"; >;
static float3 MaterialColor = saturate(MaterialAmbient * LightAmbient + MaterialEmmisive);


#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX_HIDE    "hide"
    #define OFFSCREEN_FX_SHADOW  "SoftShadowObject.fxsub"          // オフスクリーン影描画エフェクト
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define OFFSCREEN_FX_HIDE    "Hide.fxsub"
    #define OFFSCREEN_FX_SHADOW  "SoftShadowObject_MMM.fxsub"     // オフスクリーン影描画エフェクト
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


// 地面影描画用オフスクリーンバッファ
texture SoftShadowRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for SoftShadow.fx";
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = " OFFSCREEN_FX_HIDE ";"

        "*.pmd =" OFFSCREEN_FX_SHADOW ";"
        "*.pmx =" OFFSCREEN_FX_SHADOW ";"

        "* = " OFFSCREEN_FX_HIDE ";" ;
>;
sampler SoftShadowView = sampler_state {
    texture = <SoftShadowRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////

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

// スクリーンサイズ
float2 ViewportSize = float2(TEXSIZE, TEXSIZE);
static float2 ViewportOffset = float2(0.5f,0.5f)/ViewportSize;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX : RENDERCOLORTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampX = sampler_state {
    texture = <ScnMapX>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapY : RENDERCOLORTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampY = sampler_state {
    texture = <ScnMapY>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    string Format = "D24S8";
>;

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR
{
    // サンプリング範囲内の最大遮蔽距離
    float len = 0.0f;
    [unroll] //ループ展開する
    for(int i=-SampCount; i<=SampCount; i++){
       float4 c = tex2D( SoftShadowView, Tex+float2(i*ceil(GaussianLangth/SampCount), 0)/TEXSIZE );
       len = max(len, c.g * 100.0f + c.b * 10.0f);
    }

    // サンプリング間隔
    float  LStep = 0.12f*SampCount/TEXSIZE * min(len/GaussianLangth, 1.0f);
    float4 Color = tex2D( SoftShadowView, Tex );

    float r = WT_0 * Color.r;
    r += WT_1 * ( tex2D( SoftShadowView, Tex+float2(LStep  , 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep  , 0) ).r );
    r += WT_2 * ( tex2D( SoftShadowView, Tex+float2(LStep*2, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*2, 0) ).r );
    r += WT_3 * ( tex2D( SoftShadowView, Tex+float2(LStep*3, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*3, 0) ).r );
    r += WT_4 * ( tex2D( SoftShadowView, Tex+float2(LStep*4, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*4, 0) ).r );
    r += WT_5 * ( tex2D( SoftShadowView, Tex+float2(LStep*5, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*5, 0) ).r );
    r += WT_6 * ( tex2D( SoftShadowView, Tex+float2(LStep*6, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*6, 0) ).r );
    r += WT_7 * ( tex2D( SoftShadowView, Tex+float2(LStep*7, 0) ).r + tex2D( SoftShadowView, Tex-float2(LStep*7, 0) ).r );

    Color.r = r;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{
    // サンプリング範囲内の最大遮蔽距離
    float len = 0.0f;
    [unroll] //ループ展開する
    for(int i=-SampCount; i<=SampCount; i++){
       float4 c = tex2D( SoftShadowView, Tex+float2(0, i*ceil(GaussianLangth/SampCount))/TEXSIZE );
       len = max(len, c.g * 100.0f + c.b * 10.0f);
    }

    // サンプリング間隔
    float  LStep = 0.12f*SampCount/TEXSIZE * min(len/GaussianLangth, 1.0f);
    float4 Color = tex2D( ScnSampX, Tex );

    float r = WT_0 * Color.r;
    r += WT_1 * ( tex2D( ScnSampX, Tex+float2(0, LStep  ) ).r + tex2D( ScnSampX, Tex-float2(0, LStep  ) ).r );
    r += WT_2 * ( tex2D( ScnSampX, Tex+float2(0, LStep*2) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*2) ).r );
    r += WT_3 * ( tex2D( ScnSampX, Tex+float2(0, LStep*3) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*3) ).r );
    r += WT_4 * ( tex2D( ScnSampX, Tex+float2(0, LStep*4) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*4) ).r );
    r += WT_5 * ( tex2D( ScnSampX, Tex+float2(0, LStep*5) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*5) ).r );
    r += WT_6 * ( tex2D( ScnSampX, Tex+float2(0, LStep*6) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*6) ).r );
    r += WT_7 * ( tex2D( ScnSampX, Tex+float2(0, LStep*7) ).r + tex2D( ScnSampX, Tex-float2(0, LStep*7) ).r );

    Color.r = r;
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
VS_OUTPUT SoftShadow_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 SoftShadow_PS(float2 Tex : TEXCOORD0) : COLOR0
{
    float4 Color = tex2D(ScnSampY, Tex);
    return float4(MaterialColor, Color.r * MaterialDiffuse.a);
}

///////////////////////////////////////////////////////////////////////////////////////////////
technique MainTec <
    string Script = 
        "RenderColorTarget0=ScnMapX;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMapY;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	   "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_passY();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 SoftShadow_VS();
        PixelShader  = compile ps_2_0 SoftShadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
