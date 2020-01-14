////////////////////////////////////////////////////////////////////////////////////////////////
//  EnvMapRT用シェーダー：スカイドームなど陰影計算の影響を受けないもの用

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define IGNORE_SPHERE

// AutoLuminus対応
#define ENABLE_AL
// テクスチャで指定する
// #define TEXTURE_SELECTLIGHT
// ALの強度をどれだけ上げるか
#define AL_Power	4.0
//閾値
float LightThreshold = 0.9;

// PMXEditorの環境色をライトの強さの影響を受けるようにする。
//#define EMMISIVE_AS_AMBIENT	// 自己発光色をアンビエント色として扱う
//#define IGNORE_EMISSIVE			// 自己発光色の設定を無効にする。

#include "TEnvMap_common.fxsub"


