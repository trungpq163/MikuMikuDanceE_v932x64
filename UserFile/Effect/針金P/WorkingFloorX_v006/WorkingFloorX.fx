////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WorkingFloorX.fx ver0.0.6  オフスクリーンレンダを使った床面鏡像描画 & Xシャドー描画
//  作成: 針金P( 舞力介入P氏のMirror.fx, full.fx,改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float3 ShadowColor <      // X影の色(RBG)
   string UIName = "X影色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.0, 0.0, 0.0);

#define UseMirror  1    // X影のみで床面鏡像描画を使わない場合はここを0にする

#define XFileMirror  0  // アクセサリ(XFile)も鏡像化する時はここを1にする

#define FLG_EXCEPTION  0  // MMDでモデル鏡像が正常に描画されない場合はここを1にする


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 透過値
float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


#ifndef MIKUMIKUMOVING
    #if(FLG_EXCEPTION == 0)
        #define OFFSCREEN_FX_OBJECT  "WF_Object.fxsub"      // オフスクリーン鏡像描画エフェクト
    #else
        #define OFFSCREEN_FX_OBJECT  "WF_ObjectExc.fxsub"   // オフスクリーン鏡像描画エフェクト
    #endif
    #define ADD_HEIGHT   (0.05f)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define OFFSCREEN_FX_OBJECT  "WF_Object_MMM.fxsub"  // オフスクリーン鏡像描画エフェクト
    #define ADD_HEIGHT   (0.03f)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


#if(UseMirror == 1)
// 床面鏡像描画のオフスクリーンバッファ
texture WorkingFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for WorkingFloorX.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"

        "*.pmd =" OFFSCREEN_FX_OBJECT ";"
        "*.pmx =" OFFSCREEN_FX_OBJECT ";"
        #if(XFileMirror == 1)
        "*.x=   " OFFSCREEN_FX_OBJECT ";"
        "*.vac =" OFFSCREEN_FX_OBJECT ";"
        #endif

        "* = hide;" ;
>;
sampler WorkingFloorView = sampler_state {
    texture = <WorkingFloorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

// X影描画に使うオフスクリーンバッファ
texture FloorXShadowRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for XShadow of WorkingFloorX.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8";
    string DefaultEffect = 
        "self = hide;"
        "*.pmd = WF_XShadow.fxsub;"
        "*.pmx = WF_XShadow.fxsub;"
        "*.x = hide;"
        "* = hide;" ;
>;
sampler XShadowSmp = sampler_state {
    texture = <FloorXShadowRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;


////////////////////////////////////////////////////////////////////////////////////////////////
// 床面鏡像描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 VPos : TEXCOORD1;
};

#if(UseMirror == 1)

// 頂点シェーダ
VS_OUTPUT VS_Mirror(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Pos = mul( Pos, WorldMatrix );
    Pos.y += ADD_HEIGHT;  // 床と重なってちらつくのを回避するため

    // カメラ視点のビュー射影変換
    Pos = mul( Pos, GET_VPMAT(Pos) );

    Out.Pos = Pos;
    Out.VPos = Pos;

    return Out;
}

// ピクセルシェーダ
float4 PS_Mirror(VS_OUTPUT IN) : COLOR
{
    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // 鏡像の色
    float4 Color = tex2D(WorkingFloorView, texCoord);
    Color.a *= AcsTr;

    return Color;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// X影描画

// 頂点シェーダ
VS_OUTPUT VS_XShadow(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Pos = mul( Pos, WorldMatrix );
    Pos.y += ADD_HEIGHT;  // 床と重なってちらつくのを回避するため

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );
    Out.VPos = mul( Pos, ViewProjMatrix );

    return Out;
}

// ピクセルシェーダ
float4 PS_XShadow(VS_OUTPUT IN) : COLOR
{
    // X影のスクリーンの座標
    float2 texCoord = float2( ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;
    float4 Color = tex2D(XShadowSmp, texCoord);
    Color.a = Color.r;
    Color.rgb = ShadowColor;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    #if(UseMirror == 1)
    pass DrawObject{
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    #endif
    pass DrawXShadow{
        VertexShader = compile vs_2_0 VS_XShadow();
        PixelShader  = compile ps_2_0 PS_XShadow();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////



