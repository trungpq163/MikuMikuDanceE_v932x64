////////////////////////////////////////////////////////////////////////////////////////////////
//
// Material Selector for ObjectLuminous.fx
//    初音ミクVer2 Edition
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

//対象とする素材のサブセット番号
#define TargetSubset1 "0,1"
#define TargetSubset2 "8,10"
#define TargetSubset3 ""

//放射光で覆われない素材
#define BlockSubset "2,6,12-16"

//発光色 (RGBA各要素 0.0～1.0)
float4 Emittion_Color1
<
   string UIName = "Emittion Color1";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float4( 0.8, 0.9, 0.2, 0.8 );

float4 Emittion_Color2
<
   string UIName = "Emittion Color2";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float4(  1, 0, 0, 1 );

float4 Emittion_Color3
<
   string UIName = "Emittion Color3";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float4( 1, 0.8, 0, 1.0 );

//ゲイン
float Gain1
<
   string UIName = "Gain 1";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 5.0;
> = float( 0.15 );

float Gain2
<
   string UIName = "Gain 1";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 5.0;
> = float( 0.8 );

float Gain3
<
   string UIName = "Gain 1";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 5.0;
> = float( 1 );


//テクスチャ用キーカラー
float4 KeyTexColor3
<
   string UIName = "KeyTexColor3";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float4( 0, 0, 0, 0 );

//キーカラー認識閾値
float KeyThreshold
<
   string UIName = "Key Threshold";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float( 0.35 );

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

bool ColorMuch(float4 color1, float4 key){
    float4 s = color1 - key;
    return (length(s.rgb) <= KeyThreshold);
}

////////////////////////////////////////////////////////////////////////////////////////////////
//ピクセルシェーダ

float4 PS_Selected1(float2 Tex : TEXCOORD1) : COLOR {
    float4 color = Emittion_Color1;
    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    color.rgb *= (Gain1 * alpha);
    return color;
}
float4 PS_Selected2(float2 Tex : TEXCOORD1) : COLOR {
    float4 color = Emittion_Color2;
    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    color.rgb *= (Gain2 * alpha);
    return color;
}
float4 PS_Selected3(float2 Tex : TEXCOORD1) : COLOR {
    float4 color = Emittion_Color3;
    float4 texcolor;
    float alpha = alpha1;
    if ( use_texture ){
        texcolor = tex2D( ObjTexSampler, Tex );
        alpha *= texcolor.a;
        
        if(KeyTexColor3.a > 0.1){
            if(!(ColorMuch(texcolor, KeyTexColor3))) color.rgb = 0;
        }
    }
    color.rgb *= (Gain3 * alpha);
    return color;
}

float4 PS_Block() : COLOR {
    return float4(0.0, 0.0, 0.0, 0.2);
}
float4 PS_Black(float2 Tex : TEXCOORD1) : COLOR {
    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    return float4(0.0, 0.0, 0.0, alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

//セルフシャドウなし
technique Select1 < string Subset = TargetSubset1; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected1();
    }
}
technique Select2 < string Subset = TargetSubset2; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected2();
    }
}
technique Select3 < string Subset = TargetSubset3; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected3();
    }
}

technique  Block < string Subset = BlockSubset; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Block();
    }
}
technique Mask {
    pass Single_Pass { PixelShader = compile ps_2_0 PS_Black(); }
}

//セルフシャドウあり
technique Select1SS < string MMDPass = "object_ss"; string Subset = TargetSubset1; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected1();
    }
}
technique Select2SS < string MMDPass = "object_ss"; string Subset = TargetSubset2; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected2();
    }
}
technique Select3SS < string MMDPass = "object_ss"; string Subset = TargetSubset3; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Selected3();
    }
}

technique  BlockSS < string MMDPass = "object_ss"; string Subset = BlockSubset; > {
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        PixelShader = compile ps_2_0 PS_Block();
    }
}
technique MaskSS < string MMDPass = "object_ss"; > {
    pass Single_Pass { PixelShader = compile ps_2_0 PS_Black(); }
}

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

