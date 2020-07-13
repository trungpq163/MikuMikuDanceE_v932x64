////////////////////////////////////////////////////////////////////////////////////////////////
//
//  EnvMapRT用シェーダー：スカイドームなど自分で発光しているもの用
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// スフィアマップ無効
#define IGNORE_SPHERE

// AutoLuminus対応
// #define ENABLE_AL

// テクスチャで指定する
// #define TEXTURE_SELECTLIGHT

// ALの強度をどれだけ上げるか
#define AL_Power	1.0

//閾値
float LightThreshold = 0.9;

// PMXEditorの環境色をライトの強さの影響を受けるようにする。
//#define EMMISIVE_AS_AMBIENT	// 自己発光色をアンビエント色として扱う
//#define IGNORE_EMISSIVE			// 自己発光色の設定を無効にする。

#include "TEnvMap_common.fxsub"


