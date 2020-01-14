Ray-MMD1.5.2用　つや髪.fx

更科さん @sarashinuz の初心者materialキット  https://bowlroll.net/file/161752  必須。
上記の初心者materialキットを導入後、そのフォルダに追加して使ってください。
*ファイルそのものはrayにもともと付いていたものの改変ですが、フォルダ構造を更科さんのキットに合わせてある為。
 初心者materialキットは便利なので、絶対入れたほうが良いです！


内容
・material_hair_anisotropy_M.fx
　縦向きのノーマルマップが適用される髪の毛用fx
　キューティクルが出ます。
・TDA hair by RGL.jpg
　ray-MMDの古いバージョンに付属していた、Tdaミクさんの髪の毛専用ノーマルマップ。
　初心者materialキットフォルダ内のNormalMapフォルダに入れてください。


・改変のコツ
#define NORMAL_MAP_FILE "NormalMap/NMhair.png"　のファイルをNMhair_h.pngにすると、横向きのノーマルマップになります。
髪の毛のUVが、縦か横一直線に展開されてればこのどちらかで済みますが、なかなかそうはいきません。
モデルの髪のUVを縦もしくは横一直線にするか、髪のUV展開図を元に専用のノーマルマップを作ってください。
専用ノーマルマップの効果を見るには、TDA hair by RGL.jpgを指定してTda式ミクさんの髪の毛にfx当ててみましょう。

const float normalMapScale = 1;　ノーマルマップの強さが変わります。
const float normalMapLoopNum = 2;　ノーマルマップの粗さが変わります。小さくすると粗く、大きくすると細かくなります。専用ノーマルマップを使用する場合は1固定です。


元のモデルの髪の色によっては、全体的に白く飛ぶ感じになるかもしれません。
const float3 specular = 1.5;　この数値を下げると良い感じになると思います。



何か質問あればTwitterにお気軽にどうぞ～
@MyuDOLL
