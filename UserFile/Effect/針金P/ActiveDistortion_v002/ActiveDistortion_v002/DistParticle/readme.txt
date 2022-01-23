ActiveDistortion.fx(DistParticle)

ActiveParticleSmoke.fxの空間歪み版エフェクトです。
オブジェクトの移動した軌跡に合わせてモヤッとした歪み処理が行えます。
オブジェクトが動いた後に発生する気流の乱れのような表現が出来ます。


・使用方法(MMEの場合)
(1)ActiveDistortion.xをMMDにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistParticle.xをMMDにロードしてください。
(3)DistParticle.xを適当なボーンに付けて動かすと,動いた軌道上の空間が歪みます。
(4)AD_Particle.fxの先頭パラメータを適宜変更してください。
(5)DistParticle.xのアクセサリパラメータで以下の変更が可能です。
    Si：粒子の放出量
    Tr：歪みの強さ

以下全歪みエフェクト共通の処理
(6)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(7)ActiveDistortion.xのアクセサリパラメータで以下の変更が可能です。
    Si：歪みのぼかし度(大きくすると歪み方がマイルドになります)
    Tr：歪みの強度(最大値をActiveDistortion.fxの先頭パラメータで決めてここで調整)


・使用方法(MMMの場合)
(1)ActiveDistortion.fxをMMMにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistParticle.xとAD_Particle.fxをMMMにロードします。メインのエフェクト割り当てでDistParticle.xを非表示に、
   ActiveDistortionのオフスクリーンタブDistortionRTよりDistParticle.xにAD_Particle.fxを適用してください。
(4)DistParticle.xを動かすと,動いた軌道上の空間が歪みます。
   (※動かすのはアクセサリの方ですAD_Particle.fxを動かしても変化しません)
(5)AD_Particle.fxの先頭パラメータを適宜変更してください。
(6)DistParticle.xのアクセサリパラメータで以下の変更が可能です。
    拡大：粒子の放出量
    アルファ：歪みの強さ

以下全歪みエフェクト共通の処理
(7)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(8)フェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。


・背景移動演出時の利用方法ついて
オブジェクトの動きを表現する場合、直接オブジェクトを動かす以外に、背景の方を移動させてオブジェクトが
動いているように見せるような演出がよく使われます。
同梱のBackgroundControl.xを用いるとオブジェクトを動かさなくても、背景の動きに連動して粒子を放出させることが出来ます。
(1)OptionフォルダにあるBackgroundControl.xをMMD/MMMにロードしてください。アクセ自体は表示されません。
(2)MMMではBackgroundControl.xの描画順を必ずAD_Particle.fxよりも前にしてください。
(3)BackgroundControl.xを背景モデルを移動させるボーンに共に付けてください。
(4)このボーンを動かすと粒子の動きはボーンの位置・角度を基準にした座標系に切り替わり、
   オブジェクトとの相対的な位置関係でオブジェクトの移動量を計算して粒子を放出します。


・時間コントロールの方法ついて
同梱のTimeControl.xを用いると粒子の運動に対する時間の流れを遅くしたり、停止させたりできます。
スローモーションの演出や、静止画の出力などに便利です。
(1)OptionフォルダにあるTimeControl.xをMMD/MMMにロードしてください。アクセ自体は表示されません。
(2)MMMではTimeControl.xの描画順を必ずAD_Particle.fxよりも前になるようにして下さい。
(2)TimeControl.xのアクセサリパラメータで以下の変更が可能です。
    Si：0にするとフレームを移動させた時だけ時間が流れます。静止画出力の時にご利用下さい。
    Tr：時間の進行度、0にすると停止します。
  ※モニターより大きいサイズでの出力はうまく行かない場合があります。



・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


