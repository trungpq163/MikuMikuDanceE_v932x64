////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


float4 Color_White = {1,1,1,1};
float4 Color_Black = {0,0,0,1};

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float alpha2 : CONTROLOBJECT < string name = "BlackOut.pmd"; string item = "Trans"; >;

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
    Out.Pos.zw = 1;
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Black( ) : COLOR0
{
	float4 color = Color_Black;
	color.a = alpha1 * (1 - alpha2);
    return color;
}


technique BlackOut {
    
    pass Single_Pass {
    	ZENABLE = false;
    	VertexShader = compile vs_2_0 VS_Black();
        PixelShader  = compile ps_2_0 PS_Black();
    }    
}

technique BlackOutSS < string MMDPass = "object_ss"; > {
    
    pass Single_Pass {
    	ZENABLE = false;
    	VertexShader = compile vs_2_0 VS_Black();
        PixelShader  = compile ps_2_0 PS_Black();
    }
}

