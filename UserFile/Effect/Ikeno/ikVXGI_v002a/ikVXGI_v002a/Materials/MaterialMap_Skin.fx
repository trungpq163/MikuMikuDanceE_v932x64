//-----------------------------------------------------------------------------
// 材質指定。肌やゴムなど用の設定。

//-----------------------------------------------------------------------------
// 基本的な設定

// 金属かどうか。0.05(非金属)、0.4～1.0(金属)。
// F0値を設定する。
const float Metalness = 0.05;

// 表面の滑らかさ(0～1)
#define ENABLE_AUTO_SMOOTHNESS		// スペキュラパワーから自動でスムースネスを決定する。
const float Smoothness = 0.2;		// 自動設定しない場合の値。

// 映り込み強度(0:映り込まない。1:映り込む)
const float Intensity = 1.0;

// 皮下散乱度：肌などの半透明なものに指定。0:不透明。1:半透明。
const float SSSValue = 1.0;


//-----------------------------------------------------------------------------
// 材質マップ

// 材質マップを使用する? 0:使用しない。1:使用する
#define USE_MATERIALMAP	0

// 各マップファイルの指定
//	ファイル指定をコメントアウトすると、基本設定の値が使われる。
//	例：Metalness = 0.0;でメタルネスマップの指定をコメントアウトすると、非金属扱いになる。
//#define METALNESSMAP_FILENAME "Assets/value0.png"
const float MetalnessMapLoopNum = 1;

//#define SMOOTHNESSMAP_FILENAME "Assets/value60.png"
const float SmoothnessMapLoopNum = 1;

//#define INTENSITYMAP_FILENAME "Assets/value100.png"
const float IntensityMapLoopNum = 1;

//#define SSSMAP_FILENAME "Assets/value100.png"
const float SSSMapLoopNum = 1;


//-----------------------------------------------------------------------------
// 法線マップを使用するか?
// #define USE_NORMALMAP

// メイン法線マップ
#define NORMALMAP_MAIN_FILENAME "Assets/dummy_n.bmp" //ファイル名
const float NormalMapMainLoopNum = 1;				//繰り返し回数
const float NormalMapMainHeightScale = 0.0;		//高さ補正 正で高くなる 0で平坦

// サブ法線マップ(微細な凹凸用)
#define NORMALMAP_SUB_FILENAME "Assets/dummy_n.bmp" //ファイル名
const float NormalMapSubLoopNum = 7;			//繰り返し回数
const float NormalMapSubHeightScale = 0.0;		//高さ補正 正で高くなる 0で平坦


//-----------------------------------------------------------------------------
#include "MaterialMap_common.fxsub"
