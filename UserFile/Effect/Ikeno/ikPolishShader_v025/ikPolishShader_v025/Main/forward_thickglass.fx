//-----------------------------------------------------------------------------
// ガラス用
// ※ このエフェクトを割り当てる材質はColorMapRT, SSAOMaprRTから除外してください。

// 金属かどうか。0:非金属、1:金属。大きい値ほど光を反射する。
// ガラス、宝石は0.1～0.2程度。
// ※ スペキュラの強さと屈折率に影響する
const float Metalness = 0.1;

// Smoothnessの指定方法：
// 0: モデルのスペキュラパワーから自動で決定する。
// 1: スムースネスを使用。
// 2: ラフネスを使用。
#define SMOOTHNESS_TYPE			0
#define	SMOOTHNESS_VALUE		1.0

#define	SMOOTHNESS_MAP_ENABLE	0	// 1:テクスチャを使う、0:使わない
#define SMOOTHNESS_MAP_FILE		"textures/white.png"
#define SMOOTHNESS_MAP_LOOPNUM	1.0
#define SMOOTHNESS_MAP_SCALE	1.0
#define SMOOTHNESS_MAP_OFFSET	0.0

#define NORMALMAP_ENABLE		0
#define NORMALMAP_MAIN_FILENAME "textures/dummy_n.bmp"
#define NORMALMAP_MAIN_LOOPNUM	1.0
#define NORMALMAP_MAIN_HEIGHT	1.0

#define NORMALMAP_SUB_ENABLE	0
#define NORMALMAP_SUB_FILENAME "textures/dummy_n.bmp"
#define NORMALMAP_SUB_LOOPNUM	1.0
#define NORMALMAP_SUB_HEIGHT	1.0

// 方向の反転
// 0: 反転なし
// 1: xを反転
// 2: yを反転
// 3: x,yを反転
#define	NORMALMAP_FLIP		0

#define PARALLAX_ENABLE		0
#define PARALLAX_FILENAME	"textures/white.png"
#define PARALLAX_LOOPNUM	1.0		// テクスチャの繰り返し回数

// 深度の調整量(mmd単位)
// 深度マップでの0-1での高さが、mmdでどれくらいの高さを表すか。
#define PARALLAX_HEIGHT		1.0

// テクスチャ上での参照距離
// (参照ピクセル/テクスチャサイズ)
#define PARALLAX_LENGTH		(32.0/512.0)

#define PARALLAX_ITERATION	8	// 検索回数(1～16)


// 強制的に不透明度を調整する。0.5で50%の、1.0でデフォルトの不透明度。
const float ForceAlphaScale = 1.0;


// 屈折表現を無効にするか?
// ikPolishShader.fxsub 内の ENABLE_REFRACTION が 1 かつ、
// DISABLE_REFRACTION が 0 のとき屈折が有効になる。
#define DISABLE_REFRACTION		0

// 背景の色がガラスに吸収される割合。0.0～1.0
#define SURFACE_ABSORPTION_RATE			0.5 // 一律で吸収
#define BODY_ABSORPTION_RATE			0.1 // 厚みで変わる

// 厚みの計算方法
#define THICKNESS_TYPE			1
// 0: 固定値
// 1: 裏面ポリゴンとの差
// 2: 深度差 (水面に使用する)


// MMD標準のシャドウマップで陰影計算を行うか?
#define USE_MMD_SHADOW	0


//----------------------------------------------------------
// スペキュラ関連

// スフィアマップ無効
#define IGNORE_SPHERE	1

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.1;

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
// 草などアルファ抜きしている場合はエッジに強いハイライトが出ることがある。
#define ENABLE_SPECULAR_ALPHA	1


//----------------------------------------------------------
// その他

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)


// これよりも不透明度が低いなら除外する
const float CutoutThreshold = 1.0 / 255.0;

//----------------------------------------------------------
// 共通処理の読み込み
#include "Sources/forward_common.fxsub"
