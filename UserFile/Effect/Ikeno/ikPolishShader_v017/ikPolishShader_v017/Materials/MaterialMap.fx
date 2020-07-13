//-----------------------------------------------------------------------------
// 材質設定ファイル

// "//#define" となっている場合、その設定は無効になります。
// 行頭の//がなく、"#define" となっている場合、その設定は有効になります。

//-----------------------------------------------------------------------------
// 基本的な設定

// 金属かどうか。基本は0(非金属)、1(金属)のどちらか。
const float Metalness = 0.0;

// 表面の滑らかさ(0～1)
#define ENABLE_AUTO_SMOOTHNESS		// スペキュラパワーから自動でスムースネスを決定する。
const float Smoothness = 0.2;		// 自動設定しない場合の値。

// 映り込み強度(0:映り込まない。1:映り込む)
const float Intensity = 1.0;

// 非金属の垂直反射率(0.02～0.5くらい)
// 正面から見たときの映り込みの強さ。通常は0.05、宝石で0.1～0.2程度。
// 金属の場合は、色＝リフレクタンスとして扱う。
const float NonmetalF0 = 0.05;

// 金属の色をベース色だけから求める?
// 0: ベース色 * スペキュラ色で決定。(ver0.16以前の方式)
// 1: ベース色のみで決定。
#define USE_ALBEDO_AS_SPECULAR_COLOR	0

// 皮下散乱度：肌、プラスチックなどの半透明なものに指定。0:不透明。1:半透明。
// 金属の場合は無視される。
const float SSSValue = 0.0;

// この値以下の半透明度ならマテリアル的には透明扱いにする。
//#define AlphaThreshold		0.5


// 影描画のタイプ
// 0: 影を薄くする (顔用)
// 1: 通常
#define SHADOW_TYPE		1

//-----------------------------------------------------------------------------
// 材質マップ

// 材質マップを使用するか?
// #define USE_MATERIALMAP

// 1または2ならスムースネスマップをラフネスマップとして扱う
// ※ 直接指定したSmoothnessの値は変更されない。
// 0: スムースネスマップ
// 1: 反転するだけ
// 2: 平方根を取って反転する
#define USE_ROUGHNESS_MAP 0

// 材質マップのr,g,b,aには、Metalness、Smoothness、Intensity、SSSが格納されているものとする。
#define MATERIALMAP_MAIN_FILENAME "skin_material.png"		//ファイル名
const float MaterialMapLoopNum = 1;		// 繰り返し回数

// 個別の材質マップを使用するか?
// USE_MATERIALMAPを指定しなくても有効になる。
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
// 法線マップ

// 法線マップを使用するか?
// #define USE_NORMALMAP
// USE_NCHL_SETTINGSと両方使う場合、サブ法線のみが有効になります。

// メイン法線マップ
#define NORMALMAP_MAIN_FILENAME "dummy_n.bmp" //ファイル名
const float NormalMapMainLoopNum = 1;				//繰り返し回数
const float NormalMapMainHeightScale = 0.0;		//高さ補正 正で高くなる 0で平坦

// サブ法線マップ(微細な凹凸用)
#define NORMALMAP_SUB_FILENAME "dummy_n.bmp" //ファイル名
const float NormalMapSubLoopNum = 1;			//繰り返し回数
const float NormalMapSubHeightScale = 0.0;		//高さ補正 正で高くなる 0で平坦


//-----------------------------------------------------------------------------

// AutoReflectionの材質設定を利用する
// #define USE_AUTOREFLECTION_SETTINGS

// NCHLの材質設定を利用する
// #define USE_NCHL_SETTINGS
//#define NCHL_ALPHA_AS_SMOOTHNESS		// スペキュラ値をスムースネスとして使う。
//#define NCHL_ALPHA_AS_INTENSITY		// スペキュラ値をスペキュラ強度として使う。
// ↑両方同時に指定可能です。


//-----------------------------------------------------------------------------
#include "MaterialMap_common.fxsub"
