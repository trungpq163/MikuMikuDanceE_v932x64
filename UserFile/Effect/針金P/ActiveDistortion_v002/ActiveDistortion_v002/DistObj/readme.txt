ActiveDistortion.fx(DistObj)

モデル形状に合わせた空間歪み版エフェクトです。
モデルの法線+ノーマルマップを元に歪み処理を行います。
ノーマルマップのスクロールやフェードイン・アウト処理も行えるため
ダミーモデルを作成して様々な歪み効果の応用が可能です。

ノーマルマップはモデル頂点座標値で貼り付けるタイプ(AD_ObjPos.fx)と、
モデル頂点のUV値で貼り付けるタイプ(AD_ObjUV.fx)の2種類あります。
AD_ObjPos.fxはノーマルマップ貼り付けのUV値設定が不要ですが
フェードイン・アウトが出来なくなります。


・使用方法(MMEの場合)
(1)ActiveDistortion.xをMMDにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)歪みの元となるモデルをMMDにロードしてください。
(4)｢MMEffect｣→｢エフェクト割当｣のDistortionRTタブよりモデルを選択してAD_ObjUV.fxまたはAD_ObjPos.fxを適用。
(5)AD_ObjUV.fxを適用した場合はDistObjUVControl.pmdを、AD_ObjPos.fxを適用した場合はDistObjPosControl.pmdをMMDにロードします。
(6)AD_ObjUV.fxまたはAD_ObjPos.fxの先頭パラメータを適宜変更してください。
(7)DistObjUVControl.pmdまたはDistObjPosControl.pmdの表情スライダより各種パラメータ変更が可能です。

以下全歪みエフェクト共通の処理
(8)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(9)ActiveDistortion.xのアクセサリパラメータで以下の変更が可能です。
    Si：歪みのぼかし度(大きくすると歪み方がマイルドになります)
    Tr：歪みの強度(最大値をActiveDistortion.fxの先頭パラメータで決めてここで調整)


・使用方法(MMMの場合)
(1)ActiveDistortion.fxをMMMにロードしてください。
(2)ActiveDistortion.xの描画順序は出来るだけ最後の方に設定してください。
他の歪みエフェクトでActiveDistortionをすでに使用している場合は上の処理は不要です。

(3)歪みの元となるモデルをMMMにロードしてください。メインのエフェクト割り当てでこのモデルを非表示にします。
(4)AD_ObjUV.fxまたはAD_ObjPos.fxをMMMにロードします。
   ActiveDistortionのオフスクリーンタブDistortionRTでこのモデルにAD_ObjUV.fxまたはAD_ObjPos.fxを適用してください。
(5)AD_ObjUV.fxまたはAD_ObjPos.fxの先頭パラメータを適宜変更してください。
   またエフェクトプロパティに追加したUIコントロールより変更が可能です。

以下全歪みエフェクト共通の処理
(7)ActiveDistortion.fxの先頭パラメータを適宜変更してください。
(8)フェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。



・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


