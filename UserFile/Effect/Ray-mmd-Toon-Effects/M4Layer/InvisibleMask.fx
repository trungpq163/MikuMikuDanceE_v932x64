float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4 MaterialDiffuse : DIFFUSE < string Object = "Geometry"; >;
bool use_texture;
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT
{
    float4 Pos        : POSITION;
    float2 Tex        : TEXCOORD1;
};

#ifdef MIKUMIKUMOVING
VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN)
{
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    float4 Pos = SkinOut.Position;
    float3 Normal = SkinOut.Normal;
    float2 Tex = IN.Tex;
#else
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
#endif
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Tex = Tex;
    
    return Out;
}

float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    float alpha = MaterialDiffuse.a;
    
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
    return float4(1, 1, 1, alpha);
}

technique Mask < string MMDPass = "object"; >
{
    pass P
    { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

technique MaskSS < string MMDPass = "object_ss"; >
{
    pass P
    { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }
