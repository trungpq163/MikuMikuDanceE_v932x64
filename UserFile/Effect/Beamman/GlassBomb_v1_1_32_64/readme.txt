ガラス爆発エフェクト
ビームマンP


---使い方---
・pmx版
GlassBomb.pmxを読み込む
表情モーフでパラメータを設定する


・アクセサリ版
GlassBomb_AC.xとGlassBombController_0.pmxを読み込む
座標などはGlassBomb_AC.xをダミーボーンなどに付けて操作
パラメータはGlassBombController_0.pmxを使って操作する

複数のGlassBomb_AC_0.xを読み込んでもGlassBombController_0.pmx一つで全てを操作できる


尚、それぞれ別の動きをさせたい場合、GlassBomb_AC_*.x、GlassBomb_AC_*.fx、GlassBombController_*.pmxをコピー、数字を変更した後、
GlassBomb_AC_*.fxをメモ帳等で開き、

//コントローラ名
#define CONTROLLER "GlassBombController_0.pmx"
と記述してある部分の数字を先ほどの数字に変更する

例：
GlassBomb_AC_1.x,GlassBomb_AC_1.fx,GlassBombController_1.pmx



製作にあたり
furia様のThe Smokeのコード、テクスチャを参考にさせて頂きました