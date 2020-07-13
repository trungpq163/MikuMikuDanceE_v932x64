//-----------------------------------------------------------------------------
// ìÆâÊÇåıåπÇ…Ç∑ÇÈÇΩÇﬂÇ…ÉRÉsÅ[Ç∑ÇÈ

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

shared texture SavedScreen: RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	string Format = "A8R8G8B8";
	int Miplevels = 0; // make Mipmap chain
>;

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjectTextureSamp = sampler_state {
	texture = <ObjectTexture>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU  = CLAMP; AddressV  = CLAMP;
};

struct VS_OUTPUT
{
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex.xy + ViewportOffset.xy;
	return Out;
}

float4 PS_SaveScreen( float2 Tex: TEXCOORD0 ) : COLOR
{
	return tex2D(ObjectTextureSamp, Tex);
}

technique SaveScreen <
	string Script = 
		"RenderColorTarget0=SavedScreen; Pass=SavePass;"
		"RenderColorTarget0=;"
	;
> {
	pass SavePass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_SaveScreen();
	}
}

//-----------------------------------------------------------------------------

