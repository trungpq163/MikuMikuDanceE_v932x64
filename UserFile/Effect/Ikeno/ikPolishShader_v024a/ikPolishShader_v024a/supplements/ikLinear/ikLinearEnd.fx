//=============================================================================
//
// 線形で画像処理するためのエフェクト
//
// ikLinearBegin/ikLinearEndのペアで使う。
// ※ ikPolishと使う場合は、ikLinearBeginは不要。
//
//=============================================================================

// テスト用の情報を表示を有効にする。
#define ENBALE_DEBUG_VIEW	0


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

// 変化速度
// 人間の目は明るくなる方と暗くなる方で順応速度が違う。
#define SPEED_UP		3.0
#define SPEED_DOWN		1.0

// 自動露出補正
#define AUTO_EXPOSURE	0	// 0:無効、1:有効

// トーンマップ方式
#define TONEMAP_MODE	3
/*
0: Linear (トーンマップなし)
1: Reinhard
2: ACES
3: Uncharted2
*/

// 輝度ベースのトーンマップ
// 輝度ベースのほうが彩度が落ちにくいのでMMD向き?
// 0: rgbを独立して計算する
#define LUMABASE_TONEMAP	1

// ブルームを有効にする
#define ENABLE_BLOOM		1
// ブルームの強度
#define	BloomIntensity		0.5 // 0.0-5.0
// ブルームさせる明るさのしきい値
#define	BloomThreshold		2.0	// 1.0-2.0 程度


// アンチエイリアス。
#define ENABLE_AA		1
// アンチエイリアスの強度
#define AA_Intensity	0.5		// 0.0 - 1.0



// 最後にディザを足し込む。有効にするとバンディングが改善される。
#define ENABLE_DITHER	1	// 0:無効、1:有効

// エディタ時間に同期させるか?
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
//float KeyValue = 0.5;
float KeyValue = 0.9;

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

#include "ikLinearEnd_body.fxsub"

