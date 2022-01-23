ActiveDistortion.fx(DistRipple)

波紋が1点から拡がるような歪み処理を行います。


・使用方法(MMEの場合)
(1)ActiveDistortion.xをMMDにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistRipple.xをMMDにロードしてください。
(4)DistRipple.xのアクセサリパラメータで位置・角度・スケールを調整します。
   エフェクトをoffにした時の白い円盤アクセが波紋が拡がる範囲になります。
(5)波紋の進行度はMMDのアクセサリパラメータTrで決まります．
   波紋開始時にTr=0.0,波紋終了時にTr=1.0をキーフレーム登録してください．
(6)AD_Particle.fxの先頭パラメータを適宜変更してください。

以下全歪みエフェクト共通の処理
(7)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(8)ActiveDistortion.xのアクセサリパラメータで以下の変更が可能です。
    Si：歪みのぼかし度(大きくすると歪み方がマイルドになります)
    Tr：歪みの強度(最大値をActiveDistortion.fxの先頭パラメータで決めてここで調整)


・使用方法(MMMの場合)
(1)ActiveDistortion.fxをMMMにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistRipple.xとAD_Ripple.fxをMMMにロードします。メインのエフェクト割り当てでDistRipple.xを描画無しに、
   ActiveDistortionのオフスクリーンタブDistortionRTよりDistRipple.xにAD_Ripple.fxを適用してください。
(4)DistRipple.xのアクセサリパラメータで位置・角度・スケールを調整します。
   エフェクトをoffにした時の白い円盤アクセが波紋が拡がる範囲になります。
   (※動かすのはアクセサリの方ですAD_Ripple.fxを動かしても変化しません)
(5)AD_Ripple.fxのエフェクトプロパティに追加したUIコントロールより波紋の進行の他パラメータ変更が可能です。

以下全歪みエフェクト共通の処理
(7)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(8)フェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。



・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


