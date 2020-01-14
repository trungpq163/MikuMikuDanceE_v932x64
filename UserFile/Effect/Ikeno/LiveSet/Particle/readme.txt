以前作ったパーティクルをikPolish v0.24用に合わせて調整するついでにコードを変形。
実体としては以前と変わりがない。

ikBokehやそぼろさん作のMotionBlur3などに対応している。

Confettiフォルダ内のikParticle.xがパーティクル本体。
ikParticleSettings.fxsub にパーティクルの設定がある。
for_xxxが各種エフェクト用のファイル。

ikPolish用のファイルは、
	for_PolishMain.fxsub		メイン用
	for_PolishMaterial.fxsub	マテリアル用
	for_PolishSSAO.fxsub		SSAO用
	for_PolishShadow.fxsub		シャドウマップ用。

WindMakerフォルダは、パーティクルとの当たり判定用。

readme_v009.txt は ikParticle v009用の説明書。
パーティクルの種類が減っている以外は、操作方法は変わっていません。

