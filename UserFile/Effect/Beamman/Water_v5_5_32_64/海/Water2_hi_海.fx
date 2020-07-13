//水面のアニメーション速度ベース
float BaseWaveSpd = 0.1;

//反射係数
float refractiveRatio = 0.02;

//反射力
float reflectParam = 1;

//垂直ガウスぼかし強さ
float V_Gauss_pow = 0.01;

//水面の上下幅（Water2_Hhi_○○専用）
float WaveHeight = 0.01;

//スクロール速度
float2 UVScroll = float2(0.0,0.0);

//水面分割数
float WaveSplitLevel = 16;

//水面の荒さ
float WaveStrength = 8.0;

//スペキュラの鋭さ
float SpecularPower = 16.0;

//スペキュラ色
float3 SpecularColor = float3(0.5,0.5,0.5)*2;

//深度フォグ最低距離
float DepthFog_min = 0.025;

//深度フォグ効果量
float DepthFog = 0.1;

//深度フォグの色
float3 WaterColor = float3(0.1,0.2,0.3);



//生成する波の強さ
float WavePow = 0.1;

//波の減衰力
float DownPow = 0.9;

//影の凹凸強さ
float ShadowHeight = 0.05;

//影の濃さ
float ShadowPow = 0.75;

//火線の強さ
float CausticsScale = 0.2;

//火線の減衰力
float CausticsPow = 0.01;

//色収差
float3 Chromatic = float3(1.0,1.25,1.5);

//水面の計算速度
float WaveSpeed = 0.1;

//水面のぼかし値
float WaterGause = 0.0;

#include "../WaterMain.fx"