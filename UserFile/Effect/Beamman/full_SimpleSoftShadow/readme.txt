簡易ソフトシャドウ

使い方：
エフェクト割当でfull_SimpleSoftShadow.fxを対象モデルに割り当てる

ぼかし度を変えたい時は、
fx内上部にある
float SoftShadowParam = 0.5;
ここを大きくするとぼけぼけ、小さくするとシャープに（０でMMDデフォと概ね一緒）

MMD側の操作でシャドウマップ解像度アップ（CTRL+G)をした時は、
#define SHADOWMAP_SIZE 1024
ここの1024を4096にすると丁度良い、かも


以上です。簡単！

