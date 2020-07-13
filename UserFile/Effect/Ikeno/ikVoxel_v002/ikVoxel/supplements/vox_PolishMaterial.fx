//-----------------------------------------------------------------------------
// パラメータ宣言

//-----------------------------------------------------------------------------
// 基本的な設定

// 金属かどうか。基本は0(非金属)、1(金属)のどちらか。
const float Metalness = 0.0;

// 表面の滑らかさ(0～1)
#define ENABLE_AUTO_SMOOTHNESS		// スペキュラパワーから自動でスムースネスを決定する。
const float Smoothness = 0.2;		// 自動設定しない場合の値。

// 映り込み強度(0:映り込まない。1:映り込む。1以上の値も設定可能)
const float Intensity = 1.0;

// 非金属の垂直反射率
// 金属の場合は、色＝リフレクタンスとして扱う。
const float NonmetalF0 = 0.05;

// 皮下散乱度：肌などの半透明なものに指定。0:不透明。1:半透明。
// 金属の場合は無視される。
const float SSSValue = 0.5;

//-----------------------------------------------------------------------------
// AutoReflectionの材質設定を利用する
// #define USE_AUTOREFLECTION_SETTINGS

// NCHLの材質設定を利用する
// #define USE_NCHL_SETTINGS
//#define NCHL_ALPHA_AS_SMOOTHNESS		// スペキュラ値をスムースネスとして使う。
//#define NCHL_ALPHA_AS_INTENSITY		// スペキュラ値をスペキュラ強度として使う。
// ↑両方同時に指定可能です。

//-----------------------------------------------------------------------------
// 材質マップを使用するか?
// #define USE_MATERIALMAP

// 材質マップのr,g,b,aには、Metalness、Smoothness、Intensity、SSSが格納されているものとする。
#define MATERIALMAP_MAIN_FILENAME "skin_material.png"		//ファイル名
const float MaterialMapLoopNum = 1;		// 繰り返し回数


// 個別の材質マップを使用するか? USE_MATERIALMAPを指定しなくても有効になる。
// #define USE_SEPARATE_MAP

// 各マップファイルの指定
//	ファイル指定をコメントアウトすると、基本設定の値が使われる。
//	例：Metalness = 0.0;でメタルネスマップの指定をコメントアウトすると、非金属扱いになる。
#define METALNESSMAP_FILENAME "value0.png"
const float MetalnessMapLoopNum = 1;

#define SMOOTHNESSMAP_FILENAME "value60.png"
const float SmoothnessMapLoopNum = 1;

#define INTENSITYMAP_FILENAME "value100.png"
const float IntensityMapLoopNum = 1;

#define SSSMAP_FILENAME "value100.png"
const float SSSMapLoopNum = 1;

//-----------------------------------------------------------------------------
// ※ Voxel化では法線マップを使用できない。


//----------------------------------------------------------------------------
// voxel用パラメータ宣言

// ブロックのサイズ。0.1～1.0程度。
float VoxelGridSize = 0.5;

// テクスチャの解像度を下げる。8～32程度。
// 8でテクスチャを8分割する。小さいほど粗くなる。
float VoxelTextureGridSize = 16;

// 無視する透明度の閾値
// float VoxelAlphaThreshold = 0.05;

// ブロックを描画するとき半透明を考慮する?
// 0:不透明で描画、1:半透明度を利用する。
// ※ ikPolishShaderでは指定できない
// #define VOXEL_ENBALE_ALPHA_BLOCK	0

// ブロックのフチを丸めるか? 0.0～0.1程度 大きいほどエッジ部分が強調される
// ※ 0にしても計算誤差でエッジが見える場合があります。
float VoxelBevelOffset = 0.05;

// チェック回数。4～16程度。多いほど正確になるが重くなる。
#define VOXEL_ITERATION_NUMBER	6

// 外部からブロックサイズをコントロールするアクセサリ名
#define VOXEL_CONTROLLER_NAME	"ikiVoxelSize.x"

// 付き抜けチェックをする? 0:しない、1:チェックする。
// 1にすることで床が抜けるのを回避できる。代わりに見た目がおかしくなる。
#define VOXEL_ENABLE_FALLOFF		0

//-----------------------------------------------------------------------------
#include "vox_PolishMaterial_common.fxsub"
