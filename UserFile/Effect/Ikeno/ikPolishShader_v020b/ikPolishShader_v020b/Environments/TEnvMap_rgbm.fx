////////////////////////////////////////////////////////////////////////////////////////////////
//
//  EnvMapRT用シェーダー：raymmdのskyspec_hdr.ddsを環境マップとして使う場合用の設定
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

// ガンマ補正済のテクスチャか?
#define IS_LINEAR_TEXTURE

// テクスチャをRGBMとして扱う?
#define USE_TEXTURE_AS_RGBM
// RGBMの係数。UE4系なら6、Unity系なら8を指定
#define RGBM_SCALE_FACTOR	6

#include "TEnvMap_common.fxsub"

