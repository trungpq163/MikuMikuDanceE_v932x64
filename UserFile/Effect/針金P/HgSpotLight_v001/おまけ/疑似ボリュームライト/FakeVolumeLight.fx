////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FakeVolumeLight.fx ver0.0.1  HgSpotLightに連動した疑似ボリュームライト表現
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_OBJ1   "hide"
    #define OFFSCREEN_OBJ2   "FVL_Object.fxsub"
    #define OFFSCREEN_MASK   "FVL_ObjMask.fxsub"
#else
    #define OFFSCREEN_OBJ1   "FVL_ObjectMMM.fxsub"
    #define OFFSCREEN_OBJ2   "hide"
    #define OFFSCREEN_MASK   "FVL_ObjMaskMMM.fxsub"
#endif

// テクスチャフォーマット
#define TEX_FORMAT "D3DFMT_A16B16G16R16F"

// オフスクリーン疑似ボリュームライト描画バッファ
texture FVL_Draw: OFFSCREENRENDERTARGET <
    string Description = "FakeVolumeLight.fxのオブジェクト描画";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = {0, 0, 0, 1};
    float ClearDepth = 1.0;
    string Format = TEX_FORMAT;
    int MipLevels = 0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "HgSpotLight.pmx =" OFFSCREEN_OBJ1 ";"
        "FVL_Obj.pmx =" OFFSCREEN_OBJ2 ";"
        "* =" OFFSCREEN_MASK ";";
>;
sampler ObjLightSamp = sampler_state {
    texture = <FVL_Draw>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// コントロールパラメータ
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(1,1)/ViewportSize) * AcsSi * 0.1;

// サンプリングするミップマップレベル
static float MipLv = log2( max(ViewportSize.x*SampStep.x, 1.0f) );

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

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

#ifdef MIKUMIKUMOVING
// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
#endif

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

VS_OUTPUT VS_pass( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
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
    float4 Color = WT_COEF[0] * tex2Dlod( ObjLightSamp, float4(Tex,0,MipLv) );
    [unroll]
    for(int i=1; i<8; i++){
        Color += WT_COEF[i] * tex2Dlod( ObjLightSamp, float4(Tex.x-SampStep.x*i,Tex.y,0,MipLv) );
        Color += WT_COEF[i] * tex2Dlod( ObjLightSamp, float4(Tex.x+SampStep.x*i,Tex.y,0,MipLv) );
    }
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color = WT_COEF[0] * tex2D( ScnSamp2, Tex );
    [unroll]
    for(int i=1; i<8; i++){
        Color += WT_COEF[i] * tex2D( ScnSamp2, Tex-float2(0,SampStep.y*i) );
        Color += WT_COEF[i] * tex2D( ScnSamp2, Tex+float2(0,SampStep.y*i) );
    }

    #ifdef MIKUMIKUMOVING
    float4 Color0 = tex2D( ScnSamp, Tex );
    Color.rgb += Color0.rgb;
    Color.a = Color0.a;
    #endif

    Color.rgb *= AcsTr;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        #ifdef MIKUMIKUMOVING
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        #endif
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=Gaussian_X;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            #ifndef MIKUMIKUMOVING
            "ScriptExternal=Color;"
            #endif
            "Pass=Gaussian_Y;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_pass();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        #ifndef MIKUMIKUMOVING
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        #endif
        VertexShader = compile vs_3_0 VS_pass();
        PixelShader  = compile ps_3_0 PS_passY();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
