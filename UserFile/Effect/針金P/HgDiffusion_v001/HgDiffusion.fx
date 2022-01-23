////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgDiffusion.fx ver0.0.1  ディフュージョンフィルター
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ハイライトの抽出方法
#define  PickHighLight  3    // 1:ベクトル長, 2:rgb等平均, 3:NTSC系加重平均

// ハイライト判定の閾値
float HighLightThreshold = 0.8;

// ぼかし画像の合成比
float MixingMax = 0.8;  // 最大値を設定してTrで調整


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
float WT_COEF[8] = { 0.0920246,
                     0.0902024,
                     0.0849494,
                     0.0768654,
                     0.0668236,
                     0.0558158,
                     0.0447932,
                     0.0345379 };


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float3 AcsXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
static float HLightThreshold = AcsXYZ.x + HighLightThreshold;
static float MixMax = (AcsXYZ.y + MixingMax) * AcsTr;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5f,0.5f)/ViewportSize);
static float2 SampStep = (float2(1.0f,1.0f)/ViewportSize) * AcsSi * 0.1f;

// サンプリングするミップマップレベル
//static float MipLv = log2( max(ViewportSize.x*SampStep.x, 1.0f) );
static float MipLv = 0.0f;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float  ClearDepth = 1.0f;

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
// ハイライトの抽出

float GetHighLight(float4 Color)
{
    // 1:ベクトル長
    #if(PickHighLight==1)
    float light = length(Color.rgb);
    #endif
    // 2:rgb等平均グレースケール
    #if(PickHighLight==2)
    float light = (Color.r + Color.g + Color.b) * 0.3333333f;
    #endif
    // 3:NTSC系加重平均
    #if(PickHighLight==3)
    float light = 0.298912f * Color.r + 0.586611f * Color.g + 0.114478f * Color.b;
    #endif

    return step(HLightThreshold, light);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
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

float4 PS_DiffusionX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color;
    float4 sumColor = 0;
    float  sumRate = 0;
    float  isHigh;

    // ハイライトのディフューズ
    [unroll]
    for(int i=1; i<8; i++){
        Color = tex2Dlod( ScnSamp, float4(Tex.x - SampStep.x*i, Tex.y, 0, MipLv) );
        isHigh = GetHighLight(Color);
        sumColor += WT_COEF[i] * Color * isHigh;
        sumRate += WT_COEF[i] * isHigh;

        Color = tex2Dlod( ScnSamp, float4(Tex.x + SampStep.x*i, Tex.y, 0, MipLv) );
        isHigh = GetHighLight(Color);
        sumColor += WT_COEF[i] * Color * isHigh;
        sumRate += WT_COEF[i] * isHigh;
    }
    Color = tex2Dlod( ScnSamp, float4(Tex, 0, MipLv) );
    isHigh = GetHighLight(Color);
    sumColor += WT_COEF[0] * Color * isHigh;
    sumRate += WT_COEF[0] * isHigh;
    sumColor /= sumRate;

    return float4(sumColor.rgb, sumRate);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_DiffusionY(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;
    float4 sumColor = 0;
    float  sumRate = 0;
    float  sumRate2 = 0;
    float  isHigh;

    // ハイライトのディフューズ
    float a0 = tex2D( ScnSamp2, Tex ).a;
    [unroll]
    for(int i=1; i<8; i++){
        Color = tex2D( ScnSamp2, Tex - float2(0, SampStep.y*i) );
        isHigh = GetHighLight(Color);
        sumColor += WT_COEF[i] * Color * isHigh;
        sumRate += WT_COEF[i] * isHigh;
        sumRate2 += WT_COEF[i] * max(Color.a, a0);

        Color = tex2D( ScnSamp2, Tex + float2(0, SampStep.y*i) );
        isHigh = GetHighLight(Color);
        sumColor += WT_COEF[i] * Color * isHigh;
        sumRate += WT_COEF[i] * isHigh;
        sumRate2 += WT_COEF[i] * max(Color.a, a0);
    }
    Color = tex2D( ScnSamp2, Tex );
    isHigh = GetHighLight(Color);
    sumColor += WT_COEF[0] * Color * isHigh;
    isHigh = GetHighLight(Color);
    sumRate += WT_COEF[0] * isHigh;
    sumRate2 += WT_COEF[0] * max(Color.a, a0);
    //sumRate2 = saturate( sumRate2*1.5 );
    sumColor /= sumRate;

    // 元画像との合成
    Color = float4(sumColor.rgb, 1);
    float4 Color0 = tex2D(ScnSamp, Tex);
    Color = lerp(Color0, Color, sumRate2);
    if( GetHighLight(Color0) ) Color = Color0;
    Color = lerp(Color0, Color, MixMax);

    return float4(Color.rgb, Color0.a);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique Diffusion <
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
            "Pass=Diffusion_X;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=Diffusion_Y;"
    ;
> {
    pass Diffusion_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DiffusionX();
    }
    pass Diffusion_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DiffusionY();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
