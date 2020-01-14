//パラメータ

// レンズのコーティング色
// 青
float3 CoatingColor1 = float3(0.04, 0.25, 1.0);
float3 CoatingColor2 = float3(0.2, 0.8, 1.0) * 0.1;

// 画面中心を軸に点対称の位置にもゴーストを出すか?
#define ENABLE_SYMMETRY	1


// 色を強調する。
// 原色に近づく。コーティング色を白にする場合は使ったほうがいい。
#define ENABLE_COLOR_EMPHASIZE	0
// 色を強調する割合(1.0～4.0程度)
#define COLOR_EMPHASIZE_RATE	4.0

//白飛び係数　0～1
float OverExposureRatio = 0.85;


//****************** 以下は弄らないほうがいい設定

// 光芒の長さ
// AL同様Ryで長さを調整可能 
float StretchSampStep0 = 8.0 / 1024.0;

#define X_SCALE		0.5

//テクスチャフォーマット
#define TEXFORMAT "A16B16G16R16F"

#define SCREEN_TEXFORMAT "A8R8G8B8"
//#define SCREEN_TEXFORMAT "A16B16G16R16F"


// 散らす個数。sampleCoeffsの個数以下にする。
#define SampleNum	4
// 散らす位置
float2 sampleCoeffs[] = {
	float2(1.0,-1.0),
	float2(0.8, 0.3),
	float2(0.2, -0.25),
	float2(0.9, -1.5),
};


//******************設定はここまで

#include "ikCinemorphCommon.fxsub"

