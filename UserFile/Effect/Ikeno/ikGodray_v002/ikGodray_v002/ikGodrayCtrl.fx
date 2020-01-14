//-----------------------------------------------------------------------------
// レンズゴースト

// ライト自体の色：
#define LIGHT_COLOR		float3(1.0, 0.4, 0.1)
// 光の筋の色：
#define RAY_COLOR		float3(1.0, 0.8, 0.4)
// ※ MMDのライト色の色と乗算されます。

// 簡易レンズゴーストを描画するか?
#define ENBLE_LENS_GHOST	1

// 光の長さ。Siでも調整可能。大きいほど短くなる。
#define LIGHT_LENGTH	6

// 光の参照範囲。(0.1～1.0。小さいほど光源周辺だけを見る)
#define LIGHT_SIZE		0.5


// ライト位置の指定方法：
// 0: MMDのライト位置を使う。
// 1: コントローラで指定した"方向"にする。原点基準。
// 2: コントローラで指定した"位置"にする
#define USE_CTRL_POSITION	1
// コントローラの指定：
// 対象モデル名。(self)だとアクセサリ自身
#define CTRL_NAME	"(self)"
//#define CTRL_NAME	"xxx.pmx"
// 対象ボーン名。.pmxを指定先にする場合に設定する。
// アクセサリの場合は、行頭に//を入れる。
//#define CTRL_BONE_NAME	"センター"


// 参照回数
#define NUM_SAMPLES		16

// 前フレとの合成を行うか? チラつきを若干抑える
#define ENABLE_TEMPORAL_BLUR	1

// バッファサイズ。512 or 1024あたり。
#define BUFFER_SIZE		1024

//-----------------------------------------------------------------------------
#include "ikGodray_common.fxsub"
