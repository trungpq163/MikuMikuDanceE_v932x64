// 顔用。詳細をかなり残す

// ikDryBrush.fx用の詳細復元度マップ。
// 手前ほど画像の詳細を維持する。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
const float DepthAmplitude = 0.3;

// 詳細を残す強さ
const float DeltailOffset = 0.5;

// エフェクトの掛かり具合。0:エフェクト無効、1:エフェクト有効。
#define EFFECT_AMPLITUDE_VALUE		0.3


#include "DetailCommon.fxsub"
