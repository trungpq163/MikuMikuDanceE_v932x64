////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SF_Mask1.fx  マスク画像作成，適用モデルをを白に
//  ( ShadeFader.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;


////////////////////////////////////////////////////////////////////////////////////////////////

// 頂点シェーダ
float4 VS_Mask(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

//ピクセルシェーダ
float4 PS_Mask() : COLOR {
    return float4(1.0, 1.0, 1.0, 1.0);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

//セルフシャドウなし
technique Mask < string MMDPass = "object"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

//セルフシャドウあり
technique MaskSS < string MMDPass = "object_ss"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}


