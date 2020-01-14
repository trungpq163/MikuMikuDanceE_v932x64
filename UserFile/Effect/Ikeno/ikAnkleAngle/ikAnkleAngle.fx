////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 対象モデル
//#define  MODEL_NAME		"初音ミク.pmd"
#define  MODEL_NAME		"Tda式初音ミク_デフォ服すっぴん.pmx"

// 前後のグネり度：許容範囲
#define	SafeAngle		(40.0)
// 前後のグネり度：許容範囲外
#define	ErrorAngle		(60.0)

// 地面に水平以外をエラーにする場合
// #define	SafeAngle		(1.0)
// #define	ErrorAngle		(2.0)

// 内側へのグネり度
#define	SafeInnerAngle		(-40.0)
#define	ErrorInnerAngle		(-60.0)
// 外側へのグネり度
#define	SafeOuterAngle		(15.0)
#define	ErrorOuterAngle		(20.0)


// 足首がアクセサリのY値より、これ以上離れていたら空中にいるとみなす。
// 高さを無視したくない場合はコメントアウト(行頭に//を追加)するか、999.9などの大きな値にする。
#define IGNORE_HEIGHT	3.0

// 足元に出る板のサイズ (横方向,前後方向)
#define PanelSize		float2(1.5, 0.5)
// 角度の表示サイズ
#define AngleSize		1
// ※アクセサリのSiからも拡大指定可能。


// 板を地面から浮かせる高さ
float FloorOffset = 0.1;

// 板の色
// 非表示にしたい場合は、4番目の値(透明度)を0にする。
#define COLOR_OK		float4(0,1,0, 0.5)
#define COLOR_NG		float4(1,0,0, 1)
#define COLOR_AIR		float4(0.2,0.2,1.0, 0.25)	// 中空にあるので角度は無視する

#define  BONE_R_NAME	"右足首"
#define  BONE_L_NAME	"左足首"

// 親ボーン
#define  BONE_R_PARENT_NAME	"右ひざ"
#define  BONE_L_PARENT_NAME	"左ひざ"

// かかとの高さを取得するために利用
#define  BONE_R_TIP_NAME	"右つま先ＩＫ"
#define  BONE_L_TIP_NAME	"左つま先ＩＫ"


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;

float4x4 matR : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_R_NAME; >;
float4x4 matL : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_L_NAME; >;
float4x4 matRP : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_R_PARENT_NAME; >;
float4x4 matLP : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_L_PARENT_NAME; >;
float3 posRTip : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_R_TIP_NAME; >;
float3 posLTip : CONTROLOBJECT < string name = MODEL_NAME; string item = BONE_L_TIP_NAME; >;

// パネルを置く位置：足首ボーンはくるぶし辺りなので、足裏付近に下げたい。
static float4 posR = float4(matR._41,max(min(matR._42, posRTip.y), AcsY + FloorOffset),matR._43, 1);
static float4 posL = float4(matL._41,max(min(matL._42, posLTip.y), AcsY + FloorOffset),matL._43, 1);

float4x4 ViewProjMatrix : VIEWPROJECTION;
/*
float4x4 ViewInverseMatrix	: VIEWINVERSE;
static float3x3 BillboardMatrix = {
	normalize(ViewInverseMatrix[0].xyz),
	normalize(ViewInverseMatrix[1].xyz),
	normalize(ViewInverseMatrix[2].xyz),
};
*/

float2 ViewportSize : VIEWPORTPIXELSIZE;


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

#define	PI	(3.14159265359)
#define	RAD2DEG		(180.0 / PI)




texture2D NumberTex <
	string ResourceName = "Number.png";
>;
sampler NumberTexSamp = sampler_state {
	texture = <NumberTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

#define NUMBER_TEX_SIZE		256

static const float MaxValue = 99.99;
static const int MaxRadix = 3;	// 小数点以下も含め、全体で3桁の数値を表示
static const float NoDP = 1;	// 小数点一桁まで表示
static const float2 texCharSize = float2(20, 20);	// 文字テクスチャのグリッドサイズ
static const float2 dispCharSize = float2(12, 16);	// 1グリッド内の文字サイズ

#define NumberBillboardWidth ((MaxRadix + 1) * dispCharSize.x)
#define NumberBillboardHeight (texCharSize.y * 4)

texture NumberRTex : RENDERCOLORTARGET
<
	int Width = NumberBillboardWidth;
	int Height = NumberBillboardHeight;
	string Format = "D3DFMT_A8R8G8B8";
>;

sampler NumberRTexSmp
{
	Texture = <NumberRTex>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	int Width = NumberBillboardWidth;
	int Height = NumberBillboardHeight;
	string Format = "D24S8";
>;



// 接地度を求める
inline float CalcHAngle(float4x4 mat)
{
	float3 nx = mat._11_12_13;
//	float3 ny = mat._21_22_23;
//	float3 nz = mat._31_32_33;
	// return atan2(nx.y, sqrt(dot(nx.xz, nx.xz))) * RAD2DEG;
	return -asin(nx.y) * RAD2DEG;
}

// グネり度を求める
inline float CalcVAngle(float4x4 mat, float4x4 matP, bool isLeft)
{
	float3 nx = mat._11_12_13;
	float3 ny = mat._21_22_23;
	float3 nz = mat._31_32_33;
	float3 pny = matP._21_22_23;
	pny = normalize(pny - nz * dot(pny, nz));

	float sign = 1;
	if (isLeft)
	{
		sign = (dot(nx, pny) >= 0.0) ? 1 : -1;
	} else {
		sign = (dot(nx, pny) <= 0.0) ? 1 : -1;
	}

	return sign * abs(acos(dot(ny, pny))) * RAD2DEG;
}

static float AngleHR = CalcHAngle(matR);
static float AngleHL = CalcHAngle(matL);

static float AngleVR = CalcVAngle(matR, matRP, false);
static float AngleVL = CalcVAngle(matL, matLP, true);

///////////////////////////////////////////////////////////////////////////////////////
//
float4 DispNumber(float x, float y, float num)
{
	float2 result = 0;

	if (x <= dispCharSize.x)
	{
		// 符号
		float2 texCoord = float2((num < 0.0) * texCharSize.x + fmod(x, dispCharSize.x), y + texCharSize.y);
		texCoord += 0.5;
		result = tex2D(NumberTexSamp, texCoord / NUMBER_TEX_SIZE).rg;
	}
	else if (x >= 0 && y >= 0 && x <= (MaxRadix + 1) * dispCharSize.x)
	{
		int radix = floor(x / dispCharSize.x) - 1;
		float scale = pow(10, MaxRadix - radix - 1 - NoDP);
		float dispNum = fmod(floor(min(abs(num), MaxValue) / scale), 10);
		float2 texCoord = float2(dispNum * texCharSize.x + fmod(x, dispCharSize.x), y);
		texCoord += 0.5;
		result = tex2D(NumberTexSamp, texCoord / NUMBER_TEX_SIZE).rg;
	}

	return float4(result.ggg, result.r * 0.5 + 0.5);
}

///////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
	float4 Pos		: POSITION;
	float2 Tex		: TEXCOORD0;
	float4 Col		: COLOR0;
};

// 角度表示用のテクスチャを生成
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.Tex = Tex.xy;
	return Out;
}

float4 PS_MakeTexture( VS_OUTPUT IN ) : COLOR
{
	float2 uv = IN.Tex * float2(NumberBillboardWidth, NumberBillboardHeight);
	bool isLeft = (IN.Tex.y >= 0.5);
	bool isUpper = (fmod(IN.Tex.y, 0.5) < 0.25);
	float ang = isLeft ? (isUpper ? AngleVL : AngleHL) : (isUpper ? AngleVR : AngleHR);

	uv.y = fmod(uv.y, NumberBillboardHeight * 0.25);
	return DispNumber(uv.x, uv.y, ang);
}


// 足元の板を表示
VS_OUTPUT DrawPanel_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out=(VS_OUTPUT)0;

	bool isLeft = (Pos.y > 0.5);
	Pos.y = 0;
	Pos.xz *= (PanelSize.xy * (AcsSi * 0.1));

	float4x4 mat = isLeft ? matL : matR;
	float4 offset = isLeft ? posL : posR;

	float4 pos = float4(mul( Pos, (float3x3)mat ) + offset, 1);

	Out.Pos = mul(pos, ViewProjMatrix );

	float ang = isLeft ? AngleHL : AngleHR;
	float angV = isLeft ? AngleVL : AngleVR;
	float aang = abs(ang);
	float level = (aang <= SafeAngle)
				? 0
				: (max(aang - SafeAngle, 0) / (ErrorAngle - SafeAngle) * 0.5 + 0.5);

	float vLevel = 
 (angV < 0.0)
			? ((angV >= SafeInnerAngle)
				? 0
				: (max(angV - SafeInnerAngle, 0) / (ErrorInnerAngle - SafeInnerAngle) * 0.5 + 0.5))
			: ((angV <= SafeOuterAngle)
				? 0
				: (max(angV - SafeOuterAngle, 0) / (ErrorOuterAngle - SafeOuterAngle) * 0.5 + 0.5));

	level = 1.0 - (1.0 - level) * (1.0 - vLevel);

	Out.Col = lerp(COLOR_OK, COLOR_NG, saturate(level));

	#if defined(IGNORE_HEIGHT)
	if (abs(mat._42 - AcsY) >= IGNORE_HEIGHT) Out.Col = COLOR_AIR;
	#endif

	Out.Col.a *= AcsTr;

	return Out;
}


float4 DrawPanel_PS( VS_OUTPUT IN ) : COLOR0
{
	return IN.Col;
}


// 角度を表示
VS_OUTPUT DrawNum_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out=(VS_OUTPUT)0;

	float scale = AngleSize * AcsSi * 0.1;
	float h = texCharSize.y / ViewportSize.y;

	bool isLeft = (Pos.y > 0.5);
	float4 offset = isLeft ? posL : posR;
	Out.Pos = mul(offset, ViewProjMatrix );

	Out.Pos.xy /= Out.Pos.w;
	Out.Pos.zw = float2(0, 1);

	float2 pos = (Pos.xz * float2(MaxRadix + 1, 2.0) * scale + float2(0, 4)) * h;
	pos.x *= (ViewportSize.y / ViewportSize.x);
	Out.Pos.xy += pos.xy;


	Out.Tex = Tex;

	return Out;
}


float4 DrawNum_PS( VS_OUTPUT IN ) : COLOR0
{
	return tex2D(NumberRTexSmp, IN.Tex);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 <
	string MMDPass = "object";

   string Script = 
		"RenderColorTarget0=NumberRTex;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Pass=MakeTexture;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawPanel;"
		"Pass=DrawNum;";
>{
	pass MakeTexture < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_MakeTexture();
	}

	pass DrawNum {
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		AlphaBlendEnable = TRUE;
		CullMode = NONE;
		VertexShader = compile vs_3_0 DrawNum_VS();
		PixelShader  = compile ps_3_0 DrawNum_PS();
	}

	pass DrawPanel {
		CullMode = NONE;
		VertexShader = compile vs_3_0 DrawPanel_VS();
		PixelShader  = compile ps_3_0 DrawPanel_PS();
	}
}

technique ZplotTec < string MMDPass = "zplot"; > {}
