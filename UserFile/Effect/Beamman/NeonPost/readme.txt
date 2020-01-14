ネオン的な何かになったらいいなエフェクト
ビームマンP

使い方
MMDに投げ込む
fx内の
float3 ToonCol = float3(1,0.25,0.25);
float Threshold = 5.0;
float LineSize = 0.50;
↑らへんを弄る

MMEffectタブエフェクト割当、Mainタブでモデルを非表示にする。
背景黒化を行う（推奨）


複数のNeonPostを読み込んだ上で
NeonPost_DepthRTの表示非表示を切り替える事で
個別適用とか合成とか色々遊べるかもしれないしできないかもしれない
