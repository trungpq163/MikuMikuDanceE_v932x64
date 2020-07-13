// 背景のスカイドーム用

// ikDryBrush.fx用の詳細復元度マップ。
// 手前ほど画像の詳細を維持する。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
const float DepthAmplitude = 0.5;

// 深度と関係なく詳細を残す強さ
const float DeltailOffset = -0.2;

// アルファを無視する? 0:無効、1:有効
#define IGNORE_ALPHA	0

// エフェクトの掛かり具合。0:エフェクト無効、1:エフェクト有効。
#define EFFECT_AMPLITUDE_VALUE		1.0


#include "DetailCommon.fxsub"
