////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


float4 Color_White = {1,1,1,1};
float4 Color_Black = {0,0,0,1};

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
};

// 頂点シェーダ
VS_OUTPUT VS_Inv(float4 Pos : POSITION)
{
    VS_OUTPUT Out;
    
    Out.Pos = Pos;
    Out.Pos.zw = 1;
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Inv( ) : COLOR0
{
    return Color_White;
}


technique Invert {
    
    pass Single_Pass {
        ZENABLE = false;
        SRCBLEND = INVDESTCOLOR;
        DESTBLEND = ZERO;
        VertexShader = compile vs_2_0 VS_Inv();
        PixelShader  = compile ps_2_0 PS_Inv();
    }
}

technique InvertSS < string MMDPass = "object_ss"; > {
    
    pass Single_Pass {
        ZENABLE = false;
        SRCBLEND = INVDESTCOLOR;
        DESTBLEND = ZERO;
        VertexShader = compile vs_2_0 VS_Inv();
        PixelShader  = compile ps_2_0 PS_Inv();
    }
}
