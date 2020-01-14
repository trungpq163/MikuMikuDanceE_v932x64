//パラメータ

// コントローラの名前
#define ControllerName	"ikRadialBlurController.pmx"
// ボケ範囲の中心になるボーン名
#define BoneName	"全ての親"

// テストモードでつけるブラー範囲の色
#define TEST_COLOR	float3(1,0,0)

// 3Dモードでのスケール調整値：3Dモードでの最大半径をどの程度にするか? 単位cm
// デフォルト(200)は人用を想定しているので、ロボとか用ならもっと大きい値にする。
#define SCALE_3D	(200.0)

/////////////////////////////////// 以下はいじらないほうがいい項目

// ブラー幅のデフォルト("幅(**)"が0のとき)の長さ
#define BLUR_BANDWIDTH_SCALE	(4.0)

// バッファのフォーマット
#define TEXFORMAT "A8R8G8B8"
//#define TEXFORMAT "A16B16G16R16F"


////////////////////////////////////////////////////////////////////////////////////////////////

// float3 AcsPosition : CONTROLOBJECT < string name = "(self)"; >;
float4x4 AcsMat : CONTROLOBJECT < string name = ControllerName; string item = BoneName; >;
//float3 AcsPosition : CONTROLOBJECT < string name = ControllerName; string item = BoneName; >;
float AcsSiOrig : CONTROLOBJECT < string name = ControllerName; string item = "強度"; >;
float AcsTr : CONTROLOBJECT < string name = ControllerName; string item = "透明度"; >;
float AcsPos : CONTROLOBJECT < string name = ControllerName; string item = "位置"; >;

float Acs3D : CONTROLOBJECT < string name = ControllerName; string item = "2D→3D"; >;

float AcsWidth : CONTROLOBJECT < string name = ControllerName; string item = "幅"; >;
float AcsWidthIn : CONTROLOBJECT < string name = ControllerName; string item = "幅(内側)"; >;
float AcsWidthOut : CONTROLOBJECT < string name = ControllerName; string item = "幅(外側)"; >;
float AcsTest : CONTROLOBJECT < string name = ControllerName; string item = "テストモード"; >;

static float AcsSi = (1.0 - AcsSiOrig);
static float WidthScale = (1.0 - AcsWidth) * 0.5;
static float WidthScaleIn = 1.0 / (BLUR_BANDWIDTH_SCALE * (1.0 - AcsWidthIn) * WidthScale);
static float WidthScaleOut = 1.0 / (BLUR_BANDWIDTH_SCALE * (1.0 - AcsWidthOut) * WidthScale);

static float Transparency = (1.0 - AcsTr) * saturate(AcsSi * 4.0);

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5)/ViewportSize.xy;
static float2 BlurStep = max(AcsSi * 3.0, 0.0) / ViewportSize.xy;
static float2 AspectRatio = float2(1.0, ViewportSize.y / ViewportSize.x);

float4x4 matVP		: VIEWPROJECTION;
float4x4 matInvVP	: VIEWPROJECTIONINVERSE;

float3 CameraPosition	: POSITION  < string Object = "Camera"; >;

float2 CalcCenter()
{
//	float4 ppos = mul(float4(AcsPosition, 1), matVP);
	float4 ppos = mul(float4(AcsMat._41_42_43, 1), matVP);
	return ppos.xy / ppos.w * float2(1.0, -1.0) * 0.5 + 0.5;
}
static float2 CenterPos = CalcCenter();

float4x4 CalcInvCtrlMat(float4x4 mat) {
    float scaling = length(mat[0].xyz);
    float scaling_inv2 = 1.0 / scaling;

    float3x3 mat3x3_inv = transpose((float3x3)mat) * scaling_inv2;
    return float4x4(
        mat3x3_inv[0], 0, 
        mat3x3_inv[1], 0, 
        mat3x3_inv[2], 0, 
        -mul(mat._41_42_43,mat3x3_inv), 1
    );
}

static float4x4 matInvW = CalcInvCtrlMat(AcsMat);
static float4x4 matInvWVP = mul(matInvVP, matInvW);
static float3 LocalCameraPos = mul(float4(CameraPosition,1), matInvW).xyz;


float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

texture BlurMap: RENDERCOLORTARGET <
	float2 ViewportRatio = {0.5, 0.5};
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;

sampler BlurSamp = sampler_state {
	texture = <BlurMap>;
	Filter = Linear;
	AddressU = CLAMP; AddressV = CLAMP;
};


//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

static const float BlurWeight[] = {
    0.09254214,
    0.090672664,
    0.0852878,
    0.07701426,
    0.066761956,
    0.055559803,
    0.044388045,
    0.03404435,
};

static const float BlurWeight4[] = {
    0.20799541,
    0.18612246,
    0.13336258,
    0.07651724,
};

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}


VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset.xy * level;

	return Out;
}

float4 PS_Blur( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 texCoord = float4(IN.TexCoord, 0, 0);
	float2 v = (texCoord - CenterPos) * AspectRatio;
	float4 offset = float4(normalize(v) * BlurStep * 2.0, 0, 0);

	float4 sum = tex2D(smp, texCoord) * BlurWeight[0];
	[unroll] for(int i = 1; i < 8; i++)
	{
		float3 col = tex2Dlod(smp, texCoord + offset * i).rgb +
					 tex2Dlod(smp, texCoord - offset * i).rgb;
		sum.rgb += col * BlurWeight[i];
	}

	float4 Color = float4(sum.rgb, 1);

	return Color;
}


float4 PS_Blur4( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 texCoord = float4(IN.TexCoord, 0, 0);
	float2 v = (texCoord - CenterPos) * AspectRatio;
	float len2D = length(v);

	float4 PPos = float4((texCoord.xy - 0.5) * float2(2.0, -2.0), 1, 1);
	float3 LVec = normalize(mul(PPos, matInvWVP).xyz);
	float3 pos = LocalCameraPos - LVec * (LocalCameraPos.z / max(LVec.z, 1e-4));
	float len3D = length(pos.xyz) * (16.0 / SCALE_3D);

	float len = (Acs3D < 0.5) ? len2D : len3D;
	float width = AcsPos - len * 0.5;
	float scale = ((width > 0.0) ? WidthScaleIn : WidthScaleOut);
	float rate = 1.0 - saturate(abs(width) * scale - WidthScale);

	float4 offset = float4(v * BlurStep * (rate / len2D), 0, 0);
	float4 sum = tex2D(smp, texCoord) * BlurWeight4[0];
	[unroll] for(int i = 1; i < 4; i++)
	{
		float3 col = tex2Dlod(smp, texCoord + offset * i).rgb +
					 tex2Dlod(smp, texCoord - offset * i).rgb;
		sum.rgb += col * BlurWeight4[i];
	}

	float4 Color = float4(sum.rgb, 1);
	Color = lerp(tex2D( ScnSamp, texCoord), Color, Transparency * rate);

	float3 testColor = rgb2gray(Color.rgb) * (1.0 - TEST_COLOR) + TEST_COLOR;
	Color.rgb = lerp(Color.rgb, testColor, (AcsTest > 0.5) * rate);

	return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=BlurMap;"
		"Pass=BlurPass;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=BlurPass2;"
	;
> {
	pass BlurPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_Blur(ScnSamp);
	}
	pass BlurPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur4(BlurSamp);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
