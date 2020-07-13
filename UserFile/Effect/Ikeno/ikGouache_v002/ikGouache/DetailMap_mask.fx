// ikGouache.fx用の詳細復元度マップ。
// つねに詳細を復元しない。

// 深度に応じた詳細復元係数。大きい値ほど奥の詳細がボカされる。
// 0.01～0.1程度
const float DepthAmplitude = 0.1;

// 詳細を残す強さ
const float DeltailAmplitude = 1.0;


// 深度に関わらず、一定の値を維持する
#define CONSTANT_DETAIL_VALUE		0.0

#include "DetailCommon.fxsub"
