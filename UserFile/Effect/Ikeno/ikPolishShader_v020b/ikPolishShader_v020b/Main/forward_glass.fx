//-----------------------------------------------------------------------------
// ガラス用
// ※ このエフェクトを割り当てる材質はColorMapRT, SSAOMaprRTから除外してください。


// 金属かどうか。0:非金属、1:金属。大きい値ほど光を反射する。
// ガラス、宝石は0.1～0.2程度。
// ※ スペキュラの強さと屈折率に影響する
const float Metalness = 0.1;

// 表面の滑らかさ(0～1)
#define ENABLE_AUTO_SMOOTHNESS	0	// スペキュラパワーから自動でスムースネスを決定する。
const float Smoothness = 1.0;		// 自動設定しない場合の値。

// 強制的に半透明度を調整する。
const float ForceAlphaScale = 0.1;


// 屈折表現を無効にするか?
// ikPolishShader.fxsub 内の ENABLE_REFRACTION が 1 かつ、
// DISABLE_REFRACTION が 0 のとき屈折が有効になる。
#define DISABLE_REFRACTION		0

// 屈折で裏面を考慮するか? 厚みのある物体用
#define BACKFACE_AWARE			0

// 背景の色がガラスに吸収される割合。0.0～1.0
#define ABSORPTION_RATE			1.0


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
