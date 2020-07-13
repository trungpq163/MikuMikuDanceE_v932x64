//-----------------------------------------------------------------------------
// ポイントライト用の設定
//-----------------------------------------------------------------------------

// 影を描画する。0:描画しない。1:描画する
#define EnableShadowMap		0
// 影のブラー。0でブラーなし
#define ShadowSampleCount	2	// 0-4
// 影用バッファのサイズ(512,1024,2048,4096)
#define SHADOW_BUFSIZE	2048


// フォグの影響を受ける。
// ikPolishShader.fxsubで、FOG_TYPEが2の場合のみ有効になる。
#define VOLUMETRIC_FOG		1


// ライトの届く範囲 (1MMD単位は0.1m)
#define LightDistanceMin	(5.0)
#define LightDistanceMax	(100.0)

//-----------------------------------------------------------------------------
#include "./Sources/Point_Light.fxsub"
