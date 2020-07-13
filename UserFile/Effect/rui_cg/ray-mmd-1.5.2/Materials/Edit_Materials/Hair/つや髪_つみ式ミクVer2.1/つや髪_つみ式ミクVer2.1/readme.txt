Ray-MMD1.5.2用　つみ式ミク Ver2.1用つや髪.fx

更科さん @sarashinuz の初心者materialキット  https://bowlroll.net/file/161752  必須。
上記の初心者materialキットを導入後、そのフォルダに追加して使ってください。


内容
・material_hair_anisotropy_M_つみ式ミクv2_髪1.fx
　髪1.pngを使っている材質（Hair Front、Bangs、Posterior hair）に当ててください。
・material_hair_anisotropy_M_つみ式ミクv2_髪2.fx
　髪2.pngを使っている材質（Twin Tails）に当ててください。
・NormalMapフォルダ
　そのまま初心者materialキットの中にある同名フォルダに上書きしてください。

以下は流用させていただいた、ますたー様（@MyuDOLL）のデータ
・material_hair_anisotropy_M.fx
　縦向きのノーマルマップが適用される髪の毛用fx
　キューティクルが出ます。
・TDA hair by RGL.jpg
　ray-MMDの古いバージョンに付属していた、Tdaミクさんの髪の毛専用ノーマルマップ。
　初心者materialキットフォルダ内のNormalMapフォルダに入れてください。


・改変のコツ
髪の毛の色を濃くしたり薄くしたり、線を強調したい場合は下記をいじると良いです。
const float3 albedo = 1.15;　元のテクスチャの色を濃く、もしくは薄くさせます。
const float normalMapScale = 0.3;　ノーマルマップの強さが変わります。

つやを変化させたいときは下記をいじると良いです。
const float smoothness = 0.6;
const float metalness = 0.2;


何か質問あればTwitterにお気軽にどうぞ～
@lovemax109

rayMMD マテリアルに関しては偉大な先人であるますたー様へどうぞ！（丸投げ）
@MyuDOLL
