// 濡れた部分が透けるもの
// ワイシャツなど。
// ※ OpaqueMapRTでこの素材を除外しておく必要がある。

#define	PROSITY				0.0		// 濡れた部分が黒くなる度合
#define	TRANSLUCENCE		1.0		// 濡れた部分が透明になる度合

#define	TEXTURE_LOOP		2		// 濡れテクスチャの繰り返し回数

#define	SPECULAR_POWER		48
#define	SPECULAR_INTENSITY	1.0

// ikPolishShaderの法線マップを流用する?
#define USE_POLISH_NORMAL	0

// 透明度指定マスク
//#define	TRANSLUCENCE_MASK	"k_huku_wrinkle.png"

//-----------------------------------------------------------------------------

#include "WetMapCommon.fxsub"
