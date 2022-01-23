ActiveDistortion.fx(DistVortex)

渦巻き状の歪み処理を行います。


・使用方法(MMEの場合)
(1)ActiveDistortion.xをMMDにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistVortex.pmxをMMDにロードしてください。
(4)DistVortex.pmxのセンターボーンで位置・角度を調整します。
(5)DistVortex.pmxの表情スライダより各種パラメータ変更が可能です。
   また必要に応じてAD_Vortex.fxの先頭パラメータを適宜変更してください。

以下全歪みエフェクト共通の処理
(6)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(7)ActiveDistortion.xのアクセサリパラメータで以下の変更が可能です。
    Si：歪みのぼかし度(大きくすると歪み方がマイルドになります)
    Tr：歪みの強度(最大値をActiveDistortion.fxの先頭パラメータで決めてここで調整)


・使用方法(MMMの場合)
(1)ActiveDistortion.fxをMMMにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)DistVortex.xとAD_Vortex.fxをMMMにロードします。メインのエフェクト割り当てでDistVortex.xを描画無しに、
   ActiveDistortionのオフスクリーンタブDistortionRTよりDistVortex.xにAD_Vortex.fxを適用してください。
(4)DistVortex.xのアクセサリパラメータで位置・角度・スケールを調整します。
   (※動かすのはアクセサリの方ですAD_Vortex.fxを動かしても変化しません)
(5)AD_Vortex.fxのエフェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。

以下全歪みエフェクト共通の処理
(6)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(7)フェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。



・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


