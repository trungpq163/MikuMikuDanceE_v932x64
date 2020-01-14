// 1モデルの材質設定を1ファイルで行う。

//-----------------------------------------------------------------------------
// 基本的な設定：材質マップで指定しない場合のデフォルト値

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

// シャドウマップ無効なモデルを使う?
// シェーダーのコンパイル時間を短縮するため、影のあるモデルか影のないモデルの
// どちらか用のシェーダーだけを生成するようにしている。
// デフォルトでは影付きモデル用のみ生成している。
// #define DISABLE_SHADOW

//-----------------------------------------------------------------------------
// AutoReflectionの材質設定を利用する
// #define USE_AUTOREFLECTION_SETTINGS

// NCHLの材質設定を利用する
// USE_NCHL_SETTINGS を有効にすると、メイン法線マップはNCHLのものが優先される。
// #define USE_NCHL_SETTINGS
//#define NCHL_ALPHA_AS_SMOOTHNESS		// スペキュラ値をスムースネスとして使う。
//#define NCHL_ALPHA_AS_INTENSITY		// スペキュラ値をスペキュラ強度として使う。
// ↑両方同時に指定可能です。


//-----------------------------------------------------------------------------

#include "MaterialMultiMap_header.fxsub"

// デフォルト値
#define DefaultLoopNum			1		// 繰り返し回数
#define DefaultHeightScale		1.0		// 高さ補正。正で高くなる 0で平坦

/* 法線マップの指定：
	SET_NORMALMAP(テクスチャ番号、テクスチャ名、繰り返し回数、高さ補正) で登録する。

	同じ法線マップで別パラメータにする場合は、
	SET_NORMALMAP_COPY(テクスチャ番号, 参照するテクスチャ番号, 繰り返し回数, 高さ補正) を使う。

	※ 法線マップ同士でテクスチャ番号が被ってはいけない。
*/

SET_NORMALMAP(0, "dummy_n.bmp",		1.0, DefaultHeightScale)
SET_NORMALMAP(1, "dummy_n.bmp",		1.0, DefaultHeightScale)
SET_NORMALMAP(2, "dummy_n.bmp",		1.0, DefaultHeightScale)
SET_NORMALMAP(3, "dummy_n.bmp",		1.0, DefaultHeightScale)
SET_NORMALMAP(4, "dummy_n.bmp",		2.0, 0.5)


/* 材質マップの指定：
	SET_MATERIALMAP(テクスチャ番号、テクスチャ名、繰り返し回数) で登録する。
	SET_MATERIALMAP_COPY(テクスチャ番号, 参照するテクスチャ番号, 繰り返し回数) も使用可能。
	※ 材質マップ同士でテクスチャ番号が被ってはいけない。
*/
SET_MATERIALMAP(0, "value50.png",		2.0)


//-----------------------------------------------------------------------------
/* サブセット番号毎の設定を行う：

	MATERIAL + 法線マップの数 + 材質の指定方法 (UID, サブセット番号, [法線のパラメータ], [材質のパラメータ]) 

		法線の数は 0、1、2 のいずれか。
		材質の指定方法は
			0：デフォルト値
			1：材質マップで指定
			V：直接数値で指定

		UIDは内部でそれぞれを区別するための番号。
		UID同士が被ってはいけない。

		サブセット番号はモデルの材質番号を指定する。
		二重引用符で囲うこと。
		"1-4,6"のような指定も可能。この場合、1,2,3,4と6が対象となる。

	凡例：
		MATERIAL00(UID, サブセット番号)
			法線マップを指定せず、材質はデフォルトを使用。
			これを使用するより、デフォルトに任せたほうがいい。

		MATERIAL10(UID, サブセット番号, 法線番号)
			法線を1つ指定、材質はデフォルトを使用。

		MATERIAL1V(UID, サブセット番号, 法線番号、メタルネス、スムースネス、インテンシティ、SSS)
			法線を1つ指定、材質は指定した値を使用。
			ただし、スムースネスは ENABLE_AUTO_SMOOTHNESS の影響を受ける。

		MATERIAL21(UID, サブセット番号, メイン法線番号, サブ法線番号, 材質マップ番号)
			法線を2つ指定、材質を材質マップで指定。

	※ USE_NCHL_SETTINGS利用時、メイン法線が無視されるため、
		MATERIAL1xは使用する意味がない。
		MATERIAL0xを使うか、MATERIAL2xでサブ法線側に追加の法線を設定する。
		このとき、MATERIAL2xのメイン側にはダミーを指定する。
*/
#include "MaterialMultiMap_body.fxsub"

BEGIN_MATERIAL
	MATERIAL0V(0, "0,13",  0, 0.4, 1.0, 1.0)
	MATERIAL0V(1, "11,18,23-26", 1, 0.4, 1.0, 0.0)
END_MATERIAL

