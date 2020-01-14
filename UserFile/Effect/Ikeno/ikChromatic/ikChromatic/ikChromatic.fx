
//ぼかしのサンプリング数
#define SAMP_NUM  16

// パレットのサイズ
#define CLUT_WIDTH		64
#define CLUT_HEIGHT		16



///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;


// 色ずれ量
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ColorShift = AcsSi;

// CLUT番号
float4x4 AcsMatrix : CONTROLOBJECT < string name = "(self)"; >;
static const float3 AcsPos = AcsMatrix._41_42_43;
static float ClutNo = round(AcsPos.x);

float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

float4 ClearColor  = float4(0,0,0,0);
float ClearDepth  = 1.0;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};

texture ClutTex < string ResourceName = "clut.png"; >;
sampler ClutSamp = sampler_state {
	Texture = <ClutTex>;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = NONE;
	ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////

float PosToRate(float2 Tex)
{
	float2 tex2 = Tex * 2;
	return dot(tex2, tex2);
}

float4 GetWeight(float t, float clut)
{
	float u = (t * (CLUT_WIDTH - 1) + 0.5) / CLUT_WIDTH;
	float v = clut;
	return tex2D(ClutSamp, float2(u, v));
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 Tex			: TEXCOORD0;
	float4 ClutCoef		: TEXCOORD1;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex + ViewportOffset;

	Out.Tex.zw = Out.Tex.xy - 0.5;
	Out.Tex.w /= ViewportAspect;

	Out.ClutCoef.x = saturate((ClutNo + 0.5) / CLUT_HEIGHT);

	return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_passDraw1( float4 Tex: TEXCOORD0, float4 ClutCoef: TEXCOORD1 ) : COLOR
{
	float rate = PosToRate(Tex.zw);

	float2 shift = 1.0 + float2(1, -1) * (ColorShift * rate / 1024.0);
	float4 vec = Tex.zwzw * shift.xxyy;
	vec.yw *= ViewportAspect;
	vec += 0.5;

	float4 Color = 0;
	float4 WeightSum = 0;

	for(int i = 0; i < SAMP_NUM; i++)
	{
		float t = i * 1.0 / (SAMP_NUM + 1.0);
		float4 w = GetWeight(t, ClutCoef.x);
		Color += tex2D( ScnSamp, lerp(vec.xy, vec.zw, t)) * w;
		WeightSum += w;
	}

	Color = Color / max(WeightSum, 1e-4);

	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////


technique Chromatic <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=Draw1;"
	;
> {
	pass Draw1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader  = compile ps_3_0 PS_passDraw1();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////

