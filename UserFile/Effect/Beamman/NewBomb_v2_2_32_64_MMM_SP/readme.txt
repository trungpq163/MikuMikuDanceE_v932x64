爆発エフェクト
ビームマンP


---使い方---
・pmx版
NewBomb.pmxを読み込む
表情モーフでパラメータを設定する


・アクセサリ版
NewBomb_AC.xとNewBombController_0.pmxを読み込む
座標などはNewBomb_AC.xをダミーボーンなどに付けて操作
パラメータはNewBombController_0.pmxを使って操作する

複数のNewBomb_AC_0.xを読み込んでもNewBombController_0.pmx一つで全てを操作できる


尚、それぞれ別の動きをさせたい場合、NewBomb_AC_*.x、NewBomb_AC_*.fx、NewBombController_*.pmxをコピー、数字を変更した後、
NewBomb_AC_*.fxをメモ帳等で開き、

//コントローラ名
#define CONTROLLER "NewBombController_0.pmx"
と記述してある部分の数字を先ほどの数字に変更する

例：
NewBomb_AC_1.x,NewBomb_AC_1.fx,NewBombController_1.pmx



製作にあたり
furia様のThe Smokeのコード、テクスチャを参考にさせて頂きました