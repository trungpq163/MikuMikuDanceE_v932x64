AfterGrow入りObjectLuminous
改変元：ObjectLuminous
作成者：そぼろ様

改変：ビームマンP

ObjectLuminousに
カメラの焼きつき表現？っぽい効果を加えました。
基本的に使い方は元と変わりません。

ObjectLuminousAG.fxの

float AfterGlow
を大きくすると残像が長く、少なくすると短くなります。



尚、簡単設定用にOL_SimpleSelect.fxを改造したOL_SimpleSelect_EX.fxを同梱しました。
エフェクト割当、OL_EmitterRT内で任意モデル、任意材質にOL_SimpleSelect_EX.fxを設定し
OL_SimpleSelect_EX.fx内、ユーザ定義変数にて光度を調整してみてください。
（光らせたくない物はOL_BlackMask.fxを設定）


ついでに、OL_ColorSelect.fxも同梱しました。
AddColorを設定する事で
任意の色に光らせる事ができます。