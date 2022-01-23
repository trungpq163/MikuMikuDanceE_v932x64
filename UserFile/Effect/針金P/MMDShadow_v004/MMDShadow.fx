////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MMDShadow.fx ver0.0.3  エフェクトのみで実装したMMD標準シャドウマップと同等のセルフシャドウ描画
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "object";
    string ScriptOrder = "standard";
> = 0.8;

#define MMDSHADOW_MAIN
#include "MMDShadow_Header.fxh"

// シャドウマップバッファサイズ
#define SMAPSIZE_WIDTH   ShadowMapSize
#define SMAPSIZE_HEIGHT  ShadowMapSize

#if UseSoftShadow==1
    #define TEX_FORMAT  "D3DFMT_G32R32F"
    #define TEX_MIPLEVELS  0
#else
    #define TEX_FORMAT  "D3DFMT_R32F"
    #define TEX_MIPLEVELS  1
#endif

// オフスクリーンシャドウマップバッファ
shared texture MMD_ShadowMap : OFFSCREENRENDERTARGET <
    string Description = "MMDShadow.fxのシャドウマップ";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format = TEX_FORMAT;
    bool AntiAlias = false;
    int Miplevels = TEX_MIPLEVELS;
    string DefaultEffect = 
        "self = hide;"
        "* = MMDShadow_ShadowMap.fxsub;";
>;

////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef MIKUMIKUMOVING
// MMM入力パラメータの受け渡し用

bool ParthFlag <        // クリップ反転
    string UIName = "mode";
    string UIHelp = "MMDのセルフシャドウモードフラグ OFF:mode1, ON:mode2";
    bool UIVisible =  true;
> = false;

float SelfShadowLength <
    string UIName = "影範囲";
    string UIHelp = "MMDの｢セルフシャドウ操作｣における｢影範囲｣入力値";
    //string UIWidget = "Slider";
    string UIWidget = "Numeric";
    bool UIVisible =  true;
    float UIMin = 0.0;
    float UIMax = 9999.0;
> = float( 8875.0 );

// パラメータ保存用テクスチャ
shared texture MMDShadow_ParamTex : RENDERCOLORTARGET
<
    int Width  = 1;
    int Height = 1;
    int Miplevels = 1;
    string Format = "D3DFMT_R32F";
>;
texture ParamDepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width  = 1;
    int Height = 1;
    string Format = "D3DFMT_D24S8";
>;

// 頂点シェーダ
float4 VS_Param(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

// ピクセルシェーダ
float4 PS_Param() : COLOR
{
    return float4(SelfShadowLength*(ParthFlag ? -1 : 1), 0, 0, 1);
}

#endif
////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        #ifdef MIKUMIKUMOVING
        "RenderColorTarget0=MMDShadow_ParamTex;"
            "RenderDepthStencilTarget=ParamDepthBuffer;"
            "Pass=ParamPass;"
        #endif
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
    ;
> {
    #ifdef MIKUMIKUMOVING
    pass ParamPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_Param();
        PixelShader  = compile ps_2_0 PS_Param();
    }
    #endif
}

////////////////////////////////////////////////////////////////////////////////////////////////

// 地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// Zプロットは描画しない
technique ZplotTec < string MMDPass = "zplot"; > { }

