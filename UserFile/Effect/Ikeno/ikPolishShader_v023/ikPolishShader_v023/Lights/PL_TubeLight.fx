//-----------------------------------------------------------------------------
// チューブライト用の設定
//-----------------------------------------------------------------------------

// 影を描画する。0:描画しない。1:描画する
#define EnableShadowMap		0
// 影のブラー。0でブラーなし
#define ShadowSampleCount	2	// 0-4
// 影用バッファのサイズ(512,1024,2048,4096)
#define SHADOW_BUFSIZE	2048

// ライトの届く範囲 (1MMD単位は0.1m)
#define LightDistanceMin	(5.0)
#define LightDistanceMax	(100.0)

// ライトのサイズ
// ※数値は.pmxのモーフの"ライト幅+/高+"と連動させる必要がある
#define LightWidthMin	( 0.1)	// デフォルトのサイズ
#define LightHeightMin	( 1.0)	// デフォルトのサイズ
#define LightWidthMax	( 0.1)	// モーフのオフセットサイズ
#define LightHeightMax	( 9.0)	// モーフのオフセットサイズ

//-----------------------------------------------------------------------------
#include "./Sources/Tube_Light.fxsub"
