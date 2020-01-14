//=============================================================================
/*
	ikBokeh.fx
	ポストプロセスで被写界深度のエミュレートを行う。

	ボカし処理は以下を参考にした。
	Circular DOF by Kleber Garcia "Kecho" - 2017
		https://www.shadertoy.com/view/Xd2BWc
	SIGGRAPH 2017 talk:
		http://dl.acm.org/citation.cfm?id=3085022&CFID=796119909&CFTOKEN=82442532

	CoCのサイズ計算は主に以下を参照した。
	川瀬. 2010. 魅力ある絵作りのために知っておきたい色光学豆知識. CEDEC 2010.
*/
//=============================================================================

// 強制的に玉ボケのサイズをスケーリングする。1:等倍(デフォルト)、2:2倍になる。
// 別途設定されているサイズ上限を超えることはない。
#define FORCE_COC_SCALE		(1.0)

// 前ボケの大きさ。0.1～1.0。0に近づけることで前ボケを小さくする
#define FRONT_BOKEH_SCALE	(1.0)

// 外部から制御するコントローラの名前
#define CONTROLLER_NAME		"ikBokehController.pmx"

// オートフォーカスの基準位置
// 通常はアクセサリにのままにしておき、アクセサリをピントを合わせたいボーンにぶら下げる。
//#define	AF_MODEL_NAME	"ikBokeh.x"
#define	AF_MODEL_NAME	"(self)"
//#define	AF_BONE_NAME	"頭"

// テストモード有効設定。
// ENABLE_TEST_MODEが1のとき、モーフのテストモードを1にすることでピント表示を行う。
#define	ENABLE_TEST_MODE		1

// 時間の同期
#define	TimeSync		0

// コントローラが無い場合の測距モードの値
// 0: アクセサリの位置
// 1: 画面中央(狭)にピントを合わせる
// 2: 画面中央(広)にピントを合わせる
#define	DEFAULT_MEASURING_MODE	0

// 玉ボケの強調を行う?
#define ENABLE_EMPHASIZE_COLOR	1
// 最大強調度合
#define EMPHASIZE_RATE	2

// ピントのあっている範囲をゆるくする。(0～1.0)
#define PINT_MARGIN		1.0


//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// ボカすサイズ
#define KERNEL_RADIUS	8
// ※ KERNEL_RADIUSを変えたら、InvAlphaを再計算する必要がある。

#define WRITE_COEF	1	// 係数をテクスチャに書き出す

// テクスチャフォーマット
#define TEXFORMAT "A16B16G16R16F"
// 計算用テクスチャのフォーマット
#define WORK_TEXFORMAT "A16B16G16R16F"

// 単位調整用の変数。
//#define		m	(1/0.1)	// 1MMD単位 = 10cm。本来は8cm程度?
#define		m	(1/0.08)	// 1MMD単位 ≒ 8cm
#define		cm	(m * 0.01)
#define		mm	(m * 0.001)

#define	PI	(3.14159265359)
#define RAD2DEG(x)	((x) * 180 / PI)
#define DEG2RAD(x)	((x) * PI / 180)
#define LOG2_E	(1.44269504089)		// log(e)/log(2)

// コントローラのモーフで設定したパラメータのスケール値
#define AbsoluteFocusScale		(50.0 * m)		// 絶対ピント距離係数(m)
#define RelativeFocusScale		(5.0 * m)		// 相対ピント距離係数(m)
#define FocalLengthScale		(100.0 * mm)	// 焦点距離係数(mm)
#define DefaultFNumber			4.0				// デフォルトの絞り
#define FNumberScale			4.0				// 絞り係数
#define BokehFocalLengthScale	(50.0 * mm)		// ボケ調整時の焦点距離係数(mm)

// 内部的な制限
const float MinFocusDistance = (0.1 * m);
const float MinFocalLength = (20.0 * mm);
const float MaxFocalLength = (200.0 * mm);
const float MinFNumber = 1.0;
const float MaxFNumber = 16.0;

// フィルムサイズ。35mmフィルムだと24x36mm
const float FilmSize = 24 * mm;

// なにも描画しない場合の背景までの距離
// これを弄るより普通にスカイドームなどの背景をおいたほうがいい。
// 弄る場合、ikDepth.fxの同名の値も変更する必要がある。
#define FAR_DEPTH		1000

// ボケの半径上限 (ピクセル数)
#define MAX_COC_SIZE	(KERNEL_RADIUS * 8)

// a16-garcia.pdfの数値
// C0_abAB = {0.886528, 5.268909, 0.411259,-0.548794}
// C1_abAB = {1.960518, 1.558213, 0.513282, 4.561110}
float4 KernelC_ab0_ab1 = float4(-0.886528 * LOG2_E, 5.268909, -1.960518 * LOG2_E, 1.558213);
float4 KernelC_AB0_AB1 = float4(0.411259,-0.548794, 0.513282, 4.561110);
float InvAlpha = 0.064754486; // 1/alpha. 重いので前計算しておく


//****************** 設定はここまで

float4x4 matP : PROJECTION;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time2 : time1;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time2 : elapsed_time1, 1.0/120.0, 1.0/15.0);

#ifdef AF_BONE_NAME
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; string item = AF_BONE_NAME; >;
#else
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; >;
#endif

// 外部コントローラ
bool isExistController : CONTROLOBJECT < string name = CONTROLLER_NAME; >;
float3 mCtrlPosition : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "全ての親";>;
float mPintDistanceP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント距離+"; >;
float mPintDistanceM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント距離-"; >;

float mPintDelayParam : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント遅延"; >;
float mPintSlip : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント滑り"; >;
static float mPintDelay = (isExistController || DEFAULT_MEASURING_MODE ==0) ? mPintDelayParam : 0.5;

float mMeasuringXP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点x+"; >;
float mMeasuringXM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点x-"; >;
float mMeasuringYP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点y+"; >;
float mMeasuringYM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点y-"; >;
float2 CalcMeasuringPosition()
{
	float2 basePos = float2(mMeasuringXP - mMeasuringXM, mMeasuringYP - mMeasuringYM) * 0.5 + 0.5;
	float2 offset = mCtrlPosition.xy * float2(1, -1) * 0.1;
	return basePos + offset;
}
static float2 mMeasuringPosition = CalcMeasuringPosition();

//float mFNumber : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "絞り"; >;
float mBokehP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ボケ+"; >;
float mBokehM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ボケ-"; >;
float mFBokehM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "前ボケ-"; >;
float mCoCSize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "CoCサイズ"; >;
float mEmphasize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "玉ボケ強調"; >;

float mTestMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "テストモード"; >;

float mAFModeParam : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "AF測距モード"; >;
static int mAFMode = (isExistController) ? (int)(mAFModeParam * 3.0 + 0.1) : DEFAULT_MEASURING_MODE;
float mManualMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "マニュアルモード"; >;
float mPintDistance : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント距離"; >;
float mFocalLength : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "焦点距離"; >;

bool bLinearMode : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ForceCoCSacle = FORCE_COC_SCALE * AcsSi * 0.1 * (mCoCSize + 1.0);


//=============================================================================

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// ワーク用テクスチャの設定
#define FILTER_MODE			MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
//#define ADDRESSING_MODE		AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
#define ADDRESSING_MODE		AddressU = CLAMP; AddressV = CLAMP;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5) / ViewportSize.xy);
static float2 SampleStep = (float2(1.0,1.0) / ViewportSize.xy);
static float2 AspectRatio = float2(ViewportSize.x / ViewportSize.y, 1);

// ブラー用の係数
float4 DailateWeightArray[] = {
	float4(1.000000000,0.960005441,0.849365817,0.692569324),
	float4(0.520450121,0.360447789,0.230066299,0.135335283)
};
static float DailateWeight[8] = (float[8])DailateWeightArray;

float4 BlurWeightArray[] = {
	float4(0.2706821495,0.2167453214,0.1112807585,0.0366328454)
};
static float BlurWeight[4] = (float[4])BlurWeightArray;


texture2D ScnMap : RENDERCOLORTARGET <
	bool AntiAlias = false;
	float2 ViewportRatio = {1, 1};
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	FILTER_MODE		ADDRESSING_MODE
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {1, 1};
	string Format = "D24S8";
>;

#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		int MipLevels = 1; \
		float2 ViewportRatio = {1.0 / (_size), 1.0 / (_size)}; \
		string Format = WORK_TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		LINEAR_FILTER_MODE	ADDRESSING_MODE \
	};

DECL_TEXTURE( DownscaleMap0, DownscaleSamp0, 1)
DECL_TEXTURE( DownscaleMap1, DownscaleSamp1, 2)
DECL_TEXTURE( BlurMap1, BlurSamp1, 2)	// Back
DECL_TEXTURE( BlurMap2, BlurSamp2, 2)	// Front
DECL_TEXTURE( BlurMapR, BlurSampR, 2)
DECL_TEXTURE( BlurMapG, BlurSampG, 2)
DECL_TEXTURE( BlurMapB, BlurSampB, 2)
DECL_TEXTURE( BlurMapA, BlurSampA, 2)

// 探索範囲
texture2D CoCMap0 : RENDERCOLORTARGET <
	float2 ViewportRatio = {0.5,0.5};
	int MipLevels = 1;
	string Format="R16F";
>;
sampler2D CoCSamp0 = sampler_state {
	Texture = <CoCMap0>;
	LINEAR_FILTER_MODE	ADDRESSING_MODE
};
texture2D CoCMap1 : RENDERCOLORTARGET <
	float2 ViewportRatio = {0.5,0.5};
	int MipLevels = 1;
	string Format="R16F";
>;
sampler2D CoCSamp1 = sampler_state {
	Texture = <CoCMap1>;
	LINEAR_FILTER_MODE	ADDRESSING_MODE
};

// 自動焦点用の情報。フレームを超えて情報をやりとりする。
texture2D AutoFocusTex : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	int MipLevels = 1;
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp = sampler_state {
	Texture = <AutoFocusTex>;
	FILTER_MODE	ADDRESSING_MODE
};
texture2D AutoFocusTex2 : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	int MipLevels = 1;
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp2 = sampler_state {
	Texture = <AutoFocusTex2>;
	FILTER_MODE	ADDRESSING_MODE
};
texture AutoFocusDepthBuffer : RenderDepthStencilTarget <
	int2 Dimensions = {1,1};
	string Format = "D24S8";
>;

#if WRITE_COEF > 0
// 計算用のワーク
//#define COEF_TEX_WIDTH	(KERNEL_RADIUS+1) // 念のために2^xにする。
#define COEF_TEX_WIDTH	(KERNEL_RADIUS * 2)
texture2D CoefMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	int2 Dimensions = {COEF_TEX_WIDTH, 1};
	string Format = "A16B16G16R16F";
>;
sampler2D CoefSamp = sampler_state {
	texture = <CoefMap>;
	FILTER_MODE	ADDRESSING_MODE
};
#endif


//-----------------------------------------------------------------------------
// 深度マップ
texture LinearDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikBokeh.fx";
	float4 ClearColor = { 1.0, 0, 0, 1 };
	float2 ViewportRatio = {1, 1};
	float ClearDepth = 1.0;
	string Format = "R16F";
	bool AntiAlias = false;
	int MipLevels = 1;
	string DefaultEffect =
		"ikBokeh*.* = hide;"
		"rgbm_*.x = depth_rgbm.fx;"	// スカイドーム
		"*.pm* = depth.fx;"
		"*.x = depth.fx;"
		"* = hide;";
>;
sampler DepthMap = sampler_state {
	texture = <LinearDepthMapRT>;
	FILTER_MODE	ADDRESSING_MODE
};


//-----------------------------------------------------------------------------
// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
float3 Degamma(float3 col) { return (!bLinearMode) ? pow(max(col,epsilon), gamma) : col; }
float3 Gamma(float3 col) { return (!bLinearMode) ? pow(max(col,epsilon), 1.0/gamma) : col; }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float rgb2gray(float3 rgb) { return dot(float3(0.299, 0.587, 0.114), rgb); }

// 色の強調
#if ENABLE_EMPHASIZE_COLOR > 0
float CalcEmphasizeRate()
{
	float emphasizeRate = (saturate(mEmphasize) * EMPHASIZE_RATE + 1.0);
	return (mEmphasize <= 0.0) ? 0.0 : emphasizeRate;
}
float CalcDepreciateRate()
{
	// NOTE: >0 にしないと値を使わなくても、結果がNan(Inf?)になる。
	float emphasizeRate = max(CalcEmphasizeRate(), 1e-4);
	return (mEmphasize <= 0.0) ? 0.0 : (1.0 / emphasizeRate);
}
float3 EmphasizeColor(float3 col, float rate)
{
	return (rate > 0.0) ? pow(max(col, 0), rate) : col;
}
float3 DepreciateColor(float3 col, float rate)
{
	return (rate > 0.0) ? pow(max(col, 0), rate) : col;
}
#else
float CalcEmphasizeRate() { return 0; }
float CalcDepreciateRate() { return 0; }
float3 EmphasizeColor(float3 col, float rate) { return col; }
float3 DepreciateColor(float3 col, float rate) { return col; }
#endif

//-----------------------------------------------------------------------------
// どれだけボケるか

float GetTanFoV()
{
	return 1.0 / matP._22;
}

float CalcFNumber()
{
	float f = DefaultFNumber + isExistController * ((mBokehM - mBokehP) * FNumberScale);
	return clamp(f, MinFNumber, MaxFNumber);
}

float CalcFocalLength(float focusDistance)
{
	float L = focusDistance;
	float h2 = FilmSize / 2.0;
	float focalA = (L * h2) / (GetTanFoV() * L + h2);

	float focalM = MinFocalLength + mFocalLength * FocalLengthScale;

	float focal = lerp(focalA, focalM, mManualMode);
	focal += (mBokehP - mBokehM) * BokehFocalLengthScale;
	return clamp(focal, MinFocalLength, MaxFocalLength);
}

// CoC計算用の係数を求める
// CoC(x) = V * D / L - V * D / x を C1 / x + C2 の形式にする。
float2 CalcCoCCoef(float focusDistance)
{
	float L = focusDistance;
	float f = CalcFocalLength(L);
	float F = CalcFNumber();
	float D = f / F;		// 有効径。
	float M = f / (L - f);	// 撮像倍率。
//	float V = L * M;		// 実効焦点距離
	float toPixel = ViewportSize.y / FilmSize; // ピクセル数に変換するための係数

	float CoCCoef1 = -(M * D * toPixel) * L;
	float CoCCoef2 =  (M * D * toPixel);

	return float2(CoCCoef1 / FAR_DEPTH, CoCCoef2);
}

float CalcBlurLevel(float2 coef, float depth)
{
	float CoC = coef.x / depth + coef.y;
	return clamp(CoC, -MAX_COC_SIZE, MAX_COC_SIZE);
}

float MeasuringCircleRadius()
{
	return (mAFMode > 1.5) ? 0.2 : 0.05;
}


//-----------------------------------------------------------------------------
//

float4 TestColor(float3 Color, float level, float2 uv)
{
	// テストモード
	#if ENABLE_TEST_MODE == 1
	if (mTestMode >= 0.5)
	{
		Color = rgb2gray(Color) * 0.98 + 0.02; // 真っ黒い部分に色を乗せるためにゲタを履かせる。

		// 測距点の表示
		float r = length((uv - mMeasuringPosition) * AspectRatio);
		float mcr = MeasuringCircleRadius();
		if (mAFMode > 0.5 && r > mcr * 0.5 && r < mcr)
		{
			// 黄色にする
			Color.b = 0;
		}
		else
		{
			// ピントの合致度
			float radius = abs(level);
			float grad = saturate(Color.g - saturate(radius - 1));
			if (radius < 0.1) Color.rg = saturate(Color.g - (1.0 - radius * 10.0));
			else if (level < 0.0) Color.g = grad;
			else if (level > 0.0) Color.rb = grad;
		}
	}
	#endif

	return float4(Color, 1);
}

//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
	float4 TexCoord1	: TEXCOORD1;
	float4 TexCoord2	: TEXCOORD2;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;

	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4( 1,-1,  1, 1);
	return Out;
}

VS_OUTPUT VS_CalcCoC( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy;
	float2 Offset = SampleStep;

	Out.TexCoord = float4(TexCoord, Offset);

	// 距離計算用係数を求める
	float focusDistance = tex2Dlod(AutoFocusSmp2, float4(0.5,0.5, 0,0)).x;
	// 画角の変化に対してもピントの遅れを発生させる
	focusDistance /= GetTanFoV();
	Out.TexCoord1.xy = CalcCoCCoef(focusDistance);

	// CoCサイズの調整係数
	Out.TexCoord1.z = ForceCoCSacle;
	Out.TexCoord1.w = FRONT_BOKEH_SCALE * (1 - mFBokehM);
	// 色強調用の係数
	Out.TexCoord2.x = CalcEmphasizeRate();

	return Out;
}

VS_OUTPUT VS_DailateCoC( float4 Pos : POSITION, float4 Tex : TEXCOORD0,
	uniform float level, uniform bool bHorizontal, uniform float stepSize)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level * stepSize;
	Offset *= (bHorizontal ? float2(1,0) : float2(0,1));

	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4( 1,-1,  1, 1);
	return Out;
}

VS_OUTPUT VS_Blur( float4 Pos : POSITION, float4 Tex : TEXCOORD0,
	uniform float level, uniform bool bHorizontal)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Offset *= (bHorizontal ? float2(1,0) : float2(0,1));

	Out.TexCoord = float4(TexCoord, Offset);
	return Out;
}

VS_OUTPUT VS_Gather( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;

	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1.x = CalcDepreciateRate();

	return Out;
}

//-----------------------------------------------------------------------------
// 自動測距

VS_OUTPUT VS_UpdateFocusDistance( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	// Out.TexCoord = float4(Tex.xy, 0, 0);
	return Out;
}

// 合焦距離の取得
float CalcFocusDistance()
{
	// AFPositionの深度
	float fd = distance(AFPosition, CameraPosition);

	// 測距点セレクト/測距点オート
	float2 center = mMeasuringPosition;
	float r1 = MeasuringCircleRadius();
	float r2 = r1 * 0.714;
	// MEMO: AspectRatioを考慮していない
	float depthA0 = tex2D( DepthMap, float2(-r2,-r2) + center).x;
	float depthA1 = tex2D( DepthMap, float2(-r1,  0) + center).x;
	float depthA2 = tex2D( DepthMap, float2(-r2, r2) + center).x;
	float depthA3 = tex2D( DepthMap, float2(  0,-r1) + center).x;
	float depthA4 = tex2D( DepthMap, float2(  0,  0) + center).x;
	float depthA5 = tex2D( DepthMap, float2(  0, r1) + center).x;
	float depthA6 = tex2D( DepthMap, float2( r2,-r2) + center).x;
	float depthA7 = tex2D( DepthMap, float2( r1,  0) + center).x;
	float depthA8 = tex2D( DepthMap, float2( r2, r2) + center).x;
	if (mAFMode > 0.5)
	{
		float4 depthMin = min(
			float4(depthA0,depthA1,depthA2,depthA3),
			float4(depthA4,depthA5,depthA6,depthA7));
		depthMin.xy = min(depthMin.xy, depthMin.zw);
		fd = min(min(depthMin.x, depthMin.y), depthA8) * FAR_DEPTH;
	}

	// マニュアルフォーカス
	float fdM = mPintDistance * AbsoluteFocusScale;
	fd = lerp(fd, fdM, mManualMode);

	// 微調整分
	float pd = mPintDistanceP - mPintDistanceM;
	pd = (pd * pd) * sign(pd);
	float adjuster = pd * RelativeFocusScale + mCtrlPosition.z;
	fd = max(fd + adjuster, MinFocusDistance);

	return fd;
}

float4 PS_UpdateFocusDistance(float2 Tex: TEXCOORD0) : COLOR
{
	float depth0 = CalcFocusDistance();

	// 画角の変化に対してもピントの遅れを発生させる
	depth0 *= GetTanFoV();

	float4 data = tex2Dlod(AutoFocusSmp2, float4(0.5,0.5,0,0));
	float depth1 = data.x;
	float velocity = data.y;
	float prevTime = data.z;	// 前回との時間が大幅に違ったら初期化する?

	// 0フレ目なら初期化
	if (time < 1.0 / 120.0)
	{
		depth1 = depth0;
		velocity = 0;
	}

	// 減速
	velocity = velocity * pow(max(0.8 * mPintSlip, 1e-4), Dt * 30.0);
	float v = depth0 - (depth1 + velocity);
	// 手前ほど距離合わせは高速になる
	float speed = min(abs(v), clamp(35000.0 / depth0, 50.0, 1000.0) * 30.0 * Dt);
	velocity += sign(v) * speed * (1.0 - mPintDelay);
	depth1 += velocity;

	depth1 = max(depth1, MinFocusDistance * GetTanFoV());
	return float4(depth1, velocity, time, 1.0);
}

float4 PS_CopyFocusDistance(float2 Tex: TEXCOORD0) : COLOR
{
	return tex2Dlod(AutoFocusSmp, float4(0.5,0.5,0,0));
}

//-----------------------------------------------------------------------------
// CoCの計算
float4 PS_CalcCoC( VS_OUTPUT IN ) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color = Degamma4(tex2D(ScnSamp, texCoord));
	float Depth = tex2D( DepthMap, texCoord).x;

	float level = CalcBlurLevel(IN.TexCoord1.xy, Depth);

	float forceCoCSacle = IN.TexCoord1.z;
	float frontCoCSacle = IN.TexCoord1.w;
	level = (level >= 0.0) ? level : (level * frontCoCSacle);
	level = (abs(level) >= 1.0)
			? sign(level) * ((abs(level) - 1.0) * forceCoCSacle + 1)
			: level;

	float emphasizeRate = IN.TexCoord2.x;
	Color.rgb = EmphasizeColor(Color.rgb, emphasizeRate);

	return float4(Color.rgb, level);
}

// 低解像度のバッファを作る
float CalcWeight(float w) { return saturate(w); }

float4 PS_DownSampling( VS_OUTPUT IN, uniform sampler2D smp, uniform bool bBack) : COLOR
{
	float4 Color0 = tex2D(smp, IN.TexCoord1.xy);
	float4 Color1 = tex2D(smp, IN.TexCoord1.zw);
	float4 Color2 = tex2D(smp, IN.TexCoord2.xy);
	float4 Color3 = tex2D(smp, IN.TexCoord2.zw);

	float s = bBack ? 1 : -1;

	float4 Color = 0;
	float4 w;
	w.x = CalcWeight(Color0.w * s); Color += Color0 * w.x;
	w.y = CalcWeight(Color1.w * s); Color += Color1 * w.y;
	w.z = CalcWeight(Color2.w * s); Color += Color2 * w.z;
	w.w = CalcWeight(Color3.w * s); Color += Color3 * w.w;
	Color = Color / max(dot(w,1), epsilon);

	Color.w *= 0.5 * s;
	Color.rgb *= saturate(Color.w);

	return Color;
}

// CoCの範囲を大きくする
float4 PS_DailateCoCX( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;
	float coc = tex2D(smp, texCoord).x;
	for(int i = 1; i < 8; i++)
	{
		float coc0 = tex2D(smp, texCoord + i * offset).x;
		float coc1 = tex2D(smp, texCoord - i * offset).x;
		coc = max(coc, max(coc0, coc1) * DailateWeight[i]);
	}
	return float4(coc, 0, 0, 1);
}

float4 PS_DailateCoCW( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;
	float coc = tex2D(smp, texCoord).w;
	for(int i = 1; i < 8; i++)
	{
		float coc0 = tex2D(smp, texCoord + i * offset).w;
		float coc1 = tex2D(smp, texCoord - i * offset).w;
		coc = max(coc, max(coc0, coc1) * DailateWeight[i]);
	}
	return float4(coc, 0, 0, 1);
}

//-----------------------------------------------------------------------------
// CircularDoF

float4 CalcFilter(float x)
{
	float4 k = KernelC_ab0_ab1 * (x * x);
	float2 e01 = float2(exp2(k.x), exp2(k.z)) * InvAlpha;
	float4 sc01;
	sincos(k.y, sc01.y, sc01.x);
	sincos(k.w, sc01.w, sc01.z);
	return sc01.xyzw * e01.xxyy;
}

#if WRITE_COEF > 0
VS_OUTPUT VS_MakeCoef( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	float2 offset = 0.5 / float2(COEF_TEX_WIDTH, 1);
	Out.TexCoord = float4(Tex.xy + offset, 0, 0);
	return Out;
}
float4 PS_MakeCoef( VS_OUTPUT IN) : COLOR
{
	float x = floor(IN.TexCoord.x * COEF_TEX_WIDTH);
	return CalcFilter(x * (1.0 / KERNEL_RADIUS));
}
float4 GetFilter(float x)
{
	return tex2Dlod(CoefSamp, float4((x + 0.5) / COEF_TEX_WIDTH, 0.5,0,0));
}
#else

float4 GetFilter(float x)
{
	return CalcFilter(x * (1.0 / KERNEL_RADIUS));
}
#endif

float4 MultComplex2(float4 p, float4 q)
{
	return p.xxzz * q.xyzw + float4(-1,1,-1,1) * p.yyww * q.yxwz;
}

struct PS_OUT_MRT
{
	float4 ColorR	: COLOR0;
	float4 ColorG	: COLOR1;
	float4 ColorB	: COLOR2;
	float4 ColorA	: COLOR3;
};

PS_OUT_MRT PS_CircularDoFH( VS_OUTPUT IN, uniform sampler2D smp)
{
	float2 texCoord = IN.TexCoord.xy;

	float4 c0 = GetFilter(0);
	float4 color = tex2D(smp, texCoord);
	float4 sumR = color.r * c0; // == MultComplex2(float4(color.r,0,color.r,0), c0)
	float4 sumG = color.g * c0;
	float4 sumB = color.b * c0;
	float4 sumA = saturate(color.w) * c0;

	float coc = tex2D(CoCSamp1, texCoord).x;
	float2 offset = float2(coc * (1.0 / ViewportSize.x / KERNEL_RADIUS), 0);

	for(int i = 1; i <= KERNEL_RADIUS; i++)
	{
		float4 c1 = GetFilter(i);
		float4 colorP = tex2Dlod(smp, float4(texCoord + i * offset, 0,0));
		float4 colorN = tex2Dlod(smp, float4(texCoord - i * offset, 0,0));
		float3 color1 = colorP.rgb + colorN.rgb;
		sumR += color1.r * c1;
		sumG += color1.g * c1;
		sumB += color1.b * c1;
		sumA += (saturate(colorP.w) + saturate(colorN.w)) * c1;
	}

	PS_OUT_MRT Out;
	Out.ColorR = sumR;	Out.ColorG = sumG;
	Out.ColorB = sumB;	Out.ColorA = sumA;

	return Out;
}

float4 PS_CircularDoFV( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;

	float4 c0 = GetFilter(0);
	float4 sumR = MultComplex2(tex2D(BlurSampR, texCoord), c0);
	float4 sumG = MultComplex2(tex2D(BlurSampG, texCoord), c0);
	float4 sumB = MultComplex2(tex2D(BlurSampB, texCoord), c0);
	float4 sumA = MultComplex2(tex2D(BlurSampA, texCoord), c0);

	float coc = tex2D(CoCSamp1, texCoord).x;
	float2 offset = float2(0, coc * (1.0 / ViewportSize.y / KERNEL_RADIUS));

	for(int i = 1; i <= KERNEL_RADIUS; i++)
	{
		float4 c1 = GetFilter(i);
/*
		sumR += MultComplex2(tex2Dlod(BlurSampR, float4(texCoord + i * offset,0,0)), c1);
		sumR += MultComplex2(tex2Dlod(BlurSampR, float4(texCoord - i * offset,0,0)), c1);
*/
		float4 r1 = tex2Dlod(BlurSampR, float4(texCoord + i * offset, 0,0));
		float4 g1 = tex2Dlod(BlurSampG, float4(texCoord + i * offset, 0,0));
		float4 b1 = tex2Dlod(BlurSampB, float4(texCoord + i * offset, 0,0));
		float4 a1 = tex2Dlod(BlurSampA, float4(texCoord + i * offset, 0,0));
		r1 += tex2Dlod(BlurSampR, float4(texCoord - i * offset, 0,0));
		g1 += tex2Dlod(BlurSampG, float4(texCoord - i * offset, 0,0));
		b1 += tex2Dlod(BlurSampB, float4(texCoord - i * offset, 0,0));
		a1 += tex2Dlod(BlurSampA, float4(texCoord - i * offset, 0,0));
		sumR += MultComplex2(r1, c1);
		sumG += MultComplex2(g1, c1);
		sumB += MultComplex2(b1, c1);
		sumA += MultComplex2(a1, c1);
	}

	float4 Color = float4(
		dot(sumR, KernelC_AB0_AB1),	dot(sumG, KernelC_AB0_AB1),
		dot(sumB, KernelC_AB0_AB1),	dot(sumA, KernelC_AB0_AB1));
	Color = max(Color, 0);

	float4 Color0 = tex2D(DownscaleSamp0, texCoord);
	float k = (1.0 / 1024.0);
	Color.rgb += Color0.rgb * k;
	Color.rgb = Color.rgb / saturate(Color.w + k);

	return Color;
}

// CoCに応じてボカす量を変える
float4 PS_StretchBlur( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float coc = tex2D(CoCSamp1, texCoord).x;
	offset *= saturate(coc * (1.0 / KERNEL_RADIUS / 8.0));

	float4 col = tex2D(smp, texCoord) * BlurWeight[0];
	for(int i = 1; i < 4; i++)
	{
		float2 uv0 = texCoord + i * offset;
		float2 uv1 = texCoord - i * offset;
		col += (tex2D(smp, uv0) + tex2D(smp, uv1)) * BlurWeight[i];
	}
	return col;
}

float4 PS_FixedBlur( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float2 gWeights = float2(0.44908, 0.05092);
	float4 gOffsets = float4(0.53805, 2.06278, -0.53805, -2.06278);

	float4 col = 0;
	col += tex2D(smp, texCoord + gOffsets.x * offset) * gWeights.x;
	col += tex2D(smp, texCoord + gOffsets.y * offset) * gWeights.y;
	col += tex2D(smp, texCoord + gOffsets.z * offset) * gWeights.x;
	col += tex2D(smp, texCoord + gOffsets.w * offset) * gWeights.y;
	return col;
}

// 結果の合成
float4 PS_Gather( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color0 = tex2D(DownscaleSamp0, texCoord);
	float depth = Color0.w;
	float coc = Color0.w;

	float4 ColorB = tex2D(BlurSamp1, texCoord);
	float4 ColorF = tex2D(BlurSamp2, texCoord);

	float4 Color = 1;
	Color.rgb = lerp(Color0.rgb, ColorB.rgb, saturate(coc - PINT_MARGIN));
	Color.rgb = lerp(Color.rgb , ColorF.rgb, saturate(ColorF.w));

	float demphasizeRate = IN.TexCoord1.x;
	Color.rgb = DepreciateColor(Color.rgb, demphasizeRate);
	Color = Gamma4(TestColor( Color.rgb, depth, texCoord));

	return Color;
}

//=============================================================================

#define	SET_MRT	\
		"RenderColorTarget0=BlurMapR;	RenderColorTarget1=BlurMapG;" \
		"RenderColorTarget2=BlurMapB;	RenderColorTarget3=BlurMapA;"
#define	RESET_MRT	\
		"RenderColorTarget1=;	RenderColorTarget2=;	RenderColorTarget3=;"

technique DepthOfField2 <
	string Script =
		// 普通の画面をレンダリング
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		// オートフォーカスの計算
		"RenderDepthStencilTarget=AutoFocusDepthBuffer;"
		"RenderColorTarget0=AutoFocusTex;	Pass=UpdateFocusPass;"
		"RenderColorTarget0=AutoFocusTex2;	Pass=CopyFocusPass;"
		// CoCのサイズ計算
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=DownscaleMap0;	Pass=CalcCoCPass;"
		#if WRITE_COEF > 0
		// 計算用の係数を出力
		"RenderColorTarget0=CoefMap;		Pass=MakeCoefPass;"
		#endif

		// 後ボケ
		"RenderColorTarget0=DownscaleMap1;	Pass=DownscalePassBack;"
		"RenderColorTarget0=CoCMap0;		Pass=DailateCoCPassX;"
		"RenderColorTarget0=CoCMap1;		Pass=DailateCoCPassY;"
		SET_MRT	"							Pass=BlurPassH;"	RESET_MRT
		"RenderColorTarget0=BlurMap1;		Pass=BlurPassV;"
		// 軽くボカす(ノイズの軽減)
		"RenderColorTarget0=BlurMapR;		Pass=StretchBlurPassH;"
		"RenderColorTarget0=BlurMap1;		Pass=StretchBlurPassV;"

		// 前ボケ
		"RenderColorTarget0=DownscaleMap1;	Pass=DownscalePassFront;"
		"RenderColorTarget0=CoCMap0;		Pass=DailateCoCPassX2;"
		"RenderColorTarget0=CoCMap1;		Pass=DailateCoCPassY2;"
		"RenderColorTarget0=CoCMap0;		Pass=DailateCoCPassX3;"
		"RenderColorTarget0=CoCMap1;		Pass=DailateCoCPassY3;"
		SET_MRT	"							Pass=BlurPassH;"	RESET_MRT
		"RenderColorTarget0=BlurMap2;		Pass=BlurPassV;"
		"RenderColorTarget0=BlurMapR;		Pass=FixedBlurPassH;"
		"RenderColorTarget0=BlurMap2;		Pass=FixedBlurPassV;"

		// 合成
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=GatherPass;"
	;
> {
	pass UpdateFocusPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UpdateFocusDistance();
		PixelShader  = compile ps_3_0 PS_UpdateFocusDistance();
	}
	pass CopyFocusPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UpdateFocusDistance();
		PixelShader  = compile ps_3_0 PS_CopyFocusDistance();
	}

	pass CalcCoCPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_CalcCoC();
		PixelShader  = compile ps_3_0 PS_CalcCoC();
	}

	#if WRITE_COEF > 0
	pass MakeCoefPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_MakeCoef();
		PixelShader  = compile ps_3_0 PS_MakeCoef();
	}
	#endif

	pass DownscalePassBack < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp0, true);
	}
	pass DownscalePassFront < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp0, false);
	}

	pass DailateCoCPassX < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, true, 1);
		PixelShader  = compile ps_3_0 PS_DailateCoCW(DownscaleSamp1);
	}
	pass DailateCoCPassY < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, false, 1);
		PixelShader  = compile ps_3_0 PS_DailateCoCX(CoCSamp0);
	}
	pass DailateCoCPassX2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, true, 16);
		PixelShader  = compile ps_3_0 PS_DailateCoCW(DownscaleSamp1);
	}
	pass DailateCoCPassY2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, false, 16);
		PixelShader  = compile ps_3_0 PS_DailateCoCX(CoCSamp0);
	}
	pass DailateCoCPassX3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, true, 8);
		PixelShader  = compile ps_3_0 PS_DailateCoCX(CoCSamp1);
	}
	pass DailateCoCPassY3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DailateCoC(2, false, 8);
		PixelShader  = compile ps_3_0 PS_DailateCoCX(CoCSamp0);
	}

	pass BlurPassH < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_CircularDoFH(DownscaleSamp1);
	}
	pass BlurPassV < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_CircularDoFV(DownscaleSamp1);
	}

	pass StretchBlurPassH < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(2, true);
		PixelShader  = compile ps_3_0 PS_StretchBlur(BlurSamp1);
	}
	pass StretchBlurPassV < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(2, false);
		PixelShader  = compile ps_3_0 PS_StretchBlur(BlurSampR);
	}

	pass FixedBlurPassH < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(2, true);
		PixelShader  = compile ps_3_0 PS_FixedBlur(BlurSamp2);
	}
	pass FixedBlurPassV < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(2, false);
		PixelShader  = compile ps_3_0 PS_FixedBlur(BlurSampR);
	}

	pass GatherPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Gather(1);
		PixelShader  = compile ps_3_0 PS_Gather();
	}
}

//=============================================================================
