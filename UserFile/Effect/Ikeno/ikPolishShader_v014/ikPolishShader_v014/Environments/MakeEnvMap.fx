////////////////////////////////////////////////////////////////////////////////////////////////
// ikPolishShader用の環境マップを出力する
// ENV_WIDTH*2 x ENV_WIDTH の画面サイズで出力することが望ましい
////////////////////////////////////////////////////////////////////////////////////////////////

#include "../ikPolishShader.fxsub"

//******************設定はここから

// 環境マップのサイズは ikPolishShader.fxsub で行う。
// 環境マップの解像度(256～1024程度。2のべき乗がよい。)
// #define ENV_WIDTH		512

// 0:ガンマ補正して出力する、1:線形で出力する。
// ikPolishは線形の環境マップを扱うが、画面上で確認する場合は、
// ガンマ補正しているほうが最終結果に近い。
#define OUTPUT_LINEAR	1

// テクスチャ形式
//#define ENV_FORMAT		"A8R8G8B8"
#define ENV_FORMAT		"A16B16G16R16F"

//******************設定はここまで

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// スクリーン

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = Linear;	MagFilter = Linear;	MipFilter = Linear;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

///////////////////////////////////////////////////////////////////
// 動的双放物面環境マップの宣言＆使用関数

#define ENV_HEIGHT		ENV_WIDTH

	texture EnvMap : OFFSCREENRENDERTARGET <
		int Width = ENV_WIDTH * 2;
		int Height = ENV_HEIGHT * 2;
		float4 ClearColor = { 0, 0, 0, 1 };
		float ClearDepth = 1.0;
		int Miplevels = 1;
		string Format = ENV_FORMAT;
		string Description = "EnvironmentMap for MakeEnv";
		string DefaultEffect = "self = hide; *=TEnvMap.fx";
	>;

	sampler EnvMapSamp = sampler_state {
		texture = <EnvMap>;
		MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
		AddressU  = CLAMP;	AddressV = CLAMP;
	};



#define	PI	(3.14159265359)

float3 Vec0 = normalize(float3( 1, 1, 1));
float3 Vec1 = normalize(float3(-1, 1,-1));
float3 Vec2 = normalize(float3( 1,-1,-1));
float3 Vec3 = normalize(float3(-1,-1, 1));

float3x3 CalcViewMat(float3 v0, float3 v1)
{
	float3 v2 = normalize(cross(v1, v0));
	v1 = normalize(cross(v0, v2));
	return (float3x3(
		float3(v2.x, v1.x, v0.x),
		float3(v2.y, v1.y, v0.y),
		float3(v2.z, v1.z, v0.z)));
}

static float3x3 matV[] = {
	CalcViewMat(Vec0, Vec1),
	CalcViewMat(Vec1, Vec2),
	CalcViewMat(Vec2, Vec3),
	CalcViewMat(Vec3, Vec0)
};

static float2 offsets[] = {
	float2(1, 1) / 4.0,
	float2(3, 1) / 4.0,
	float2(1, 3) / 4.0,
	float2(3, 3) / 4.0
};

float3 GetTetrahedron(float3 N)
{
	N = normalize(N.xzy);
	float d0 = dot(Vec0, N);
	float d1 = dot(Vec1, N);
	float d2 = dot(Vec2, N);
	float d3 = dot(Vec3, N);

	float3 texCoord = 0;
	int face = 0;

	if (d0 > d1 && d0 > d2 && d0 > d3)
	{
		;
	}
	else if (d1 > d2 && d1 > d3)
	{
		face = 1;
	}
	else if (d2 > d3)
	{
		face = 2;
	}
	else
	{
		face = 3;
	}

	texCoord = mul(N, matV[face]);
	texCoord.xy /= texCoord.z;
	texCoord.xy *= (1 / 2.6) * float2(0.25, -0.25);
	float2 offset = offsets[face];

	// tex2Dでは補間でおかしくなる
	// return tex2D(EnvMapSamp, texCoord.xy + offset).rgb;
	return tex2Dlod(EnvMapSamp, float4(texCoord.xy + offset,0,0)).rgb;
}

// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }
inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}


////////////////////////////////////////////////////////////////////////////////////////////////
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
	float2 Tex2			: TEXCOORD1;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.Tex = Tex;
	return Out;
}

float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
	float4 Color = float4(0,0,0,1);

	float x0 = Tex.x * 2.0;
	float x = (frac(x0) * 2.0 - 1.0) / EnvFrameScale;
	x = x * ((x0 < 1.0) ? 1 : -1);
	float y = -(Tex.y * 2.0 - 1.0) / EnvFrameScale;
	float z = ((x0 < 1.0) ? 1 : -1) * (1.0 - (x*x+y*y)) * 0.5;
	float3 N = float3(x,y,z);

	Color.rgb = GetTetrahedron(N);

//	Color.rgb = tex2D(EnvMapSamp, Tex);

	#if defined(OUTPUT_LINEAR) && OUTPUT_LINEAR == 0
	Color.rgb = Gamma(Color.rgb);
	#endif

	return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////

// レンダリングターゲットのクリア値
const float4 BackColor = float4(0,0,0,1);
const float ClearDepth  = 1.0;

technique MakeEnv <
	string Script = 
		"ClearSetColor=BackColor;"
		"ClearSetDepth=ClearDepth;"

		"RenderColorTarget0=ScnMap;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawPass;"
	;
> {
	pass DrawPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_Draw();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
