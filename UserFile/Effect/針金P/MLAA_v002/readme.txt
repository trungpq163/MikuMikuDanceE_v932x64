MLAA.fx v0.0.2

Morphological Antialiasing(MLAA)法を用いたポストエフェクトによるアンチエイリアシング処理
技術情報 : http://visual-computing.intel-research.net/publications/papers/2009/mlaa/mlaa.pdf(英文)

MLAA法はMMDで使われている Multisample Antialiasing(MSAA)法に比べ高品位とされています。
・・・が、実際試した結果MMDとの相性はあまり良くないことが解りました(特にMMDエッジ描画においては)。
とりあえずサンプルコードとして配布します(MSAAが使えないMultiRenderTarget(MRT)とかで利用出来るかも)。


・動作環境
SM3.0対応グラフィックボードが必須になります。


・基本的な使用方法
(1)MMD・MMM標準のアンチエイリアスはoffにしてください。またPMD・PMXのエッジ描画は非表示にした方がよいです。
   これ以外の条件では多分MMD・MMM標準のアンチエイリアスより汚くなります。
(2)MLAA.xをMMDにロードしてください。MMMではMLAA.fxを直接ロードします。
(3)必要に応じてMLAA.fxの先頭パラメータを変更してください。


・更新履歴
v0.0.2  2013/07/03   MikuMikuMovingの対応
v0.0.1  2012/10/09   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


