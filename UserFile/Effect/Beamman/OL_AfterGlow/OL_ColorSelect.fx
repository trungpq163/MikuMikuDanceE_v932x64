////////////////////////////////////////////////////////////////////////////////////////////////
//	
//	ObjectLuminous用シンプルエミッター（ほぼBasic.fx）
//	作成：ビームマンP
//  ベース：Basic.fx
//  作成: 舞力介入P
//
////////////////////////////////////////////////////////////////////////////////////////////////

//ユーザ定義変数

//色調 左からRGBA
float4 AddColor = float4(0.05,0,0.5,1);

// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS() : COLOR0
{
    return AddColor;
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec < string MMDPass = "object";> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique MainTec_ss < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}