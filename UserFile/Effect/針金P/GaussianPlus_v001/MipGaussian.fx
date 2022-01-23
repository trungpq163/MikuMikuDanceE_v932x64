////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MipGaussian.fx ver0.0.1  強力なぼかしが掛けられるガウスフィルター(ミップマップフィルター使用)
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

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


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(1,1)/ViewportSize) * AcsSi * 0.1;

// サンプリングするミップマップレベル
static float MipLv = log2( max(ViewportSize.x*SampStep.x, 1.0f) );

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 0;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
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
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

VS_OUTPUT VS_pass( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
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
    float4 Color;

    Color  = WT_0 *   tex2Dlod( ScnSamp, float4(Tex,0,MipLv) );
    Color += WT_1 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x  ,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x  ,Tex.y,0,MipLv) ) );
    Color += WT_2 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*2,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*2,Tex.y,0,MipLv) ) );
    Color += WT_3 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*3,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*3,Tex.y,0,MipLv) ) );
    Color += WT_4 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*4,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*4,Tex.y,0,MipLv) ) );
    Color += WT_5 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*5,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*5,Tex.y,0,MipLv) ) );
    Color += WT_6 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*6,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*6,Tex.y,0,MipLv) ) );
    Color += WT_7 * ( tex2Dlod( ScnSamp, float4(Tex.x+SampStep.x*7,Tex.y,0,MipLv) ) + tex2Dlod( ScnSamp, float4(Tex.x-SampStep.x*7,Tex.y,0,MipLv) ) );
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

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

technique Gaussian <
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=Gaussian_X;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=Gaussian_Y;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_pass();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_pass();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
