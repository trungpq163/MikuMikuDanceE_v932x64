//-----------------------------------------------------------------------------
// パネルライト用の設定
//-----------------------------------------------------------------------------

// 影を描画する。0:描画しない。1:描画する
#define EnableShadowMap		0
// 影のブラー。0でブラーなし
#define ShadowSampleCount	2	// 0-4程度
// ソフトシャドウを有効にする。0:無効、1:有効
#define EnableSoftShadow	0
// 影用バッファのサイズ(512,1024,2048,4096)
#define SHADOW_BUFSIZE	1024


// テクスチャを使用する。使用しない場合は0
#define EnableLighTexture	1
// 仮のテクスチャサイズ
#define	TextureSize		256

// 動画をライトテクスチャとして使用する。
// 要：SaveScreen.x
#define USE_SCREEN_BMP		0


// ライトの届く範囲 (1MMD単位は0.1m)
#define LightDistanceMin	(5.0)
#define LightDistanceMax	(100.0)

// ライトのサイズ
// ※数値は.pmxのモーフの"ライト幅+/高+"と連動させる必要がある
#define LightWidthMin	( 1.0)	// デフォルトのサイズ
#define LightHeightMin	( 1.0)	// デフォルトのサイズ
#define LightWidthMax	(19.0)	// モーフのオフセットサイズ
#define LightHeightMax	(19.0)	// モーフのオフセットサイズ

//-----------------------------------------------------------------------------
#include "./Sources/Panel_Light.fxsub"
