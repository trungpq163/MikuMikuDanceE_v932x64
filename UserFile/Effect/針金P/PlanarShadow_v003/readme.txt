PlanarShadow.fx ver0.0.3
PlanarShadow_MMM.fxm ver0.0.3

MMDの地面影を任意の平面に投影できるようにします。
段差のある地形や斜面に地面影を描画したい時に用います。


・使用方法
[MMD･MME版の場合]
(1)PMD･PMXにPlanarShadow.fxを適用してください。
    GUIの場合｢MMEffect｣→｢エフェクト割当｣のメインタブより適用したいオブジェクトにPlanarShadow.fxを割り当てる。
    ファイル名設定の場合：XXXXX.pmd から XXXXX[PlanarShadow.fx].pmd に変更，または PlanarShadow.fx を XXXXX.fx に変更してロード。
(2)必要に応じてPlanarShadow.fxの先頭パラメータを適宜変更してください。

[MikuMikuMoving版の場合]
(1)PlanarShadow_MMM.fxmをMMMにロードしてください。
(2)MMMメニューの｢ファイル｣→｢エフェクト割当｣より適用したいモデルを選択して、PlanarShadow_MMMを割り当てる.
(3)MMMのエフェクトプロパティに追加したUIコントロールよりパラメータ変更が可能です。


・問題点
照明の位置がY≧0の時は地面影が表示されません(MMDの仕様です)。
アクセサリに適用しても正しい座標に変換されません。


・更新履歴
v0.0.3  2013/07/03   MMEシェーダを新しいバージョン(v0.33以降)仕様にした(GROUNDSHADOWCOLORに対応)
                     MikuMikuMoving版の追加(3照明に対応)
v0.0.2  2011/02/05   頂点シェーダの簡素化
v0.0.1  2010/11/16   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


