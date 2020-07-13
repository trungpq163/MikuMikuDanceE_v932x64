//--------------------------------------------------------------//
// 

#define	FLIP_NOISE


#define FLOW_MAP_NAME		"../flowmap.png"
#define NOISE_MAP_NAME		"hairnoise.png"

// 内部的に大きくレンダリングする
#define	FLOW_SCALE	4

#define SiScale		(0.999)
#define TrScale		(0.1)

//--------------------------------------------------------------//

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;

texture FlowResultMap: RENDERCOLORTARGET <
	float2 ViewportRatio = {FLOW_SCALE, FLOW_SCALE};
	int MipLevels = 1;
	string Format = "R16F";
>;

sampler FlowResult = sampler_state {
	texture = <FlowResultMap>;
	Filter = Linear;
	AddressU = WRAP;	AddressV = WRAP;
};

texture FlowResultMap2: RENDERCOLORTARGET <
	float2 ViewportRatio = {FLOW_SCALE, FLOW_SCALE};
	int MipLevels = 1;
	string Format = "R16F";
>;

sampler FlowResult2 = sampler_state {
	texture = <FlowResultMap2>;
	Filter = Linear;
	AddressU = WRAP;	AddressV = WRAP;
};


texture FlowTex < string ResourceName = FLOW_MAP_NAME; >;
sampler FlowSamp = sampler_state
{
	texture = < FlowTex>;
	Filter = Linear;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture NoiseTex < string ResourceName = NOISE_MAP_NAME; >;
sampler NoiseSamp = sampler_state
{
	texture = < NoiseTex>;
	Filter = Linear;
	AddressU = WRAP;
	AddressV = WRAP;
};



//-----------------------------------------------------------------------------
//
struct VS_OUTPUT {
	float4 Pos:			POSITION;
	float2 TexCoord:	TEXCOORD0;
};


inline bool IsTimeToReset()
{
	return (time1 == time2 && time1 < 0.001f);
}

//-----------------------------------------------------------------------------
//
VS_OUTPUT VS_Draw(float4 Pos: POSITION, float2 Tex: TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset;
	return Out;
}

float4 PS_Flow(VS_OUTPUT In, uniform sampler smp) : COLOR
{
	float2 uv = In.TexCoord - ViewportOffset + (float2(0.5,0.5)/(ViewportSize * FLOW_SCALE));

	#if defined(FLIP_NOISE)
	float basex = tex2D(NoiseSamp, uv * 2.0).x;
	#else
	float basex = tex2D(NoiseSamp, uv.yx * 2.0).x;
	#endif

	float2 v = normalize(tex2D(FlowSamp, uv).xy * 2.0 - 1.0) * (1.0 / ViewportSize);

	float x = tex2D(smp, uv).x;
	float nx = tex2D(smp, uv + v.xy * float2(-1,1)).x;

	x = lerp(x, nx, AcsTr * TrScale);

	basex = (AcsTr == 0.0) ? x: basex; // AcsTr が0なら ノイズの追加も止める
	float reset = (IsTimeToReset() ? 0 : saturate(AcsSi * 0.1 * SiScale));
	x = lerp(basex, x, reset);

	return float4(x,x,x, 1);
}


float4 PS_Draw(VS_OUTPUT In) : COLOR
{
	float x = tex2D(FlowResult2, In.TexCoord).x;
	x = (x - 0.5) * 1.5 + 0.5; // boost

	return float4(x,x,x, 1);
}

//-----------------------------------------------------------------------------
float4 ClearColor = {1,1,1,1};
float4 ClearColorParicle = {0,0,0,0};
float ClearDepth  = 1.0;

technique Splash
<
	string Script = 
		"RenderColorTarget0=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=FlowResultMap;		Pass=FlowPass1;"
		"RenderColorTarget0=FlowResultMap2;		Pass=FlowPass2;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawPass;"
	;
>
{
	pass FlowPass1 < string Script= "Draw=Buffer;"; >
	{
		VertexShader = compile vs_3_0 VS_Draw();
		PixelShader = compile ps_3_0 PS_Flow(FlowResult2);
	}
	pass FlowPass2 < string Script= "Draw=Buffer;"; >
	{
		VertexShader = compile vs_3_0 VS_Draw();
		PixelShader = compile ps_3_0 PS_Flow(FlowResult);
	}

	pass DrawPass < string Script= "Draw=Buffer;"; >
	{
		VertexShader = compile vs_3_0 VS_Draw();
		PixelShader = compile ps_3_0 PS_Draw();
	}
}
