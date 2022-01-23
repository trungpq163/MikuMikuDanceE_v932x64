////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Ripple.fx 空間歪みエフェクト(波紋の衝撃波っぽいエフェクト,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#ifdef MIKUMIKUMOVING
float RippleTime < // 波紋進行度
   string UIName = "波紋進行度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );
#endif

float Amplitude < // 波紋振幅
   string UIName = "波紋振幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 2.0 );

float AmpRate < // 振幅変位比
   string UIName = "振幅変位比";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );

float WaveCount < // 波紋の数
   string UIName = "波紋の数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 2.0 );

float FreqRate < // 波紋が広がる領域中の波紋のある割合
   string UIName = "波紋割合";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.01;
   float UIMax = 2.0;
> = float( 1.0 );


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define DEPTH_FAR    5000.0f   // 深度最遠値

#define PAI 3.14159265f   // π

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ProjMatrix          : PROJECTION;
float4x4 WorldViewMatrix     : WORLDVIEW;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

// カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifndef MIKUMIKUMOVING
    float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
    #define rippleTime  AcsTr
    #define GET_WVPMAT(p) (WorldViewProjMatrix)
#else
    #define rippleTime  RippleTime
    #define GET_WVPMAT(p) (MMM_IsDinamicProjection ? mul(WorldViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : WorldViewProjMatrix)
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

// 波紋変位量
float CalcZ(float R)
{
    float minLen1 = - FreqRate+(FreqRate+1)*rippleTime;
    float minLen2 = - FreqRate*0.2f+(FreqRate+1)*rippleTime;
    float maxLen  = (FreqRate+1.0f)*rippleTime;

    float z = -0.05f * Amplitude * (cos(2.0f*PAI*(WaveCount*R/FreqRate - WaveCount*(FreqRate+1)/FreqRate*rippleTime))-1.0f);
    z *= smoothstep(minLen1, minLen2, R) * step(R, maxLen);
    z *= smoothstep(-1.0f, -0.2f, -R);
    z *= 1.0f - R;

    return z;
}

// 波紋変位勾配
float CalcGrad(float R)
{
    float z0 = CalcZ( R - 1.0f / 128.0f );
    float z1 = CalcZ( R + 1.0f / 128.0f );
    return (z1-z0)*64.0f;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 法線・深度描画

struct VS_OUTPUT {
    float4 Pos    : POSITION;   // 射影変換座標
    float3 Normal : TEXCOORD0;  // 法線
    float4 VPos   : TEXCOORD1;  // ビュー座標
};

// 頂点シェーダ
VS_OUTPUT VS_Object( float4 Pos : POSITION )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    float R = length(Pos.xy);

    Pos.z = CalcZ(R) * AmpRate;
    float grad = CalcGrad(R);

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, GET_WVPMAT(Pos) );

    // カメラ視点のワールドビュー変換
    Out.VPos = mul( Pos, WorldViewMatrix );

    // 法線のカメラ視点のワールドビュー変換
    float3 Normal = float3(grad*Pos.x/R, grad*Pos.y/R, -1);
    Out.Normal = normalize( Normal );

    return Out;
}

//ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN) : COLOR
{
    // 法線(0～1になるよう補正)
    float3 Normal = (IN.Normal + 1.0f) / 2.0f;

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画(セルフシャドウなし)
technique DepthTec1 < string MMDPass = "object"; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object();
    }
}

// オブジェクト描画(セルフシャドウあり)
technique DepthTecSS1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Object();
        PixelShader  = compile ps_3_0 PS_Object();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
//エッジ・地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

