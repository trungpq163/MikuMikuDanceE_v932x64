////////////////////////////////////////////////////////////////////////////////////////////////
//
// EmittionDraw for AutoLuminous.fx
//
////////////////////////////////////////////////////////////////////////////////////////////////

#define SpecularToneCurve  0.3333f  // 反射率に対する発光変化係数

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;

float AcsAlpha : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


// 発光部の床面鏡像描画のオフスクリーンバッファ
shared texture WF_EmitterRT : OFFSCREENRENDERTARGET;
sampler MirrorEmitterView = sampler_state {
    texture = <WF_EmitterRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


#ifndef MIKUMIKUMOVING
    #define ADD_HEIGHT   (0.05f)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define ADD_HEIGHT   (0.01f)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 VPos : TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド変換
    Pos = mul( Pos, WorldMatrix );
    Pos.y += ADD_HEIGHT;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );
    Out.VPos = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // 鏡像の色
    float4 Color = tex2D(MirrorEmitterView, texCoord);
    Color *= AcsAlpha; // 半透明鏡面の裏側にあるObjを発光させるためα値も乗算

    return Color;
}

float4 ShadowBuff_PS(VS_OUTPUT IN) : COLOR0
{
    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // 鏡像の色
    float4 Color = tex2D(MirrorEmitterView, texCoord);
    Color.rgb *= pow(AcsAlpha, SpecularToneCurve) * step(0.01, AcsAlpha);
    Color.w *= AcsAlpha;

    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        AlphaBlendEnable = TRUE;
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

technique MainTecSS < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = TRUE;
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Basic_VS();
        #ifndef MIKUMIKUMOVING
        PixelShader  = compile ps_2_0 ShadowBuff_PS();
        #else
        PixelShader  = compile ps_2_0 Basic_PS();
        #endif
    }
}


//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

