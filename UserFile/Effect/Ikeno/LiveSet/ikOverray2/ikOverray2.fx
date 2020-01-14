//-----------------------------------------------------------------------------
// 



//-----------------------------------------------------------------------------

#define DEPTHMAP_NAME	PostDepthMapRT
#define FAR_DEPTH		1000.0
#define CONTROLLER_NAME	"ikOverray2Controller.pmx"

//-----------------------------------------------------------------------------

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define DECLARE_PARAM(_t,_var,_item)	\
	_t _var : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = _item;>;

DECLARE_PARAM(float4x4, lightMat, "ターゲット");

DECLARE_PARAM(float, mHue, "色");
DECLARE_PARAM(float, mSaturate, "白");
DECLARE_PARAM(float, mBrightness, "明るさ");
// 色にグラデをつけたい?
DECLARE_PARAM(float, mLength, "短く");
DECLARE_PARAM(float, mRoundness, "丸い");
DECLARE_PARAM(float, mThickness, "厚み");		// 深度によって濃さを変えるかどうか
DECLARE_PARAM(float, mPhase, "向き依存");

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float Aspect = (ViewportSize.y / ViewportSize.x);
static float LongestEdge = max(ViewportSize.x, ViewportSize.y * Aspect);
static float DefaultRadius = sqrt(2) * LongestEdge;

float4x4 matV		: VIEW;


texture PalletTex < string ResourceName = "pallet.png"; >;
sampler PalletSamp = sampler_state {
	Texture = <PalletTex>;
	ADDRESSU = CLAMP; ADDRESSV = CLAMP;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = NONE;
};

// 深度マップ
shared texture DEPTHMAP_NAME : OFFSCREENRENDERTARGET;
sampler DepthMap = sampler_state {
	texture = <DEPTHMAP_NAME>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP; AddressV  = CLAMP;
};


// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;

float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float4 Degamma(float4 col) { col.rgb = Degamma(col.rgb); return col; }
float4 Gamma(float4 col) { col.rgb = Gamma(col.rgb); return col; }


struct VS_OUTPUT
{
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float4 LightPosition	: TEXCOORD1;

	float4 Color		: COLOR0;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex.xy + ViewportOffset.xy;

	float u = mHue * 0.97 + 0.015;
	float v = mSaturate * 0.97 + 0.015;
	Out.Color = Degamma(tex2Dlod(PalletSamp, float4(u,v,0,0)));
		// 色シフトをつけるならここで計算できない

	float3 dir = mul(lightMat[1].xyz, (float3x3)matV);

	float2 ppos = normalize(dir.xy * float2(1,-1));
	float r0 = DefaultRadius / LongestEdge * 0.5;
	float r = r0 * lerp(8, 1, mRoundness * mRoundness);
	float rMin = max(r - r0, 0);
	float rBand = r0 * lerp(2, 0.1, mLength);

	ppos.xy *= r;
	ppos.y /= Aspect;
	Out.LightPosition.xy = ppos.xy + 0.5;
	Out.LightPosition.z = rMin;
	Out.LightPosition.w = 1.0 / rBand;

	float intensity = saturate(lerp(dir.z * 0.5 + 0.5, dir.z, mPhase));
	Out.Color.a = saturate(intensity * (1.0 - mBrightness));

	return Out;
}

float4 PS_Draw( VS_OUTPUT In ) : COLOR
{
	float2 uv = (In.TexCoord.xy - In.LightPosition.xy);
	uv.y *= Aspect;
	float d = length(uv);
	d = 1 - saturate((d - In.LightPosition.z) * In.LightPosition.w);
	d *= d;
	d *= In.Color.a;

	// 深度によるフェード
	float depth = tex2D(DepthMap, In.TexCoord.xy).x * FAR_DEPTH;
	float depthRate = 1 - exp2(-depth / lerp(0.01, 100, mThickness));
	depthRate = (mThickness == 0.0) ? 1 : depthRate;
	d *= depthRate;

	float3 col = Gamma(In.Color.rgb * d);

	return float4(col, 1);
}

technique Overray2 <
	string Script = 
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ScriptExternal=Color;"
		"Pass=DrawPass;"
	;
> {
	pass DrawPass < string Script= "Draw=Buffer;"; > {
		ZENABLE = FALSE;	ZWRITEENABLE = FALSE;
		SRCBLEND = SRCALPHA;		DESTBLEND = ONE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Draw();
	}
}


//-----------------------------------------------------------------------------

