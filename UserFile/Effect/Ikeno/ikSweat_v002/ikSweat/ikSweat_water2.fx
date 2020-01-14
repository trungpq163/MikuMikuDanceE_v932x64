
// 大きめで、長く筋を引く水。


// プリセットの値を使うかどうか。0の場合はアクセサリで設定したパラメータが使われる。
#define USE_PRESET	1

#if defined(USE_PRESET) && USE_PRESET > 0
// 水滴の大きさ (0.5～4.0 小さくし過ぎると軌跡が途切れる)
const float ParticleSize = 1.5;
// 軌跡が乾く速度(1未満にすること。1に近過ぎると飽和してフラットになる。)
const float DryRate = 0.94;
// 水滴の落下速度 (速過ぎると軌跡が途切れる)
const float FallSpeedRate = 2.0;
// 水滴の厚み (0.5～4.0程度。大きいほど厚い)
const float Thickness = 1.0;
// 半透明度: 1.0 (不透明)
const float MaterialAlpha = 0.03;
// 落下までの時間の加速度
const float LifetimeScale = 1.0;
#endif


// 水滴が落下するまでの最小時間
const float LifetimeMin = 0.1;
// 水滴が落下するまでの揺れ幅
// LifetimeMin ～ LifetimeMin+LifetimeFluctuation が落下までの間に落下する。
const float LifetimeFluctuation = 0.1;

// 落下した水滴が消滅するまでの時間
const float DurationMin = 60.0;
// 消滅するまでの時間の揺れ幅
const float DurationFluctuation = 30.0;


// 水滴の色。
const float3 MaterialColor = float3(1,1,1);

// 水滴の光源計算で、光の影響をどれだけ弱くするか。
const float AmbientPower = 0.5;
// ハイライトの鋭さ：角度に対する反応の鋭さ
const float Smoothness = 0.40;			// 0.3～0.5程度
// ハイライトの強度：ハイライトの明るさ
const float SpecularScale = 1.5;

// 水滴の影の色。モデルの色に依存。
const float3 MaterialShadowColor = float3(162/255.0,110/255.0,98/255.0);
// 影の濃さ
const float ShadowPower = 0.5;


// 0フレ再生時に水滴を消すか? (0:消さない。1:消す)
#define RESET_AT_START		0

// ワーク用テクスチャのサイズ
#define	TEX_SIZE	1024
#define	TRAIL_TEX_SIZE	1024		// 軌跡用

// 編集モードでエフェクトを止める
#define STOP_IN_EDITMODE	0

// 影チェック時に対象領域を青く塗るか?
#define	DISPLAY_TARGET_AREA	0

// テクスチャ上に何個の雨粒パターンがあるか?
static int NumRaindropInTextureW = 4;	// 横方向
static int NumRaindropInTextureH = 1;	// 縦方向

// モーションによる影響
#define USE_MOTION		0
const float MovemenScale = 0.1;			// 動きの影響度
const float MaxMovement = 1.0;			// 移動上限
const float StaticFriction = 0.1;		// 停止中の水滴は、これ以下の速度の動きを無視する
const float Friction = 0.95;			// 速度の減速率(1未満にすること)


