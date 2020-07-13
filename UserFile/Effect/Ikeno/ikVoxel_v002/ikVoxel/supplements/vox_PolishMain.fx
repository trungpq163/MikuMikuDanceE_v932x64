////////////////////////////////////////////////////////////////////////////////////////////////
// 汎用のプリセット。通常は全部これを設定するだけでいい。

// パラメータ宣言

#define ToonColor_Scale			1.0			// トゥーン色を強調する度合い。(1.0～5.0程度)

// 第二スペキュラ
// 車のコート層とボディ本体、皮膚と汗などのように複数のハイライトがある場合用
const float SecondSpecularSmooth =	 0.4;		// 1に近づくほどスペキュラが鋭くなる。(0～1)
const float SecondSpecularIntensity = 0.0;		// スペキュラの強度。0でオフ。1で等倍。(0～)

// PMXEditorの環境色をライトの強さの影響を受けるようにする。
#define EMMISIVE_AS_AMBIENT
// #define IGNORE_EMISSIVE			// 環境色を無効にする。

// AutoLuminous対策。明るい部分をカットする。
// #define DISABLE_HDR

// スフィアマップ無効
// スフィアマップによる偽ハイライトが不自然に見える場合に無効化する。
// NCHL用のモデルを使う場合も、スフィアマップを無効にする。
//#define IGNORE_SPHERE

//----------------------------------------------------------
// SSS用の設定

// 逆光からの光で明るくする(カーテンや葉っぱなどに使う)
//#define ENABLE_BACKLIGHT

// 材質設定のSSSにより、にじんだ光につく色
#define ScatterColor	MaterialToon
//#define ScatterColor	float3(1.0, 0.6, 0.3)

// SSS効果を有効にするか。
// 材質設定のSSSに追加してさらに効果を加えるかどうか。
//#define ENABLE_SSS

// 表層：表面の色
const float3 TopCol = float3(1.0,1.0,1.0);	// 色
const float TopScale = 2.0;					// 視線との角度差に反応する度合い。
const float TopBias = 0.01;					// 正面でどの程度影響を与えるか
const float TopIntensity = 0.2;				// 全体影響度
// 深層：内部の色
const float3 BottomCol = float3(1.0, 0.0, 0.0);	// 色
const float BottomScale = 0.4;			// 視線との角度差に反応する度合い。
const float BottomBias = 0.2;			// 正面でどの程度影響を与えるか
const float BottomIntensity = 0.2;			// 全体影響度


//----------------------------------------------------------------------------
// voxel用パラメータ宣言

// ブロックのサイズ。0.1～1.0程度。
float VoxelGridSize = 0.5;

// テクスチャの解像度を下げる。8～32程度。
// 8でテクスチャを8分割する。小さいほど粗くなる。
float VoxelTextureGridSize = 16;

// 無視する透明度の閾値
float VoxelAlphaThreshold = 0.05;

// ブロックを描画するとき半透明を考慮する?
// 0:不透明で描画、1:半透明度を利用する。
// ※ ikPolishShaderでは指定できない
#define VOXEL_ENBALE_ALPHA_BLOCK	1

// ブロックのフチを丸めるか? 0.0～0.1程度 大きいほどエッジ部分が強調される
// ※ 0にしても計算誤差でエッジが見える場合があります。
float VoxelBevelOffset = 0.05;

// チェック回数。4～16程度。多いほど正確になるが重くなる。
#define VOXEL_ITERATION_NUMBER	6

// ブロック表面にテクスチャを追加する場合のテクスチャ名。
// コメントアウト(行頭に"//"をつける)すると無効になる。
#define VOXEL_TEXTURE	"../grid.png"

// 外部からブロックサイズをコントロールするアクセサリ名
#define VOXEL_CONTROLLER_NAME	"ikiVoxelSize.x"

// 付き抜けチェックをする? 0:しない、1:チェックする。
// 1にすることで床が抜けるのを回避できる。代わりに見た目がおかしくなる。
#define VOXEL_ENABLE_FALLOFF		0

////////////////////////////////////////////////////////////////////////////////////////////////

#include "vox_PolishMain_common.fxsub"
