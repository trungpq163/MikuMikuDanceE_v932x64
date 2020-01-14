//-----------------------------------------------------------------------------
// 汎用のプリセット。

//----------------------------------------------------------
// SSS用の設定

// ベルベット効果を有効にするか?
#define ENABLE_VELVET	0
const float VelvetExponent = 2.0;			// 縁の大きさ
const float VelvetBaseReflection = 0.01;	// 正面での明るさ 
#define VELVET_MUL_COLOR		float3(0.50, 0.50, 0.50)	// 正面の色(乗算)
#define VELVET_MUL_RIM_COLOR	float3(1.00, 1.00, 1.00)	// 縁の色(乗算)
#define VELVET_ADD_COLOR		float3(0.00, 0.00, 0.00)	// 正面の色(加算)
#define VELVET_ADD_RIM_COLOR	float3(0.00, 0.00, 0.00)	// 縁の色(加算)

//----------------------------------------------------------
// スペキュラ関連

// クリアコート効果
// モデルの上に透明なレイヤーを追加する。
#define ENABLE_CLEARCOAT		0			// 0:無効、1:有効

const float USE_POLYGON_NORMAL = 1.0;		// クリアコート層の法線マップを無視する?
const float ClearcoatSmoothness =  0.95;		// 1に近づくほどスペキュラが鋭くなる。(0～1)
const float ClearcoatIntensity = 0.5;		// スペキュラの強度。0でオフ。(0～1.0)
const float3 ClearcoatF0 = float3(0.05,0.05,0.05);	// スペキュラの反射度
const float4 ClearcoatColor = float4(1,1,1, 0.0);	// クリアコートの色


// 髪の毛の専用のスペキュラを追加する
#define ENABLE_HAIR_SPECULAR	0
// 髪の毛のツヤ
const float HairSmoothness = 0.5;	// (0～1)
// 髪の毛のスペキュラの強さ
const float HairSpecularIntensity = 1.0;	// (0～1)
// 髪の毛の向きの基準になるボーン名
// #define HAIR_CENTER_BONE_NAME	"頭"


// スフィアマップ無効。
#define IGNORE_SPHERE	1

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.1;

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
// 草などアルファ抜きしている場合はエッジに強いハイライトが出ることがある。
#define ENABLE_SPECULAR_ALPHA	0


//----------------------------------------------------------
// その他

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)

// アルファをカットアウトする
// 葉っぱなどの抜きテクスチャで縁が汚くなる場合に使う。
#define Enable_Cutout	0
#define CutoutThreshold	0.5		// 透明/不透明の境界の値

// g-bufferから色を取得する。
// POMを使う場合、高さで色の位置が変わるので、g-bufferから色を取得する必要がある。
// 0の場合、モデルのテクスチャから色を取得する
#define USE_ALBEDO_MAP		0


//----------------------------------------------------------
// 共通処理の読み込み
#include "Sources/PolishMain_common.fxsub"
