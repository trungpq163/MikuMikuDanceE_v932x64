// 濡れた部分が暗くなるもの
// コンクリートや厚い布など。

#define	PROSITY				0.5		// 濡れた部分が黒くなる度合
#define	TRANSLUCENCE		0.0		// 濡れた部分が透明になる度合

#define	TEXTURE_LOOP		2		// テクスチャの繰り返し回数

#define	SPECULAR_POWER		48
#define	SPECULAR_INTENSITY	1.0

// ikPolishShaderの法線マップを流用する?
#define USE_POLISH_NORMAL	0

// テクスチャによる濡れ度合いの指定
#define TRANSLUCENCE_MASK	"masktest.png"
#define TRANSLUCENCE_MASK_MODE	1 // 0:旧方式、1:新方式
// 新方式では、
// R: 透け度合い
// G: 水が弾いた瞬間スペキュラ強度
// B: 濡れたときの黒くなる度合い。を指定。
// 黒ほどエフェクトの影響を受けづらく、白ほど影響を受ける。
// 旧方式では、赤チャンネルのみを参照していた。


//-----------------------------------------------------------------------------

#include "WetMapCommon.fxsub"
