// 濡れた部分が暗くならないもの
// 肌やプラスティックなど

#define	PROSITY				0.0		// 濡れた部分が黒くなる度合
#define	TRANSLUCENCE		0.0		// 濡れた部分が透明になる度合

#define	TEXTURE_LOOP		2		// テクスチャの繰り返し回数

#define	SPECULAR_POWER		48
#define	SPECULAR_INTENSITY	1.0

// ikPolishShaderの法線マップを流用する?
#define USE_POLISH_NORMAL	0

//-----------------------------------------------------------------------------

#include "WetMapCommon.fxsub"
