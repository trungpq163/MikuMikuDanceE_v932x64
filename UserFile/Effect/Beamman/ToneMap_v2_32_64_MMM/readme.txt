AutoLuminous及びパーティクル等加算エフェクトとの併用を前提

画面内の"明るい部分"の量に従って露光を自動補正するエフェクトです。

挙動はToneMap_v2.fx内の
//トーンマップの強さ
float ToneParam = 1;
//トーンマップ速度
float ToneSpd = 0.025;
を操作して変更します。

--重要--
AutoLuminousより後に描画する用にして下さい

--使い方--
ToneMap_v2をMMDに読み込む


