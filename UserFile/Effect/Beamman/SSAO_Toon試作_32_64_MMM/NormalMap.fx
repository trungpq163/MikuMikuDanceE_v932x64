// パラメータ宣言


// 座法変換行列
float4x4 matWVP      : WORLDVIEWPROJECTION;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Normal     : COLOR0;      // 法線
    float2 Tex	  : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex: TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Out.Pos = mul( Pos, matWVP );

    Out.Normal = (normalize(Normal) + 1.0) / 2.0;
    Out.Tex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	float4 Color;
	return float4(IN.Normal.x, IN.Normal.y, IN.Normal.z, 1);

}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
