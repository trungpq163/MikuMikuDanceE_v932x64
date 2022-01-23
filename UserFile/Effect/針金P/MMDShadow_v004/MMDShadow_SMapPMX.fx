////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MMDShadowMapPMX.fx : MMDShadow シャドウマップ作成(PMXでシャドウマップOFF指定のあるモデルに適応)
//  ( MMDShadow.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// PMXの材質でシャドウマップOFFの材質番号をリストアップする  例) "3,5,12"
#define NONE_SHADOWMAP  "10000"


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define MMDSHADOWMAPDRAW

// 共通のシャドウマップパラメータを取り込む
#include "MMDShadow_Header.fxh"


// 透過値に対する深度読み取り閾値
float AlphaClipThreshold = 0.005;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;

bool opadd; // 加算合成フラグ

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifndef MIKUMIKUMOVING
    bool parthf;
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
    };
    #define MMM_SKINNING
    #define GETPOS  (IN.Pos)
#else
    #define parthf  MMDShadow_ParthFlag
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define MMM_SKINNING  MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    #define GETPOS  (SkinOut.Position)
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// Zプロット描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;    // 射影変換座標
    float4 PPos : TEXCOORD0;   // 射影変換座標
    float2 Tex  : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT VS_ShadowMap(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    MMM_SKINNING

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( GETPOS, MMDShadow_GetLightWorldViewProjMatrix(parthf) );
    Out.PPos = Out.Pos;

    // テクスチャ座標
    Out.Tex = IN.Tex;

    return Out;
}

// ピクセルシェーダ
float4 PS_ShadowMap(VS_OUTPUT IN, uniform bool useTexture) : COLOR
{
    // α値
    float alpha = MaterialDiffuse.a;

    // α値が0.98の材質はシャドウマップには描画しない
    clip(abs(alpha - 0.98f) - 0.00001f);

    // 加算合成モデルはシャドウマップには描画しない
    clip( !opadd - 0.001f );

    if ( useTexture ) {
        // テクスチャ透過値適用
        alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
    }
    // α値が閾値以下の箇所はシャドウマップには描画しない
    clip(alpha - AlphaClipThreshold);

    // Z値
    float z = saturate(IN.PPos.z / IN.PPos.w);

    return float4(z, z*z, 0, 1);
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

// シャドウマップを描画しない材質
technique NoneDepthTec   < string MMDPass = "object";    string Subset = NONE_SHADOWMAP; > { }
technique NoneDepthTecSS < string MMDPass = "object_ss"; string Subset = NONE_SHADOWMAP; > { }


// オブジェクト描画(セルフシャドウなし)
technique DepthTec0 < string MMDPass = "object"; bool UseTexture = false; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_ShadowMap();
        PixelShader  = compile ps_3_0 PS_ShadowMap(false);
    }
}

technique DepthTec1 < string MMDPass = "object"; bool UseTexture = true; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_ShadowMap();
        PixelShader  = compile ps_3_0 PS_ShadowMap(true);
    }
}

// オブジェクト描画(セルフシャドウあり)
technique DepthTecSS0 < string MMDPass = "object_ss"; bool UseTexture = false; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_ShadowMap();
        PixelShader  = compile ps_3_0 PS_ShadowMap(false);
    }
}

technique DepthTecSS1 < string MMDPass = "object_ss"; bool UseTexture = true; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_ShadowMap();
        PixelShader  = compile ps_3_0 PS_ShadowMap(true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////

// 輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
// 地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }

