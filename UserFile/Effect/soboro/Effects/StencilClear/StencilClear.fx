////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
};

// 頂点シェーダ
VS_OUTPUT VS_Black(float4 Pos : POSITION)
{
    VS_OUTPUT Out;
    
    Out.Pos = Pos;
    Out.Pos.z = 0.5;
    Out.Pos.w = 1;
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Black( ) : COLOR0
{
    return float4(0,0,0,0);
}


stateblock state1 = stateblock_state
{
    ZEnable = false;
    AlphaBlendEnable = true;
    AlphaTestEnable = false;
    StencilEnable = true;
    StencilRef = 0;
    StencilFunc = Always;
    StencilFail = Replace;
    StencilPass = Replace;
    VertexShader = compile vs_2_0 VS_Black();
    PixelShader  = compile ps_2_0 PS_Black();
};

technique BlackOut {
    
    pass Single_Pass {
        StateBlock = (state1);
    }    
}

technique BlackOutSS < string MMDPass = "object_ss"; > {
    
    pass Single_Pass {
        StateBlock = (state1);
    }
}

