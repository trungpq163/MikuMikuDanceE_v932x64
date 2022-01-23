////////////////////////////////////////////////////////////////////////////////////////////////
//
//  指定オブジェクトはオフスクリーンのみに描画するため通常描画を非表示にする
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

#ifndef MIKUMIKUMOVING
///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
// 自身のセルフシャドー描画を行うためにZバッファプロットだけは出力する必要有り
struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS();
    }
}

#endif

// 他は全て非表示にする
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique MainTec < string MMDPass = "object"; > { }
technique MainTecBS  < string MMDPass = "object_ss"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
