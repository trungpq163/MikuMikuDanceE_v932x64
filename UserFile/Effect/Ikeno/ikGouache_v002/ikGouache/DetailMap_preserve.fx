// ikGouache.fx用の詳細復元度マップ。
// デフォルトより詳細を維持する。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
// 0.01～0.1程度
const float DepthAmplitude = 0.001;

// 詳細を残す強さ
const float DeltailAmplitude = 5.0;

// 深度に関わらず、一定の値を維持する
//#define CONSTANT_DETAIL_VALUE		0.0

#include "DetailCommon.fxsub"
