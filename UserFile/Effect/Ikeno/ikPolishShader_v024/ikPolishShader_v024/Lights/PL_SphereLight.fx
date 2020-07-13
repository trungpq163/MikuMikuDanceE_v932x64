//-----------------------------------------------------------------------------
// スフィアライト用の設定
//-----------------------------------------------------------------------------

// 影を描画する。0:描画しない。1:描画する
#define EnableShadowMap		0
// 影のブラー。0でブラーなし
#define ShadowSampleCount	2	// 0-4
// 影用バッファのサイズ(512,1024,2048,4096)
#define SHADOW_BUFSIZE	2048


// テクスチャを使用する。使用しない場合は0
#define EnableLighTexture	1
// テクスチャ参照のブラー
#define TextureSampleCount	1	// 0-3
// 仮のテクスチャサイズ
#define	TextureSize		512

// 動画をライトテクスチャとして使用する。
// 要：SaveScreen.x
#define USE_SCREEN_BMP		0


// フォグの影響を受ける。
// ikPolishShader.fxsubで、FOG_TYPEが2の場合のみ有効になる。
#define VOLUMETRIC_FOG		1


// ライトの半径サイズ
// 数値は.pmxのモーフの"ライトサイズ+"と連動させる必要がある
#define LightRadiusMin	( 1.0)	// デフォルトのサイズ
#define LightRadiusMax	(19.0)	// モーフのオフセットサイズ

// ライトの届く範囲 (1MMD単位は0.1m)
#define LightDistanceMin	(5.0)
#define LightDistanceMax	(100.0)

//-----------------------------------------------------------------------------
#include "./Sources/Sphere_Light.fxsub"
