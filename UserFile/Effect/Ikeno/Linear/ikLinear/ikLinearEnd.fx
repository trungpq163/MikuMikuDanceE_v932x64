/////////////////////////////////////////////////////////////////////
//
// 線形で画像処理するためのエフェクト
//
// ikLinearBegin/ikLinearEndのペアで使う。
//
/////////////////////////////////////////////////////////////////////

#define ENABLE_DITHER	1


//白飛び係数　0～1
float OverExposureRatio <
   string UIName = "OverExposure";
   string UIWidget = "Slider";
   string UIHelp = "白飛び係数";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 3;
> = 0.5;


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

// AutoLuminous から借用
float4 OverExposure(float4 color){
    float4 newcolor = color;

    //ある色が1を超えると、他の色にあふれる
	float3 leakcol = max(color - 1, 0) * OverExposureRatio;
    newcolor.r += dot(leakcol, float3(0.0, 0.2, 0.1));
    newcolor.g += dot(leakcol, float3(0.2, 0.0, 0.2));
    newcolor.b += dot(leakcol, float3(0.1, 0.2, 0.0));
    return newcolor;
}

// ジッター
static float JitterOffsets[16] = {
	 6/16.0, 1/16.0,12/16.0,11/16.0,
	 9/16.0,14/16.0, 5/16.0, 2/16.0,
	 0/16.0, 7/16.0,10/16.0,13/16.0,
	15/16.0, 8/16.0, 3/16.0, 4/16.0,
};

inline float GetJitterOffset(int2 iuv)
{
	int index = (iuv.x % 4) * 4 + (iuv.y % 4);
	int index2 = ((iuv.x/4) % 4) * 4 + ((iuv.y/4) % 4);
	return (JitterOffsets[index] + JitterOffsets[index2] * (1/16.0));
}



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

float4 DrawBuffer_PS( float2 Tex : TEXCOORD0 ) : COLOR0
{
	float4 col = tex2D(ScnSamp, Tex.xy);
	col = OverExposure(col);
	col = Gamma4(col);

	#if ENABLE_DITHER > 0
	int2 iuv = floor(Tex.xy * ViewportSize);
	float jitter = GetJitterOffset(iuv);

	float3 col255 = col.rgb * 255;
	float3 diff = col255 - floor(col255);

	float3 dither = 0;
	dither.r = (diff.r > jitter);
	dither.g = (diff.g > jitter);
	dither.b = (diff.b > jitter);

	col.rgb = (floor(col255) + dither) * (1.0 / 255);
	#endif

	return col;
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
