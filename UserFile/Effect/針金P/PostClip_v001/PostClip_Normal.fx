////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PostClip (PostClip_Normal.fx) ver0.0.1
//  既存のポストエフェクトを特定領域でクリップ（法線に応じてクリップ）
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// クリップ判定の法線とのなす角(MMEのみ,MMMはエフェクトプロパティで変更)
float ClipAngle = 45.0;

// クリップ合成初期法線
float3 InitNormal = float3(0.0f, 1.0f, 0.0f);


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#include "PostClipHeader.fxh"

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 座標変換行列
float4x4 WorldMatrix : WORLD;

// クリップ合成法線
static float3 ClipNormal = normalize( mul( InitNormal, (float3x3)WorldMatrix ) );

// アクセサリパラメータ
float  AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float  AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#ifndef MIKUMIKUMOVING

    float3 AcsXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
    static bool ClipFlag = (AcsXYZ.x < 0.999f) ? false : true;   // クリップ実行
    static bool MulFlag  = (AcsXYZ.y < 0.999f) ? false : true;   // 論理積合成
    static bool InvFlag  = (AcsXYZ.z < 0.999f) ? false : true;   // クリップ反転

    static float Shift = clamp(ClipAngle/90.0f, -0.999f, 0.999f);

#else

    bool ClipFlag <        // クリップ実行
       string UIName = "クリップ実行";
       bool UIVisible =  true;
    > = true;

    bool MulFlag <        // 論理積合成
       string UIName = "論理積";
       bool UIVisible =  true;
    > = false;

    bool InvFlag <        // クリップ反転
       string UIName = "反転";
       bool UIVisible =  true;
    > = false;

    float Shift0 <
        string UIName = "クリップ基準";
        string UIHelp = "クリップ判定の法線とのなす角";
        string UIWidget = "Slider";
        //string UIWidget = "Numeric";
        bool UIVisible =  true;
        float UIMin = -90.0;
        float UIMax = 90.0;
    > = float( 45.0 );
    static float Shift = clamp(Shift0/90.0f, -0.999f, 0.999f);

#endif

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// ポストエフェクトをかける前の画像
shared texture2D ScnMapSrc : RENDERCOLORTARGET;
sampler2D ScnSampSrc = sampler_state {
    texture = <ScnMapSrc>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// クリップ領域のマッピング画像
shared texture2D ScnClipMap : RENDERCOLORTARGET;
sampler2D ScnSampClip = sampler_state {
    texture = <ScnClipMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_NORMAL "PC_Normal.fxsub"
#else
    #define OFFSCREEN_NORMAL "PC_NormalMMM.fxsub"
#endif

// 法線マップ描画先オフスクリーンバッファ
texture PC_NormalRT: OFFSCREENRENDERTARGET <
    string Description = "PostClipの法線マップバッファ";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0.5, 0.5, 0.5, 0 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_X8R8G8B8" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "PreClip.x = hide;"
        "* =" OFFSCREEN_NORMAL ";";
>;
sampler NormalSamp = sampler_state {
    texture = <PC_NormalRT>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// ポストエフェクトの前と後の画像を合成

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Clip( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

// ピクセルシェーダ
float4 PS_Clip( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 直前までのクリップ合成結果
    float s0 = tex2D( ScnSampClip, Tex ).r;

    // ピクセルの法線
    float3 Normal = 2.0f * tex2D( NormalSamp, Tex ).rgb - 1.0f;

    // このエフェクトのクリップ範囲
    float s = 0.0f;
    if(length(Normal) > 0.01f){
        float x = dot(normalize(Normal), ClipNormal);
        s = clamp((Shift >= 0.0f) ? (x-Shift)/(1.0f-Shift) : -(Shift-x)/(Shift+1.0f), -1.0f, 1.0f);
        s = 0.5f * ( sign(s) * pow( abs(s), max(AcsSi*0.1f, 0.01f) ) + 1.0f );
    }

    // クリップ合成
    if(InvFlag) s = 1.0f - s;
    s *= AcsTr;
    s = MulFlag ? s*s0 : max(s, s0);

    return float4(s, 0, 0, 1);

}

// ピクセルシェーダ(画像描画)
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    // ポストエフェクト処理前の画像
    float4 Color0 = tex2D( ScnSampSrc, Tex );

    // ポストエフェクト処理後の画像
    float4 Color = tex2D( ScnSamp, Tex );

    // クリップ範囲
    float4 s = tex2D( ScnSampClip, Tex ).r;

    // 合成
    if(ClipFlag) Color = lerp(Color0, Color, s);

    return Color;

}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        "RenderColorTarget0=ScnClipMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "Pass=PostClip;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=PostDraw;"
    ;
> {
    pass PostClip < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Clip();
        PixelShader  = compile ps_2_0 PS_Clip();
    }
    pass PostDraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Clip();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
