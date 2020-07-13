// パラメータ宣言


float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
// 座法変換行列
float4x4 matWVP      : WORLDVIEWPROJECTION;
float4x4 matW	     : WORLD;

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

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
    float3 Normal  	  : TEXCOORD0;
    float2 ObjTex	  : TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL,float2 Tex: TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = mul( Pos, matWVP );
    Out.Normal = mul(float4(normalize(Normal),1),matW).xyz;
    Out.ObjTex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN, uniform bool useTex ) : COLOR
{
	float alpha = MaterialDiffuse.a;

	if(useTex)
	{
		alpha = tex2D(ObjTexSampler,IN.ObjTex).a;
	}
	return float4(IN.Normal*0.5+0.5,alpha > 0.9);
}

// オブジェクト描画用テクニック
technique MainTec_1 < string MMDPass = "object"; bool UseTexture = false;> {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false);
    }
}

// オブジェクト描画用テクニック
technique MainTecBS_1  < string MMDPass = "object_ss"; bool UseTexture = false;> {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false);
    }
}
// オブジェクト描画用テクニック
technique MainTec_2 < string MMDPass = "object"; bool UseTexture = true;> {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true);
    }
}

// オブジェクト描画用テクニック
technique MainTecBS_2  < string MMDPass = "object_ss"; bool UseTexture = true;> {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true);
    }
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
