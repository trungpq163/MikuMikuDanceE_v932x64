//=============================================================================
//
// 線形で画像処理するためのエフェクト
//
// ikLinearBegin/ikLinearEndのペアで使う。
// ※ ikPolishと一緒に使う場合は、ikLinearBeginは不要。
//
//=============================================================================

// 自動露出補正
#define AUTO_EXPOSURE	1	// 0:無効、1:有効

// 補正強度 (0.0～1.0) 小さいほど補正しない。
#define EXPOSURE_INTENSITY	0.8

// 変化速度
// 人間の目は明るくなる方と暗くなる方で順応速度が違う。
// それぞれ、0.1～5.0程度。大きいほど早く反応する。早すぎるとチラつきの元になる
#define SPEED_UP		3.0		// 明順応の速度
#define SPEED_DOWN		1.0		// 暗順応の速度


// トーンマップ方式
#define TONEMAP_MODE	3
/*
0: Linear (トーンマップなし)
1: Reinhard
2: ACES
3: Uncharted2
*/

// テスト用の情報を表示を有効にする。
#define ENABLE_DEBUG_VIEW	0


// ブルームを有効にする
#define ENABLE_BLOOM		1
// ブルームの強度
#define	BloomIntensity		0.5 // 0.0-5.0
// ブルームさせる明るさのしきい値
#define	BloomThreshold		2.0	// 1.0-2.0 程度

// 簡易レンズフレアを有効にする
#define ENABLE_LENSFLARE	1


// アンチエイリアス。
#define ENABLE_AA		1
// アンチエイリアスの強度
#define AA_Intensity	0.5		// 0.0 - 1.0


// 平均輝度を計算する範囲。
// 画面内の輝度を明るさ順にならべて、LOW_PERCENT未満、HIGH_PERCENT以上の
// 情報を捨ててから平均を計算する。
#define LOW_PERCENT		(70)		// 50～80 程度
#define HIGH_PERCENT	(95)		// 80～98 程度


// 平均輝度の下限と上限 0.01-4の間
#define LOWER_LIMIT		(0.03)
#define UPPER_LIMIT		(2.0)
/*
#define LOWER_LIMIT		(0.5)
#define UPPER_LIMIT		(0.5)
*/

// 輝度ベースのトーンマップ
// 輝度ベースのほうが彩度が落ちにくいのでMMD向き?
// 0: rgbを独立して計算する
#define LUMABASE_TONEMAP	1


// 最後にディザを掛ける。有効にするとバンディングが改善される。
#define ENABLE_DITHER	1	// 0:無効、1:有効

// エディタ時間に同期させるか? 0:同期しない、1:同期する
#define TimeSync		0


//-----------------------------------------------------------------------------
// あまりいじならい項目

#define CONTROLLER_NAME		"ikPolishController.pmx"

// ホワイトポイント。トーンマップ後にRGB(1,1,1)になる明るさ。
//#define	WHITE_POINT		(11.2)
#define	WHITE_POINT		(4.0)

// ヒストグラムの範囲(Log2単位)
#define LOWER_LOG		(-8)
#define UPPER_LOG		(2)		// 2^x

// 画面の平均輝度をどこまで明るくするか。
float KeyValue = 0.5;
//float KeyValue = 0.9;

// 輝度を格納するためのテクスチャサイズ。それなりのサイズが必要
#define LUMINANCE_TEX_SIZE		512
static float MAX_MIP_LEVEL = log2(LUMINANCE_TEX_SIZE);

// ブルームに色を付ける
#define BLOOM_TINT1	float3(1,1,1)
#define BLOOM_TINT2	float3(1,1,1)
#define BLOOM_TINT3	float3(1,1,1)
#define BLOOM_TINT4	float3(1,1,1)
#define BLOOM_TINT5	float3(1,1,1)


//=============================================================================

// #include "ikLinearEnd_body.fxsub"

//=============================================================================
//
//=============================================================================

//=============================================================================

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time2 : time1;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time2 : elapsed_time1, 0.0f, 0.1f);

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A16B16G16R16F";
>;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};
sampler ScnSampBorder = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;


#if AUTO_EXPOSURE > 0
texture LuminanceTex: RENDERCOLORTARGET <
	int2 Dimensions = int2(LUMINANCE_TEX_SIZE, LUMINANCE_TEX_SIZE);
	int Miplevels = 0;
	string Format = "A16B16G16R16F";
>;
sampler LuminanceSamp = sampler_state {
	texture = <LuminanceTex>;
//	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = POINT;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
texture2D LuminanceDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = int2(LUMINANCE_TEX_SIZE, LUMINANCE_TEX_SIZE);
	string Format = "D24S8";
>;

texture AverageTex: RENDERCOLORTARGET <
	int2 Dimensions = int2(1,1);
	int Miplevels = 1;
	string Format = "G16R16F";
>;
sampler AverageSamp = sampler_state {
	texture = <AverageTex>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
texture AverageWorkTex: RENDERCOLORTARGET <
	int2 Dimensions = int2(1,1);
	int Miplevels = 1;
	string Format = "G16R16F";
>;
sampler AverageWorkSamp = sampler_state {
	texture = <AverageWorkTex>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
#endif

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float3 AcsPosition : CONTROLOBJECT < string name = "(self)"; >;

#define DECLARE_PARAM(_t,_var,_item)	\
	_t _var : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = _item;>;

bool mExistPolish : CONTROLOBJECT < string name = CONTROLLER_NAME; >;
DECLARE_PARAM(float, mExposureIntensity, "露出補正低減");
DECLARE_PARAM(float, mExposureP, "露出+");
DECLARE_PARAM(float, mExposureM, "露出-");
DECLARE_PARAM(float, mExposureSnap, "露出スナップ");
DECLARE_PARAM(float, mBloomP, "ブルーム+");
DECLARE_PARAM(float, mBloomM, "ブルーム-");

static float AcsExposureOffset = (AcsPosition.x + (mExposureP - mExposureM) * 4.0);
static float AcsBloomIntensity = (AcsPosition.y + 1.0 + (mBloomP * 3.0 - mBloomM));


#define SQRT2	1.4142
const float gamma = 2.2;
const float epsilon = 1.0e-6;
float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float Luminance(float3 rgb)
{
//	return dot(float3(0.2126, 0.7152, 0.0722), max(rgb,0));
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

float Brightness(float3 rgb)
{
	return max(max(rgb.r, rgb.g), rgb.b);
}


#if ENABLE_DITHER > 0

#define	NOISE_TEXTURE_SIZE	(256.0)
texture2D NoiseTex <
	string ResourceName = "bluenoise.png";
	int MipLevels = 1;
>;
sampler NoiseSamp = sampler_state {
	texture = <NoiseTex>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = WRAP;	AddressV  = WRAP;
};

float GetJitterOffset(int2 iuv)
{
	return tex2D(NoiseSamp, iuv / NOISE_TEXTURE_SIZE).x;
}
#endif


#if ENABLE_BLOOM > 0
#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		int MipLevels = 1; \
		float2 ViewportRatio = {1.0/(_size), 1.0/(_size)}; \
		string Format = "A16B16G16R16F"; \
	>; \
	sampler _samp = sampler_state { \
		texture = <_map>; \
		MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE; \
		AddressU  = CLAMP; AddressV = CLAMP; \
	};

DECL_TEXTURE( BrightMap, BrightSamp, 2)
DECL_TEXTURE( BlurMap1X, BlurSamp1X, 4)
DECL_TEXTURE( BlurMap1Y, BlurSamp1Y, 4)
DECL_TEXTURE( BlurMap2X, BlurSamp2X, 8)
DECL_TEXTURE( BlurMap2Y, BlurSamp2Y, 8)
DECL_TEXTURE( BlurMap3X, BlurSamp3X, 16)
DECL_TEXTURE( BlurMap3Y, BlurSamp3Y, 16)
DECL_TEXTURE( BlurMap4X, BlurSamp4X, 32)
DECL_TEXTURE( BlurMap4Y, BlurSamp4Y, 32)
DECL_TEXTURE( BlurMap5X, BlurSamp5X, 64)
DECL_TEXTURE( BlurMap5Y, BlurSamp5Y, 64)

// ぼかし処理の重み係数：
float4 BlurWeightArray[] = {
/*
	float4(0.0920246, 0.0902024, 0.0849494, 0.0768654),
	float4(0.0668236, 0.0558158, 0.0447932, 0.0345379)
*/
	float4(0.1167251335, 0.1121482756, 0.0994665976, 0.0814363623),
	float4(0.0615482786, 0.0429407769, 0.0276554243, 0.016441718),
};

static float BlurWeight[8] = (float[8])BlurWeightArray;

#endif


//-----------------------------------------------------------------------------
// トーンマッピング

// https://www.shadertoy.com/view/ldcSRN
float3 FilmicReinhard(float3 x)
{
	// T = 0: no toe, classic Reinhard
	const float T = 0.01;
	float3 q = (T + 1.0) * x*x;
	return q / (q + x + T);
}

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
float3 ACESFilm( float3 x )
{
	float a = 2.51;
	float b = 0.03;
	float c = 2.43;
	float d = 0.59;
	float e = 0.14;
	return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

// http://filmicworlds.com/blog/filmic-tonemapping-operators/
float3 Uncharted2Tonemap(float3 x)
{
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;

	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float3 Tonecurve(float3 col)
{
	#if TONEMAP_MODE == 0
		// 何もしない
	#elif TONEMAP_MODE == 1
		col.rgb = FilmicReinhard(col.rgb);

	#elif TONEMAP_MODE == 2
		col.rgb = ACESFilm(col.rgb);

	#elif TONEMAP_MODE == 3
		col.rgb = Uncharted2Tonemap(col.rgb);
	#endif

	return col.rgb;
}

#if TONEMAP_MODE == 3
// Uncharted2
float ExposureBias = 2.0;
#else
float ExposureBias = 1.0;
#endif

float3 Tonemap(float3 col, float inverseWhitepoint)
{
	float ExposureBias = 2.0f;

	#if TONEMAP_MODE == 0
		// 何もしない
	#elif LUMABASE_TONEMAP == 0
		col.rgb = Tonecurve(col.rgb * ExposureBias) * inverseWhitepoint;
	#else
		// 輝度ベース
		float l0 = Luminance(col.rgb);
//		float l0 = Brightness(col.rgb);
		float l1 = Tonecurve(l0 * ExposureBias).x * inverseWhitepoint;
		col.rgb *= (l1 / max(l0, 1e-4));
	#endif

	return saturate(col.rgb);
}



//-----------------------------------------------------------------------------
// 正規化されたログ輝度
float LuminanceToNormalizedLog(float x)
{
	return saturate((log2(max(x, 1.0/1024.0)) - LOWER_LOG) / (-LOWER_LOG + UPPER_LOG));
}
float NormalizedLogToLuminance(float x)
{
	return exp2(x * (-LOWER_LOG + UPPER_LOG) + LOWER_LOG);
}


//-----------------------------------------------------------------------------
//

// トーンマップの値を即座に反映させる?
bool DoSnap(float2 oldValue)
{
	// モーフなどからの強制リセット
	float isForceSnap = (AcsTr < 0.1);
	isForceSnap += (mExposureSnap > 0.5);

	// 0になるかどうかはグラボ・ドライバ次第?
	float isInvalidTextureValue = (dot(oldValue, 1) < 1e-4);

	// 0フレーム目
	float isZeroFrame = (time < 0.5 / 60.0);

	return isForceSnap + isInvalidTextureValue + isZeroFrame;
}

// 露出補正の値。EV値
float GetExposureBias()
{
	return exp2(AcsExposureOffset);
}

// 外部から設定された強制値がある?
float GetExternalExposureValue(float value)
{
/*
	return 1.0 / GetExposureBias();
*/
	return value;
}

#if AUTO_EXPOSURE > 0
float CalcExposureIntensity()
{
	float r = 1.0 - (1.0 - (EXPOSURE_INTENSITY)) * (1.0 - (EXPOSURE_INTENSITY));
	r *= (1.0 - mExposureIntensity);
	return saturate(r);
}

float2 EyeAdaptation(float rawValue)
{
	float2 oldValue = tex2D(AverageSamp, float2(0.5,0.5)).xy;
		// x: smoothed average luminance
		// y: raw average luminance (for debug)

	float targetValue = lerp(KeyValue, rawValue, CalcExposureIntensity());

	float d = targetValue - oldValue.x;
	float s = (d >= 0.0) ? SPEED_UP : SPEED_DOWN;
	float newValue = d * saturate(1 - exp2(-Dt * s)) + oldValue.x;
	newValue = DoSnap(oldValue) ? targetValue : newValue;

	float2 result = float2(newValue, rawValue);
	// result.x = GetExternalExposureValue(result.x);

	return result;
}
#endif


//=============================================================================

struct VS_OUTPUT {
	float4 Pos : POSITION;
	float4 Tex : TEXCOORD0;
	float4 ToneParam : TEXCOORD1;
};


VS_OUTPUT VS_Common(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex.xy = Tex + 0.5 / LUMINANCE_TEX_SIZE;
	return Out;
}

#if AUTO_EXPOSURE > 0
float4 PS_DrawHistogram( float2 Tex : TEXCOORD0 ) : COLOR0
{
	float2 uv = floor(Tex * LUMINANCE_TEX_SIZE);
	float2 iuv = floor(uv / (LUMINANCE_TEX_SIZE / 4));
	float2 fuv = fmod(uv, LUMINANCE_TEX_SIZE / 4);
	float levelOffset = (iuv.x + iuv.y * 4) * 4.0;
	float2 suv0 = (fuv * 4 + 0.5) / LUMINANCE_TEX_SIZE;

	#define LOOP_COUNT	2 // 1,2,4

	float4 ch = 0;
	for(int vy = 0; vy < LOOP_COUNT; vy++)
	{
		for(int vx = 0; vx < LOOP_COUNT; vx++)
		{
			float offset = float2(vx, vy) * 4.0 / (LOOP_COUNT * LUMINANCE_TEX_SIZE);
			float2 suv = suv0 + offset;
			float x = LuminanceToNormalizedLog(Luminance(tex2D(ScnSamp, suv).rgb));
			x = floor(x * 64.0 - levelOffset);
			ch += float4((x == 0.0), (x == 1.0), (x == 2.0), (x == 3.0));
		}
	}

	// 画面周辺の影響度を下げる
	float2 d = (suv0 - 0.5);
	float w = saturate(1.0 - dot(d,d));
	// w *= w;
	w *= (1.0/(LOOP_COUNT * LOOP_COUNT));

	return ch * w;
}


float4 PS_CalcAverage( float2 Tex : TEXCOORD0 ) : COLOR0
{
	#define GET_BIN(x,y)	\
		tex2Dlod(LuminanceSamp, float4((float2(x, y) + 0.5) / 4.0, 0, MAX_MIP_LEVEL - 2))

	float4 ch00 = GET_BIN(0,0); ch00 *= float4(0,0.25,0.5,0.75); // 外れ値扱いにする
	float4 ch01 = GET_BIN(1,0);
	float4 ch02 = GET_BIN(2,0);
	float4 ch03 = GET_BIN(3,0);

	float4 ch10 = GET_BIN(0,1);
	float4 ch11 = GET_BIN(1,1);
	float4 ch12 = GET_BIN(2,1);
	float4 ch13 = GET_BIN(3,1);

	float4 ch20 = GET_BIN(0,2);
	float4 ch21 = GET_BIN(1,2);
	float4 ch22 = GET_BIN(2,2);
	float4 ch23 = GET_BIN(3,2);

	float4 ch30 = GET_BIN(0,3);
	float4 ch31 = GET_BIN(1,3);
	float4 ch32 = GET_BIN(2,3);
	float4 ch33 = GET_BIN(3,3);

	// binの合計値
	float4 sum =
			  ch00 + ch01 + ch02 + ch03
			+ ch10 + ch11 + ch12 + ch13
			+ ch20 + ch21 + ch22 + ch23
			+ ch30 + ch31 + ch32 + ch33;
	float total = dot(sum, 1);

	float2 level = 0;
	float2 target = float2(LOW_PERCENT, HIGH_PERCENT) * 0.01 * total;
	float acc = 0;
	float ra, rb, r;
	float2 lum = 0;

/*
	#define CALC(reg, lv)	\
		ra = saturate(target.x - acc);	acc += reg; \
		rb = saturate(acc - target.y);	\
		r = saturate(reg - ra - rb);	\
		lum += float2(NormalizedLogToLuminance(lv / 64.0), 1.0) * r;
*/

#if 1
	acc = -target.y;
	target.x = target.x - target.y;
	#define CALC(reg, lv)	\
		ra = saturate(target.x - acc);	acc += reg; \
		r = saturate(reg - ra - saturate(acc));	\
		lum += float2(NormalizedLogToLuminance(((lv) + 0.5) / 64.0), 1.0) * r;
#else
	#define CALC(reg, lv)	\
		lum += float2(NormalizedLogToLuminance(((lv) + 0.5) / 64.0), 1.0) * reg;
#endif

	#define CALC4(ch, lvBase)	\
			CALC(ch.x, lvBase * 4 + 0); CALC(ch.y, lvBase * 4 + 1); \
			CALC(ch.z, lvBase * 4 + 2); CALC(ch.w, lvBase * 4 + 3);

	CALC4(ch00,  0); CALC4(ch01,  1); CALC4(ch02,  2); CALC4(ch03,  3);
	CALC4(ch10,  4); CALC4(ch11,  5); CALC4(ch12,  6); CALC4(ch13,  7);
	CALC4(ch20,  8); CALC4(ch21,  9); CALC4(ch22, 10); CALC4(ch23, 11);
	CALC4(ch30, 12); CALC4(ch31, 13); CALC4(ch32, 14); CALC4(ch33, 15);

//	lum.y *= GetExposureBias(); // => avgLum / GetExposureBias()
	float avgLum = lum.x / max(lum.y, 1e-6);

	float2 result = EyeAdaptation(avgLum);
	result = clamp(result, LOWER_LIMIT, UPPER_LIMIT);
	return float4(result, 0, 1);
}

float4 PS_Copy( float2 Tex : TEXCOORD0) : COLOR0
{
	float2 result = tex2D(AverageWorkSamp, float2(0.5,0.5)).xy;
	return float4(result, 0, 1);
}
#endif

//-----------------------------------------------------------------------------
//

/*
	@return
		x: smoothed average luminance (for debug)
		y: raw average luminance (for debug)
		z: exposure scale
		w: inverse white point
*/
float4 CalcToneParam()
{
	float4 result = 0;

	#if AUTO_EXPOSURE > 0
	float2 param = tex2Dlod(AverageSamp, float4(0.5,0.5, 0,0)).xy;
	result.xy = param.xy;

	float EV = GetExposureBias();
	result.z = KeyValue * EV / max(param.x, 1e-4);
	result.xy /= EV;
	#else
	result.z = GetExposureBias();
	#endif

	result.w = 1.0 / Tonecurve(WHITE_POINT).x;
	return result;
}

VS_OUTPUT VS_DrawBuffer(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex.xy = Tex + ViewportOffset;
	Out.Tex.zw = 1.0 / ViewportSize;

	Out.ToneParam = CalcToneParam();

	return Out;
}

#if ENABLE_DEBUG_VIEW > 0
float3 DisplayDebugInfo(float2 uv, float4 ToneParam, float hscale)
{
	#if AUTO_EXPOSURE > 0
	float idx = floor(uv.x * 16);
	float2 histuv = (float2(fmod(idx, 4), floor(idx / 4)) + 0.5) / 4.0;
	float4 hist = tex2Dlod(LuminanceSamp, float4(histuv, 0, MAX_MIP_LEVEL - 2));

	float ch = floor(fmod(floor(uv.x * 64), 4));
	float n = hist.w;
	if (ch < 0.9)
		n = hist.x;
	else if (ch < 1.9)
		n = hist.y;
	else if (ch < 2.9)
		n = hist.z;

	float3 vis = (uv.y > 1.0 - n * 15.0) * 0.5;

	// 上限と下限
	float ll = LuminanceToNormalizedLog(LOWER_LIMIT);
	float ul = LuminanceToNormalizedLog(UPPER_LIMIT);
	if (ll < uv.x && uv.x < ul)  vis = vis * float3(0,0.5,0) + float3(0,0.1,0);

	float mean = LuminanceToNormalizedLog(ToneParam.x);
	float rawmean = LuminanceToNormalizedLog(ToneParam.y);
	if (abs(uv.x - rawmean) * ViewportSize.x < 4) vis = vis * float3(0.5,0.5,1) + float3(0,0,0.1);
	if (abs(uv.x - mean) * ViewportSize.x < 4) vis = vis + 0.5;

	#else
	float3 vis = 0;
	#endif

	// カーブ
	float lum = NormalizedLogToLuminance(uv.x) * ToneParam.z;
	float scurve = 1.0 - Tonemap(lum, ToneParam.w).x;
	float bold = saturate(1.0 - abs(uv.y - scurve) * ViewportSize.y / hscale);
	vis = lerp(vis, 1, bold);

	return saturate(vis);
}
#endif


float4 GetScreenColor(float4 Tex)
{
	float2 uv = Tex.xy;
	float2 offset = Tex.zw;
	float4 center = tex2D(ScnSamp, uv);

#if ENABLE_AA > 0
/*============================================================================
                    NVIDIA FXAA 3.11 by TIMOTHY LOTTES
COPYRIGHT (C) 2010, 2011 NVIDIA CORPORATION. ALL RIGHTS RESERVED.
============================================================================*/
/* NOTE: 
自作コードに対して .pdfを参照してfxaa風に改変してから、
ソースを参照したため、オリジナルとは変数名などが違う。
最適化のため？のコード順序にも従わず、ナイーブな順序になっている。
*/

	const float fxaaConsoleEdgeThreshold = 0.125;		// 0.125: softer, 0.25: sharper
	const float fxaaConsoleEdgeThresholdMin = 0.04;		// 0.04～0.08
	const float fxaaConsoleEdgeSharpness = 2.0;			// 2.0～8.0

	float4 uv2 = uv.xyxy + (float4(-1,-1, 1,1) * 0.5) * offset.xyxy;
	float lumaLU = Luminance(tex2D( ScnSamp, uv2.xy).rgb);
	float lumaRU = Luminance(tex2D( ScnSamp, uv2.zy).rgb);
	float lumaLD = Luminance(tex2D( ScnSamp, uv2.xw).rgb);
	float lumaRD = Luminance(tex2D( ScnSamp, uv2.zw).rgb);
	float lumaC = Luminance(center.rgb);

	float maxLuma = max(max(lumaLU, lumaLD), max(lumaRU, lumaRD));
	float minLuma = min(min(lumaLU, lumaLD), min(lumaRU, lumaRD));
	float maxLumaC = max(lumaC, maxLuma);
	float minLumaC = min(lumaC, minLuma);

	float threshold = max(maxLuma * fxaaConsoleEdgeThreshold, fxaaConsoleEdgeThresholdMin);
	float w = saturate((maxLumaC - minLumaC) / threshold - 0.05);
	w *= w;

	lumaRU += 1.0 / 1024.0;

	float2 dir0 = float2(lumaLD - lumaRU, lumaRD - lumaLU);
	float2 dir1 = normalize(dir0.xx + float2(dir0.y, -dir0.y));
	float3 rgb1p = tex2D(ScnSamp, uv + dir1 * offset).rgb;
	float3 rgb1n = tex2D(ScnSamp, uv - dir1 * offset).rgb;

	float dirScale = min(abs(dir1.x), abs(dir1.y)) * fxaaConsoleEdgeSharpness;
	float2 dir2 = clamp(dir1 / dirScale, -2.0, 2.0);
	float3 rgb2p = tex2D(ScnSamp, uv + dir2 * offset).rgb;
	float3 rgb2n = tex2D(ScnSamp, uv - dir2 * offset).rgb;

	float3 rgbA = rgb1p + rgb1n;
	float3 rgbB = (rgbA + rgb2p + rgb2n) * 0.25;
	float lumaB = Luminance(rgbB);
	rgbB = ((minLuma <= lumaB) * (lumaB <= maxLuma)) ? rgbB : (rgbA * 0.5);
	// rgbB = float3(1,0,0);

	float3 col = lerp(center.rgb, rgbB, w * AA_Intensity);

/*============================================================================*/
#else

	float3 col = center.rgb;

#endif

	return float4(col, 1);
}


float4 PS_DrawBuffer( float4 Tex : TEXCOORD0, float4 ToneParam : TEXCOORD1) : COLOR0
{
	float4 col = GetScreenColor(Tex);
	col.rgb *= ToneParam.z;

	#if ENABLE_BLOOM > 0
	float3 bloom = tex2D(BlurSamp1X, Tex.xy).rgb;
	col.rgb += bloom;
	#endif

	col.rgb = Tonemap(col.rgb, ToneParam.w);

	#if ENABLE_DEBUG_VIEW > 0
	// ヒストグラム
	if (Tex.y > 0.9 && Tex.x < 0.5)
	{
		float2 uv = Tex.xy;
		float hscale = 10;
		uv = uv * float2(2.0, hscale) - float2(0, 1.0 * hscale - 1);
		float3 vis = DisplayDebugInfo(uv, ToneParam, hscale);
		col.rgb = lerp(col.rgb, vis, 0.9);
	}
	#endif

	col.rgb = Gamma(col.rgb);

	#if ENABLE_DITHER > 0
	int2 iuv = floor(Tex.xy * ViewportSize);
	col.rgb += (GetJitterOffset(iuv) / 255.0);
	#endif


	return col;
}


#if ENABLE_BLOOM > 0
//-----------------------------------------------------------------------------
// Bloom

VS_OUTPUT VS_DrawBright(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;

	float2 pixsize = floor(ViewportSize / 2.0);
	float2 uv = Tex + 0.5 / pixsize;
	float2 offset = 1.0 / pixsize;
	Out.Tex = uv.xyxy;
	Out.ToneParam = CalcToneParam();

	return Out;
}

float3 CalcBrightColor(float3 col)
{
	const float k1 = 3.0; // toe slope

	col.rgb = (col.rgb - BloomThreshold);
	// しきい値以下も少し残す
	float3 toe = saturate(col.rgb * k1 + 1.0);
	col.rgb = lerp(toe * toe, col.rgb + 1.0, toe);

	// 色のブーストを行う?

	return col;
}

float4 PS_DrawBright( float4 Tex: TEXCOORD0, float4 ToneParam : TEXCOORD1) : COLOR
{
	#define GetBloomColor(uv) \
		CalcBrightColor(tex2D(ScnSampBorder, uv).rgb * ToneParam.z)

	float3 col = GetBloomColor(Tex.xy) * 0.5;

	#if ENABLE_LENSFLARE > 0
	float2 center = Tex.xy - 0.5;
	center = center * length(center);	// 曲面になると面白い?
	float3 lensflare = 0;
	lensflare += GetBloomColor(-center * 0.75 + 0.5) * float3(0.2, 0.1, 0.5);
	lensflare += GetBloomColor(-center * 2.0 + 0.5) * float3(0.3, 1.0, 0.5);
	col += lensflare * 0.05;
	#endif

	return float4(col.rgb, 1);
}


VS_OUTPUT VS_Blur(float4 Pos: POSITION, float2 Tex: TEXCOORD,
	uniform float level, uniform bool isXBlur)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;

	float2 pixsize = floor(ViewportSize / level);
	Out.Tex.xy = Tex + 0.5 / pixsize;
	Out.Tex.zw = (isXBlur ? float2(1, 0) : float2(0, 1)) / pixsize;

	Out.ToneParam.x = (1/5.0) * max(BloomIntensity * AcsBloomIntensity, 0);

	return Out;
}

float4 PS_Blur( float4 Tex: TEXCOORD0, uniform sampler smp) : COLOR
{
	float2 uv = Tex.xy;
	float2 offset = Tex.zw;
	float3 sum = tex2D( smp, uv).rgb * BlurWeight[0];
	[unroll] for(int i = 1; i < 8; i ++) {
		float t = i;
		sum.rgb += tex2D(smp, uv + offset * t).rgb * BlurWeight[i];
		sum.rgb += tex2D(smp, uv - offset * t).rgb * BlurWeight[i];
	}
	return float4(sum, 1);
}

float4 PS_BlurMix( float4 Tex: TEXCOORD0, float4 ToneParam : TEXCOORD1) : COLOR
{
	float2 uv = Tex.xy;

	float3 sum1 = tex2D(BlurSamp1Y, uv).rgb * BLOOM_TINT1;
	float3 sum2 = tex2D(BlurSamp2Y, uv).rgb * BLOOM_TINT2;
	float3 sum3 = tex2D(BlurSamp3Y, uv).rgb * BLOOM_TINT3;
	float3 sum4 = tex2D(BlurSamp4Y, uv).rgb * BLOOM_TINT4;
	float3 sum5 = tex2D(BlurSamp5Y, uv).rgb * BLOOM_TINT5;
	float3 sum = (sum1 + sum2 + sum3 + sum4 + sum5) * ToneParam.x;

	return float4(sum, 1);
}

#endif


//=============================================================================

technique LinearEnd <
	string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"

		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		#if AUTO_EXPOSURE > 0
		"RenderDepthStencilTarget=LuminanceDepthBuffer;"
		"RenderColorTarget0=LuminanceTex;	Pass=DrawHistogram;"
		"RenderColorTarget0=AverageWorkTex;	Pass=CalcAverage;"
		"RenderColorTarget0=AverageTex;		Pass=CopyPass;"
		#endif

		#if ENABLE_BLOOM > 0
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=BrightMap;		Pass=DrawBrightPass;"
		"RenderColorTarget0=BlurMap1X;		Pass=BlurX1Pass;"
		"RenderColorTarget0=BlurMap1Y;		Pass=BlurY1Pass;"
		"RenderColorTarget0=BlurMap2X;		Pass=BlurX2Pass;"
		"RenderColorTarget0=BlurMap2Y;		Pass=BlurY2Pass;"
		"RenderColorTarget0=BlurMap3X;		Pass=BlurX3Pass;"
		"RenderColorTarget0=BlurMap3Y;		Pass=BlurY3Pass;"
		"RenderColorTarget0=BlurMap4X;		Pass=BlurX4Pass;"
		"RenderColorTarget0=BlurMap4Y;		Pass=BlurY4Pass;"
		"RenderColorTarget0=BlurMap5X;		Pass=BlurX5Pass;"
		"RenderColorTarget0=BlurMap5Y;		Pass=BlurY5Pass;"
		"RenderColorTarget0=BlurMap1X;		Pass=BlurMixPass;"
		#endif

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawBuffer;";
>{
	#if AUTO_EXPOSURE > 0
	pass DrawHistogram < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_DrawHistogram();
	}
	pass CalcAverage < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_CalcAverage();
	}
	pass CopyPass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_Copy();
	}
	#endif

	#if ENABLE_BLOOM > 0
	pass DrawBrightPass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_DrawBright();
		PixelShader  = compile ps_3_0 PS_DrawBright();
	}

	pass BlurX1Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(4, true);
		PixelShader  = compile ps_3_0 PS_Blur(BrightSamp);
	}
	pass BlurY1Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(4, false);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp1X);
	}
	pass BlurX2Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(8, true);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp1Y);
	}
	pass BlurY2Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(8, false);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp2X);
	}
	pass BlurX3Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(16, true);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp2Y);
	}
	pass BlurY3Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(16, false);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp3X);
	}
	pass BlurX4Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(32, true);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp3Y);
	}
	pass BlurY4Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(32, false);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp4X);
	}
	pass BlurX5Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(64, true);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp4Y);
	}
	pass BlurY5Pass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(64, false);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp5X);
	}
	pass BlurMixPass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_Blur(4, true);
		PixelShader  = compile ps_3_0 PS_BlurMix();
	}
	#endif

	pass DrawBuffer < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_DrawBuffer();
		PixelShader  = compile ps_3_0 PS_DrawBuffer();
	}
}

