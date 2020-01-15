

//シルエット色(R,G,B,A　各0～1)
float4 SilhouetteColor = float4(0.25, 0, 1, 0.6);

///////////////////////////////////////////////////////////////////////////////////////////////


// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

bool use_texture;  //テクスチャの有無

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
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
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    
    float4 Color = SilhouetteColor;
    
    Color.a *= MaterialDiffuse.a;
    
    if ( use_texture ) Color.a *= tex2D( ObjTexSampler, IN.Tex ).a;
    
    return Color;
}



stateblock state1 = stateblock_state
{
    StencilEnable = true;
    StencilRef = 5;
    StencilFunc = Greater;
    StencilFail = Keep;
    StencilPass = Replace;
    VertexShader = compile vs_2_0 Basic_VS();
    PixelShader  = compile ps_2_0 Basic_PS();
};

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        StateBlock = (state1);
    }
}
technique MainTecSS < string MMDPass = "object_ss"; > {
    pass DrawObject
    {
        StateBlock = (state1);
    }
}

// 輪郭と影は描画しない
technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}

