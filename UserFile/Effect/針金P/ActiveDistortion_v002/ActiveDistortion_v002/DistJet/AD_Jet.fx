////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Jet.fx 空間歪みエフェクト(ジェット噴射による歪み, 法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#ifndef MIKUMIKUMOVING

#define ControlModel  "(self)"  // コントロールモデルファイル名
float4x4 BoneCenter : CONTROLOBJECT < string name = ControlModel; string item = "センター"; >;
float MorphScaleZ0M : CONTROLOBJECT < string name = ControlModel; string item = "噴射元縮小"; >;
float MorphScaleZ0P : CONTROLOBJECT < string name = ControlModel; string item = "噴射元拡大"; >;
float MorphScaleZ1M : CONTROLOBJECT < string name = ControlModel; string item = "噴射先縮小"; >;
float MorphScaleZ1P : CONTROLOBJECT < string name = ControlModel; string item = "噴射先拡大"; >;
float MorphScaleLM  : CONTROLOBJECT < string name = ControlModel; string item = "長さ縮小"; >;
float MorphScaleLP  : CONTROLOBJECT < string name = ControlModel; string item = "長さ拡大"; >;
float MorphUScaleP  : CONTROLOBJECT < string name = ControlModel; string item = "直揺らぎ粗"; >;
float MorphUScaleM  : CONTROLOBJECT < string name = ControlModel; string item = "直揺らぎ細"; >;
float MorphVScaleP  : CONTROLOBJECT < string name = ControlModel; string item = "軸揺らぎ粗"; >;
float MorphVScaleM  : CONTROLOBJECT < string name = ControlModel; string item = "軸揺らぎ細"; >;
float MorphVScroll  : CONTROLOBJECT < string name = ControlModel; string item = "スクロール"; >;
float MorphV0Fade   : CONTROLOBJECT < string name = ControlModel; string item = "先フェード"; >;
float MorphV0FadeW  : CONTROLOBJECT < string name = ControlModel; string item = "先フェード幅"; >;
float MorphDist     : CONTROLOBJECT < string name = ControlModel; string item = "歪み度"; >;
static float ScaleZ0 = 1.0f + MorphScaleZ0P*19.0f - MorphScaleZ0M*19.0f/20.0f;
static float ScaleZ1 = 1.0f + MorphScaleZ1P*19.0f - MorphScaleZ1M*19.0f/20.0f;
static float ScaleL = 1.0f + MorphScaleLP*19.0f - MorphScaleLM*19.0f/20.0f;
static float ScaleU = 1.0f + MorphUScaleM*19.0f - MorphUScaleP*19.0f/20.0f;
static float ScaleV = 1.0f + MorphVScaleM*19.0f - MorphVScaleP*19.0f/20.0f;
static float ScrollSpeedV = -MorphVScroll * MorphVScroll * 10.0f;
static float FadeValue = MorphV0Fade;
static float FadeWidth = MorphV0FadeW;
static float DistFactor = 1.0f - sqrt(MorphDist);

#else

float MMMScaleZ0 < // 噴射元サイズ
   string UIName = "噴射元ｻｲｽﾞ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMScaleZ1 < // 噴射先サイズ
   string UIName = "噴射先ｻｲｽﾞ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMScaleL < // 噴射長さサイズ
   string UIName = "噴射長ｻｲｽﾞ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMScaleU < // 直揺らぎ度
   string UIName = "直揺らぎ度";
   string UIHelp = "噴射直角方向の揺らぎのサイズ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMScaleV < // 軸揺らぎ度
   string UIName = "軸揺らぎ度";
   string UIHelp = "噴射軸方向の揺らぎのサイズ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMScroll < // スクロール
   string UIName = "スクロール";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMFade < // フェード
   string UIName = "フェード";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMFadeW < // フェード幅
   string UIName = "フェード幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );

float MMMDist < // 歪み度
   string UIName = "歪み度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 1.0 );

static float ScaleZ0 = pow(20.0f, MMMScaleZ0);
static float ScaleZ1 = pow(20.0f, MMMScaleZ1);
static float ScaleL = pow(20.0f, MMMScaleL);
static float ScaleU = pow(20.0f, -MMMScaleU);
static float ScaleV = pow(20.0f, -MMMScaleV);
static float ScrollSpeedV = -MMMScroll * MMMScroll * 10.0f;
static float FadeValue = MMMFade;
static float FadeWidth = MMMFadeW;
static float DistFactor = MMMDist * MMMDist;

#endif


#define DEPTH_FAR  5000.0f   // 深度最遠値

// 透過値に対する深度読み取り閾値
float AlphaClipThreshold = 0.05;

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;
float4x4 ViewProjMatrix : VIEWPROJECTION;

// カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// ノーマルマップテクスチャ
texture2D NormalMapTex <
    string ResourceName = "NormalMapSample.png";
    int MipLevels = 0;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMapTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// スクロール距離・時間間隔計算

float time : TIME;

// 更新スクロール距離・時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_A32B32G32R32F" ;
>;
sampler TimeTexSmp = sampler_state
{
   Texture = <TimeTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D3DFMT_D24S8";
>;
static float Dt = clamp(time - tex2D(TimeTexSmp, float2(0.5f,0.5f)).z, 0.001f, 0.1f);

float4 UpdatePosTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdatePosTime_PS() : COLOR
{
    float4 Pos = tex2D(TimeTexSmp, float2(0.5f, 0.5f));
    float2 p = Pos.xy - float2(0.3f*ScrollSpeedV*ScaleU, ScrollSpeedV*ScaleV) * Dt;
    if(time < 0.001f) p = float2(0,0);
    return float4(frac(p), time, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
//接空間回転行列取得

float3x3 GetTangentFrame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifndef MIKUMIKUMOVING
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
        float4 AddUV1 : TEXCOORD1;
        float4 AddUV2 : TEXCOORD2;
        float3 Normal : NORMAL;
    };
    #define GETPOS        (IN.AddUV1)
    #define GETNORMAL     (IN.AddUV2.xyz)
    #define GET_WMAT      (BoneCenter)
    #define GET_CENTERVEC (BoneCenter._31_32_33)
    #define GET_VPMAT(p)  (ViewProjMatrix)
#else
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define GETPOS        (IN.Pos)
    #define GETNORMAL     (IN.Normal)
    #define GET_WMAT      (WorldMatrix)
    #define GET_CENTERVEC (WorldMatrix._31_32_33)
    #define GET_VPMAT(p)  (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 法線・深度描画

struct VS_OUTPUT {
    float4 Pos       : POSITION;   // 射影変換座標
    float3 Normal    : TEXCOORD0;  // 法線
    float4 VPos      : TEXCOORD1;  // ビュー座標
    float3 CenterVec : TEXCOORD2;  // 噴射軸方向
    float2 Tex       : TEXCOORD3;  // UV座標
};

// 頂点シェーダ
VS_OUTPUT VS_Object( VS_INPUT IN )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    // ローカル座標
    float4 Pos = GETPOS;

    float scaleXY = lerp(ScaleZ0, ScaleZ1, 1.0f - IN.Tex.y);
    Pos.xyz *= float3(scaleXY, scaleXY, ScaleL);

    // 頂点のワールド座標変換
    float4 WPos = mul(Pos, GET_WMAT);

    // カメラ視点のビュー射影変換
    Out.Pos = mul( WPos, GET_VPMAT(WPos) );

    // カメラ視点のビュー変換
    Out.VPos = mul( WPos, ViewMatrix );

    // 頂点変形に伴う法線の変化
    float3 Normal = GETNORMAL;
    float3 XZ = float3(5.0f*ScaleZ0, 5.0f*ScaleZ1, 40.0f*ScaleL);
    float  len = sqrt( XZ.z*XZ.z + (XZ.x-XZ.y)*(XZ.x-XZ.y) );
    float2 sc = float2( (XZ.y-XZ.x)/len, XZ.z/len );
    Normal = float3(Normal.xy*sc.y, -sc.x);

    // 法線のカメラ視点のワールドビュー変換
    Normal = mul(Normal, (float3x3)GET_WMAT);
    Out.Normal = normalize( mul(Normal, (float3x3)ViewMatrix) );

    // 噴射軸方向のカメラ視点のビュー変換
    Out.CenterVec = normalize( mul(GET_CENTERVEC, (float3x3)ViewMatrix) );

    // テクスチャ座標
    Out.Tex = IN.Tex;

    return Out;
}

//ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN, uniform bool FlagClip) : COLOR
{
    // ノーマルマップを含む法線取得
    float3 eye = normalize(-IN.VPos.xyz / IN.VPos.w);
    float3 normal = normalize(IN.Normal);
    float2 tex0 = tex2D(TimeTexSmp, float2(0.5f,0.5f)).xy;
    float2 tex1 =  float2(IN.Tex.x*ScaleU, IN.Tex.y*ScaleV) + tex0;
    float3x3 tangentFrame1 = GetTangentFrame(normal, eye, tex1);
    float3 Normal1 = mul(2.0f * tex2D(NormalMapSamp, tex1).rgb - 1.0f, tangentFrame1);
    float2 tex2 =  float2(IN.Tex.x*ScaleU, IN.Tex.y*ScaleV) + float2(-tex0.x, tex0.y);
    float3x3 tangentFrame2 = GetTangentFrame(normal, eye, tex2);
    float3 Normal2 = mul(2.0f * tex2D(NormalMapSamp, tex2).rgb - 1.0f, tangentFrame2);
    float3 Normal = normalize( Normal1 + Normal2);

    // フェード透過値計算
    float alpha = smoothstep(FadeValue, FadeValue + max(FadeWidth, 0.01f), saturate(IN.Tex.y));

    // α値が閾値以下の箇所は描画しない
    clip(alpha - AlphaClipThreshold);

    // 噴射外側面の処理
    if( FlagClip ){
        // 噴射先のクリップ
        float3 nrml = lerp(float3(0.0, 0.0, -1.0f), Normal, alpha);
        nrml = lerp(float3(1.0, 0.0, 0.0f), nrml, 1-alpha);
        clip(1-dot(normalize(nrml),float3(0.0, 0.0, -1.0f)) - 0.2);
        // 噴射側面エッジ部ぼかし
        float s = dot( normalize(cross(-eye, IN.CenterVec)), normal );
        float h = min( abs(ScaleZ0 - ScaleZ1)*0.1f, 0.4f );
        alpha *= 1.0f - smoothstep(0.5f+h, 1.0f, abs(s));
    }
    alpha *= DistFactor;

    // 法線(0～1になるよう補正)
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, alpha);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画(セルフシャドウなし)
technique DepthTec0 < string MMDPass = "object";  string Subset = "0";
    string Script = 
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdatePosTime;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "Pass=DrawObject;" ;
>{
    pass UpdatePosTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdatePosTime_VS();
        PixelShader  = compile ps_2_0 UpdatePosTime_PS();
    }
    pass DrawObject {
        ZEnable = TRUE;
        AlphaBlendEnable = FALSE;
        CullMode = CCW;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object(false);
    }
}

technique DepthTec1 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZEnable = TRUE;
        AlphaBlendEnable = FALSE;
        CullMode = CCW;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object(true);
    }
}

// オブジェクト描画(セルフシャドウあり)
technique DepthTecSS0 < string MMDPass = "object_ss";  string Subset = "0";
    string Script = 
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdatePosTime;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "Pass=DrawObject;" ;
>{
    pass UpdatePosTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdatePosTime_VS();
        PixelShader  = compile ps_2_0 UpdatePosTime_PS();
    }
    pass DrawObject {
        ZEnable = TRUE;
        AlphaBlendEnable = FALSE;
        CullMode = CCW;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object(false);
    }
}

technique DepthTecSS1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        ZEnable = TRUE;
        AlphaBlendEnable = FALSE;
        CullMode = CCW;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object(true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
//エッジ・地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

