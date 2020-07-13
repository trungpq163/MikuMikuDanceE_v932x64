ActiveParticleSmoke.fx ver0.0.3
ActiveParticleSmokeHG.fx ver0.0.3

オブジェクトの移動に応じて煙が尾を引きます．納豆ミサイルっぽい効果が出せます．
オブジェクトの移動量に応じて放出される粒子の数と放出位置が調整されるので,オブジェクトを速く動かしても煙の
尾が途切れにくくなっています．
通常版(ActiveParticleSmoke.fx:粒子数4096)とハイグレード版(ActiveParticleSmokeHG.fx:粒子数16384)
の2種類用意しました．ActiveParticle.fxを応用して作成しました．


・ActiveParticleSmoke.fx,ActiveParticleSmokeHG.fx使用方法
(1)ActiveParticleSmoke.xまたはActiveParticleSmokeHG.xをMMDにロードしてください．
(2)描画順序はできるだけ後の方にしてください．
(3)ActiveParticleSmoke.x,ActiveParticleSmokeHG.xを適当なボーンに付けて動かすと,動いた軌道上に煙の尾が描画されます．
(4)必要に応じてfxファイルの先頭パラメータを変更してください．
(5)MMDのアクセサリパラメータで以下の変更が可能です．
    Si：粒子の放出量
    Tr：粒子の透過度


・注意点
一度に描画される粒子数は最大で4096(HG版は16384)です．これ以上の粒子を発生させるような状況になると
発生中の粒子が消失するまで新たな粒子を放出しなくなります．

※このFXファイルをMMEで使用するにはVTF(Vertex Texture Fetch)対応のSM3.0グラフィックボードが必須になります．
また、MME ver0.24以降でないと正しく動作しません。


・更新履歴
v0.0.3  2011/11/20  粒子発生･挙動アルゴリズムの改良,発生位置のムラを軽減
                    相対速度設定を廃止して重力設定,流体場設定追加
v0.0.2  2011/10/2   相対速度設定(止まっていても粒子放出可)追加
v0.0.1  2011/9/12   初回版公開


・免責事項
ご利用はすべて自己責任でお願いします．


by 針金P

