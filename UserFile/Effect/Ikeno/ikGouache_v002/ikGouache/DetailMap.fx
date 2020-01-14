// ikGouache.fx用の詳細復元度マップ。
// 手前ほど画像の詳細を維持する。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
// 0.01～0.1程度
const float DepthAmplitude = 0.05;

// 詳細を残す強さ
const float DeltailAmplitude = 2.0;

// 深度に関わらず、一定の値を維持する。0.0～1.0:値が大きいほど詳細を維持する。
//#define CONSTANT_DETAIL_VALUE		0.0


// エフェクトの掛かり具合。0:エフェクト無効、1:エフェクト有効。
#define EFFECT_AMPLITUDE_VALUE		1.0


#include "DetailCommon.fxsub"
