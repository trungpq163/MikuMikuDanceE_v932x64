////////////////////////////////////////////////////////////////////////////////////////////////
// ikボケ.fx
// ポストプロセスで被写界深度のエミュレートを行う。
// Ver 0.06
////////////////////////////////////////////////////////////////////////////////////////////////

// ボケエフェクト全体を無効にする。 0:エフェクト有効、1:無効
#define DISABLE_ALL		0

// サンプリング時のステップサイズ
// 大きいほど高速、画質が劣化する。1:画質優先、2:速度優先
#define SAMPLING_STEP	1

// 強制的に玉ボケのサイズをスケーリングする。1:等倍(デフォルト)、2:2倍になる。
// 別途設定されているサイズ上限を超えることはない。
#define FORCE_COC_SCALE		(1.0)

// 前ボケの裏側を捏造するか? 0:無効、1:有効。重い。
// 現実では前ボケの境界付近で前ボケとその背後が馴染んで曖昧になる。
// ピクセル上存在しない前ボケの背後を捏造する。
// 背景がフラットな場合はかなり改善されるが、複雑な形状だと捏造がバレて逆に不自然になる。
#define	USE_FRONTBACK			0

// テストモード有効設定。
// ENABLE_TEST_MODEが1のとき、アクセサリのXに1をいれるとテストモードになる。
#define	ENABLE_TEST_MODE		1

// 前ボケを処理しない…。0:処理する、1:処理しない。
#define	DISABLE_FRONT_BOKEH		0



// 自動追従用ターゲット。モデル名がコメントアウトされている場合、自動追従しない。
// ボーンに追従するテスト
//#define	AF_MODEL_NAME	"初音ミクmetal.pmd"
//#define	AF_BONE_NAME	"頭"
// アクセサリに追従するテスト。
// ※ アクセサリが非表示だと手動モードになる。
//#define	AF_MODEL_NAME	"ikWindMaker01.x"


//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// 単位調整用の変数。
#define		m	(10.0)	// 1MMD単位 = 10cm
#define		cm	(0.1)
#define		mm	(0.01)

// ガンマ値
const float gamma = 2.2;

// テスト用：ボケ画像にブラーを掛ける。0:無効、1:有効(通常)。
#define USE_BLUR		1

// ボケ画像の加工サイズ。画面サイズ/LowResになる。1,2,4以外の動作は未確認。
// 1にすると重くなる＆鮮明になる。ボケ度合いが下がるので 2を推奨。
#define	LowRes		2

// 前ボケ裏の解像度：小さいほうが精度が高いが、その分、捏造範囲がせばまる。
#define FrontBackRes	4


// ボケの半径上限。6～16 (推奨:12以下)
// この半径を大きくしても内部の計算式で最大半径が決るので、際限なく大きくなる訳ではない。
// 大きな数値ほど重くなる。
#define MAX_COC_SIZE	12

// フィルムサイズ。一般的に35mmか70mmを使う(らしい)
const float FilmSize = 35 * mm;

// なにも描画しない場合の背景までの距離
// これを弄るより普通にスカイドームなどの背景をおいたほうがいい。
// 弄る場合、ikDepthBright.fxの同名の値も変更する必要がある。
#define FAR_DEPTH		1000


// ピントの合う距離(1MMD = 10cm)
float FocusDistanceAc : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

// 指定モデル・ボーンへの自動追従
#ifdef AF_MODEL_NAME
#ifdef AF_BONE_NAME
bool ExistAFTarget : CONTROLOBJECT < string name = AF_MODEL_NAME; string item = AF_BONE_NAME; >;
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; string item = AF_BONE_NAME; >;
float4x4 AFMatrix : CONTROLOBJECT < string name = AF_MODEL_NAME; string item = AF_BONE_NAME; >;
#else
bool ExistAFTarget : CONTROLOBJECT < string name = AF_MODEL_NAME; >;
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; >;
float4x4 AFMatrix : CONTROLOBJECT < string name = AF_MODEL_NAME; >;
#endif
#else
bool ExistAFTarget = false;
float3 AFPosition;
float4x4 AFMatrix;
#endif

float4x4 matV : VIEW;

inline float CalcFocusDistance()
{
	return (ExistAFTarget)
//		? length(mul(mul(float4(AFPosition,1), AFMatrix), matV)) * 10.0
		? mul(mul(float4(AFPosition,1), AFMatrix), matV).z * 10.0
		: FocusDistanceAc;
}

static float FocusDistance = CalcFocusDistance();


// 焦点距離：カメラ内で焦点の合う距離 (mm単位。25mm広角～50mm標準～200mm望遠)
// 焦点距離を変えると本来は画角が変わる。
// 焦点距離が短いほど被写界深度(ボケない範囲)は深くなる。
float FocalLength : CONTROLOBJECT < string name = "(self)"; string item = "Ry"; >;

// 有効口径。(1.4～16程度?)
// FNumber = 2.8 なら F = f / 2.8。
float FNumber : CONTROLOBJECT < string name = "(self)"; string item = "Rz"; >;

const float MinFocusDistance = (0.5 * m);
const float MinFocalLength = (20.0 * mm);
const float MinFNumber = 1.0;
const float MaxFNumber = 16.0;

// ピントテスト用
#define DebugCoC		0	// テスト用の適当な焦点計算を使用する
#define WorldNearEndRate	0.25	// 被写界深度の手前の終わり開始位置
#define WorldFarStartRate	1.0		// 被写界深度の奥の終わり開始位置
#define WorldFarEndRate		100.0	// 最大ボケに到達する距離

	// |<---前ボケ--->|<--前-- 被写界深度 ---後ろ----->|<----後ボケ------>|
	// |------------------------>
	//	距離は、被写界深度(アクセサリのSi)の何倍かで示す。

//テクスチャフォーマット
//#define TEXFORMAT "D3DFMT_A32B32G32R32F"
#define TEXFORMAT "D3DFMT_A16B16G16R16F"

#define INTENSITY_TEXFORMAT "D3DFMT_G16R16F"


////////////////////////////////////////////////////////////////////////////////////////////////
// ALの計算した高輝度部分を利用する実験。
// AL自身の効果のほうが影響度が高くほぼ無意味。

#define USE_HDR		0

#if defined(USE_HDR) && USE_HDR > 0
const float AL_SCALE = 10.0;
#if 0 //
bool Exist_AutoLuminous : CONTROLOBJECT < string name = "AutoLuminous.x"; >;

shared texture2D ExternalHighLight : RENDERCOLORTARGET;

sampler2D ExternalHighLightView = sampler_state {
    texture = <ExternalHighLight>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = NONE;
    AddressU  = Border;
    AddressV = Border;
};
#else
bool Exist_AutoLuminous : CONTROLOBJECT < string name = "AutoLuminousBasic.x"; >;

// AutoLuminousBasic.fxを書き換えて、sharedを付加する必要あり。
shared texture ALB_EmitterRT: OFFSCREENRENDERTARGET;

sampler2D ExternalHighLightView = sampler_state {
    texture = <ALB_EmitterRT>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = NONE;
    AddressU  = Border;
    AddressV = Border;
};
#endif
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

#if ENABLE_TEST_MODE == 1
// テストモード
float TestModeFlag : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
#endif

#define	PI	(3.14159265359)
#define Rad2Deg(x)	((x) * 180 / PI)

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define TEXBUFFRATE {1.0/LowRes, 1.0/LowRes}

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float2 ViewportOffsetLow = (LowRes * float2(0.5,0.5)/ViewportSize.xy);

static float2 SampleStep = (float2(1, 1) / ViewportSize.xy);
static float2 SampleStepLow = (LowRes * float2(1, 1) / ViewportSize.xy);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	bool AntiAlias = false;
	int MipLevels = 1;
	string Format = "D3DFMT_A16B16G16R16F";
>;

sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

sampler2D ScnSampPoint = sampler_state {
	texture = <ScnMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;


// ボケの分配強度とボケ半径を格納
texture2D IntensityMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1,1};
	string Format = INTENSITY_TEXFORMAT;

	float4 ClearColor = { 0, 0, 0, 0 };
>;
sampler2D IntensitySamp = sampler_state {
	texture = <IntensityMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

sampler2D IntensitySampPoint = sampler_state {
	texture = <IntensityMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 後ボケ：前計算の格納先
texture2D BackDoFMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
	float4 ClearColor = { 0, 0, 0, 0 };
>;

sampler2D BackDoFSamp1 = sampler_state {
	texture = <BackDoFMap1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 前ボケ：前計算の格納先
texture2D FrontDoFMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;

sampler2D FrontDoFSamp1 = sampler_state {
	texture = <FrontDoFMap1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


#if defined(USE_BLUR) && USE_BLUR > 0
// 後ボケ：BackDoFMap1にブラーを掛けたもの
texture2D BackDoFMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;

sampler2D BackDoFSamp2 = sampler_state {
	texture = <BackDoFMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 前ボケ：FrontDoFMap1にブラーを掛けたもの
texture2D FrontDoFMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;

sampler2D FrontDoFSamp2 = sampler_state {
	texture = <FrontDoFMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

// ブラー用
texture2D DownscaleMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
	float4 ClearColor = { 0, 0, 0, 0 };
>;

sampler2D DownscaleSamp = sampler_state {
	texture = <DownscaleMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;

	AddressU  = CLAMP;
	AddressV = CLAMP;
};


// 前ボケの裏側
#if defined(USE_FRONTBACK) && USE_FRONTBACK > 0
texture2D FrontBackMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1.0 / FrontBackRes, 1.0 / FrontBackRes};
	string Format = TEXFORMAT;
	float4 ClearColor = { 0, 0, 0, 0 };
>;

sampler2D FrontBackSamp1 = sampler_state {
	texture = <FrontBackMap1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D FrontBackMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1.0 / FrontBackRes, 1.0 / FrontBackRes};
	string Format = TEXFORMAT;
	float4 ClearColor = { 0, 0, 0, 0 };
>;

sampler2D FrontBackSamp2 = sampler_state {
	texture = <FrontBackMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif


// デバッグ時の数値表示用テクスチャ
#if ENABLE_TEST_MODE == 1
#define NUMBER_TEX_SIZE		256
texture NumberTex <
	string ResourceName="DbgNumber.png";
	int Miplevels=1;
>;
sampler NumberMap = sampler_state {
	texture = <NumberTex>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif


//-----------------------------------------------------------------------------
// 深度マップ
// 深度情報と明るさ情報を格納
texture LinearDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikボケ.fx";
	float4 ClearColor = { 1, 0, 0, 1 };
	float2 ViewportRatio = {1, 1};
	float ClearDepth = 1.0;
	string Format = "D3DFMT_G16R16F";
	bool AntiAlias = false;
	string DefaultEffect = 
		"self = hide;"
		"* = ikDepthBright.fx";
>;

sampler DepthMap = sampler_state {
	texture = <LinearDepthMapRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;

	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
};


//-----------------------------------------------------------------------------
// 固定定義
//-----------------------------------------------------------------------------
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float2 TexCoordLow	: TEXCOORD1;
};

struct PS_OUT_MRT
{
	float4 BackDoF		: COLOR0;
	float4 FrontDoF		: COLOR1;
};


// ガンマ補正
inline float3 Degamma(float3 col) { return pow(col, gamma); }
inline float3 Gamma(float3 col) { return pow(col, 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }


//-----------------------------------------------------------------------------
// どれだけボケるか

static float focusDistance = max(FocusDistance * 0.1, MinFocusDistance);
static float focalLength = max(Rad2Deg(FocalLength) * mm, 20 * mm);
static float aperture = 1.0 / clamp(Rad2Deg(FNumber), MinFNumber, MaxFNumber);

static float I = (focusDistance * focalLength) / (focusDistance - focalLength);
static float S = aperture / FilmSize * (ViewportSize.y / LowRes);
static float CoCCoefMul =-(I * S);
static float CoCCoefAdd = (I * S / focalLength) - S;

inline float CalcBlurLevel(float distance)
{
#if DebugCoC == 1
	// テスト用の適当な処理
	float CoC = (distance - focusDistance);
	if (CoC <= 0.0) {
		// 前ボケ
		float nearLimit = focusDistance * WorldNearEndRate;
		CoC = (CoC + nearLimit) / (focusDistance - nearLimit);
		CoC = MAX_COC_SIZE * min(CoC, 0);
	} else {
		// 後ろボケ
		float farLimit = focusDistance * WorldFarStartRate;
		CoC = (CoC - farLimit) / (focusDistance * WorldFarEndRate);
		CoC = MAX_COC_SIZE * saturate(CoC);
	}

#else
	float CoC = CoCCoefMul / distance + CoCCoefAdd;
#endif

	return clamp(CoC, -MAX_COC_SIZE, MAX_COC_SIZE);
}


// カメラの設定からFoVを計算する
float GetFoV(void)
{
#if DebugCoC != 1
	const float PlaneInFocus = focusDistance;
	float S = (PlaneInFocus * focalLength);
	float I = S / (PlaneInFocus - focalLength);
	return atan(FilmSize / (2.0 * I)) * 2.0 * (180.0 / PI);
#endif

	return 0;	// 計測不能 
}

float GetDisplayDistance(void)
{
#if DebugCoC != 1
	return min(focusDistance * 10.0, 999);
#endif
	return 0;	// 計測不能 
}


float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}


#if ENABLE_TEST_MODE == 1
float DispNumber(float x, float y)
{
	const int MaxRadix = 3;
	const float2 texCharSize = float2(20, 20);
	const float2 dispCharSize = float2(12, 16);

	float result = 0;

	if (x >= 0 && y >= 0 && x <= MaxRadix * dispCharSize.x)
	{
		int radix = floor(x / dispCharSize.x);
		float scale = pow(10, MaxRadix - radix - 1);
		float dispNum = 0;

		if (y <= dispCharSize.y)
		{
			// 角度
			dispNum = fmod(floor(GetFoV() / scale), 10);
			float2 texCoord = float2(dispNum * texCharSize.x + fmod(x, dispCharSize.x), y);
			result = tex2D( NumberMap, texCoord / NUMBER_TEX_SIZE).r;
		}
		else if (y <= dispCharSize.y * 2.0)
		{
			// 焦点までの距離
			dispNum = fmod(floor(GetDisplayDistance() / scale), 10);
			float2 texCoord = float2(dispNum * texCharSize.x + fmod(x, dispCharSize.x), y - dispCharSize.y);
			result = tex2D( NumberMap, texCoord / NUMBER_TEX_SIZE).r;
		}
	}

	return result;
}
#endif

//-----------------------------------------------------------------------------
//
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord  = Tex.xy + ViewportOffset.xy;
	Out.TexCoordLow = Tex.xy + ViewportOffsetLow.xy;

	return Out;
}

VS_OUTPUT VS_CalcDoF( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord  = Tex.xy + ViewportOffset.xy;
	Out.TexCoordLow.xy = Tex.xy + ViewportOffsetLow.xy;

	return Out;
}


//-----------------------------------------------------------------------------
// CoCの計算
float4 PS_CalcCoC( VS_OUTPUT IN ) : COLOR
{
	float2 DepthInfo = tex2D( DepthMap, IN.TexCoord).xy;

	float Depth = DepthInfo.r * FAR_DEPTH;	// 奥行き
	float emission = DepthInfo.g;			// 明るい部分を強調する
	float level = CalcBlurLevel(Depth);

	#if defined(FORCE_COC_SCALE)
	if (FORCE_COC_SCALE != 1.0)
	{
		level = (abs(level) >= 1.0)
				? sign(level) * ((abs(level) - 1.0) * FORCE_COC_SCALE + 1)
				: level;
	}
	#endif

	#if defined(USE_HDR) && USE_HDR > 0
	if (Exist_AutoLuminous)
	{
		emission = rgb2gray(tex2D( ExternalHighLightView, IN.TexCoord ).rgb) * AL_SCALE;
	}
	#endif

	float radius = level;
	float radius2 = max(radius * radius, 4);

	float intensity = (1 + emission) / (radius2 * PI);
	// in-focusな部分をボケに含ませない
	intensity *= saturate(abs(level) - 1);

	return float4(intensity, radius, 0, 1);
}


//-----------------------------------------------------------------------------
// 低解像度のバッファを作る
float4 PS_DownSampling( VS_OUTPUT IN ) : COLOR
{
	float2 DepthInfo = tex2D(IntensitySamp, IN.TexCoord).xy;
	float intensity = DepthInfo.x;
	float radius = DepthInfo.y;

	float2 step = SampleStepLow;
	float3 Color = Degamma(tex2D(ScnSampPoint, IN.TexCoordLow).rgb);
	float4 sum = float4(Color * intensity, intensity);

	[unroll]
	for(float ang = 0; ang < 8; ang++) {
		float x = cos(ang * (PI / 4.0));
		float y = sin(ang * (PI / 4.0));
		float2 offset = float2(x,y) * step;
		float3 col = Degamma(tex2D(ScnSampPoint, IN.TexCoordLow + offset).rgb);
		float2 info0 = tex2D(IntensitySamp, IN.TexCoord + offset).xy;
		float w0 = (radius * info0.y > 0.0); // 前ボケと後ボケを混ぜない
		float intensity0 = info0.x * w0;
		sum += float4(col * intensity0, intensity0);
	}

	return sum / 9.0;
}

//-----------------------------------------------------------------------------
// 
float2 ToUnitDisk( float x, float y)
{
	float r = 0;
	float phi = 0;

	if (x > -y) {
		if (x > y) {
			r = x;
			phi = y / x;
		} else {
			r = y;
			phi = 2.0 - x / y;
		}
	} else {
		if (x < y) {
			r = -x;
			phi = 4.0 + y / x;
		} else {
			r = -y;
			phi = (y != 0) ? (6.0 - x / y) : 0;
		}
	}

	phi *= (PI / 4.0);

	return float2(r, phi);
}


//-----------------------------------------------------------------------------
// 遠距離/近距離のDoFを作成
//-----------------------------------------------------------------------------
PS_OUT_MRT PS_CalcDoF( VS_OUTPUT IN ) : COLOR
{
	float2 texCoord = IN.TexCoordLow.xy;

	float4 sumB = 0;
	float4 sumF = 0;
	float cnt1 = 0;
	float cnt2 = 0;

	const float stepY = SAMPLING_STEP;
	const float stepX = SAMPLING_STEP;

#if 0
	[loop]
	for(float y = -MAX_COC_SIZE; y <= MAX_COC_SIZE; y += stepY) {
		[loop]
		for(float x = -MAX_COC_SIZE; x <= MAX_COC_SIZE; x += stepX) {
#else
	// 32bit対応
	const int loopX = (MAX_COC_SIZE * 2 + 1) / stepX;
	const int loopY = (MAX_COC_SIZE * 2 + 1) / stepY;
	for(int iy = 0; iy < loopY; iy++) {
		float y = iy * stepY - MAX_COC_SIZE;
		for(int ix = 0; ix < loopX; ix++) {
			float x = ix * stepX - MAX_COC_SIZE;
#endif

			float2 disc = ToUnitDisk(x,y);
			float2 uv = float2(cos(disc.y), sin(disc.y)) * disc.x;
			float dist = disc.x;

			float2 texCoord1 = texCoord + uv * SampleStepLow;
			float radius = tex2D(IntensitySamp, texCoord1).y;
			float w = saturate(abs(radius) - dist) * (stepX * stepY / 2.0);
			float4 Color = tex2D(DownscaleSamp, texCoord1);
			float4 result = Color * w;

			if (radius >= 1.0) {
				sumB += result; 
			} else if (radius <= -1.0) {
				sumF += result;
				cnt1 += saturate(-radius - 1); // * w;
			}

			cnt2 += 1;
		}
	}

	// 計算誤差?で前ボケの明るさが足りなくなる分を補正
	float a = saturate(max(cnt1 / cnt2, sumF.a));
	sumF = sumF * (a / sumF.a);

	PS_OUT_MRT OUT;
	OUT.FrontDoF = sumF;
	OUT.BackDoF = sumB;

	return OUT;
}


#if defined(USE_FRONTBACK) && USE_FRONTBACK > 0
//-----------------------------------------------------------------------------
// 前ボケの後を捏造

//#define NUM_BLUR_SAMPLES	8
static const int NUM_BLUR_SAMPLES = max(MAX_COC_SIZE / FrontBackRes + 1, 8);

static const float BlurWeight[] = {
	// 近いほど優先する。
	1.0,
	1/2.0,
	1/4.0,
	1/8.0,
	1/16.0,
	1/32.0,
	1/64.0,
	1/128.0,
};

float4 PS_CreateFrontBack( float2 TexCoord: TEXCOORD0 ) : COLOR
{
	float2 step = FrontBackRes / ViewportSize.xy;
	float2 Tex = TexCoord - ViewportOffset + step * 0.5;

	float2 DepthInfo = tex2D(IntensitySamp, Tex).xy;
	float radius = DepthInfo.y;

	float3 Color = Degamma(tex2D(ScnSampPoint, Tex).rgb);
	#if defined(USE_BLUR) && USE_BLUR > 0
	float4 backColor = tex2D( BackDoFSamp2, Tex);
	#else
	float4 backColor = tex2D( BackDoFSamp1, Tex);
	#endif
	const float lowKey = 0.5 / (MAX_COC_SIZE * MAX_COC_SIZE * PI);
	backColor += float4(Color, 1) * lowKey;
	backColor /= backColor.a;
	Color = lerp(Color, backColor.rgb, saturate(radius-1));
		// ここまでやるなら、後ボケとインフォーカスの画像の合成を別パスで先に行い、
		// その結果を利用してボカしたほうがいいかも?

	float a = saturate(radius + 2.0);
	return float4(Color.rgb, 1) * a;
}

float4 PS_BlurFrontBack( float2 TexCoord: TEXCOORD0, uniform bool isXBlur ) : COLOR
{
	sampler2D smp = (isXBlur) ? FrontBackSamp1 : FrontBackSamp2;

	float2 step = FrontBackRes / ViewportSize.xy;
	float2 Tex = TexCoord - ViewportOffset + step * 0.5;
	step *= ((isXBlur) ? float2(1,0) : float2(0,1));

	float4 Color = tex2D( smp, Tex);
	if (Color.a == 1.0) return Color;

	Color *= BlurWeight[0];

	[unroll]
	for(int i = 1; i < NUM_BLUR_SAMPLES; i++) {
		float w = BlurWeight[i];
		float4 cp = tex2D( smp, Tex + step * i);
		float4 cn = tex2D( smp, Tex - step * i);
		Color += (cp + cn) * w;
	}

	return Color * (0.2 / Color.a);
}

float4 PS_BlurFrontBack2( float2 TexCoord: TEXCOORD0) : COLOR
{
	float2 step = FrontBackRes / ViewportSize.xy;
	float2 Tex = TexCoord - ViewportOffset + step * 0.5;

	const float w0 = 0.7071;

	sampler2D Samp = FrontBackSamp1;

	float4 sum = 0;
	sum += tex2D(Samp, TexCoord + (float2(-1,-1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2( 0,-1) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1,-1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2(-1, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2( 0, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2(-1, 1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2( 0, 1) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1, 1) * step)) * w0;
	return sum / (5 + w0 * 4);
}

#endif


//-----------------------------------------------------------------------------
// ボカし処理
#if defined(USE_BLUR) && USE_BLUR > 0
float4 SecondPassBlur(sampler2D Samp, float2 TexCoord)
{
	const float2 step = SampleStepLow * 1.25;
	const float w0 = 0.7071;

	float4 sum = 0;
	sum += tex2D(Samp, TexCoord + (float2(-1,-1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2( 0,-1) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1,-1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2(-1, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2( 0, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1, 0) * step));
	sum += tex2D(Samp, TexCoord + (float2(-1, 1) * step)) * w0;
	sum += tex2D(Samp, TexCoord + (float2( 0, 1) * step));
	sum += tex2D(Samp, TexCoord + (float2( 1, 1) * step)) * w0;
	return sum / (5 + w0 * 4);
}

// 後ボケのボカし
float4 PS_BlurBackDoF( VS_OUTPUT IN ) : COLOR
{
	return SecondPassBlur( BackDoFSamp1, IN.TexCoordLow);
}

// 前ボケのボカし
float4 PS_BlurFrontDoF( VS_OUTPUT IN ) : COLOR
{
	return SecondPassBlur( FrontDoFSamp1, IN.TexCoordLow);
}
#endif

//-----------------------------------------------------------------------------
// 最後に元画面と計算結果を合成する
//-----------------------------------------------------------------------------
float4 PS_Last( VS_OUTPUT IN ) : COLOR
{
	float2 texCoord = IN.TexCoord;

#if DISABLE_ALL >= 1
	return float4(tex2D( ScnSampPoint, texCoord ).rgb, 1);
#else
	float3 ColorBase = Degamma(tex2D( ScnSampPoint, texCoord ).rgb);

//	return float4( rgb2gray(tex2D( ExternalHighLightView, IN.TexCoord ).rgb).xxx, 1);

	float level = tex2D( IntensitySampPoint, texCoord).y;
	float radius = abs(level);

	#if defined(USE_BLUR) && USE_BLUR > 0
		float4 backColor = tex2D( BackDoFSamp2, texCoord);
		float4 frontColor = tex2D( FrontDoFSamp2, texCoord);
	#else
		float4 backColor = tex2D( BackDoFSamp1, texCoord);
		float4 frontColor = tex2D( FrontDoFSamp1, texCoord);
	#endif

	// 後ボケの合成
	const float lowKey = 0.5 / (MAX_COC_SIZE * MAX_COC_SIZE * PI);
	backColor += float4(ColorBase, 1) * lowKey;
	backColor /= backColor.a;
	float3 Color = lerp(ColorBase, backColor.rgb, saturate(level-1));

	#if !defined(DISABLE_FRONT_BOKEH) || DISABLE_FRONT_BOKEH == 0
		// 前ボケの裏側を合成
		#if defined(USE_FRONTBACK) && USE_FRONTBACK > 0
		float4 frontBack = tex2D( FrontBackSamp2, texCoord);
		frontBack.rgb /= frontBack.a;
		Color = lerp(Color, frontBack.rgb, saturate(-level-1) * (frontBack.a > 0.0));
		#endif

		// 前ボケの合成
		float frontAlpha = saturate(frontColor.a);
		frontColor.rgb /= frontColor.a;
		Color = lerp(Color, frontColor, frontAlpha);
	#endif

	// テストモード
	#if ENABLE_TEST_MODE == 1
	if (TestModeFlag > 0)
	{
		Color = rgb2gray(Color) * 0.98 + 0.02; // 真っ黒い部分に色を乗せるため。
		float grad = saturate(Color.g - saturate(radius - 1));
		if (level < 0.0) Color.g = grad;
		else if (level > 0.0) Color.rb = grad;

		float2 dbgDispPos = texCoord * ViewportSize - 8;
		float dbgDisp = DispNumber(dbgDispPos.x, dbgDispPos.y);
		Color = (dbgDisp > 0.0) ? dbgDisp : Color;
	}
	#endif

	return float4(Gamma(Color), 1);
#endif
}
////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
	string Script = 
		// 普通の画面をレンダリング
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

#if DISABLE_ALL == 0

		// CoCのサイズ計算
		"RenderColorTarget0=IntensityMap;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=CalcCoCPass;"

		// ダウンスケールした画像の作成
		"RenderColorTarget0=DownscaleMap;"
		"Clear=Color;"
		"Pass=ScalePass;"

		// DoFの適用
		"RenderColorTarget0=BackDoFMap1;"
		"RenderColorTarget1=FrontDoFMap1;"
		"Clear=Color;"
		"Pass=BackDoFPass;"
		"RenderColorTarget1=;"		// MRTの解除

#if defined(USE_BLUR) && USE_BLUR > 0
		// 遠景のDoFにボカしを掛ける
		"RenderColorTarget0=BackDoFMap2;"
		"Clear=Color;"
		"Pass=BlurBackDoFPass;"

#if !defined(DISABLE_FRONT_BOKEH) || DISABLE_FRONT_BOKEH == 0
		// 手前のDoFにボカしを掛ける
		"RenderColorTarget0=FrontDoFMap2;"
		"Clear=Color;"
		"Pass=BlurFrontDoFPass;"
#endif
#endif

#if !defined(DISABLE_FRONT_BOKEH) || DISABLE_FRONT_BOKEH == 0
#if defined(USE_FRONTBACK) && USE_FRONTBACK > 0
		// 前ボケの裏側を作成
		"RenderColorTarget0=FrontBackMap1;"
		"Clear=Color;"
		"Pass=CreateFrontBackPass;"

		"RenderColorTarget0=FrontBackMap2;"
		"Clear=Color;"
		"Pass=BlurFrontBackXPass;"

		"RenderColorTarget0=FrontBackMap1;"
		"Clear=Color;"
		"Pass=BlurFrontBackYPass;"

		"RenderColorTarget0=FrontBackMap2;"
		"Clear=Color;"
		"Pass=BlurFrontBack2Pass;"
#endif
#endif
#endif

		// 合成する
		"RenderColorTarget0=;"
		"RenderColorTarget1=;"
		"RenderDepthStencilTarget=;"
		"Pass=LastPass;"
	;
> {
	pass CalcCoCPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_CalcCoC();
	}

	pass ScalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_DownSampling();
	}

	pass BackDoFPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_CalcDoF();
		PixelShader  = compile ps_3_0 PS_CalcDoF();
	}

#if defined(USE_FRONTBACK) && USE_FRONTBACK > 0
	pass CreateFrontBackPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_CreateFrontBack();
	}

	pass BlurFrontBackXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_BlurFrontBack(true);
	}

	pass BlurFrontBackYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_BlurFrontBack(false);
	}

	pass BlurFrontBack2Pass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_BlurFrontBack2();
	}
#endif

#if defined(USE_BLUR) && USE_BLUR > 0
	pass BlurBackDoFPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_BlurBackDoF();
	}

	pass BlurFrontDoFPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_BlurFrontDoF();
	}
#endif

	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Last();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////

