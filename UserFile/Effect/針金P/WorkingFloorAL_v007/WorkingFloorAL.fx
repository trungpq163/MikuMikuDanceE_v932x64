////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WorkingFloorAL.fx ver0.0.7  AutoLuminous対応の床面鏡像描画
//  作成: 針金P( 舞力介入P氏のMirror.fx, full.fx, そぼろ氏のAutoLuminous.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
//オプションスイッチ(AutoLuminous.fxと同じ設定にすること)

//発光除外マスクを使用する
//MMEタブに WF_MaskRT が現れます。
//0がオフ、1がオンです
#define MASK_ENABLE  0

//MMD上の描画をHDR情報として扱います
//明るさが1を超えた部分が光って見えるようになります
//0がオフ、1がオンです
#define HDR_RENDER  1

//作業用バッファのサイズを半分にして軽くします
//画質は落ちます
//0がオフ、1がオンです
#define HALF_DRAW  0


////////////////////////////////////////////////////////////////////////////////////
//オプションスイッチ(WorkingFloorAL固有の設定)

// Xシャドウの描画をするかどうか
// 0がオフ、1がオンです
#define UseXShadow  1

float3 ShadowColor <      // X影の色(RBG)
   string UIName = "X影色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.0, 0.0, 0.0);

// 鏡面エフェクトとして使用するか
// 0が床面鏡像描画、1が鏡面エフェクト
#define UseMirror  0

// TrueCameraLXで使用する
//0がオフ、1がオンです
#define UseTrueCameraLX  0

// MMDでモデル鏡像が正常に描画されない場合はここを1にする
#define FLG_EXCEPTION  0


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
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;


#ifndef MIKUMIKUMOVING
    #if(FLG_EXCEPTION == 0)
        #define OFFSCREEN_FX_OBJECT  "WF_Object.fxsub"      // オフスクリーン鏡像描画エフェクト
    #else
        #define OFFSCREEN_FX_OBJECT  "WF_ObjectExc.fxsub"   // オフスクリーン鏡像描画エフェクト
    #endif
    #define ADD_HEIGHT   (0.05f)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define OFFSCREEN_FX_OBJECT  "WF_Object_MMM.fxsub"      // オフスクリーン鏡像描画エフェクト
    #define ADD_HEIGHT   (0.01f)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


//テクスチャフォーマット
#if HDR_RENDER==0
    #define AL_TEXFORMAT "A8R8G8B8"
#else
    //#define AL_TEXFORMAT "A32B32G32R32F"
    #define AL_TEXFORMAT "A16B16G16R16F"
#endif

#if HALF_DRAW==0
    #define TEXSIZE1  1
#else
    #define TEXSIZE1  0.5
#endif

#if UseMirror==0
    #define BUFF_COLOR  { 0, 0, 0, 0 }
#else
    #define BUFF_COLOR  { 0, 0, 0, 1 }
#endif


// 床面鏡像描画のオフスクリーンバッファ
shared texture WorkingFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = BUFF_COLOR;
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string Format = AL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "* =" OFFSCREEN_FX_OBJECT ";"
    ;
>;
sampler WorkingFloorView = sampler_state {
    texture = <WorkingFloorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// 発光部の鏡像描画のオフスクリーンバッファ
shared texture WF_EmitterRT : OFFSCREENRENDERTARGET <
    string Description = "EmitterDrawRenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    int MipLevels = 1;
    string Format = AL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "* = WF_ObjectEmit.fxsub;"
    ;
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// 鏡面マスク描画先オフスクリーンバッファ

#if(MASK_ENABLE != 0)

shared texture WF_MaskRT : OFFSCREENRENDERTARGET <
    string Description = "MaskDrawRenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8";
    string DefaultEffect = 
        "self = hide;"
        "* = hide;"
    ;
>;

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// X影描画に使うオフスクリーンバッファ

#if(UseXShadow != 0)

texture FloorXShadowRT : OFFSCREENRENDERTARGET <
    string Description = "XShadowDrawRenderTarget for WorkingFloorAL.fx";
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
        "* = hide;"
    ;
>;
sampler XShadowSmp = sampler_state {
    texture = <FloorXShadowRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// TrueCameraLX用深度付きベロシティマップ作成に使うオフスクリーンバッファ

//ベロシティマップバッファフォーマット
#define VM_TEXFORMAT "A32B32G32R32F"
//#define VM_TEXFORMAT "A16B16G16R16F"

#define VPRATIO 1.0

#if(UseTrueCameraLX != 0)

shared texture WF_DVMapDraw : OFFSCREENRENDERTARGET <
    string Description = "Depth && Velocity Map Drawing for WorkingFloorAL.fx";
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    float4 ClearColor = { 0.5, 0.5, 100, 1 };
    float ClearDepth = 1.0;
    string Format = VM_TEXFORMAT ;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = WF_TCLXObject.fxsub;"
        ;
>;

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
//床面鏡像描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 VPos : TEXCOORD1;
};

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

////////////////////////////////////////////////////////////////////////////////////////////////
// X影描画

#if(UseXShadow != 0)

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


// X影描画
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

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec0 < string MMDPass = "object"; > {
    pass DrawObject{
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    #if(UseXShadow != 0)
    pass DrawXShadow{
        VertexShader = compile vs_2_0 VS_XShadow();
        PixelShader  = compile ps_2_0 PS_XShadow();
    }
    #endif
}

technique MainTec1 < string MMDPass = "object_ss"; > {
    pass DrawObject{
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    #if(UseXShadow != 0)
    pass DrawXShadow{
        VertexShader = compile vs_2_0 VS_XShadow();
        PixelShader  = compile ps_2_0 PS_XShadow();
    }
    #endif
}

////////////////////////////////////////////////////////////////////////////////////////////////

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }




