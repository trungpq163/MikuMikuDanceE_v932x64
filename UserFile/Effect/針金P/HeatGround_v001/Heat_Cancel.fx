////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Heat_PosDepthMMM.fxsub  位置・深度マップ作成(MME・MMM供用)
//  ( HeatGround.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 透過値に対する深度読み取り閾値
float AlphaClipThreshold = 0.5;

// 座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix     : WORLDVIEW;
float4x4 WorldMatrix         : WORLD;
float4x4 ProjMatrix          : PROJECTION;

//カメラ位置
float3 CameraPosition  : POSITION < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
float4 EdgeColor       : EDGECOLOR;

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
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
        float3 Normal : NORMAL;
    };
    #define MMM_SKINNING
    #define GETPOS      (IN.Pos)
    #define GETPOSEDGE  (0.0f)
    #define GET_WVPMAT(p) (WorldViewProjMatrix)
#else
    float  EdgeWidth : EDGEWIDTH;
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define MMM_SKINNING  MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    #define GETPOS      (SkinOut.Position)
    #define GETPOSEDGE  (float4(SkinOut.Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(Pos.xyz, CameraPosition))
    #define GET_WVPMAT(p) (MMM_IsDinamicProjection ? mul(WorldViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : WorldViewProjMatrix)
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 深度描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 WPos : TEXCOORD0;
    float2 Tex  : TEXCOORD2;
};

//==============================================
// 頂点シェーダ
//==============================================
VS_OUTPUT VS_Object(VS_INPUT IN, uniform bool isObj)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    MMM_SKINNING

    float4 Pos = GETPOS;
    if( !isObj ) Pos += GETPOSEDGE;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, GET_WVPMAT(Pos) );

    // カメラ視点のワールド変換
    Out.WPos = mul( Pos, WorldMatrix );

    // テクスチャ座標
    Out.Tex = IN.Tex;

    return Out;
}

//==============================================
// ピクセルシェーダ
//==============================================
float4 PS_Object(VS_OUTPUT IN, uniform bool isObj, uniform bool useTexture) : COLOR0
{
    float alpha;
    if( isObj ) {
        alpha = MaterialDiffuse.a * !opadd;
        if ( useTexture ) {
            // テクスチャ透過値適用
            alpha *= tex2D( ObjTexSampler, IN.Tex ).a * !opadd;
        }
    }else{
        alpha = EdgeColor.a * !opadd;
    }
    // α値が閾値以下の箇所は描画しない
    clip(alpha - AlphaClipThreshold);

    return float4(IN.WPos.xyz / IN.WPos.w, 0.0f);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

// エッジ描画
technique EdgeDepthTec < string MMDPass = "edge"; >
{
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_3_0 VS_Object(false);
        PixelShader  = compile ps_3_0 PS_Object(false, false);
    }
}

// オブジェクト描画(セルフシャドウなし)
technique DepthTec0 < string MMDPass = "object"; bool UseTexture = false; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_Object(true);
        PixelShader  = compile ps_2_0 PS_Object(true, false);
    }
}

technique DepthTec1 < string MMDPass = "object"; bool UseTexture = true; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_Object(true);
        PixelShader  = compile ps_2_0 PS_Object(true, true);
    }
}

// オブジェクト描画(セルフシャドウあり)
technique DepthTecSS0 < string MMDPass = "object_ss"; bool UseTexture = false; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_Object(true);
        PixelShader  = compile ps_2_0 PS_Object(true, false);
    }
}

technique DepthTecSS1 < string MMDPass = "object_ss"; bool UseTexture = true; >
{
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_Object(true);
        PixelShader  = compile ps_2_0 PS_Object(true, true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

//地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }

