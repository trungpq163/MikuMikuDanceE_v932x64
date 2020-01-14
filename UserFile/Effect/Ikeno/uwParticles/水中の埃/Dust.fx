////////////////////////////////////////////////////////////////////////////////////////////////
// パーティクル用の設定ファイル
//
// これだけ変更しても変更が反映されない場合は、MMEで"全て更新"を選択すれば反映されます。

// ビルボード(常にカメラに正面が向く)にするか? 0:しない、1:する
#define USE_BILLBOARD	1

// 粒子数設定
#define UNIT_COUNT   4   // ←この数×1024 が一度に描画出来る粒子の数になる(整数値で指定すること)

#define MMD_LIGHTCOLOR	1	// MMDの照明色に 0:連動しない, 1:連動する
#define ENABLE_LIGHT	0	// 光源計算を 0:しない、1:する。
float EmissivePower = 0.3;	// 光源計算時のパーティクル自体の明るさ
float Translucency = 0.0;	// 光が透ける割合。0:光源計算の影響大。1:光源計算の影響小。

#define TEX_FileName  "dust.png"  // 粒子に貼り付けるテクスチャファイル名
#define TEX_PARTICLE_XNUM   4       // 粒子テクスチャのx方向粒子数
#define TEX_PARTICLE_YNUM   4       // 粒子テクスチャのy方向粒子数

#define TEX_ZBuffWrite      0       // Zバッファの書き換え 0:しない, 1:する (テクスチャにα透過がある場合は0にする)

#define USE_SPHERE       0          // スフィアマップを 0:使わない, 1:使う
#define SPHERE_SATURATE  1          // スフィアマップ適用後に 0:そのまま, 1:色範囲を0～1に制限 ←ここが0だとAutoLuminousで発光する
#define SPHERE_FileName  "sphere_sample.png" // 粒子に貼り付けるスフィアマップテクスチャファイル名

#define PALLET_FileName "palletDust.png"	// 粒子の色を指定するファイル
#define PALLET_TEX_SIZE 64		// パレットの横幅

// 粒子パラメータ設定
float ParticleSize = 0.25;          // 粒子大きさ
float ParticleSpeedMin = 0.1;    // 粒子初速度最小値
float ParticleSpeedMax = 0.5;    // 粒子初速度最大値
float ParticleRotSpeed = 1.0;      // 粒子の回転スピード
float ParticleInitPos = 32.0;       // 粒子発生時の分散位置(大きくすると粒子の初期配置が広くなります)
float ParticleLife = 16.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.9;     // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleOccur = 100.0;         // 粒子発生度(大きくすると粒子が出やすくなる)
float DiffusionAngle = 180.0;       // 発射拡散角(0.0～180.0)
float FloorFadeMax = 1.0;          // フェードアウト開始高さ
float FloorFadeMin = 0.0;          // フェードアウト終了高さ

// 物理パラメータ設定
float3 GravFactor = {0.0, 0.0, 0.0};	// 重力定数
float ResistFactor = 5.0;		// 速度抵抗力
float RotResistFactor = 4.0;		// 回転抵抗力(大きくするとゆらゆら感が増します)

#define		TimeSync		1


// 風力のスケール値
float WindPowerScale = 0.1;

// 風の速度制限
const float MaxWindSpeed = 5.0;	// 最大風速 (単位はMMD/sec)
const float MinWindSpeed = 1.0;		// これ以下の風速は無視する。


// 当たり判定
#define ENABLE_BOUNCE	1		// 当たり判定を有効にする
float BounceFactor = 0.5;		// 衝突時の跳ね返り率。0～1
float FrictionFactor = 0.9;		// 衝突時の減速率。1で減速しない。
float IgnoreDpethOffset = 20.0;	// 正面よりこれ以上後のパーティクルは衝突を無視する


// 水面設定用
#define WATER_CTRL_NAME	"ikUWController.pmx"	// 水面指定のコントローラ名

float FogAmount = 0.01;		// 距離による半透明度の増加率。大きな値ほどすぐに消える。0.0001～1.0


//-------------------------------------------------------------------------

// 当たり判定用のデータを生成するか?
// 他のパーティクルの当たり判定を利用できる場合、0を指定することで高速化できる。
#define DRAW_NORMAL_MAP		1

// 座標を共有する時の名前
// 複数のパーティクルエフェクトを使う場合、名前が重複しないようにする必要がある。
#define	COORD_TEX_NAME		ParticleCoordTexDust


// 設定ここまで
//-------------------------------------------------------------------------

#ifndef AS_SETTING_FILE
#include "../Commons/ikParticle.fxsub"
#endif

