
// 追従するモデルとボーン名
#define	TARGET_MODEL_NAME	"(self)"
//#define	TARGET_MODEL_NAME	"初音ミク.pmd"
//#define	TARGET_BONE_NAME	"頭"


// ドットと線の色
#define DOT_COLOR	float3(0.2, 0.2, 0.8)
// ドットパターン用テクスチャ
#define DOT_TEXTURE_NAME	"dot.png"

// 何フレームおきにドットを表示するか?
// 1だと詰まりすぎて分かりにくい
#define DOT_STEP	4
// ドットを何個まで表示するか?
// ※ DOT_STEP * DOT_DRAW_NUM が 512を超えないこと。
#define DOT_DRAW_NUM	64

// ドットの表示サイズ(1～16程度)
#define	DOT_SIZE		6
// 現フレームのドットのサイズ(他のドットより少し大きく表示する)
#define	DOT_SIZE_CURRENT	10

// 線の表示サイズ(1～4程度)
#define	LINE_WIDTH		2


// 記録用バッファのサイズ
// 256x64で1.6万フレーム分保存できる。それ以上保存したい場合は256x256などにする。
#define TEX_WIDTH	256
#define TEX_HEIGHT	64

// fps
#define FRAME_PER_SECOND	30

// カメラに映る位置を記録するか(1)、カメラに依存しない位置を記録するか(0)
// 0にした場合、現在のカメラから見た、過去/未来のターゲット位置を表示する。
// 1にした場合、記録時点での画面内の位置を記録して表示する。
#define SAVE_PROJECTION_POSITION	1

////////////////////////////////////////////////////////////////////////////////////////////////

#include "arc_common.fxsub"
