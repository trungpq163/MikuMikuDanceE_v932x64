////////////////////////////////////////////////////////////////////////////////////////////////
//
// Material Selector for ObjectLuminous.fx
//    指定されたオブジェクトを、元の素材の色で描画します
//    MMEのGUIから、サブセットごとの割り当てに使用できます
//
////////////////////////////////////////////////////////////////////////////////////////////////

float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

bool use_texture;  //テクスチャの有無

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
//ピクセルシェーダ

float4 PS_Selected1(float2 Tex : TEXCOORD1) : COLOR {
    float4 color = MaterialDiffuse;
    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    color.rgb *= (Gain * alpha);
    return color;
}

float4 PS_Black(float2 Tex : TEXCOORD1) : COLOR {
    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    return float4(0.0, 0.0, 0.0, alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

//セルフシャドウなし
technique Tec1 {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected1();
    }
}

//セルフシャドウあり
technique Tec1SS < string MMDPass = "object_ss"; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected1();
    }
}

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

