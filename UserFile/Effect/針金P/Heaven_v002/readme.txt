ヘブンフィルター ver0.0.2

ヘブン状態ぽい演出に使うエフェクトです．一応ドラマ制作向けです．
カメラをぐりぐり回すような使い方には向かないかも・・
特定のオブジェクト周辺にかける場合(Heaven_Back.fx,Heaven_Flont.fx)と
画面全体(Screen_Heaven_Back.fx,Screen_Heaven_Flont.fx：カメラ固定)の2種類用意しました．
舞力介入P氏のlaughing_man.fx,FireParticleSystem.fxを改変して作成しました．


・Heaven_Back.fx,Heaven_Flont.fx使用方法
(1)Heaven_Back.x,Heaven_Flont.xをMMDにロードしてください．
(2)描画順序はHeaven_Back.x→対象となるモデル→Heaven_Flont.xにしてください．
(3)必要に応じてfxファイルの先頭パラメータを変更してください．
(4)MMDの通常のアクセサリパラメータ変更で位置,大きさ,透過度を設定してください．

・Screen_Heaven_Back.fx,Screen_Heaven_Flont.fx使用方法
(1)Screen_Heaven_Back.x,Screen_Heaven_Flont.xをMMDにロードしてください．
(2)描画順序はScreen_Heaven_Back.x→対象となるモデル→Screen_Heaven_Flont.xにしてください．
(3)必要に応じてfxファイルの先頭パラメータを変更してください．
(4)MMDのアクセサリパラメータはTr(透過度)のみ使用できます．


・MikuMikuMovingについて
このエフェクトはMikuMikuMovingにも対応しています。
Heaven_Back.fx,Heaven_Flont.fx,Screen_Heaven_Back.fx,Screen_Heaven_Flont.fxを
直接MikuMikuMovingにロードしてご利用下さい。


・更新履歴
v0.0.2  2013/07/01   オブジェクト周辺版にボーンの鈍化追従機能追加
                     MikuMikuMoving向けの調整、動的パースの対応等
v0.0.1  2011/11/16   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


