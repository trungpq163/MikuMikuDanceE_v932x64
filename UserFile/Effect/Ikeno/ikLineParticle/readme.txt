
ikLineParticle


■ 概要

	尾を引くパーティクルを表示するエフェクト。


■ 使用方法

	MMDのアクセサリに、"ikLineParticle.x"を追加してください。

	MMDのアクセサリパラメータで設定可能な項目
		X,Y,Z：：発射位置
		Rx,Ry,Rz：発射方向
		Si：パーティクルの放出量


	ikParticleSettings.fxsub を編集することで、パーティクルのテクスチャや色を変更できます。


■ エフェクトを複製する場合

	複数のパーティクルエフェクトを使用する場合、コピペするだけでなく、
	一部内容を変更する必要があります。

	ikLineParticle.fx内の COORD_TEX_NAME を書き換える。
	ikボケ、ikWetFloorと連携する場合は、ikParticleDepth.fx、
	WF_ObjectParticle.fxsub も複製して、中のCOORD_TEX_NAME を同様に書き換える。

		この名前でパーティクルの位置情報を共有しています。


	当たり判定を使う場合、複製した ikLineParticle.fxの DRAW_NORMAL_MAP を0にする。

		当たり判定用のデータを生成するか、人の借りるかを決めています。
		誰かが作成していれば、それを流用できます。

		当たり判定を使わない場合は、生成しないので関係ありません。

		1のままにしても、当たり判定を複数回生成するだけなので、
		重くなる以外に問題はありません。

		パーティクルによって当たる対象を変えたい場合は1のままにしてください。


■ ファイルの内容 (抜粋)

	ikParticleSettings.fxsub
						エフェクトの設定ファイル。

	sample.png			パーティクルの形状と基本色を決定するテクスチャ。
						かなり適当に作っているので、ぜひ自作してください。

						パーティクルを短くしたい場合は、このテクスチャの下部を透明にすることで、見かけ上、短くすることが出来ます。

						このテクスチャ内に複数のパターンを格納できます。

	ikDepthParticle.fx
						ikボケと併用しない場合は不要。
						このファイルをMMEのikボケ用のLinearDepthMapRTタブのikParticle.xに対して設定すれば、被写界深度が正しく計算されるようになります。

	WF_ObjectParticle.fxsub
						ikWetFloor用。WetFloorRTのパーティクル場所に指定する。

	supplement/ikLineParticle512x16.x
						より尻尾の長い.xファイル。
						これを使う場合、ikParticleSettings.fxsub 内の TAIL_DIVを16に設定する必要がある。


■ 使用、再配布に関して

	エフェクトの利用、改造、再配布などについては自由に行ってもらってかまいません、連絡も不要です。

	このエフェクトを使用したことによって起きたすべての損害等について、作者及び関係者は一切責任を負わないものとします。



■ 更新履歴

	2015/01/28 Ver 0.01		初公開

ikeno
@ikeno_mmd
