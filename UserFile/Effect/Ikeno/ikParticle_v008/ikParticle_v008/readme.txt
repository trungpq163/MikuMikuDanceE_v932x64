
ikParticle


■ 概要

　モデルの動きにあわせて動くパーティクル。


■ 使用方法

1. Confetti, Petals, Snowフォルダのいずれかにある、ikParticle.xをMMDに入れる。

2. アクセサリの位置を変えて、パーティクルの発生位置を調整する。

　 MMDのアクセサリパラメータで設定可能な項目
　　X,Y,Z：：発射位置
　　Rx,Ry,Rz：発射方向
　　Si：パーティクルの放出量
　　Tr：パーティクルの透明度

3. ikParticleSettings.fxsub を編集することで、パーティクルのテクスチャや色を変更できます。



　WindMakerフォルダ内にある、ikWindMaker**.x が動くと、パーティクルがあわせて動きます。
　モデルの先端のボーンにぶら下げてください。
　　例：両手首、初音ミクの場合は髪の毛の先のIKなど。

　ikWindMaker**.xのすべてを使用する必要はありません。
　パーティクルを動かさない場合は、1つも追加しなくても動作します。

　ikWindMaker**.x の Si値は影響範囲を示しています。
　ikWindMaker**.x の Tr値は影響力を示しています。
　　Tr = 1.0だと影響を受け過ぎるので、0.1程度に設定してから、必要に応じて上下させてください。



■ ファイルの内容

　Confetti	紙吹雪っぽい設定
　Petals	花吹雪っぽい設定
　Snow		雪っぽい設定
　Commons	共通のファイル置き場
　WindMaker	風発生用アクセサリ


　ikParticle.fx　　パーティクル用エフェクトファイル
　ikParticle.x　　パーティクル用アクセサリ

　ikParticleSettings.fxsub
　　　エフェクトの設定ファイル。


□ その他のエフェクトと併用する場合のファイル。

　for_AutoLuminous.fxsub
　　AutoLuminous用。パーティクルを光らせる場合に使用する。

　for_Bokeh.fxsub
　　ikBokhe(ikボケ)用。

　for_MotionBlur.fxsub
　　そぼろさんのMotionBlur3用。

　for_PolishShader.fxsub
　　ikPolishShader用。ColorMapRTに設定する。
　　パーティクルの質感向上のためというより、パーティクルの後ろのモデルの材質が
　　パーティクルに適用されることで、見た目がおかしくなるのを避けるためのもの。

　for_WetFloor.fxsub
　　ikWetFloor用。WetFloorRTのパーティクル場所に指定する。
　　FloorHeightタブのチェックは外す。

　for_WorkingFloor.fxsub
　　針金PのWorkingFloorX用


■ エフェクトを複製する場合

　Confettiなどのフォルダ毎コピーする。
　コピーした側のikParticleSettings.fxsub 内の COORD_TEX_NAME を書き換える。
　同じく、DRAW_NORMAL_MAP を0にする。


■ 使用、再配布に関して

　エフェクトの利用、改造、再配布などについては自由に行ってもらってかまいません、連絡も不要です。

　このエフェクトを使用したことによって起きたすべての損害等について、作者及び関係者は一切責任を負わないものとします。


■ 更新履歴

　2016/04/17 Ver 0.08
　　風の計算がおかしかったのを修正

　2016/02/04 Ver 0.07
　　AutoLuminousとWorkingFloorに対応。

　2015/03/31 Ver 0.06
　　バグ修正。ikボケとの連携でズレが出る問題に対処。
　　ikPolishShader対応

　2015/03/22 Ver 0.05
　　シャドウマップ関連の修正
　　MotionBlur3対応

　2015/01/28 Ver 0.04
　　擬似当たり判定をつける。
　　ikWetFloor対応

　2014/11/09 Ver 0.03
　　32bit対応

　2014/11/07 Ver 0.02
　　全面的に改造。
　　風の発生方式を変更した。
　　ikボケ対応

　2014/09/03 Ver 0.01
　　初公開

ikeno
@ikeno_mmd
