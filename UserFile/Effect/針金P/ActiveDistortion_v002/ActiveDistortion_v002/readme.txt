ActiveDistortion.fx ver0.0.2

空間歪みエフェクトです。
深度情報で歪みの度合いを変化、手前にあるオブジェクトによるマスク処理
を行い3D的に扱えるようになっています。

ActiveDistortion.fxはポストエフェクトで様々な歪み処理を行うためのベースになっています。
ActiveDistortion.fx単体だけでは特に画面上に変化はありません。
同梱の各フォルダにあるエフェクトファイルと組み合わせて以下のような歪み処理が行えます。

・DistFire : FireParticleSystemExの歪み版です
・DistJet : ジェット噴射による歪み処理をします
・DistLine : ライン描画による歪み処理をします
・DistMangaTears : MangaTearsの歪み版です
・DistObj : モデルの形状に合わせて歪み処理をします
・DistParticle : ActiveParticleSmokeの歪み版です
・DistRipple : 波紋衝撃波っぽい歪み処理をします
・DistSpiral : スクリュー衝撃波っぽい歪み処理をします
・DistVortex : 渦巻き状の歪み処理をします
・DistWind : 風エフェクトの歪み版です


・使用方法(概要、詳細は各フォルダのreadme.txtを参照)
(1)ActiveDistortion.xをMMDにロードしてください。MMMではActiveDistortion.fxを直接ロードします。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
(3)各フォルダにあるエフェクトファイルを適用します。個々の処理については各フォルダにある
   readme.txtを参照ください。
   これらのエフェクトは1つのActiveDistortion.fxで複数の歪み処理を供用して使用することが出来ます。
(4)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
   MMMではエフェクトプロパティに追加したUIコントロールより変更が可能です。
(5)ActiveDistortion.xのアクセサリパラメータで以下の変更が可能です。
    Si：歪みのぼかし度(大きくすると歪み方がマイルドになります)
    Tr：歪みの強度(最大値をActiveDistortion.fxの先頭パラメータで決めてここで調整)
    MMMではUIアノテーションより変更が可能です。


・手前にあるオブジェクトのマスク補正について
このエフェクトでは歪みの大きさを深度で調整していますが、条件によっては手前にあるモデル
の周辺の歪みが弱くなることがあります。この現象が目立つ場合は手前にあるモデルに
AD_Mask.fxsub→AD_MaskFront.fx(MMMではAD_MaskMMM.fxsub→AD_MaskFrontMMM.fx)に差し替える
と直ります。ただしモデルの前後関係が正しく読めなくなるので手前にあるモデルにのみ
適用してください。


・OptionフォルダにあるBackgroundControl.x,TimeControl.xでそれぞれ背景移動時の演出や
時間コントロールが行える歪みエフェクトがあります。詳細は各フォルダのreadme.txtを参照ください。



・更新履歴
v0.0.2  2014/5/20   DistJet, DistLine, DistVortexを新規追加
                    時間コントロールの制御アクセTimeControl.x追加
                    ActiveDistortion.fxの内部コード整理、各歪みエフェクトの細かい修正
v0.0.1  2013/9/18   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


