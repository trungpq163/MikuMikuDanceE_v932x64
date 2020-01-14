/////////////////////////////////////////////////////////////////////
//
// 線形で画像処理するためのエフェクト
//
// ikLinearBegin/ikLinearEndのペアで使う。
//
/////////////////////////////////////////////////////////////////////

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A16B16G16R16F";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};

const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

struct VS_OUTPUT {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};

VS_OUTPUT DrawBuffer_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

float4 DrawBuffer_PS( VS_OUTPUT IN ) : COLOR0
{
	return Degamma4(tex2D(ScnSamp, IN.Tex.xy));
}

technique MainTec1 <
	string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"

		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawBuffer;"
;
>{
	pass DrawBuffer < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DrawBuffer_VS();
		PixelShader  = compile ps_3_0 DrawBuffer_PS();
	}
}
