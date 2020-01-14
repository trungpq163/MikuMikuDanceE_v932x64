///////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// パネルの中心となるアクセサリ名
// モデル自身の場合は(self)を指定する。アクセサリなどの場合は、.xなど拡張子まで指定する。
#define	PanelObjectName		"(self)"
// パネルの中心となるボーン名
// ボーンが不要な場合は、#defineの前に//を入れてコメントアウトする。
//#define	PanelBoneName		"センター"
#define	PanelBoneName		"上半身"

// ダミー親
// モデルの挙動とは別にパネルを動かしたい場合用。
// 使用しない場合は、ParentObjectName の行頭に//を入れる。
#define	ParentObjectName		"dummyParent.pmx"
#define	ParentBoneName			"ボーン08"


// パネルの余白部分の色
float3 PanelColor = float3(1.0,1.0,1.0);
float3 PanelShadowColor = float3(1.0,1.0,1.0) * 0.8; // 影の濃さ
float3 PanelAmbient = float3(1.0,1.0,1.0) * 0.4; // ライトが(0,0,0)のときの明るさ

// パネル全体のスペキュラ
float PanelSpecularPower = 32.0;
float3 PanelSpecularColor = float3(1.0,1.0,1.0);

// パネルの余白。1.0 = 1MMD ≒ 10cm
float	PanelMargin = 0.4;
// パネルのエッジサイズ。
float	PanelThickness = 0.03;
// パネルの深度をいじる量。
float	PanelDepthOffset = 0.5;

// 厚みを潰す率。
// 前後関係が破たんしてチラつく場合は、大きめの値にする。大きい値ほど厚みが見える
#define	SqueezeScale	0.1

// パネルの回転を倍にする。0: 1倍。1: 2倍
#define ENABLE_TWICE_ROTATION	0

// パネルの縁を描画する。0:描画しない。1:描画する。
#define ENABLE_DRAW_EDGE	1

// パネル内のモデルも陰影計算を行うか。0:陰影計算をしない。1:する。
// パネルとモデル両方に落ち影が出たりなど、立体感があると、おかしく見えることがある。
#define ENABLE_INNER_LIGHTING	1
// スフィアマップの計算も行う? 0:行わない。1:行う。
// ENABLE_INNER_LIGHTING 0の場合、常にスフィアマップを計算しない。
#define ENABLE_SPHERE_MAP		0
// モデル内のシャドウマップを有効にする。
#define ENABLE_SHADOW_MAP		0


////////////////////////////////////////////////////////////////////////////////////////////////

#include "ikPaper.fxsub"

