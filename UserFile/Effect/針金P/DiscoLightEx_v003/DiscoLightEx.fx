////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DiscoLightEx.fx v0.0.3
//  作成: 針金P( 舞力介入P氏のDiscoLighting改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
//(DLEX_Object.fxsubと同名パラメータは同じ値に設定してください)

// セルフシャドウの有無
#define Use_SelfShadow  1  // 0:なし, 1:有り

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024   // 512, 1024, 2048, 4096 のどれかで選択



// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

#ifdef MIKUMIKUMOVING
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// テクスチャフォーマット
#define TEX_FORMAT "D3DFMT_A16B16G16R16F"

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

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_D24S8";
>;
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 動的双放物面シャドウマップ描画先オフスクリーンバッファ

#if Use_SelfShadow==1

#define SMAPSIZE_WIDTH   ShadowMapSize
#define SMAPSIZE_HEIGHT  ShadowMapSize

shared texture DL_ShadowMap : OFFSCREENRENDERTARGET <
    string Description = "DiscoLightEx.fxのシャドウマップバッファ";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    #if UseSoftShadow==1
    string Format = "D3DFMT_G32R32F" ;
    int Miplevels = 0;
    #else
    string Format = "D3DFMT_R32F" ;
    int Miplevels = 1;
    #endif
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "DiscoLightEx.pmx = hide;"
        "DiscoLightBall.x = hide;"
        "FloorAssist.x = DLEX_ShadowMapFA.fxsub;"
        "* = DLEX_ShadowMap.fxsub;"
    ;
>;

#endif

///////////////////////////////////////////////////////////////////
// DiscoLighting描画先オフスクリーンバッファ

texture DiscoLightingRT: OFFSCREENRENDERTARGET <
    string Description = "DiscoLightEx.fxのモデル描画";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "DiscoLightEx.pmx = hide;"
        "FloorAssist.x = hide;"
        "DiscoLightBall.x = DiscoLightBallMask.fxsub;"
        "* = DLEX_Object.fxsub;" 
    ;
>;
sampler DiscoLightingView = sampler_state {
    texture = <DiscoLightingRT>;
//    texture = <DL_ShadowMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Draw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color = tex2D( DiscoLightingView, Tex );

    #ifdef MIKUMIKUMOVING
    float4 Color0 = tex2D( ScnSamp, Tex );
    Color.rgb += Color0.rgb;
    Color.a = Color0.a;
    #endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech1 < string MMDPass = "object";
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
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            #ifndef MIKUMIKUMOVING
            "ScriptExternal=Color;"
            #endif
            "Pass=DrawPass;"
        ; >
{
    pass DrawPass < string Script= "Draw=Buffer;"; > {
        #ifndef MIKUMIKUMOVING
        ZEnable = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        #endif
        VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}


