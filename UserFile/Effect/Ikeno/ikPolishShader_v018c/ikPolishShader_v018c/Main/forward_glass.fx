//-----------------------------------------------------------------------------
// ガラス用
// ※ このエフェクトを割り当てる材質はColorMapRTから除外してください。


// 金属かどうか。基本は0(非金属)、1(金属)のどちらか。
const float Metalness = 0.0;

// 表面の滑らかさ(0～1)
//#define ENABLE_AUTO_SMOOTHNESS		// スペキュラパワーから自動でスムースネスを決定する。
const float Smoothness = 1.0;		// 自動設定しない場合の値。

// 映り込み強度(0:映り込まない。1:映り込む)
const float Intensity = 1.0;

// 非金属の垂直反射率(0.02～0.5くらい)
// 正面から見たときの映り込みの強さ。通常は0.05、宝石で0.1～0.2程度。
// 金属の場合は、色＝リフレクタンスとして扱う。
const float NonmetalF0 = 0.05;

// MMD標準のシャドウマップで陰影計算を行うか?
#define USE_MMD_SHADOW	0


//----------------------------------------------------------
// AutoLuminous対応

//#define ENABLE_AL

//テクスチャ高輝度識別フラグ
//#define TEXTURE_SELECTLIGHT

//テクスチャ高輝度識別閾値
float LightThreshold = 0.9;

// AutoLuminous対策。かってに発光しないように明るい部分をカットする。
// #define DISABLE_HDR

// PMXEditorの環境色をライトの強さの影響を受けるようにする。
// #define EMMISIVE_AS_AMBIENT
#define IGNORE_EMISSIVE			// 環境色を無効にする。


//----------------------------------------------------------
// SSS用の設定

// 逆光からの光で明るくする(カーテンや葉っぱなどに使う)
// #define ENABLE_BACKLIGHT

// SSS効果を有効にするか。
// #define ENABLE_SSS

// 表層：表面の色
const float3 TopCol = float3(1.0,1.0,1.0);	// 色
const float TopScale = 2.0;					// 視線との角度差に反応する度合い。
const float TopBias = 0.01;					// 正面でどの程度影響を与えるか
const float TopIntensity = 0.0;				// 全体影響度
// 深層：内部の色
const float3 BottomCol = float3(1.0, 1.0, 1.0);	// 色
const float BottomScale = 0.4;			// 視線との角度差に反応する度合い。
const float BottomBias = 0.2;			// 正面でどの程度影響を与えるか
const float BottomIntensity = 0.0;			// 全体影響度


//----------------------------------------------------------
// スペキュラ関連

#define ENABLE_CLEARCOAT		0			// 有効にする
const float USE_POLYGON_NORMAL = 1.0;		// クリアコート層の法線マップを無視する?
const float ClearcoatSmoothness =  0.95;		// 1に近づくほどスペキュラが鋭くなる。(0～1)
const float ClearcoatIntensity = 0.5;		// スペキュラの強度。0でオフ。(0～1.0)
const float3 ClearcoatF0 = float3(0.05,0.05,0.05);	// スペキュラの反射度
const float4 ClearcoatColor = float4(1,1,1, 0.0);	// クリアコートの色

// スフィアマップ無効
// スフィアマップによる偽ハイライトが不自然に見える場合に無効化する。
// NCHL用のモデルを使う場合も、スフィアマップを無効にする。
#define IGNORE_SPHERE

// スフィアマップの強度
float3 SphereScale = float3(1.0, 1.0, 1.0) * 0.0;

// スペキュラに応じて不透明度を上げる。
// 有効にすると、ガラスなどに映るハイライトがより強く出る。
#define ENABLE_SPECULAR_ALPHA


//----------------------------------------------------------
// その他

#define ToonColor_Scale			0.5			// トゥーン色を強調する度合い。(0.0～1.0)

// テスト用：色を無視する。
//#define DISABLE_COLOR

//----------------------------------------------------------
// 共通処理の読み込み
#include "forward_common.fxsub"
