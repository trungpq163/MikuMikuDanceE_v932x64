//=============================================================================
// ikBokeh.fx
// ポストプロセスで被写界深度のエミュレートを行う。
//=============================================================================


// 32bit版のMMEを使用している。0:64bit版、1:32bit版
#define USE_MME_32BIT		1


// 強制的に玉ボケのサイズをスケーリングする。1:等倍(デフォルト)、2:2倍になる。
// 別途設定されているサイズ上限を超えることはない。
#define FORCE_COC_SCALE		(1.0)

// 前ボケの大きさ。0.1～1.0。0に近づけることで前ボケを小さくする
#define FRONT_BOKEH_SCALE		(1.0)

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

// 時間の同期：編集中もズーム時間を考慮するか?
#define	TimeSync		1

// コントローラが無い場合の測距モードの値
// 0: アクセサリの位置
// 1: 画面中央(狭)にピントを合わせる
// 2: 画面中央(広)にピントを合わせる
#define	DEFAULT_MEASURING_MODE	0

// 0:エフェクト無効、1:エフェクト有効
#define BOKEH_LEVEL		1

// 1回でボカすサイズ (6-8程度。小さいほど高速。)
#define BULR_SIZE		8

// 玉ボケの強調：玉ボケDOF(Elle/データP)から借用
#define ENABLE_EMPHASIZE_COLOR	1
// 最大強調度合
#define EMPHASIZE_RATE	4

// 縮小バッファを追加するかどうか。
#define ENABLE_DEEP_LEVEL	0

//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// テクスチャフォーマット
//	HDRを使うなら、浮動小数点である必要がある。
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"
//#define TEXFORMAT "A8R8G8B8"

// 計算用テクスチャのフォーマット
//	浮動小数点でないと計算結果を維持できない。
#define WORK_TEXFORMAT "A16B16G16R16F"


// 単位調整用の変数。
#define		m	(10.0)	// 1MMD単位 = 10cm。本来は8cm程度?
#define		cm	(m * 0.01)
#define		mm	(m * 0.001)

// コントローラのモーフで設定したパラメータのスケール値
#define AbsoluteFocusScale		100.0			// 絶対ピント距離(m)
#define RelativeFocusScale		50.0			// 相対ピント距離(m)
#define FocalLengthScale		100.0			// 焦点距離(mm)
#define DefaultFNumber			4.0				// デフォルトの絞り
#define FNumberScale			4.0				// 絞り係数
#define BokehFocalLengthScaleP	1.0				// ボケ調整時の焦点距離(ボケ増加)
#define BokehFocalLengthScaleM	1.0				// ボケ調整時の焦点距離(ボケ減少)

// 内部的な制限
const float MinFocusDistance = (0.1 * m);
const float MinFocalLength = (20.0 * mm);
const float MaxFocalLength = (200.0 * mm);
const float MinFNumber = 1.0;
const float MaxFNumber = 16.0;

const float gamma = 2.2;
#define	PI	(3.14159265359)

// フィルムサイズ。一般的に35mmか70mmを使う(らしい)
const float FilmSize = 35 * mm;

// なにも描画しない場合の背景までの距離
// これを弄るより普通にスカイドームなどの背景をおいたほうがいい。
// 弄る場合、ikDepth.fxの同名の値も変更する必要がある。
#define FAR_DEPTH		1000

//****************** 設定はここまで

#define Rad2Deg(x)	((x) * 180 / PI)

float4x4 matV : VIEW;
float4x4 matP : PROJECTION;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time1 : elapsed_time2, 1.0/120.0, 1.0/15.0);

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
float mPintFrictionParam : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント安定度"; >;
static float mPintDelay = (isExistController || DEFAULT_MEASURING_MODE == 0) ? mPintDelayParam : 0.8;
static float mPintFriction = (isExistController || DEFAULT_MEASURING_MODE == 0) ? mPintFrictionParam : 0.5;

float mMeasuringXP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点x+"; >;
float mMeasuringXM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点x-"; >;
float mMeasuringYP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点y+"; >;
float mMeasuringYM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "測距点y-"; >;
static float2 mMeasuringPosition = float2(mMeasuringXP - mMeasuringXM, mMeasuringYP - mMeasuringYM) * 0.5 + 0.5 + mCtrlPosition.xy * float2(1, -1) * 0.1;

//float mFNumber : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "絞り"; >;
float mBokehP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ボケ+"; >;
float mBokehM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ボケ-"; >;
float mFBokehM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "前ボケ-"; >;
float mCoCSize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "CoCサイズ"; >;
float mEmphasize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "玉ボケ強調"; >;
static float mEmphasizeScale = EMPHASIZE_RATE * (0.1 + mEmphasize);

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

#define ScreenScale		1
#define MinimumCoCRadius	0.01		// CoCの最低保証値。小さすぎると発散する。

// ボケの半径上限
#define MAX_COC_SIZE	((BULR_SIZE) * 8)

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
static float2 ViewportOffset = (float2(0.5,0.5) /(ScreenScale * ViewportSize.xy));
static float2 SampleStep = (float2(1.0,1.0) / (ScreenScale * ViewportSize.xy));
static float2 AspectRatio = float2(ViewportSize.x / ViewportSize.y, 1);

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	bool AntiAlias = false;
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;

sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	FILTER_MODE
	ADDRESSING_MODE
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	string Format = "D24S8";
>;

#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		int MipLevels = 1; \
		float2 ViewportRatio = {ScreenScale * 1.0/(_size), ScreenScale * 1.0/(_size)}; \
		string Format = WORK_TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		FILTER_MODE	ADDRESSING_MODE \
	}; \
	sampler2D _samp##Linear = sampler_state { \
		texture = <_map>; \
		LINEAR_FILTER_MODE	ADDRESSING_MODE \
	};

DECL_TEXTURE( DownscaleMap0, DownscaleSamp0, 1)
DECL_TEXTURE( DownscaleMap1, DownscaleSamp1, 2)
DECL_TEXTURE( DownscaleMap2, DownscaleSamp2, 4)
DECL_TEXTURE( DownscaleMap3, DownscaleSamp3, 8)

DECL_TEXTURE( BlurMap0, BlurSamp0, 1)
DECL_TEXTURE( BlurMap1, BlurSamp1, 2)
DECL_TEXTURE( BlurMap2, BlurSamp2, 4)
DECL_TEXTURE( BlurMap3, BlurSamp3, 8)

DECL_TEXTURE( BlurMapF0, BlurSampF0, 1)
DECL_TEXTURE( BlurMapF1, BlurSampF1, 2)
DECL_TEXTURE( BlurMapF2, BlurSampF2, 4)
DECL_TEXTURE( BlurMapF3, BlurSampF3, 8)
// F:Front(前ボケ) / B:Back(後ボケ)

#if ENABLE_DEEP_LEVEL > 0
DECL_TEXTURE( DownscaleMap4, DownscaleSamp4,16)
DECL_TEXTURE( BlurMap4, BlurSamp4,16)
DECL_TEXTURE( BlurMapF4, BlurSampF4,16)
#endif

// 自動焦点用の情報。フレームを超えて情報をやりとりする。
texture2D AutoFocusTex : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp = sampler_state {
	Texture = <AutoFocusTex>;
	AddressU  = CLAMP;	AddressV = CLAMP;
	FILTER_MODE
};
texture2D AutoFocusTexCopy : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmpCopy = sampler_state {
	Texture = <AutoFocusTexCopy>;
	AddressU  = CLAMP;	AddressV = CLAMP;
	FILTER_MODE
};

texture AutoFocusDepthBuffer : RenderDepthStencilTarget <
	int2 Dimensions = {1,1};
	string Format = "D24S8";
>;



//-----------------------------------------------------------------------------
// 深度マップ
// 深度情報を格納
texture LinearDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikBokeh.fx";
	float4 ClearColor = { 1.0, 0, 0, 1 };
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	float ClearDepth = 1.0;
	string Format = "R16F";
	bool AntiAlias = false;
	int MipLevels = 1;
	string DefaultEffect = 
		"self = hide;"
		"ikBokeh*.* = hide;"
		"* = ikDepth.fx";
>;

sampler DepthMap = sampler_state {
	texture = <LinearDepthMapRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;

	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
};


//-----------------------------------------------------------------------------
// ガンマ補正
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col)
{
	return (!bLinearMode) ? pow(max(col,epsilon), gamma) : col;
}
inline float3 Gamma(float3 col)
{
	return (!bLinearMode) ? pow(max(col,epsilon), 1.0/gamma) : col;
}
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

// 色の強調
inline float3 EmphasizeColor(float3 col, float rate)
{
	#if ENABLE_EMPHASIZE_COLOR > 0
	col = (mEmphasize > 0.0) ? exp(col * rate) : col;
	#endif
	return col;
}

inline float3 DepreciateColor(float3 col, float rate)
{
	#if ENABLE_EMPHASIZE_COLOR > 0
	col = (mEmphasize > 0.0) ? log(col) * rate : col;
	#endif
	return col;
}

//-----------------------------------------------------------------------------
// どれだけボケるか

inline float CalcAperture()
{
	// float adjustValue = mBokehM * BokehFNumberScaleM - mBokehP * BokehFNumberScaleP;
	// float f = mFNumber * FNumberScale + adjustValue;
	float f = DefaultFNumber + (mBokehM - mBokehP) * FNumberScale;
	f = (isExistController) ? f : DefaultFNumber;
	float aperture = 1.0 / clamp(f, MinFNumber, MaxFNumber);
	return aperture;
}

inline float CalcFocalLength(float focusDistance)
{
	float focalM = mFocalLength * FocalLengthScale * mm;

	// 画角をもとに焦点距離を計算する
	// カメラによって画角と焦点距離の関係は変わる?
	float i = FilmSize * matP._22 / 2.0;
	float focalA = i / (1.0 + i / focusDistance);
	float rate = (isExistController) ? (1.0 - mManualMode) : 1.0;

	float focal = lerp(focalM, focalA, rate);
	focal += (mBokehP * BokehFocalLengthScaleP - mBokehM * BokehFocalLengthScaleM);

	return clamp(focal, MinFocalLength, MaxFocalLength);
}

static float aperture = CalcAperture();

// CoC計算用の係数を求める
inline float2 CalcCoCCoef(float focusDistance)
{
	float focalLength = CalcFocalLength(focusDistance);

	float I = (focusDistance * focalLength) / (focusDistance - focalLength);
	float S = aperture / FilmSize * (2.0 * ViewportSize.y * ScreenScale * 0.5);

	float CoCCoefMul =-(I * S);
	float CoCCoefAdd = (I * S / focalLength) - S;
	return float2(CoCCoefMul / FAR_DEPTH, CoCCoefAdd);
}

inline float CalcBlurLevel(float2 coef, float depth)
{
	float CoC = coef.x / depth + coef.y;
	return clamp(CoC, -MAX_COC_SIZE, MAX_COC_SIZE);
}

inline float MeasuringCircleRadius()
{
	return (mAFMode > 1.5) ? 0.2 : 0.05;
}


//-----------------------------------------------------------------------------
//

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

inline float4 TestColor(float3 Color, float level, float2 uv)
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

VS_OUTPUT VS_SetTexCoord2( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;

	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * float4( 1,-1,  1, 1);

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
	Out.TexCoord1.xy = CalcCoCCoef(tex2Dlod(AutoFocusSmp, float4(0.5,0.5, 0,0)).x);
	// CoCサイズの調整係数
	Out.TexCoord1.z = ForceCoCSacle;
	Out.TexCoord1.w = FRONT_BOKEH_SCALE * (1 - mFBokehM);
	// 色強調用の係数
	Out.TexCoord2.x = mEmphasizeScale;

	return Out;
}

VS_OUTPUT VS_Gather( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;

	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1.x = (1.0 / mEmphasizeScale);

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
inline float CalcFocusDistance()
{
	// AFPositionの深度
	float depth0 = distance(AFPosition, CameraPosition);

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
		depth0 = min(min(depthMin.x, depthMin.y), depthA8) * FAR_DEPTH;
	}

	// マニュアルフォーカス
	float rate = (isExistController) ? (1.0 - mManualMode) : 1.0;
	depth0 = lerp(mPintDistance * AbsoluteFocusScale, depth0, rate);

	// 微調整分
	float adjuster = (mPintDistanceP - mPintDistanceM) * RelativeFocusScale + mCtrlPosition.z;
	depth0 = max(depth0 + adjuster, MinFocusDistance);

	return depth0;
}


float4 PS_UpdateFocusDistance(float2 Tex: TEXCOORD0) : COLOR
{
	float depth0 = CalcFocusDistance();
	float4 data = tex2Dlod(AutoFocusSmpCopy, float4(0.5,0.5,0,0));
	// float4 data = AutoFocusTexArray[0];
	float depth1 = data.x;
	float Vel = data.y;
	// float prevTime = data.z;
		// この値が大幅に違ったら初期化する? abs(time - prevTime) > 10.0 とか。

	// 0フレ目なら初期化
	if (time < 1.0 / 120.0)
	{
		depth1 = depth0;
		Vel = 0;
	}

	// *** ピント速度の計算は、針金PのPowerDOFを参考にしました。 ***

	// 減速
	Vel *= (1.0 - mPintFriction);
	Vel = Vel - Vel * Dt * 0.05;
	float v = depth0 - (depth1 + Vel);
	// 手前ほど距離合わせは高速になる
	float speed = min(abs(v), clamp(35000.0f/depth0, 50.0f, 1000.0f) * 30.0 * Dt);
	Vel += sign(v) * speed * (1.0 - mPintDelay);
	depth1 += Vel;

	depth1 = max(depth1, MinFocusDistance);

	return float4(depth1, Vel, time, 1.0);
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

	float emphasizeScale = IN.TexCoord2.x;
	Color.rgb = EmphasizeColor(Color.rgb, emphasizeScale);

	return float4(Color.rgb, level);
}


//-----------------------------------------------------------------------------
// 低解像度のバッファを作る

inline float CalcWeight(float4 col) { return abs(col.w); }

float4 PS_DownSampling( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 Color0 = tex2D(smp, IN.TexCoord1.xy);
	float4 Color1 = tex2D(smp, IN.TexCoord1.zw);
	float4 Color2 = tex2D(smp, IN.TexCoord2.xy);
	float4 Color3 = tex2D(smp, IN.TexCoord2.zw);

	float4 Color = 0;
	float w0 = CalcWeight(Color0); Color += Color0 * w0;
	float w1 = CalcWeight(Color1); Color += Color1 * w1;
	float w2 = CalcWeight(Color2); Color += Color2 * w2;
	float w3 = CalcWeight(Color3); Color += Color3 * w3;
	Color = Color / max(w0+w1+w2+w3, epsilon);
	Color.w *= 0.5;

	return Color;
}


//-----------------------------------------------------------------------------
// ボカす

struct PS_OUT_MRT
{
	float4 ColorBack	: COLOR0;
	float4 ColorFront	: COLOR1;
};

float2 CalcWeight(float2 coc, float2 weight, uniform bool bFirst, uniform bool bLast)
{
	if (!bFirst) weight *= saturate(coc * 2.0 - (BULR_SIZE - 1.0));
	if (!bLast) weight *= saturate(BULR_SIZE - coc);
	return weight / max(coc * coc, MinimumCoCRadius);
}
float4 CalcWeight(float4 coc, float4 weight, uniform bool bFirst, uniform bool bLast)
{
	if (!bFirst) weight *= saturate(coc * 2.0 - (BULR_SIZE - 1.0));
	if (!bLast) weight *= saturate(BULR_SIZE - coc);
	return weight / max(coc * coc, MinimumCoCRadius);
}

PS_OUT_MRT PS_Blur( VS_OUTPUT IN, uniform sampler2D smp, 
	uniform bool bFirst, uniform bool bLast)
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;
	float2 offset2 = IN.TexCoord.zw * float2(1,-1);

	float depth0 = tex2D(smp, texCoord).w;
//	float2 coc0 = float2(max( depth0, 0), BULR_SIZE);
	float4 coc0 = float2(max( depth0, 0), BULR_SIZE).xyxy;
	float4 sumB = 0;
	float4 sumF = 0;

#if USE_MME_32BIT
	int dither = 0;
	for(int iy = 0; iy <= BULR_SIZE * 2; iy++)
	{
		float vy = iy - BULR_SIZE;
		float dither2 = -BULR_SIZE + dither;
		for(int ix = 0; ix <= BULR_SIZE; ix++)
		{
			float vx = ix * 2 + dither2;
			float2 uv = float2(vx, vy);
			float l = length(uv);
			float4 Color = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float2 coc = max(float2( Color.w, -Color.w), 0);
			float2 dist = saturate(min(coc, coc0) - l);
			float2 weight = CalcWeight(coc, dist, bFirst, bLast);
			sumB += float4(Color.rgb, 1) * weight.x;
			sumF += float4(Color.rgb, 1) * weight.y;
		}
		dither = 1 - dither;
	}
#else
	{
		float dither2 = -BULR_SIZE + 0;
		for(int ix = 0; ix <= BULR_SIZE; ix++)
		{
			float vx = ix * 2 + dither2;
			float2 uv = float2(vx, 0);
			float l = abs(vx);
			float4 Color = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float2 coc = max(float2( Color.w, -Color.w), 0);
			float2 dist = saturate(min(coc, coc0.xy) - l);
			float2 weight = CalcWeight(coc, dist, bFirst, bLast);
			sumB += float4(Color.rgb, 1) * weight.x;
			sumF += float4(Color.rgb, 1) * weight.y;
		}
	}

	int dither = 1;
	for(int iy = 1; iy <= BULR_SIZE; iy++)
	{
		float dither2 = -BULR_SIZE + dither;
		for(int ix = 0; ix <= BULR_SIZE; ix++)
		{
			float2 uv = float2(ix * 2 + dither2, iy);
			float l = length(uv.xy);
			float4 Color1 = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float4 Color2 = tex2Dlod(smp, float4(offset2 * uv + texCoord, 0,0));
			float4 coc = max(float4( Color1.w, -Color1.w, Color2.w, -Color2.w), 0);
			float4 dist = saturate(min(coc, coc0) - l);
			float4 weight = CalcWeight(coc, dist, bFirst, bLast);
			sumB += float4(Color1.rgb, 1) * weight.x;
			sumF += float4(Color1.rgb, 1) * weight.y;
			sumB += float4(Color2.rgb, 1) * weight.z;
			sumF += float4(Color2.rgb, 1) * weight.w;
		}
		dither = 1 - dither;
	}
#endif

	PS_OUT_MRT Out;
	Out.ColorBack = sumB;
	Out.ColorFront = sumF;

	return Out;
}

//-----------------------------------------------------------------------------
// 低解像度マップを高解像度に復元
float4 PS_UpSampling( VS_OUTPUT IN, uniform sampler2D smp, uniform sampler2D smp2) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color0 = tex2D(smp, texCoord);
	float4 Color1 = 
		tex2D(smp2, IN.TexCoord1.xy) + tex2D(smp2, IN.TexCoord1.zw) + 
		tex2D(smp2, IN.TexCoord2.xy) + tex2D(smp2, IN.TexCoord2.zw);
	return Color0 + Color1 * 0.25;
}

//-----------------------------------------------------------------------------
// 
float4 PS_Gather( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float4 Color = tex2D(DownscaleSamp0, texCoord);
	float depth = Color.w;
	float2 coc = max(float2(depth, -depth), 0);
	float2 rcoc2 = 1.0 / max(coc * coc, 1.0);
	Color.w = 1;

	// 後ボケの合成
	float4 ColorB = tex2D(DownscaleSamp1Linear, texCoord);
	ColorB += tex2D(BlurSamp0Linear, texCoord);
	ColorB += Color * epsilon;
	Color.rgb = lerp(ColorB.rgb / ColorB.w, Color.rgb, rcoc2.x);
	Color.w = 1;

	// 前ボケの合成
	float4 ColorF = tex2D(BlurSamp1Linear, texCoord);;
	ColorF += tex2D(BlurSampF0Linear, texCoord);
	float alpha = saturate(ColorF.w);
	Color = Color * rcoc2.y + ColorF;
	Color.rgb /= Color.w;
	ColorF.rgb /= max(ColorF.w, epsilon);
	Color.rgb = lerp(Color.rgb, ColorF.rgb, alpha);

	float demphasizeScale = IN.TexCoord1.x;
	Color.rgb = DepreciateColor(Color.rgb, demphasizeScale);
	Color = Gamma4(TestColor( Color.rgb, depth, texCoord));
	Color.a = 1;

	return Color;
}

//=============================================================================

technique DepthOfField <
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
		"RenderColorTarget0=AutoFocusTex;		Pass=UpdateFocusPass;"
		"RenderColorTarget0=AutoFocusTexCopy;	Pass=CopyFocusPass;"

		// CoCのサイズ計算
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=DownscaleMap0;"
		// "Clear=Color; Clear=Depth;"
		"Pass=CalcCoCPass;"

		// 画像のダウンスケール
		"RenderColorTarget0=DownscaleMap1; Pass=ScalePass1;"
		"RenderColorTarget0=DownscaleMap2; Pass=ScalePass2;"
		"RenderColorTarget0=DownscaleMap3; Pass=ScalePass3;"
		#if ENABLE_DEEP_LEVEL > 0
		"RenderColorTarget0=DownscaleMap4; Pass=ScalePass4;"
		#endif

		// ボカす
		"RenderColorTarget0=BlurMap0; RenderColorTarget1=BlurMapF0; Pass=BlurPass0;"
		"RenderColorTarget0=BlurMap1; RenderColorTarget1=BlurMapF1; Pass=BlurPass1;"
		"RenderColorTarget0=BlurMap2; RenderColorTarget1=BlurMapF2; Pass=BlurPass2;"
		"RenderColorTarget0=BlurMap3; RenderColorTarget1=BlurMapF3; Pass=BlurPass3;"
		#if ENABLE_DEEP_LEVEL > 0
		"RenderColorTarget0=BlurMap4; RenderColorTarget1=BlurMapF4; Pass=BlurPass4;"
		#endif
		"RenderColorTarget1=;"

		// アップサンプリング
		#if ENABLE_DEEP_LEVEL > 0
		"RenderColorTarget0=DownscaleMap3; Pass=UpScale3;"
		#endif
		"RenderColorTarget0=DownscaleMap2; Pass=UpScale2;"
		"RenderColorTarget0=DownscaleMap1; Pass=UpScale1;"
		// (※合成の終わった後ボケ用バッファに前ボケの合成結果を格納)
		#if ENABLE_DEEP_LEVEL > 0
		"RenderColorTarget0=BlurMap3; Pass=UpScaleF3;"
		#endif
		"RenderColorTarget0=BlurMap2; Pass=UpScaleF2;"
		"RenderColorTarget0=BlurMap1; Pass=UpScaleF1;"

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

	// ダウンサンプリング
	pass ScalePass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp0);
	}
	pass ScalePass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp1);
	}
	pass ScalePass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp2);
	}
#if ENABLE_DEEP_LEVEL > 0
	pass ScalePass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp3);
	}
#endif

	// ボカし
	pass BlurPass0 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp0, true, false);
	}
	pass BlurPass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp1, false, false);
	}
	pass BlurPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp2, false, false);
	}
#if ENABLE_DEEP_LEVEL > 0
	pass BlurPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp3, false, false);
	}
	pass BlurPass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp4, false, true);
	}
#else
	pass BlurPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp3, false, true);
	}
#endif

	// アップサンプリング
#if ENABLE_DEEP_LEVEL > 0
	pass UpScale3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(8);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp3, BlurSamp4Linear);
	}
	pass UpScale2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp2, DownscaleSamp3Linear);
	}
#else
	pass UpScale2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp2, BlurSamp3Linear);
	}
#endif
	pass UpScale1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp1, DownscaleSamp2Linear);
	}

#if ENABLE_DEEP_LEVEL > 0
	pass UpScaleF3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(8);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF3, BlurSampF4Linear);
	}
	pass UpScaleF2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF2, BlurSamp3Linear);
	}
#else
	pass UpScaleF2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF2, BlurSampF3Linear);
	}
#endif
	pass UpScaleF1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF1, BlurSamp2Linear);
	}

	// 合成
	pass GatherPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Gather(1);
		PixelShader  = compile ps_3_0 PS_Gather();
	}
}

//=============================================================================
