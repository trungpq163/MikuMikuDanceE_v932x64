キラキラエフェクト

作った人：ビームマンP(ロベリア）
改変元：TexSnowLite.fx（そぼろ様）

-基本的な使い方-
1:KiraKira.xを読み込みます。とりあえずこれで出るはずです。
2:Controller_0.pmdを読み込みます。
3:コントローラのX,Z座標で風向きを、表情モーフから各種設定が行えます。

・備考
「速度」モーフ変更時に全体がちらつくのは計算上の仕様です。
場面転換時などで上手くごまかして下さい。


各テクスチャ説明
lamp.png　光り方をなんかそんなかんじで
particle.png ベーステクスチャ
random256x256.bmp 触らない方がいいかもしれない


重要な事
CrossLuminouseとの併用を前提にしています。
CL_EmitterRTにて、KiraKira.xにKiraKira.fxを適用して下さい。（最初はBlackMaskになっている筈・・・！）