////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PC_Object.fx モデルの形状をマスクするエフェクト
//  ( PostClip_Obj.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換パラメータ
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;

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
// ボード面への描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    // ワールドビュー射影座標変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

//ピクセルシェーダ(エッジ描画)
float4 PS_EdgeMask(VS_OUTPUT IN) : COLOR
{
    // クリップするところを白で塗り潰し
    return float4(1, 1, 1, 1);
}

//ピクセルシェーダ(オブジェクト描画)
float4 PS_ObjectMask(VS_OUTPUT IN, uniform bool useTexture) : COLOR
{
    float alpha = MaterialDiffuse.a;

    if ( useTexture ) {
        // テクスチャ透過値適用
        alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
    }

    clip(alpha - 0.005f);

    // クリップするところを白で塗り潰し
    return float4(1, 1, 1, 1);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader = compile ps_2_0 PS_EdgeMask();
    }
}

technique Mask0 < string MMDPass = "object"; bool UseTexture = false; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader = compile ps_2_0 PS_ObjectMask(false);
    }
}

technique Mask1 < string MMDPass = "object"; bool UseTexture = true; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader = compile ps_2_0 PS_ObjectMask(true);
    }
}

technique MaskSS0 < string MMDPass = "object_ss"; bool UseTexture = false; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader = compile ps_2_0 PS_ObjectMask(false);
    }
}

technique MaskSS1 < string MMDPass = "object_ss"; bool UseTexture = true; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader = compile ps_2_0 PS_ObjectMask(true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

// 地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは描画しない
technique ZplotTec < string MMDPass = "zplot"; > { }

