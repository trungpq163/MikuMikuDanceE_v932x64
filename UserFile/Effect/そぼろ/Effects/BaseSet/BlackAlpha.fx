////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float4 DrawColor = float4(0, 0, 0, 1);



// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Tex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
    float4 color = DrawColor;
    color.a *= MaterialDiffuse.a;
    if(useTexture) color.a *= tex2D( ObjTexSampler, IN.Tex ).a;
    return color;
}

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true);
    }
}

technique MainTec0SS < string MMDPass = "object_ss"; bool UseTexture = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false);
    }
}

technique MainTec1SS < string MMDPass = "object_ss"; bool UseTexture = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 輪郭色で塗りつぶし
    return DrawColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 影なし
technique ShadowTec < string MMDPass = "shadow"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

// セルフシャドウなし
technique ZplotTec < string MMDPass = "zplot"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
