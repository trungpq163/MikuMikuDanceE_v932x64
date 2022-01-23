////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MMDShadow_Header.fxh : MMDShadow シャドウマップ作成に必要な基本パラメータ定義ヘッダファイル
//  MMDとほとんど同じシャドウマップをエフェクトのみで実装しています。
//  ここのパラメータを他のエフェクトファイルで #include して使用します。
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
// ※ファイル更新後に｢MMEffect｣→｢全て更新｣で参照しているエフェクトファイルを更新する必要があります

// シャドウマップバッファサイズ
#define ShadowMapSize  2048

// VSMシャドウマップの実装
#define UseSoftShadow  1
// 0 : 実装しない(MMD標準のシャドウマップとほとんど同じになる。ソフトシャドウは使えないけど描画速度は向上する)
// 1 : 実装する(ソフトシャドウが使えるようになります)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#ifndef MMDSHADOW_MAIN

#ifndef MIKUMIKUMOVING

    // MMDの｢セルフシャドウ操作｣における｢影範囲｣入力値
    float4x4 MMDShadow_LtPMat : PROJECTION < string Object = "Light"; >;
    static float MMDShadow_SelfShadowLength = 10000.0f * ( 1.0f - MMDShadow_LtPMat._33 / 0.015f );

#else

    shared texture MMDShadow_ParamTex : RENDERCOLORTARGET;
    sampler MMDShadow_ParamSamp = sampler_state
    {
        Texture = <MMDShadow_ParamTex>;
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = NONE;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };
    /* ↓これで読みたいけどエラーになる
    float4 MMDShadow_OwnerDat[1] : TEXTUREVALUE <
       string TextureName = "MMDShadow_ParamTex";
    >; */
    static float MMDShadow_OwnerDat = tex2Dlod(MMDShadow_ParamSamp, float4(0.5f, 0.5f, 0, 0 )).r;
    // MMDの｢セルフ影操作｣における｢影範囲｣入力値
    static float MMDShadow_SelfShadowLength = abs(MMDShadow_OwnerDat);
    // MMDのセルフシャドウモードフラグ false:mode1, true:mode2
    static bool MMDShadow_ParthFlag = (MMDShadow_OwnerDat < 0.0f) ? true : false;

#endif

// カメラ位置
float3 MMDShadow_CameraPosition  : POSITION  < string Object = "Camera"; >;

// カメラ方向(正規化済み)
float3 MMDShadow_CameraDirection : DIRECTION < string Object = "Camera"; >;

// MMD照明操作入力値XYZ×(-1),MMMでは入力値XYZ×(-100)
float3 MMDShadow_LightPosition   : POSITION  < string Object = "Light"; >;

// ライト方向(正規化済み)、normalize(-MMDShadow_LightPosition) でも求まる
float3 MMDShadow_LightDirection  : DIRECTION < string Object = "Light"; >;


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
・MMDライト方向のビュー変換行列

MMDのライトはディレクショナルライト(平行光源)であるため、ライトの位置座標は本来ライトの向きと逆方向の無限遠点になる。

float3 LightPosition : POSITION < string Object = "Light"; >; で取得される値はMMEではMMD照明操作入力値XYZ ×(-1)の値であり、
MMMの場合は照明操作入力値XYZ ×(-100)の値である。

MMDのライト方向ビュー変換行列については、カメラ位置からLightPosition×50の位置を仮の光源座標として計算している。
ライト方向をz軸正方向として、ライト方向とカメラ方向が共に垂直になる方向をx軸(正負はy軸正方向にカメラ視点が
向くように決める)になるように変換する。
よって以下の計算式で float4x4 LightViewMatrix : VIEW < string Object = "Light"; >; と同じ値を求められる
*/

float4x4 MMDShadow_LightViewMatrix()
{
   // x軸方向ベクトル(MMDShadow_LightDirectionがz軸方向ベクトル)
   float3 ltViewX = cross( MMDShadow_CameraDirection, MMDShadow_LightDirection ); 

   // x軸方向ベクトルの正規化(MMDShadow_CameraDirectionとMMDShadow_LightDirectionの方向が一致する場合は特異値となる)
   float viewLength = length(ltViewX);
   if(viewLength == 0.0f) viewLength = 1;
   ltViewX /= viewLength;

   // y軸方向ベクトル
   float3 ltViewY = cross( MMDShadow_LightDirection, ltViewX );  // 共に垂直なのでこれで正規化

   // 仮の光源位置
   #ifndef MIKUMIKUMOVING
   float3 ltViewPos = MMDShadow_CameraPosition + MMDShadow_LightPosition * 50.0f;
   #else
   float3 ltViewPos = MMDShadow_CameraPosition + MMDShadow_LightPosition * 0.5f;
   #endif

   // ビュー座標変換の回転行列
   float3x3 ltViewRot = { ltViewX.x, ltViewY.x, MMDShadow_LightDirection.x,
                          ltViewX.y, ltViewY.y, MMDShadow_LightDirection.y,
                          ltViewX.z, ltViewY.z, MMDShadow_LightDirection.z };

   // ビュー変換行列
   return float4x4( ltViewRot[0],  0,
                    ltViewRot[1],  0,
                    ltViewRot[2],  0,
                   -mul( ltViewPos, ltViewRot ), 1 );
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
・MMDライト方向の射影変換行列

MMDのライト方向射影変換行列はライト方向とカメラ方向のなす角によって行列の算定方法が分類されている。
具体的には、なす角αの余弦絶対値が

① |cosα| = 0.0～0.8 の時(ライトとカメラの方向がそれなりに異なる時)
   mode1とmode2それぞれ個別にシャドウ距離から一意的に決められる

② |cosα| = 0.9～1.0 の時(ライトとカメラの方向が近くなる,または相対する時)
   mode1とmode2の区別なくシャドウ距離と|cosα|より決められる

③ |cosα| = 0.8～0.9 の時
   ①と②の遷移補完値になる。要素._23, ._24 は|cosα|に対する2次関数補間、他は線形補間になっている

実際には以下の計算式で float4x4 LightProjMatrix : PROJECTION < string Object = "Light"; >; と同じ値が求められる

float MMDShadow_SelfShadowLength;  // MMDの｢セルフ影操作｣における｢影範囲｣入力値(0～9999)
bool ParthFlag;   // セルフシャドウモードフラグ false:mode1,true:mode2
*/

float4x4 MMDShadow_LightProjMatrix(bool ParthFlag)
{
   float s = (10000.0 - MMDShadow_SelfShadowLength) / 100000.0;

   float c0, c1, c2;
   float4x4 ltPrjMat;

   if(ParthFlag){
      // ①mode2の射影変換行列
      ltPrjMat = float4x4( 3*s,    0,      0,   0,
                             0,  3*s,  1.5*s, 3*s,
                             0,    0, 0.15*s,   0,
                             0,   -1,      0,   1 );
      c0 = 3.0;  c1 = -4.7;  c2 = 1.8;
   }else{
      // ①mode1の射影変換行列
      ltPrjMat = float4x4( 2*s,    0,      0,   0,
                             0,  2*s,  0.5*s,   s,
                             0,    0, 0.15*s,   0,
                             0,   -1,      0,   1 );
      c0 = 1.0;  c1 = -1.3;  c2 = 0.4;
   }

   // ライト方向とカメラ方向のなす角の余弦絶対値
   float absCosD = abs( dot(MMDShadow_CameraDirection, MMDShadow_LightDirection) );

   if(absCosD > 0.9){
      // ②の射影変換行列
      ltPrjMat = float4x4( s,         0,                 0,             0,
                           0,         s, 0.5*s*(1-absCosD), s*(1-absCosD),
                           0,         0,            0.15*s,             0,
                           0, absCosD-1,                 0,             1 );
   }else if(absCosD > 0.8){
      // ③の射影変換行列
      float t = 10 * ( absCosD - 0.8 );
      ltPrjMat._11 = lerp( ltPrjMat._11, s, t );
      ltPrjMat._22 = lerp( ltPrjMat._22, s, t );
      ltPrjMat._24 = s * ( c0 + c1*t + c2*t*t );
      ltPrjMat._23 = 0.5 * ltPrjMat._24;
      ltPrjMat._42 = lerp( -1, -0.1, t );
   }

   return ltPrjMat;
}

/*
・LightProjMatrixに対する補足説明

※上式よりLightProjMatrix._33だけはどの分類に属しても同じ算定式になるため、ここから
  MMDの｢セルフ影操作｣における｢影範囲｣のシャドウ距離入力値を以下のような式で求めることが出来る。

static float SelfShadowLength = 10000 * ( 1 - LightProjMatrix._33 / 0.015 );

※シャドウ距離は s = (10000 - SelfShadowLength) / 100000 の相対距離を基準にして
  射影変換行列を求めている(VMDに記録されるシャドウ距離もこの値が入っている)。

※射影変換行列よりシャドウマップが適用される範囲(射影座標がxy:-1～+1,z:0～1となる範囲)はビュー座標で
  ①mode1の時
     y = 0 ～ 2/s
     y=0 で、x = -1/(2s) ～ +1/(2s)
     y=2/s で、x = -3/(2s) ～ +3/(2s)
     Near：z = -(10/3)y、Far：z = (10/3)y+1/(0.15s)
     mode1ではカメラ近距離～遠距離を平均的(マップ範囲のカメラ最近・最遠スケール比は3倍)にシャドウマップ範囲を割り当てる。
     シャドウ距離が短いと遠距離部分はセルフシャドウ適用範囲外になる。

  ①mode2の時
     y = 0 ～ +∞
     y=0 で、x = -1/(3s) ～ +1/(3s)
     y=+∞ で、x = -∞ ～ +∞
     Near：z = -10y、Far：z = 10y+1/(0.15s)
     mode2ではカメラ方向の全範囲をカバーしているが、その分マップ範囲のカメラ最近・最遠スケール比は極端に大きくなる。
     よってカメラ近距離はシャドウマップ解像度は高いが中距離・遠距離のシャドウマップ解像度は粗くなる。

  ビュー座標でカメラ位置はz軸上にありカメラ方向はy軸正方向を向いていて、シャドウマップ適用範囲がビュー座標でy>0であるため、
  ①mode1,①mode2ではカメラの後ろ側はシャドウマップ範囲外になる。

  ②の時(とりあえずabsCosD=1について)
     y = -1/s ～ +1/s
     x = -1/s ～ +1/s
     Near：z = 0、Far：z = 1/(0.15s)
     よって、ライトとカメラの方向が近くなる(または相対する)とシャドウマップ適用範囲はカメラ位置を中心にした範囲に遷移するようになる。

※MMD標準のLightProjMatrixは次の状態の時は正しく取得できなくなる
　  MMDの[表示(V)]-[セルフシャドウ表示(P)]をOFFにした時
　  MMDの[セルフ影操作]で｢影なし｣を選択した時
    ボーン選択状態の時
  上記以外なら非セルフシャドウのオブジェクト描画の時でも正しく取得できる。なおLightViewMatrixは常に正しく取得できる模様。

*/

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 座標変換行列

float4x4 MMDShadow_WorldMatrix : WORLD;

float4x4 MMDShadow_GetLightViewProjMatrix(bool ParthFlag)
{
    return mul( MMDShadow_LightViewMatrix(), MMDShadow_LightProjMatrix(ParthFlag) );
}

float4x4 MMDShadow_GetLightWorldViewProjMatrix(bool ParthFlag)
{
    return mul( MMDShadow_WorldMatrix, MMDShadow_GetLightViewProjMatrix(ParthFlag) );
}

////////////////////////////////////////////////////////////////////////////////////////////////
// VSMシャドウマップ関連の処理

#ifndef MMDSHADOWMAPDRAW

// 制御パラメータ
#define MMDShadow_CTRLFILENAME  "MMDShadow.x"
bool MMDShadow_Valid  : CONTROLOBJECT < string name = MMDShadow_CTRLFILENAME; >;

// ぼかし強度
float MMDShadow_AcsSi : CONTROLOBJECT < string name = MMDShadow_CTRLFILENAME; string item = "Si"; >;
float MMDShadow_BlurUp   : CONTROLOBJECT < string name = "(self)"; string item = "ShadowBlur+"; >;
float MMDShadow_BlurDown : CONTROLOBJECT < string name = "(self)"; string item = "ShadowBlur-"; >;
static float MMDShadow_ShadowBulrPower = max((MMDShadow_AcsSi * 0.1f + 5.0f*MMDShadow_BlurUp)*(1.0f - MMDShadow_BlurDown), 0.0f);

// 影濃度
float MMDShadow_AcsTr : CONTROLOBJECT < string name = MMDShadow_CTRLFILENAME; string item = "Tr"; >;
float MMDShadow_AcsX  : CONTROLOBJECT < string name = MMDShadow_CTRLFILENAME; string item = "X"; >;
float MMDShadow_DensityUp   : CONTROLOBJECT < string name = "(self)"; string item = "ShadowDen+"; >;
float MMDShadow_DensityDown : CONTROLOBJECT < string name = "(self)"; string item = "ShadowDen-"; >;
static float MMDShadow_Density = max(((MMDShadow_AcsX+1.0f) * MMDShadow_AcsTr + 5.0f*MMDShadow_DensityUp)*(1.0f - MMDShadow_DensityDown), 0.0f);

// MMDShadowによるシャドウマップバッファ
shared texture MMD_ShadowMap : OFFSCREENRENDERTARGET;
sampler MMDShadow_ShadowMapSamp = sampler_state {
    texture = <MMD_ShadowMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

#if UseSoftShadow==1

    // シャドウマップの周辺サンプリング回数
    #define BASESMAP_COUNT  4

    // シャドウマップバッファサイズ
    #define SMAPSIZE_WIDTH   ShadowMapSize
    #define SMAPSIZE_HEIGHT  ShadowMapSize

    // シャドウマップのサンプリング間隔
    static float2 MMDShadow_SMapSampStep = float2(MMDShadow_ShadowBulrPower/SMAPSIZE_WIDTH, MMDShadow_ShadowBulrPower/SMAPSIZE_HEIGHT);

    // シャドウマップの周辺サンプリング1
    float2 MMDShadow_GetZPlotSampleBase1(float2 Tex, float smpScale)
    {
        float2 smpStep = MMDShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // シャドウマップの周辺サンプリング2
    float2 MMDShadow_GetZPlotSampleBase2(float2 Tex, float smpScale)
    {
        float2 smpStep = MMDShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(MMDShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // セルフシャドウの遮蔽確率を求める
    float MMDShadow_GetSelfShadowRate(float2 SMapTex, float z, bool ParthFlag)
    {
        // シャドウマップよりZプロットの統計処理(zplot.x:平均, zplot.y:2乗平均)
        float2 zplot = float2(0,0);
        float rate = 1.0f;
        float sumRate = 0.0f;
        [unroll]
        for(int i=0; i<BASESMAP_COUNT; i+=2) {
            rate *= 0.5f; sumRate += rate;
            zplot += MMDShadow_GetZPlotSampleBase1(SMapTex, float(i+1)) * rate;
            rate *= 0.5f; sumRate += rate;
            zplot += MMDShadow_GetZPlotSampleBase2(SMapTex, float(i+2)) * rate;
        }
        zplot /= sumRate;

        // 影部判定(VSM:Variance Shadow Maps法)
        float variance = max( zplot.y - zplot.x * zplot.x, 0.001f );
        float comp = variance / (variance + max(z - zplot.x, 0.0f));

        comp = smoothstep(0.1f/max(MMDShadow_ShadowBulrPower, 1.0f), 1.0f, comp);
        return (1.0f-(1.0f-comp) * min(MMDShadow_Density, 1.0f));
    }

#else

    #define MMDShadow_SKII1  1500
    #define MMDShadow_SKII2  8000

    // セルフシャドウの遮蔽確率を求める(ソフトシャドウを使わない場合)
    float MMDShadow_GetSelfShadowRate(float2 SMapTex, float z, bool ParthFlag)
    {
        float comp;
        float dist = max( min(z, 1.0f) - tex2D(MMDShadow_ShadowMapSamp, SMapTex).r, 0.0f );
        if(ParthFlag) {
            // セルフシャドウ mode2
            comp = 1.0f - saturate( dist * MMDShadow_SKII2 * SMapTex.y - 0.3f );
        } else {
            // セルフシャドウ mode1
            comp = 1.0f - saturate( dist * MMDShadow_SKII1 - 0.3f);
        }

        return (1.0f-(1.0f-comp) * min(MMDShadow_Density, 1.0f));
    }

#endif

float MMDShadow_ObjTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

struct MMDShadow_COLOR {
    float4 Color;        // オブジェクト色
    float4 ShadowColor;  // 影色
};

// 影色に濃度を加味する
MMDShadow_COLOR MMDShadow_GetShadowDensity(float4 Color, float4 ShadowColor, bool useToon, float LightNormal)
{
    MMDShadow_COLOR Out;
    Out.Color = Color;
    Out.ShadowColor = ShadowColor;

    if( !useToon || length(Color.rgb-ShadowColor.rgb) > 0.01f ){
        float e = max(MMDShadow_Density, 1.0f);
        float s = 1.0f - 0.3f * smoothstep(3.0f, 6.0f, e);
        Out.ShadowColor = saturate(float4(pow(max(ShadowColor.rgb*s, float3(0.001f, 0.001f, 0.001f)), e), ShadowColor.a));
    }
    if( !useToon ){
        float e = lerp( max(MMDShadow_Density, 1.0f), 1.0f, smoothstep(0.0f, 0.4f, LightNormal) );
        float s = 1.0f - 0.3f * smoothstep(3.0f, 6.0f, e);
        Out.Color = saturate(float4(pow(max(Color.rgb*s, float3(0.001f, 0.001f, 0.001f)), e), Color.a));
        #ifndef MIKUMIKUMOVING
        Out.Color.a *= MMDShadow_ObjTr;
        Out.ShadowColor.a *= MMDShadow_ObjTr;
        #endif
    }

    return Out;
}

#endif
#endif
