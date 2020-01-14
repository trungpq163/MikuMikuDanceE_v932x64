

VoxelParticle (ikCubeParticle, ikFragmentParticle)


■ 概要

ポリゴンのように見えるパーティクルエフェクト
針金P作成のパーティクルエフェクトCannonParticle.fxを元に作成しました。

cube/ikCubeParticle は 立方体パーティクル。
fragment/ikFragmentParticle はテクスチャで指定した形状のパーティクルになります。


■ 使用方法

1. MMDのアクセサリに、"ikCubeParticle.x" または "ikFragmentParticle.x"を追加する。
2. アクセサリの位置と向きを調整する。
3. 必要に応じて、描画順序を調整する。

■ 設定項目

	MMDのアクセサリパラメータで設定可能な項目
		X,Y,Z：：発射位置
		Rx,Ry,Rz：発射方向
		Si：パーティクルの放出量。0で停止。
		Tr：透明度。

	ik***Settings.fxsub を編集することで、パーティクルのテクスチャや色を変更できます。


■ エフェクトを複製する場合

複数のパーティクルエフェクトを使用する場合、ファイルをコピペするだけでなく、
Settingsファイル(ik***Settings.fxsub)の内容を一部変更する必要があります。

COORD_TEX_NAME を重複しない名前にしてください。

	デフォルトで↓のようになっている場合、
	#define	COORD_TEX_NAME		FragmentParticleCoordTex
	2つ目のik***Settings.fxsubを、
	#define	COORD_TEX_NAME		FragmentParticleCoordTex2
	のように変更してください。

当たり判定を使う場合、複製した Settingsファイル の
DRAW_NORMAL_MAPを0にすることで高速化できます。

	当たり判定を使わない場合は、生成しないので関係ありません。

	1のままにしても、当たり判定を複数回生成するだけなので、
	重くなる以外に問題はありません。


■ 使用、再配布に関して

エフェクトの利用、改造、再配布などについては自由に行ってもらってかまいません、連絡も不要です。

このエフェクトを使用したことによって起きたすべての損害等について、作者及び関係者は一切責任を負わないものとします。


■ 更新履歴

2015/10/13 Ver 0.02 一部計算の修正
2015/10/03 Ver 0.01 初公開

ikeno
@ikeno_mmd
