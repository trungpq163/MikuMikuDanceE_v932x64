

float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

// 頂点数
int VertexCount;

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Color      : COLOR0;      // ディフューズ色
};


VS_OUTPUT Basic_VS(float4 Pos : POSITION, int index: _INDEX)
{
    VS_OUTPUT Out;
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    float f = (float)index/VertexCount;
    Out.Color = float4(f,f,f,1);
    
    return Out;
}

float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    return IN.Color;
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique MainTecSS < string MMDPass = "object_ss"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 輪郭なし
technique EdgeTec < string MMDPass = "edge"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 影なし
technique ShadowTec < string MMDPass = "shadow"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////

