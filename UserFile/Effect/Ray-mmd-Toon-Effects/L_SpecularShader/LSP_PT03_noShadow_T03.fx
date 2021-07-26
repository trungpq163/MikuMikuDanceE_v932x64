/////////////////////////////
// L_SpecularShader ver1.00
// 作成: 下っ腹P
/////////////////////////////

// パラメータ宣言
/////////////////////////////
float3 SpColor = {0.3,0.3,0.3};  // 光沢の色。
float3 ShadowColor = {0,0,0}; // 光沢以外の色。

float SpecularPow = 15; // 光沢の大きさ

bool ToonSpecular = 1; // 1にするとToon調の光沢になります。

bool ShadowON = 0; // 1にすると影の範囲で光沢が消えます

/////////////////////////////
//SSAOパラメーター
float SSAOPower = 1.0; // SSAOの強度。０で無し

/////////////////////////////
// ●スペキュラーマップ(スペキュラーの強度をテクスチャで調整。フレネル反射にも影響が出ます)
// #define USE_HILIGHT_MAP // 使う? (使わない場合、左に//を追加してコメントアウト)
#define HILIGHT_PATH "tex/specular_test.png"

/////////////////////////////
// ●法線マップ(法線の方向を変えて凹凸感、重い)
// #define USE_NORMAL_MAP // 使う? (使わない場合、左に//を追加してコメントアウト)
#define NORMAL_MAP_PATH "tex/normal_test.png"


#include "_LSPCommon.fxsub"
