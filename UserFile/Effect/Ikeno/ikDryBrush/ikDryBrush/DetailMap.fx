// 汎用

// ikDryBrush.fx用の詳細復元度マップ。
// 手前ほど画像の詳細を維持する。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
// 0.1～5.0程度。
const float DepthAmplitude = 0.3;

// 深度と関係なく詳細を残す強さ。-0.5～+0.5程度
const float DeltailOffset = 0.0;

// アルファを無視する? 0:無効、1:有効
#define IGNORE_ALPHA	0

// エフェクトの掛かり具合。0:エフェクト無効、1:エフェクト有効。
// 0.0～1.0
#define EFFECT_AMPLITUDE_VALUE		1.0


#include "DetailCommon.fxsub"
