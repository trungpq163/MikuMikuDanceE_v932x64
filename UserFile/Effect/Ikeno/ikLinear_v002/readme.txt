
トーンマッパー

■ これはなに？
ikPolish用に画面の明るさを調整するエフェクト。

もともとは、ikeno製のエフェクト間でデータの精度を保って、
やりとりするためのエフェクトだった。
→ "リニアワークフロー"で検索と、添付のworkflow.jpgを参照。

なぜ ikPolishと分離しているかといえば、ikBokehなど、
その他のエフェクトを途中にはさみたい場合があるため。


■ 使い方

1. ikPolishを入れる。
2. ikLinerEndを入れる。

エフェクトの順番は、
　0. 背景、パーティクルなど。
　1. ikPolish (または ikLinearBegin)
　2. ikBokeh, MotionBlurなど。
　3. ikLinerEnd
　4. ikClutなどの色調変換系。
の順にする。

ikLinearBeginはikPolishを使わない場合に使用する。


■ 設定

・露出補正
自動露出で明るくなりすぎる、暗くなりすぎるときに使用します。
屋内、夜などの暗いシーンが自動露出で明るくなりすぎる場合、
晴天の屋外でより明るさを強調したい場合に使用します。

指定方法：
　アクセサリのX。+1で2倍の明るさ、-1で1/2の暗さにする。-3～3程度で調整。
　コントローラの露出+/-。+1で16倍の明るさ(+4EV)。-1で1/16の暗さ(-4EV)になる。


・強制スナップ
露出の滑らかの変化をカットして、強制的に露出を調整します。
カットが切り替わる場合に、前カットの露出を引き継ぎたくない場合、
0フレーム目で露出の初期値がおかしい場合に使用します。

指定方法：
　アクセサリのTrを0にする。
　コントローラの露出スナップを1にする。


・ブルームの調整
明るすぎる部分の色がにじむ強度を指定。
※ AutoLuminousと競合する機能なので、AutoLuminousを使用する場合は
ikLinearEnd.fx内の設定でブルームをオフにしてください。

指定方法：
　アクセサリのY。-1～+4程度。
　コントローラのブルーム+/-。


・デバッグ機能
ikLinearEnd.fx内 の ENBALE_DEBUG_VIEWを1にすることで、
内部の計算を見えるようにします。


■ 添付ファイル

workflow.jpg
　処理の流れを図示したもの。

NoAE/ikLinerEnd.fx
　自動露出機能をカットした従来と同等のikLinerEnd。
　ikLinerEnd.fxの中にある設定を変更しただけ。


以下のファイルは将来的にikPolishに統合される予定。

for_ikPolish/full_linear.fx
　ikLinearの存在に応じて出力情報を変えるfull.fx改。

for_ikPolish/ldr_skydome.fx
　full_linear.fxをスカイドーム用に簡略化したもの。

for_ikPolish/rgbm_skydome.fx
　ikLinear対応した ikPolishのHDRIスカイドーム用エフェクト。

for_ikPolish/ikPolishController.pmx
　露出用のモーフを追加した ikPolishコントローラ。



■ 対応しているエフェクト

https://ux.getuploader.com/ikeno/download/144/Linear.zip
を参照。


■ 使用、再配布に関して
エフェクトの利用、改造、再配布などについては自由に行ってもらってかまいません。
連絡も不要です。
このエフェクトを使用したことによって起きたすべての損害等について、
作者及び関係者は一切責任を負わないものとします。


ikeno
Twitter: @ikeno_mmd
