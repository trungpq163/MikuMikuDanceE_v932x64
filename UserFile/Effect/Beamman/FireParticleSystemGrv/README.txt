FireParticle.fxの改造になります。

--追加されたパラメータ説明--

//重力の向き
float3 particleGravityVec
重力の方向を表します。初期値は下向きになっています。

//重力の強さ
float particleGravity
重力の強さを表します。強くすれば強くする程重力の影響を大きく受けます。

//重力曲線の係数
int particleGravityPow
重力を受ける際の曲線を制御する係数です。
具体的には、
１：１次関数、直線
２：２次関数、放物線
以下３次、４次と続く

