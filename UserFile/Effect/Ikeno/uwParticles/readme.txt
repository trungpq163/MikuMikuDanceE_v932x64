
ikUnderwater用のパーティクル


水中の埃
	Dust.x
		パーティクル本体
	Dust.fx
		エフェクトの設定
	dust.png
		パーティクル用テクスチャ。黒いほど透明。
	palletDust.png
		パーティクルのパレット。

水中の泡
	bubble.x
		パーティクル本体

口元の泡
	MouthBubble.x
		パーティクル本体
		キャラの頭ボーンにブラさげて、zを-1前後に設定する。
	MouthBubble.fx
		エフェクトの設定
		ENABLE_MORPH_EMISSION を1にして、
		MORPH_TARGETにターゲット名を指定することで、口モーフの動きに合わせて泡を出す。

Commons
	ikWindMaker**.x
		パーティクルを手足の動きに合わせて動かしたい場合に、
		それらのボーンにぶら下げる。
		Siで影響範囲が変わる。


共通
	アクセサリのSiでパーティクルの出現数が変わる
	Trで半透明度が変わる。

	ikUnderwaterより後ろに置くことでフォグの影響を受けなくなる。



ikeno
@ikeno_mmd

