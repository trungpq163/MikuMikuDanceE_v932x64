///////////////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////////////

#include "../ikPolishShader.fxsub"

// 自己発光色の強さ。(0.0～1.0)
#define EmissiveIntensity	1.0

// 環境光の強さ
#define AmbientIntensity	0.2

// 反射強度
#define GI_SCALE			0.5

// 色の強調度合(1～4)
#define COLOR_BOOST			2


//------------------------------------
// AutoLuminous用の設定
// ALを使用する
#define ENABLE_AL

//テクスチャ高輝度識別フラグ
// #define TEXTURE_SELECTLIGHT

// ALの強度をどれだけ上げるか
#define AL_Power	1.0

//閾値
float LightThreshold = 0.9;
//------------------------------------

#include "SSDO_common.fxsub"

///////////////////////////////////////////////////////////////////////////////
