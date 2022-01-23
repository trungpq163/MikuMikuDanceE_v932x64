////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PowerDOF.fx ver0.0.5  被写界深度エフェクト
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータスイッチ

#define FrontPowerBlur  0   // 前ボケのぼかし方法
// 0 : 描画速度優先、強いぼかしを掛けると縞模様が出ます。
// 1 : かなり強力なぼかしもきれい掛けられますが描画速度は落ちる。


#define UseHDR  0   // HDRレンダリングの有無
// 0 : 通常の256階調で処理
// 1 : 高照度情報をそのまま処理、ぼかしたところにグレア効果が出る。


#define UseMLAA  0   // MLAA法による被写体のアンチエイリアシング処理
// 0 : 処理しない、描画速度優先、後ボケとピントがあった被写体の境界にジャギーが出る。
// 1 : 処理する、被写体の境界はきれいになるが描画速度は落ちる。



// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX    "PDOF_Depth.fxsub"
    #define MLAA_TEX_FORMAT "D3DFMT_A4R4G4B4"
    #define AF_PAPAM1        100.0f
    #define AF_PAPAM2        20.0f
    #define COEF_BLUR_POWER  1.0f
#else
    #define OFFSCREEN_FX    "PDOF_DepthMMM.fxsub"
    #define MLAA_TEX_FORMAT "D3DFMT_A8R8G8B8"
    #define AF_PAPAM1        10.0f
    #define AF_PAPAM2        10.0f
    #define COEF_BLUR_POWER  0.5f
#endif

#if FrontPowerBlur==1
    #define FRONT_RERERT_COUNT  3
    #define FRONT_MIPLEVEL      1
    #define FRONT_MIPFILTER     NONE
#else
    #define FRONT_RERERT_COUNT  1
    #define FRONT_MIPLEVEL      0
    #define FRONT_MIPFILTER     LINEAR
#endif

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#define AF_FLIENAME   "PDOF_AutoFocus.x"
bool flagAF : CONTROLOBJECT < string name = AF_FLIENAME; >;
float AcsX  : CONTROLOBJECT < string name = AF_FLIENAME; string item = "X"; >;
float AcsY  : CONTROLOBJECT < string name = AF_FLIENAME; string item = "Y"; >;
float AcsRx : CONTROLOBJECT < string name = AF_FLIENAME; string item = "Rx"; >;
float AcsRy : CONTROLOBJECT < string name = AF_FLIENAME; string item = "Ry"; >;
static float AF_ElasticFactor = clamp(AF_PAPAM1 + degrees(AcsRx), 1.0f, 1000.0f);  // オートフォーカス合焦距離追従の弾性度
static float AF_ResistFactor  = clamp(AF_PAPAM2 + degrees(AcsRy), 0.1f, 100.0f);   // オートフォーカス合焦距離追従の抵抗度

float time : TIME;

int RepertCount = 3;  // 描画反復回数
int RepertCountF = FRONT_RERERT_COUNT;  // 前ボケ描画反復回数
int RepertIndex;      // 描画反復回数のカウンタ

#define DEPTH_FAR   5000.0f  // 深度最遠値
#define FOCUS_AREA  0.15f    // ピントが合う範囲
#define SAMP_NUM    8        // MLAA法の一方向のサンプリング数

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
float WT_COEF[8] = { 0.0920246,
                     0.0902024,
                     0.0849494,
                     0.0768654,
                     0.0668236,
                     0.0558158,
                     0.0447932,
                     0.0345379 };

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 AASmpStep = float2(1,1) / ViewportSize;

// 座標パラメータ
float4x4 WorldMatrix  : WORLD;
float4x4 ProjMatrix   : PROJECTION;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// カメラ操作のパースペクティブフラグ
static bool IsParth = ProjMatrix._44 < 0.5f;

// 深度マップ描画先オフスクリーンバッファ
texture PDOF_DepthRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for PowerDOF.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0f;
    string Format = "D3DFMT_R32F";
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* =" OFFSCREEN_FX ";"
    ;
>;
sampler DepthMapSmp = sampler_state {
    texture = <PDOF_DepthRT>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0f;

#if UseHDR==0
    #define TEX_FORMAT "D3DFMT_A8R8G8B8"
#else
    #define TEX_FORMAT "D3DFMT_A16B16G16R16F"
    //#define TEX_FORMAT "D3DFMT_A32B32G32R32F"
#endif

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 前ボケ描画結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = FRONT_MIPLEVEL;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = FRONT_MIPFILTER;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 前ボケ用深度マップを記録するためのレンダーターゲット
texture DepthMapBuff : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R32F";
>;
sampler DepthMapBuffSmp = sampler_state {
    texture = <DepthMapBuff>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 前ボケ用深度マップのX方向のぼかし結果を記録するためのレンダーターゲット
texture DepthMapBuff2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R32F";
>;
sampler DepthMapBuffSmp2 = sampler_state {
    texture = <DepthMapBuff2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

#if UseMLAA==1
// 輪郭抽出結果を記録するためのレンダーターゲット
texture2D OutlineMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = MLAA_TEX_FORMAT;
>;
sampler2D OutlineMapSamp = sampler_state {
    texture = <OutlineMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

// オートフォーカスの合焦距離記録用
texture AutoFocusTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler AutoFocusSmp = sampler_state
{
   Texture = <AutoFocusTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture AutoFocusDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D24S8";
>;


// 光学パラメータ(適当)
static float3 FocusPos = WorldMatrix._41_42_43;   // マニュアルフォーカスの合焦位置
static float2 AutoFocusPos = saturate( float2(0.5f+0.5f*AcsX, 0.5f-0.5f*AcsY) ); // オートフォーカスするスクリーン座標
static float FocusDistance = flagAF ? tex2D(AutoFocusSmp, float2(0.5f,0.5f)).x : length(FocusPos - CameraPosition); // 合焦距離
static float DiaphragmVal = 0.25f * sqrt(AcsSi*0.1f);            // 絞り値(ぼかしの基準値)
static float FocusLength = max(FOCUS_AREA * FocusDistance / pow(AcsSi * 0.1f, 0.25f), 5.0f); // ピントが合う範囲
static float FocusFar = FocusDistance + FocusLength;             // 被写界深度の後端
static float FocusNear = max(FocusDistance - FocusLength, 0.1f); // 被写界深度の前端

////////////////////////////////////////////////////////////////////////////////////////////////

// 深度マップの読み取り
float GetDepth(float2 Tex)
{
    return tex2D( DepthMapSmp, Tex ).r * DEPTH_FAR;
}

// 後ボケのぼかし強度
float BackBlurPower(float dep)
{
    float blurLength = FocusFar * pow(6.0f, RepertIndex);
    float pixLen = max( DiaphragmVal * (dep - FocusFar) / blurLength, 0.0f);
    float viewLen = IsParth ? ProjMatrix._22 / dep : max(0.001f/ProjMatrix._11, 0.0001f);
    float blurPower = ViewportSize.y * pixLen * viewLen / 8.0f;
    return blurPower * COEF_BLUR_POWER;
}

// 後ボケのサンプリングレート(手前に位置するサンプルはレートを下げる)
float BackBlurRate(float2 Tex, float dep0)
{
    float dep = GetDepth(Tex);
    float blurLength = FocusFar * pow(6.0f, RepertIndex);
    return saturate( (dep - FocusFar) / clamp(dep0 - FocusFar, 0.0001f, blurLength) );
}

// 前ボケ用深度マップのぼかし強度
float DepthBlurPower()
{
    float dep = 0.9f;
    float dep0 = (1.0f - dep) * FocusDistance;
    float pixLen = DiaphragmVal * dep;
    float viewLen = IsParth ? ProjMatrix._22 / dep0 : max(0.001f/ProjMatrix._11, 0.0001f);
    float blurPower = ViewportSize.y * pixLen * viewLen / 8.0f;
    return blurPower*FocusDistance*0.005f/sqrt(AcsSi*0.1f);
}

// 前ボケのぼかし強度
float FrontBlurPower(float2 Tex)
{
    float dep = tex2D( DepthMapBuffSmp, Tex ).r;
    float dep0 = (1.0f - dep) * FocusDistance;
    float pixLen = DiaphragmVal * dep;
    float viewLen = IsParth ? ProjMatrix._22 / dep0 : max(0.001f/ProjMatrix._11, 0.0001f);
    float blurPower = ViewportSize.y * pixLen * viewLen / 8.0f;
    return blurPower*AcsTr*0.25f/pow(6.0f, RepertIndex);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 後ボケX方向

float4 PS_BackGaussianX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float dep = GetDepth(Tex);
    float SmpStep = BackBlurPower(dep) / ViewportSize.x;

    float rate, sumRate = WT_COEF[0];
    float4 Color = WT_COEF[0] *  tex2D( ScnSamp, Tex );

    // 手前に位置するサンプルはレートを下げて加算
    [unroll]
    for(int i=1; i<8; i++){
        rate = WT_COEF[i] * BackBlurRate(Tex-float2(SmpStep*i,0), dep);
        sumRate += rate;
        Color += rate * tex2D( ScnSamp, Tex-float2(SmpStep*i,0) );

        rate = WT_COEF[i] * BackBlurRate(Tex+float2(SmpStep*i,0), dep);
        sumRate += rate;
        Color += rate * tex2D( ScnSamp, Tex+float2(SmpStep*i,0) );
    }

    Color /= sumRate;

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 後ボケY方向

float4 PS_BackGaussianY(float2 Tex: TEXCOORD0) : COLOR
{
    float dep = GetDepth(Tex);
    float SmpStep = BackBlurPower(dep) / ViewportSize.y;

    float rate, sumRate = WT_COEF[0];
    float4 Color = WT_COEF[0] * tex2D( ScnSamp2, Tex );

    // 手前に位置するサンプルはレートを下げて加算
    [unroll]
    for(int i=1; i<8; i++){
        rate = WT_COEF[i] * BackBlurRate(Tex-float2(0,SmpStep*i), dep);
        sumRate += rate;
        Color += rate * tex2D( ScnSamp2, Tex-float2(0,SmpStep*i) );

        rate = WT_COEF[i] * BackBlurRate(Tex+float2(0,SmpStep*i), dep);
        sumRate += rate;
        Color += rate * tex2D( ScnSamp2, Tex+float2(0,SmpStep*i) );
    }

    Color /= sumRate;

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 前ボケ用深度マップの正規化

float4 PS_InitDepth( float2 Tex: TEXCOORD0 ) : COLOR
{
    float dep = max(FocusNear - GetDepth(Tex), 0.0f) / FocusNear;
    return float4(dep, 0, 0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 前ボケ用深度マップのぼかしX方向

float4 PS_DepthGaussianX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float SmpStep = DepthBlurPower() / ViewportSize.x;

    //float MipLv = log2( max(ViewportSize.x*SmpStep, 1.0f) );
    float MipLv = 0;

    float dep, sumRate = WT_COEF[0];
    float dep0 = tex2Dlod( DepthMapBuffSmp, float4(Tex,0,MipLv) ).r;
    float sumDep = WT_COEF[0] * dep0;

    // 奥側にある深度はサンプリングしない
    [unroll]
    for(int i=1; i<8; i++){
        dep = tex2Dlod( DepthMapBuffSmp, float4(Tex.x-SmpStep.x*i,Tex.y,0,MipLv) ).r;
        sumDep += WT_COEF[i] * dep * step(dep0, dep);
        sumRate += WT_COEF[i] * step(dep0, dep);

        dep = tex2Dlod( DepthMapBuffSmp, float4(Tex.x+SmpStep.x*i,Tex.y,0,MipLv) ).r;
        sumDep += WT_COEF[i] * dep * step(dep0, dep);
        sumRate += WT_COEF[i] * step(dep0, dep);
    }

    dep = sumDep / sumRate;
    return float4(dep, 0, 0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 前ボケ用深度マップのぼかしY方向

float4 PS_DepthGaussianY(float2 Tex: TEXCOORD0) : COLOR
{
    float SmpStep = DepthBlurPower() / ViewportSize.y;

    float dep, sumRate = WT_COEF[0];
    float dep0 = tex2D( DepthMapBuffSmp2, Tex ).r;
    float sumDep = WT_COEF[0] * dep0;

    // 奥側にある深度はサンプリングしない
    [unroll]
    for(int i=1; i<8; i++){
        dep = tex2D( DepthMapBuffSmp2, Tex-float2(0,SmpStep*i) ).r;
        sumDep += WT_COEF[i] * dep * step(dep0, dep);
        sumRate += WT_COEF[i] * step(dep0, dep);

        dep = tex2D( DepthMapBuffSmp2, Tex+float2(0,SmpStep*i) ).r;
        sumDep += WT_COEF[i] * dep * step(dep0, dep);
        sumRate += WT_COEF[i] * step(dep0, dep);
    }

    dep = sumDep / sumRate;
    return float4(dep, 0, 0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 前ボケX方向

float4 PS_FrontGaussianX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float SmpStep = FrontBlurPower(Tex) / ViewportSize.x;

    #if FrontPowerBlur==0
    float MipLv = log2( max(ViewportSize.x*SmpStep, 1.0f) );
    #else
    float MipLv = 0;
    #endif

    float4 Color = WT_COEF[0] * tex2Dlod( ScnSamp3, float4(Tex,0,MipLv) );
    [unroll]
    for(int i=1; i<8; i++){
        Color += WT_COEF[i] * ( tex2Dlod( ScnSamp3, float4(Tex.x-SmpStep.x*i,Tex.y,0,MipLv) )
                              + tex2Dlod( ScnSamp3, float4(Tex.x+SmpStep.x*i,Tex.y,0,MipLv) ) );
    }

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 前ボケY方向

float4 PS_FrontGaussianY(float2 Tex: TEXCOORD0) : COLOR
{
    float SmpStep = FrontBlurPower(Tex) / ViewportSize.y;

    float4 Color = WT_COEF[0] * tex2D( ScnSamp2, Tex );
    [unroll]
    for(int i=1; i<8; i++){
        Color += WT_COEF[i] * ( tex2D( ScnSamp2, Tex+float2(0,SmpStep*i) )
                              + tex2D( ScnSamp2, Tex-float2(0,SmpStep*i) ) );
    }

    return Color;
}


#if UseMLAA==1
////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭抽出

float4 PS_PickupOutline( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 深度
    float dep0 = GetDepth( Tex );
    float depL = GetDepth( Tex-float2(AASmpStep.x,0) );
    float depR = GetDepth( Tex+float2(AASmpStep.x,0) );
    float depB = GetDepth( Tex+float2(0,AASmpStep.y) );
    float depT = GetDepth( Tex-float2(0,AASmpStep.y) );

    // 被写界深度の後端の境界抽出
    float bflagL = (dep0 > FocusFar && FocusFar >= depL);
    float bflagR = (dep0 > FocusFar && FocusFar >= depR);
    float bflagB = (dep0 > FocusFar && FocusFar >= depB);
    float bflagT = (dep0 > FocusFar && FocusFar >= depT);

    return float4(bflagL, bflagR, bflagB, bflagT);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// MLAA法によるアンチエイリアシング処理

// 境界色のブレンド
float4 AAColorBlend(float4 color0, float4 color1, float4 color2, float2 linePt1, float2 linePt2)
{
    float s = 0.0f;

    if(linePt1.y * linePt2.y == 0.0f){
        // L型境界の処理
        float x1 = (linePt1.y == 0.0f) ? max(linePt1.x, linePt2.x-SAMP_NUM-1) : linePt1.x;
        float x2 = (linePt2.y == 0.0f) ? min(linePt2.x, linePt1.x+SAMP_NUM+1) : linePt2.x;
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-x1)/(x2-x1));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-x1)/(x2-x1));
        if(h1 >= 0.0f && h2 >= 0.0f){
            s = 0.5f * (h1 + h2);
        }else if(h1 > 0.0f){
            s = 0.25f * h1;
        }else if(h2 > 0.0f){
            s = 0.25f * h2;
        }
    }else if(linePt1.y * linePt2.y < 0.0f){
        // Z型境界の処理
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        if(h1 >= 0.0f && h2 >= 0.0f){
            s = 0.5f * (h1 + h2);
        }else if(h1 > 0.0f){
            s = 0.25f * h1;
        }else if(h2 > 0.0f){
            s = 0.25f * h2;
        }
    }else if(linePt1.y > 0.0f && linePt2.y > 0.0f){
        // U型境界の処理
        float h1, h2;
        float x0 = (linePt1.x + linePt2.x) * 0.5f;
        if(x0 >= 0.5f){
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(x0-linePt1.x));
            h2 = lerp(linePt1.y, 0.0f, ( 0.5f-linePt1.x)/(x0-linePt1.x));
            s = 0.5f * (h1 + h2);
        }else if(x0 <= -0.5f){
            h1 = lerp(0.0f, linePt2.y, (-0.5f-x0)/(linePt2.x-x0));
            h2 = lerp(0.0f, linePt2.y, ( 0.5f-x0)/(linePt2.x-x0));
            s = 0.5f * (h1 + h2);
        }else{
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(-linePt1.x));
            h2 = lerp(0.0f, linePt2.y,   0.5f           /( linePt2.x));
            s = 0.25f * (h1 + h2);
        }
    }

    color1 = (color1 - color2 * s) / (1.0f - s); // ブレンド色をAA前の色に戻す

    return lerp(color0, color1, s);
}


// LeftRight境界のAA処理
float4 PS_MLAA_LeftRight(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color   = tex2D( ScnSamp, Tex );
    float4 colorL1 = tex2D( ScnSamp, Tex-float2(AASmpStep.x  ,0) );
    float4 colorL2 = tex2D( ScnSamp, Tex-float2(AASmpStep.x*2,0) );
    float4 colorR1 = tex2D( ScnSamp, Tex+float2(AASmpStep.x  ,0) );
    float4 colorR2 = tex2D( ScnSamp, Tex+float2(AASmpStep.x*2,0) );

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Left境界のAA処理
    if(bflag.x > 0.5f){
        // Left境界のジャギー形状解析
        float4 bflag0, bflagL;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0          , AASmpStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x, AASmpStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagL.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0          ,-AASmpStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x,-AASmpStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagL.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Left境界色ブレンド
        Color = AAColorBlend(Color, colorL1, colorL2, linePt1, linePt2);
    }

    // Right境界のAA処理
    if(bflag.y > 0.5f){
        // Right境界のジャギー形状解析
        float4 bflag0, bflagR;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0          , AASmpStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x, AASmpStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagR.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0          ,-AASmpStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x,-AASmpStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagR.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Right境界色ブレンド
        Color = AAColorBlend(Color, colorR1, colorR2, linePt1, linePt2);
    }

    return Color;
}


// BottomTop境界のAA処理
float4 PS_MLAA_BottomTop(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color   = tex2D( ScnSamp2, Tex );
    float4 colorB1 = tex2D( ScnSamp2, Tex+float2(0,AASmpStep.y  ) );
    float4 colorB2 = tex2D( ScnSamp2, Tex+float2(0,AASmpStep.y*2) );
    float4 colorT1 = tex2D( ScnSamp2, Tex-float2(0,AASmpStep.y  ) );
    float4 colorT2 = tex2D( ScnSamp2, Tex-float2(0,AASmpStep.y*2) );

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Bottom境界のAA処理
    if(bflag.z > 0.5f){
        // Bottom境界のジャギー形状解析
        float4 bflag0, bflagB;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x*i, 0          ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x*i, AASmpStep.y) );
            if(bflag0.z < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagB.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x*i, 0          ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x*i, AASmpStep.y) );
            if(bflag0.z < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagB.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Bottom境界色ブレンド
        Color = AAColorBlend(Color, colorB1, colorB2, linePt1, linePt2);
    }

    // Top境界のAA処理
    if(bflag.w > 0.5f){
        // Top境界のジャギー形状解析
        float4 bflag0, bflagT;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x*i, 0          ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2(-AASmpStep.x*i, AASmpStep.y) );
            if(bflag0.w < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagT.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x*i, 0          ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2( AASmpStep.x*i, AASmpStep.y) );
            if(bflag0.w < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagT.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Top境界色ブレンド
        Color = AAColorBlend(Color, colorT1, colorT2, linePt1, linePt2);
    }

    return Color;
    //return tex2D( OutlineMapSamp, Tex );
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////

// スクリーンバッファのコピー
float4 PS_CopyScreen( float2 Tex: TEXCOORD0 ) : COLOR
{
    return tex2D( ScnSamp, Tex );
}


// スクリーンバッファの合成
float4 PS_MixScreen( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 ColorB = tex2D( ScnSamp, Tex );
    float4 ColorF = tex2D( ScnSamp3, Tex );

    float dep = GetDepth(Tex);

    if(dep >= FocusNear){
       float depF = tex2D( DepthMapBuffSmp, Tex ).r;
       float r = clamp(0.1f * AcsSi * sqrt(AcsTr), 0.5f, 100.0f);
       float s = pow( depF, 0.3f*pow(0.45f, log10(r)) );
       ColorF = ColorF * s + ColorB * (1-s);
    }

    return ColorF;
}



////////////////////////////////////////////////////////////////////////////////////////////////
// オートフォーカスの合焦距離計算

// 共通の頂点シェーダ
VS_OUTPUT VS_FocusDepth(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.5f, 0.5f);

    return Out;
}

// 深度更新
float4 PS_FocusDepth(float2 Tex: TEXCOORD0) : COLOR
{
    // オブジェクトの深度
    float4 Pos = tex2D(AutoFocusSmp, Tex);
    if( time < 0.001f ){
        // 0フレーム再生でリセット
        float dep = GetDepth( AutoFocusPos );
        Pos = float4(dep, dep, 0, 0);
    }
    float dep1 = Pos.x;  // 現在の深度
    float dep2 = Pos.y;  // 1フレーム前の深度

    // 1フレームの時間間隔
    float Dt = clamp(time - Pos.z, 0.001f, 0.05f);

    // 深度変更速度
    float Vel = ( dep1  - dep2 ) / Dt;

    // 深度マップの値
    float dep0 = GetDepth( AutoFocusPos );

    // 加速度計算(弾性力+速度抵抗力)
    float Accel = sign(dep0 - dep1) * min(abs(dep0 - dep1), clamp(35000.0f/dep0, 50.0f, 1000.0f))
                  * AF_ElasticFactor - Vel * AF_ResistFactor;
    if(Accel > 0.0f && Vel > 0.0f){
        Accel *= 0.2f + 0.8f * smoothstep(30.0f, 150.0f, dep1);
    }

    // 新しい深度に更新
    dep2 = dep1;
    dep1 += Dt * (Vel + Dt * Accel);

    return float4(dep1, dep2, time, 0);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        // オリジナルの描画
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

        "LoopByCount=flagAF;"
            // オートフォーカスの合焦距離計算
            "RenderColorTarget0=AutoFocusTex;"
                "RenderDepthStencilTarget=AutoFocusDepthBuffer;"
                "Pass=FocusUpdate;"
        "LoopEnd=;"

        // 前ボケ用深度マップ描画
        "RenderColorTarget0=DepthMapBuff;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=DepthInitPass;"

        "LoopByCount=RepertCount;"
        "LoopGetIndex=RepertIndex;"
            // 前ボケ用深度マップのぼかし
            "RenderColorTarget0=DepthMapBuff2;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=DepthGaussian_X;"
            "RenderColorTarget0=DepthMapBuff;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=DepthGaussian_Y;"

            // 後ボケ処理
            "RenderColorTarget0=ScnMap2;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=BackGaussian_X;"
            "RenderColorTarget0=ScnMap;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=BackGaussian_Y;"
        "LoopEnd=;"

        #if UseMLAA==1
        // 被写界深度の後端のアンチエイリアシング処理
        "RenderColorTarget0=OutlineMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=PickupOutline;"
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=MLAA_LeftRight;"
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=MLAA_BottomTop;"
        #endif

        // スクリーンバッファのコピー
        "RenderColorTarget0=ScnMap3;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "Pass=FrontCopyPass;"

        "LoopByCount=RepertCountF;"
        "LoopGetIndex=RepertIndex;"
            // 前ボケ処理
            "RenderColorTarget0=ScnMap2;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=FrontGaussian_X;"
            "RenderColorTarget0=ScnMap3;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=FrontGaussian_Y;"
        "LoopEnd=;"

        // 描画結果書き出し
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=MixPass;"
    ; >
{
    pass FocusUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 VS_FocusDepth();
        PixelShader  = compile ps_2_0 PS_FocusDepth();
    }
    pass DepthInitPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_InitDepth();
    }
    pass DepthGaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DepthGaussianX();
    }
    pass DepthGaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DepthGaussianY();
    }
    pass BackGaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_BackGaussianX();
    }
    pass BackGaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_BackGaussianY();
    }
    #if UseMLAA==1
    pass PickupOutline < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_PickupOutline();
    }
    pass MLAA_LeftRight < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_MLAA_LeftRight();
    }
    pass MLAA_BottomTop < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_MLAA_BottomTop();
    }
    #endif
    pass FrontGaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_FrontGaussianX();
    }
    pass FrontGaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_FrontGaussianY();
    }
    pass FrontCopyPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_CopyScreen();
    }
    pass MixPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_MixScreen();
    }
}



////////////////////////////////////////////////////////////////////////////////////////////////
