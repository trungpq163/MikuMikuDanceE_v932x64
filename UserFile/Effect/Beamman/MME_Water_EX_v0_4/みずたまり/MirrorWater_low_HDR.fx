// 変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

//HDR情報を保存するテクスチャ
shared texture HDROutTex : RenderColorTarget;

sampler HDROutSamp = sampler_state
{
	Texture = <HDROutTex>;
	Filter = LINEAR;
};

// 頂点シェーダ
struct OutVS
{
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};

OutVS Test_VS(float4 Pos : POSITION,float2 Tex : TEXCOORD0)
{
	OutVS Out;
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Tex = Tex*float2(-1,1);
    return Out;
}

// ピクセルシェーダ
float4 Test_PS(OutVS IN) : COLOR
{
	return tex2D(HDROutSamp,IN.Tex);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

// オブジェクト描画用テクニック
technique MainPass  < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Test_VS();
        PixelShader  = compile ps_2_0 Test_PS();
    }
}
technique MainPass_SS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Test_VS();
        PixelShader  = compile ps_2_0 Test_PS();
    }
}
