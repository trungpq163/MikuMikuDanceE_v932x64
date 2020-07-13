
//アニメーション速度
float AnmTime = 1.0;




// 変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

//
texture LineTex
<
   string ResourceName = "LineTex.png";
>;
texture LineColor
<
   string ResourceName = "LineColor.png";
>;
sampler LineTexSampler = sampler_state
{
   Texture = (LineTex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
	FILTER = LINEAR;
};
sampler LineColorSampler = sampler_state
{
   Texture = (LineColor);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
	FILTER = LINEAR;
};


float fTime : TIME;

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
    Out.Tex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Test_PS(OutVS IN) : COLOR
{
	float4 col = tex2D(LineTexSampler,IN.Tex);
	float l = col.r + fTime * AnmTime;
	col = tex2D(LineColorSampler,float2(l,0.5))*col.a;
    return col;
}
float4 Black_PS(OutVS IN) : COLOR
{
	return float4(0,0,0,1);
}
// オブジェクト描画用テクニック
technique MainPass  < string MMDPass = "object";
	    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObjectBase;"
	    "Pass=DrawObject;"
	    ;
 > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Test_VS();
        PixelShader  = compile ps_2_0 Test_PS();
    }
     pass DrawObjectBase {
     	//MMD標準描画を行う
    }
}
technique MainPass_SS  < string MMDPass = "object_ss"; 	    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObjectBase;"
	    "Pass=DrawObject;"
	    ;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Test_VS();
        PixelShader  = compile ps_2_0 Test_PS();
    }
     pass DrawObjectBase {
     	//MMD標準描画を行う
        VertexShader = compile vs_2_0 Test_VS();
        PixelShader  = compile ps_2_0 Black_PS();
    }
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}