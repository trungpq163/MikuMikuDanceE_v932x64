////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FireLight.fx v0.0.3   炎っぽい点光源エフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ライトID番号
#define  LightID  3   // 1～4以外で新たに光源を増やす場合はファイル名変更とこの値を5,6,7･･と変えていく

// セルフシャドウの有無
#define Use_SelfShadow  1  // 0:なし, 1:有り

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024   // 512, 1024, 2048, 4096 のどれかで選択

//-----------------------------------------------------
#ifndef MIKUMIKUMOVING
// MMEのみここのパラメータを変更してください(MMMはプロパティシートより変更可能)

// ソフトシャドウのぼかし強度
float ShadowBulrPower = 1.0;  // 0.5～5.0程度で調整

// セルフ影の濃度(0.0～1.0で調整)
float ShadowDensity = 1.0f;

// 光源の距離に対する減衰量係数(0.0～1.0で調整)
float Attenuation = 0.2;

// 光源よる散乱光の強さ(0.0～1.0程度)
float AmbientPower = 0.03;

// ライト色
float3 LightColor = {1.0, 0.3, 0.0}; // ライトの色

// 炎の揺らぎパラメータ
float firePosAmpFactor = 0.7;   // 炎の位置の揺らぎ振幅
float firePosFreqFactor = 0.4;  // 炎の位置の揺らぎ周波数
float firePowAmpFactor = 0.3;   // 炎の明るさ揺らぎ振幅
float firePowFreqFactor = 5.0;  // 炎の明るさ揺らぎ周波数


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////

float3 AcsRxyz : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;

static float3 degRxyz = degrees(AcsRxyz);
static float posAmp  = firePosAmpFactor  * max(degRxyz.x + 1.0f, 0.0f);  // 炎の位置の揺らぎ振幅
static float posFreq = firePosFreqFactor * max(degRxyz.y + 1.0f, 0.0f);  // 炎の位置の揺らぎ周波数
static float powAmp  = firePowAmpFactor;                                 // 炎の明るさ揺らぎ振幅
static float powFreq = firePowFreqFactor * max(degRxyz.z + 1.0f, 0.0f);  // 炎の明るさ揺らぎ周波数

#else

float Attenuation <
   string UIName = "距離減衰";
   string UIHelp = "光源の距離に対する減衰量係数(0.0～1.0で調整)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.2 );

float AmbientPower <
   string UIName = "散乱光";
   string UIHelp = "光源よる散乱光の強さ(0.0～1.0程度)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.03 );

float ShadowBulrPower <
   string UIName = "影ぼかし";
   string UIHelp = "ソフトシャドウのぼかし強度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 1.0 );

float ShadowDensity <
   string UIName = "影濃度";
   string UIHelp = "セルフ影の濃度(0.0～1.0で調整)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 1.0 );

// 炎の揺らぎパラメータ
float posAmp <
   string UIName = "揺れ振幅";
   string UIHelp = "炎の位置の揺らぎ振幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 0.7 );

float posFreq <
   string UIName = "揺れ周波数";
   string UIHelp = "炎の位置の揺らぎ周波数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = float( 0.4 );

float powAmp <
   string UIName = "明度振幅";
   string UIHelp = "炎の明るさ揺らぎ振幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.3 );

float powFreq <
   string UIName = "明度周波数";
   string UIHelp = "炎の明るさ揺らぎ周波数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 5.0 );

float3 LightColor <
   string UIName = "ライト色";
   string UIHelp = "炎の色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(1.0, 0.3, 0.0);


#endif


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


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

#if LightID > 1
    #define  ShadowMap(n)  FL_ShadowMap##n                          // シャドウマップテクスチャ名
    #define  ShadowMap_FileName(n)  "* = FL_ShadowMap"#n".fxsub;"   // シャドウマップfxファイル名
    #define  ShadowMap_FA_FileName(n)  "FloorAssist.x = FL_ShadowMapFA"#n".fxsub;"   // シャドウマップ(床補助)fxファイル名
#else
    #define  ShadowMap(n)  FL_ShadowMap                             // シャドウマップテクスチャ名
    #define  ShadowMap_FileName(n)  "* = FL_ShadowMap.fxsub;"       // シャドウマップfxファイル名
    #define  ShadowMap_FA_FileName(n)  "FloorAssist.x = FL_ShadowMapFA.fxsub;"   // シャドウマップ(床補助)fxファイル名
#endif

#if Use_SelfShadow==1

// シャドウマップバッファサイズ
#if ShadowMapSize==512
    #define SMAPSIZE_WIDTH   512
    #define SMAPSIZE_HEIGHT  1024
#endif
#if ShadowMapSize==1024
    #define SMAPSIZE_WIDTH   1024
    #define SMAPSIZE_HEIGHT  2048
#endif
#if ShadowMapSize==2048
    #define SMAPSIZE_WIDTH   2048
    #define SMAPSIZE_HEIGHT  4096
#endif
#if ShadowMapSize==4096
    #define SMAPSIZE_WIDTH   4096
    #define SMAPSIZE_HEIGHT  8192
#endif

shared texture ShadowMap(LightID) : OFFSCREENRENDERTARGET <
    string Description = "FireLight.fxのシャドウマップバッファ";
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
        "FireLight*.x = hide;"
        ShadowMap_FA_FileName(LightID)
        ShadowMap_FileName(LightID)
    ;
>;

#endif

///////////////////////////////////////////////////////////////////
// FireLighting描画先オフスクリーンバッファ

#if LightID > 1
    #define  ObjectDraw_RT(n)  FireLightingRT##n                // オブジェクト描画テクスチャ名
    #define  ObjectDraw_FileName(n)  "* = FL_Object"#n".fxsub;" // オブジェクト描画fxファイル名
#else
    #define  ObjectDraw_RT(n)  FireLightingRT                 // オブジェクト描画テクスチャ名
    #define  ObjectDraw_FileName(n)  "* = FL_Object.fxsub;"   // オブジェクト描画fxファイル名
#endif

texture ObjectDraw_RT(LightID) : OFFSCREENRENDERTARGET <
    string Description = "FireLight.fxのモデルの点光源オブジェクト描画";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "FloorAssist.x = hide;"
        ObjectDraw_FileName(LightID)
    ;
>;
sampler FireLightingView = sampler_state {
    Texture = <ObjectDraw_RT(LightID)>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

///////////////////////////////////////////////////////////////////
// このファイルの変数をオフスクリーンバッファに渡すためにテクスチャに記録する

#define  OwnerDataTex(n)  FireLight_OwnerDataTex##n                        // データバッファのテクスチャ名
#define  OwnerDataRT(n)  "RenderColorTarget0=FireLight_OwnerDataTex"#n";"  // データバッファのレンダターゲット

shared texture OwnerDataTex(LightID) : RENDERCOLORTARGET <
    int Width=4;
    int Height=1;
    int Miplevels = 1;
    string Format="D3DFMT_A32B32G32R32F";
>;
texture OwnerDataDepthBuffer : RenderDepthStencilTarget <
    int Width=4;
    int Height=1;
    string Format = "D3DFMT_D24S8";
>;

float time : TIME;

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_OwnerData(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex+float2(0.125,0.5);

    return Out;
}

// ピクセルシェーダ
float4 PS_OwnerData(VS_OUTPUT IN) : COLOR
{
    // 炎の光源位置の揺らぎ
    float time2 = time + 0.25;
    float3 ltOffset = float3(posAmp * (0.66f * (abs(frac(2.1f * posFreq * time ) * 2.0f - 1.0f) - 0.5)
                                     + 0.33f * (abs(frac(3.3f * posFreq * time2) * 2.0f - 1.0f) - 0.5) ),
                             posAmp * (0.42f * (abs(frac(3.2f * posFreq * time ) * 2.0f - 1.0f) - 0.5)
                                     + 0.58f * (abs(frac(1.3f * posFreq * time2) * 2.0f - 1.0f) - 0.5) ),
                             posAmp * (0.71f * (abs(frac(2.7f * posFreq * time ) * 2.0f - 1.0f) - 0.5)
                                     + 0.29f * (abs(frac(1.9f * posFreq * time2) * 2.0f - 1.0f) - 0.5) ) );

    // 炎の明るさの揺らぎ
    float ltPow = 1.0f + powAmp * (0.66f * sin(2.1f * time * powFreq)
                                 + 0.33f * cos(3.3f * time * powFreq) );

    if(IN.Tex.x < 0.25f){
       return float4(ltOffset, max(ltPow, 0));
    }else if(IN.Tex.x < 0.5f){
       return float4(ShadowBulrPower, ShadowDensity, 1.0f/max(lerp(0.1f, 5.0f, Attenuation), 0.1f), AmbientPower);
    }else if(IN.Tex.x < 0.75f){
       return float4(LightColor, 0);
    }else{
       return float4(0, 0, 0, 0);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// 頂点シェーダ
VS_OUTPUT VS_Draw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color = tex2D( FireLightingView, Tex );

    #ifdef MIKUMIKUMOVING
    float4 Color0 = tex2D( ScnSamp, Tex );
    Color.rgb += Color0.rgb;
    Color.a = Color0.a;
    #endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech1 <
    string Script = 
        OwnerDataRT(LightID)
            "RenderDepthStencilTarget=OwnerDataDepthBuffer;"
            "Pass=SetOwnerData;"
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
    pass SetOwnerData < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_OwnerData();
        PixelShader  = compile ps_2_0 PS_OwnerData();
    }
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

