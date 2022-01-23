MangaLines ver0.0.3

漫画･アニメの効果線エフェクトです。
集中線(MangaLines_Center.fx,Post_MangaLines_Center.fx,Post_MangaLines_CenterBlur.fx)と
平行線(MangaLines_Parallel.fx,Post_MangaLines_Parallel.fx,Post_MangaLines_ParallelBlur.fx)の
6種類用意しました(Post_～はポストエフェクト版)。
アニメーションで効果線を動かすことも出来ます。


・MangaLines_Center.fx使用方法
(1)MangaLines_Center.xをMMDにロードしてください。
(2)描画順序はできるだけ後ろの方にしてください。。
(3)必要に応じてfxファイルの先頭パラメータを変更してください。
(4)MMDのアクセサリパラメータで以下の変更が可能です。
    XY：線の中心位置補正(画面中心が0で画面端が-1,+1になります)
    Z ：0でアニメーションなし、Zの絶対値がアニメーションする線の長さ、－値で逆移動
    Rx：線全体の透過度(0.0～1.0で指定、1で完全透過、0に近づくほど不透過になる)
    Ry：線の太さ調整
    Rz：集中線の中心空白の大きさ
    Si：アニメーション時の線のスピード
    Tr：線の透過度(フェード進行度)


・MangaLines_Parallel.fx使用方法
(1)MangaLines_Parallel.xをMMDにロードしてください。
(2)描画順序はできるだけ後ろの方にしてください。。
(3)必要に応じてfxファイルの先頭パラメータを変更してください。
(4)MMDのアクセサリパラメータで以下の変更が可能です。
    XY：線の位置補正(画面中心が0で画面端が-1,+1になります)
    Z ：0でアニメーションなし、Zの絶対値がアニメーションする線の長さ、－値で逆移動
    Rx：線全体の透過度(0.0～1.0で指定、1で完全透過、0に近づくほど不透過になる)
    Ry：線の太さ調整
    Rz：線の回転角
    Si：アニメーション時の線のスピード
    Tr：線の透過度(フェード進行度)


・Post_MangaLines_Center.fx,Post_MangaLines_Parallel.fx使用方法
Post_MangaLines_Center.xまたはPost_MangaLines_Parallel.xをMMDにロードしてください。
使い方はそれぞれMangaLines_Center.fx,MangaLines_Parallel.fxと同じです。
こちらはポストエフェクトとして動作します。DOF等の他のポストエフェクトの影響を
受けずに描画することが出来ます。
描画順序は必ず他のポストエフェクトの後にしてください。


・Post_MangaLines_CenterBlur.fx,Post_MangaLines_ParallelBlur.fx使用方法
Post_MangaLines_CenterBlur.xまたはPost_MangaLines_ParallelBlur.xをMMDにロードしてください。
こちらはポストエフェクトとして動作して、かつ背景にブラー効果を入れることが出来ます。
ブラー関連のパラメータ変更はfxファイルの先頭パラメータで調整してください。


・ボーン追従コントローラについて
CentetControl.pmxをMMDにロードすると効果線の中心位置がこのモデルのセンターボーンの動きに
追従するようになります。ボーンのz軸回転で効果線をスクリーン座標回転させることも出来ます。


・MikuMikuMovingについて
このエフェクトはMikuMikuMovingにも対応しています。
各fxファイルを直接MikuMikuMovingにロードしてご利用下さい。操作方法はMMDと同じです。


・更新履歴
v0.0.3  2013/7/08   背景ブラー版Post_MangaLines_CenterBlur.fx,Post_MangaLines_ParallelBlur.fx追加
                    ボーン追従設定をコントローラモデルで行うように変更
                    MikuMikuMoving向けの調整
v0.0.2  2012/9/10   Rxで全体の透過度、Zのマイナス入力でアニメーションの逆移動追加
                    中心位置をボーン追従できるようにした
                    線境界を少しぼかしてきれいに見えるようにした
v0.0.1b 2011/10/12  ポストエフェクトタイプ追加
v0.0.1  2011/9/16   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


