////////////////////////////////////////////////////////////////////////////////////////////////
// ikBokeh.fx
// ポストプロセスで被写界深度のエミュレートを行う。
////////////////////////////////////////////////////////////////////////////////////////////////

// 強制的に玉ボケのサイズをスケーリングする。1:等倍(デフォルト)、2:2倍になる。
// 別途設定されているサイズ上限を超えることはない。
#define FORCE_COC_SCALE		(1.0)

// 外部から制御するコントローラの名前
#define CONTROLLER_NAME		"ikBokehController.pmx"

// オートフォーカスの基準位置
// 通常はアクセサリにのままにしておき、アクセサリをピントを合わせたいボーンにぶら下げる。
#define	AF_MODEL_NAME	"ikBokeh.x"
//#define	AF_BONE_NAME	"頭"

// ボカしループを展開するか? 0:行わない、1:描画が高速になる代わりに起動が遅くなる。
#define ENABLE_BLUR_UNROLL	0

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

// ジャギ取りモード
// 0: ジャギを取らない
// 1: ジャギを取る(簡易)
// 2: ジャギを取る(真面目。1より控えめ)
#define ANTIALIAS_MODE	1

//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// 0:エフェクト無効、1:エフェクト有効
#define BOKEH_LEVEL		1

#define BULR_SIZE		8	// 1回でボカすサイズ
//#define BULR_SIZE		6	// 1回でボカすサイズ

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
#define FNumberScale			10.0			// 絞り係数
#define BokehFocalLengthScaleP	50.0			// ボケ調整時の焦点距離(ボケ増加)
#define BokehFocalLengthScaleM	100.0			// ボケ調整時の焦点距離(ボケ減少)

// 内部的な制限
const float MinFocusDistance = (0.1 * m);
const float MinFocalLength = (20.0 * mm);
const float MaxFocalLength = (200.0 * mm);
const float MinFNumber = 1.0;
const float MaxFNumber = 16.0;

const float gamma = 2.233333333;
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
float mCoCSize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "CoCサイズ"; >;

float mTestMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "テストモード"; >;

float mAFModeParam : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "AF測距モード"; >;
static int mAFMode = (isExistController) ? (int)(mAFModeParam * 3.0 + 0.1) : DEFAULT_MEASURING_MODE;
float mManualMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "マニュアルモード"; >;
float mPintDistance : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ピント距離"; >;
float mFocalLength : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "焦点距離"; >;




#if defined(FORCE_COC_SCALE)
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ForceCoCSacle = FORCE_COC_SCALE * AcsSi * 0.1 * (mCoCSize + 1.0);
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define BULR_SIZE2		2

// ボケの半径上限
#define MAX_COC_SIZE	((BULR_SIZE) * BULR_SIZE2 * 8)

// ワーク用テクスチャの設定
#define FILTER_MODE			MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
#define ADDRESSING_MODE		AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

#define ScreenScale		1

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
DECL_TEXTURE( DownscaleMap4, DownscaleSamp4,16)

DECL_TEXTURE( BlurMap0, BlurSamp0, 1)
DECL_TEXTURE( BlurMap1, BlurSamp1, 2)
DECL_TEXTURE( BlurMap2, BlurSamp2, 4)
DECL_TEXTURE( BlurMap3, BlurSamp3, 8)
DECL_TEXTURE( BlurMap4, BlurSamp4,16)

DECL_TEXTURE( BlurMapF0, BlurSampF0, 1)
DECL_TEXTURE( BlurMapF1, BlurSampF1, 2)
DECL_TEXTURE( BlurMapF2, BlurSampF2, 4)
DECL_TEXTURE( BlurMapF3, BlurSampF3, 8)
DECL_TEXTURE( BlurMapF4, BlurSampF4,16)
// FはNear/FarではなくFront/Backな点に注意。

#if ANTIALIAS_MODE != 0
DECL_TEXTURE( GatherMap, GatherSamp, 1)
sampler2D GatherSampClamp = sampler_state {
	texture = <GatherMap>;
	LINEAR_FILTER_MODE	AddressU = CLAMP; AddressV = CLAMP;
};
#endif

texture2D AutoFocusTex : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp = sampler_state {
	Texture = <AutoFocusTex>;
	AddressU  = CLAMP;	AddressV = CLAMP;
	FILTER_MODE
};
float4 AutoFocusTexArray[1] : TEXTUREVALUE <
	string TextureName = "AutoFocusTex";
>;

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
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }


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
	float S = aperture / FilmSize * (2.0 * BULR_SIZE2 * ViewportSize.y * ScreenScale * 0.5);

	float CoCCoefMul =-(I * S);
	float CoCCoefAdd = (I * S / focalLength) - S;
	return float2(CoCCoefMul, CoCCoefAdd);
}

inline float CalcBlurLevel(float2 coef, float distance)
{
	float CoC = coef.x / distance + coef.y;
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
	float depth1 = AutoFocusTexArray[0].x;
	float Vel = AutoFocusTexArray[0].y;
	// float prevTime = AutoFocusTexArray[0].z;
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


//-----------------------------------------------------------------------------
// CoCの計算
float4 PS_CalcCoC( VS_OUTPUT IN ) : COLOR
{
	float4 Color = Degamma4(tex2D(ScnSamp, IN.TexCoord.xy));
	float2 DepthInfo = tex2D( DepthMap, IN.TexCoord.xy).xy;

	float Depth = DepthInfo.x * FAR_DEPTH;	// 奥行き
	float level = CalcBlurLevel(IN.TexCoord1.xy, Depth);

	#if defined(FORCE_COC_SCALE)
	{
		level = (abs(level) >= 1.0)
				? sign(level) * ((abs(level) - 1.0) * ForceCoCSacle + 1)
				: level;
	}
	#endif

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

// 8サンプル
float3 eighth[]  = {
	float3(1,2,2.236068),
//	float3(1,3,3.1622777),
	float3(1,4,4.1231055),
//	float3(1,5,5.0990195),
	float3(1,6,6.0827627),
///	float3(1,7,7.071068),

	float3(2,3,3.6055512),
//	float3(2,4,4.472136),
	float3(2,5,5.3851647),
//	float3(2,6,6.3245554),
	float3(2,7,7.28011),

	float3(3,4,5.0),
//	float3(3,5,5.8309517),
	float3(3,6,6.708204),
///	float3(3,7,7.615773),

	float3(4,5,6.4031243),
///	float3(4,6,7.2111025),

	float3(5,6,7.81025),
};

#define LOOP_NUM2		5			// 対角線用
#define LOOP_NUM3		(18-8)


#define CALCBLUR(uvx,uvy,dist) \
	CalcBlur((offset * float2(uvx, uvy) + texCoord), dist, depth0, \
		smp, bFirst, bLast, bFront)

inline float4 CalcBlur(float2 uv, float dist, float depth0, 
	uniform sampler2D smp, uniform bool bFirst, uniform bool bLast, uniform bool bFront)
{
	const float MinRadius = (BULR_SIZE - 1.0) * 0.5;
	const float MaxRadius = BULR_SIZE;

	float4 Color = tex2Dlod(smp, float4(uv,0,0));
	float depth = Color.w;
#if 0
	// こっちにすると色が滲んで汚くなる。
	float coc0 = abs(depth0);
	float coc = abs(depth);
	float localRadius = min(coc, (depth <= depth0) * coc + coc0);
#else
	float coc = (bFront) ? -depth : depth;
	float localRadius = (bFront) ? coc : min(coc, depth0);
#endif

	float radius = max(coc, 1.0);
	float3 intensity = saturate(float3(localRadius - dist, (coc - MinRadius) * 2.0, MaxRadius - coc));
	// 縮小バッファ間のつながりをスムーズにするための重み付け
	if (!bFirst) intensity.x *= intensity.y;
	if (!bLast) intensity.x *= intensity.z;
	intensity.x = intensity.x / (radius * radius);

	return float4(Color.rgb, 1) * intensity.x;
}


float4 PS_Blur( VS_OUTPUT IN, uniform float scale, uniform sampler2D smp,
	uniform bool bFirst, uniform bool bLast, uniform bool bFront) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;
	float4 sum = 0;

	float depth0 = tex2D(smp, texCoord).w;

#if ENABLE_BLUR_UNROLL == 0
	int dither = 1;
	for(int iy = 0; iy <= BULR_SIZE * 2; iy++)
	{
		float vy = iy - BULR_SIZE;
		[unroll] for(int ix = 0; ix <= BULR_SIZE; ix++)
		{
			float vx = ix * 2 - BULR_SIZE + dither;
			sum += CALCBLUR(vx, vy, length(float2(vx, vy)));
		}

		dither = (dither == 0) ? 1 : 0;
	}

#else
	// 矩形で検索すると約1/4が無駄になるが、円形に走査するとループ展開が遅くなる。
	[unroll] for(int i = 1; i <= 8; i+=2)
	{
		sum += CALCBLUR( i, 0, i);		sum += CALCBLUR(-i, 0, i);
		sum += CALCBLUR( 0, i, i);		sum += CALCBLUR( 0,-i, i);
	}

	[unroll] for(int i = 0; i < LOOP_NUM3; i++)
	{
		float3 uv = eighth[i];
		sum += CALCBLUR( uv.x, uv.y, uv.z);		sum += CALCBLUR(-uv.x, uv.y, uv.z);
		sum += CALCBLUR( uv.x,-uv.y, uv.z);		sum += CALCBLUR(-uv.x,-uv.y, uv.z);
		sum += CALCBLUR( uv.y, uv.x, uv.z);		sum += CALCBLUR(-uv.y, uv.x, uv.z);
		sum += CALCBLUR( uv.y,-uv.x, uv.z);		sum += CALCBLUR(-uv.y,-uv.x, uv.z);
	}

#endif

	sum *= (1.0 / (scale * scale * PI));
/*
	本来、
		float radius = coc * scale;
		intensity = intensity / (radius * radius * PI);
		sum += color * intensity;
	となるうちの定数成分のみをここで計算している。
*/

	// ディザで半分の明るさになった分を補償
	sum *= 2;

	return sum;
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

	return Color0 + Color1;
}

float4 PS_Gather( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;

	float4 Color0 = tex2D(DownscaleSamp0, texCoord);
	float depth = Color0.w;

	// 後ボケの合成
	float4 Color1 = 
		tex2D(DownscaleSamp1Linear, IN.TexCoord1.xy) + 
		tex2D(DownscaleSamp1Linear, IN.TexCoord1.zw) + 
		tex2D(DownscaleSamp1Linear, IN.TexCoord2.xy) + 
		tex2D(DownscaleSamp1Linear, IN.TexCoord2.zw);
	Color1 += tex2D(BlurSamp0, texCoord);

	float coc = max(depth, 0);
	Color1 = Color1 / max(Color1.w, epsilon);
	Color0.rgb = lerp(Color0.rgb, Color1.rgb, saturate(coc-1.0));

	// 前ボケの合成
	Color1 = 
		tex2D(BlurSamp1Linear, IN.TexCoord1.xy) + 
		tex2D(BlurSamp1Linear, IN.TexCoord1.zw) + 
		tex2D(BlurSamp1Linear, IN.TexCoord2.xy) + 
		tex2D(BlurSamp1Linear, IN.TexCoord2.zw);
	Color1 += tex2D(BlurSampF0, texCoord);

	coc = max(-depth, 0);
	float radius = max(-coc - 1.0, 1.0);
	float intensity = 1.0 / (radius * radius * PI);
	Color0 = Color1 + float4(Color0.rgb, 1.0) * intensity;
	Color0.rgb = Color0.rgb / max(Color0.w, epsilon);

	#if ANTIALIAS_MODE == 0
	Color0 = Gamma4(TestColor( Color0.rgb, depth, texCoord));
	Color0.a = 1;
	#else
	Color0.a = depth;
	#endif

	return Color0;
}


#if ANTIALIAS_MODE != 0
// アンチエイリアス
float4 PS_Last( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 s = SampleStep;

	float4 colC = tex2D(GatherSampClamp, texCoord);
	float4 colL = tex2D(GatherSampClamp, texCoord + float2(-1,0) * s);
	float4 colR = tex2D(GatherSampClamp, texCoord + float2( 1,0) * s);
	float4 colU = tex2D(GatherSampClamp, texCoord + float2(0,-1) * s);
	float4 colD = tex2D(GatherSampClamp, texCoord + float2(0, 1) * s);

	// 深度差
	float cocC = abs(colC.w);
	float cocL = abs(colL.w);
	float cocR = abs(colR.w);
	float cocU = abs(colU.w);
	float cocD = abs(colD.w);
	float4 grad = abs(cocC - float4(cocL,cocR,cocU,cocD));
	float w = dot(grad, 1) * (10.0 / MAX_COC_SIZE);
/*
	// 色の差
	float lumaC = rgb2gray(colC.rgb);
	float lumaL = rgb2gray(colL.rgb);
	float lumaR = rgb2gray(colR.rgb);
	float lumaU = rgb2gray(colU.rgb);
	float lumaD = rgb2gray(colD.rgb);
	float4 gradCol = abs(lumaC - float4(lumaL,lumaR,lumaU,lumaD));
	w *= dot(gradCol, 1);
*/
	w = saturate(w * 1.1 - 0.1); // 0.01～0.1程度

	#if ANTIALIAS_MODE == 1
	float3 col = (colC + colL + colR + colU + colD).rgb * (1.0 / 5.0);
	#else
	float4 offset = 2.0 / (saturate(grad) + 1.0);
	colL = tex2D(GatherSampClamp, texCoord + float2(-1,0) * s * offset.x);
	colR = tex2D(GatherSampClamp, texCoord + float2( 1,0) * s * offset.y);
	colU = tex2D(GatherSampClamp, texCoord + float2(0,-1) * s * offset.z);
	colD = tex2D(GatherSampClamp, texCoord + float2(0, 1) * s * offset.w);
	float3 col = (colC + colL + colR + colU + colD).rgb * (1.0 / 5.0);
	#endif

	col = lerp(colC.rgb, col, w);

	return Gamma4(TestColor(col, colC.w, texCoord));
}
#endif

#if BOKEH_LEVEL <= 0
float4 PS_Copy( VS_OUTPUT IN) : COLOR
{
	return tex2D(ScnSamp, IN.TexCoord.xy);
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

technique DepthOfField <
	string Script = 
		// 普通の画面をレンダリング
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

#if BOKEH_LEVEL >= 1
		// CoCのサイズ計算
		"RenderColorTarget0=AutoFocusTex;"
		"RenderDepthStencilTarget=AutoFocusDepthBuffer;"
		"Clear=Color; Clear=Depth;"
		"Pass=UpdateFocusPass;"

		"RenderColorTarget0=DownscaleMap0;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color; Clear=Depth;"
		"Pass=CalcCoCPass;"

		// 画像のダウンスケール
		"RenderColorTarget0=DownscaleMap1; Pass=ScalePass1;"
		"RenderColorTarget0=DownscaleMap2; Pass=ScalePass2;"
		"RenderColorTarget0=DownscaleMap3; Pass=ScalePass3;"
		"RenderColorTarget0=DownscaleMap4; Pass=ScalePass4;"

		// 奥ボケ
		"RenderColorTarget0=BlurMap0; Pass=BlurPass0;"
		"RenderColorTarget0=BlurMap1; Pass=BlurPass1;"
		"RenderColorTarget0=BlurMap2; Pass=BlurPass2;"
		"RenderColorTarget0=BlurMap3; Pass=BlurPass3;"
		"RenderColorTarget0=BlurMap4; Pass=BlurPass4;"

		// 前ボケ
		"RenderColorTarget0=BlurMapF0; Pass=BlurPassF0;"
		"RenderColorTarget0=BlurMapF1; Pass=BlurPassF1;"
		"RenderColorTarget0=BlurMapF2; Pass=BlurPassF2;"
		"RenderColorTarget0=BlurMapF3; Pass=BlurPassF3;"
		"RenderColorTarget0=BlurMapF4; Pass=BlurPassF4;"

		// アップサンプリング
		"RenderColorTarget0=DownscaleMap3; Pass=UpScale3;"
		"RenderColorTarget0=DownscaleMap2; Pass=UpScale2;"
		"RenderColorTarget0=DownscaleMap1; Pass=UpScale1;"
		// (合成の終わった後ボケ用バッファを前ボケの合成結果格納に使用)
		"RenderColorTarget0=BlurMap3; Pass=UpScaleF3;"
		"RenderColorTarget0=BlurMap2; Pass=UpScaleF2;"
		"RenderColorTarget0=BlurMap1; Pass=UpScaleF1;"

		// 合成
		#if ANTIALIAS_MODE == 0
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=GatherPass;"
		#else
		"RenderColorTarget0=GatherMap;"
		"Pass=GatherPass;"
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=LastPass;"
		#endif

#else
		// 加工せずにコピー
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=CopyPass;"
#endif
	;
> {
	pass UpdateFocusPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UpdateFocusDistance();
		PixelShader  = compile ps_3_0 PS_UpdateFocusDistance();
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
	pass ScalePass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp3);
	}

	// 奥ボケ
	pass BlurPass0 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(0.5, DownscaleSamp0, true, false, false);
	}
	pass BlurPass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_Blur(1, DownscaleSamp1, false, false, false);
	}
	pass BlurPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(2, DownscaleSamp2, false, false, false);
	}
	pass BlurPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(4, DownscaleSamp3, false, false, false);
	}
	pass BlurPass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(8, DownscaleSamp4, false, true, false);
	}

	// 前ボケ
	pass BlurPassF0 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(0.5, DownscaleSamp0, true, false, true);
	}
	pass BlurPassF1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_Blur(1, DownscaleSamp1, false, false, true);
	}
	pass BlurPassF2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(2, DownscaleSamp2, false, false, true);
	}
	pass BlurPassF3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(4, DownscaleSamp3, false, false, true);
	}
	pass BlurPassF4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(8, DownscaleSamp4, false, true, true);
	}

	// アップサンプリング
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
	pass UpScale1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp1, DownscaleSamp2Linear);
	}

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
	pass UpScaleF1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF1, BlurSamp2Linear);
	}

	// アップサンプリング+合成
	pass GatherPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(1);
		PixelShader  = compile ps_3_0 PS_Gather();
	}

	#if ANTIALIAS_MODE != 0
	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(1);
		PixelShader  = compile ps_3_0 PS_Last();
	}
	#endif

	// 何もしない
#if BOKEH_LEVEL <= 0
	pass CopyPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Copy();
	}
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////
