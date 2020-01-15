////////////////////////////////////////////////////////////////////////////////////////////////
//
//  カメラ光学系統合エフェクト
//  作成: そぼろ
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ


// DOFパラメータ //////////////////////////////////////////////////////////

// ぼかし範囲(大きくしすぎると縞が出ます)
float DOF_Extent
<
   string UIName = "DOF_Extent";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.002;
> = float( 0.0005 );

//ぼかし制限値
float DOF_BlurLimit
<
   string UIName = "DOF_BlurLimit";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = 6;


float ShallowDOFPower
<
   string UIName = "ShallowDOFPower";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 15.0;
> = 5;


//手前側DOFループ数
#define DOF_Shallow_LOOP 5

#define DOF_EXPBLUR 0

// モーションブラーパラメータ //////////////////////////////////////////////

// ぼかし強度(大きくしすぎると縞が出ます)
float DirectionalBlurStrength <
   string UIName = "DirBlur";
   string UIWidget = "Slider";
   string UIHelp = "モーションブラーぼかし強度";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 2.0;
> = 0.4;

//残像長さ
float LineBlurLength <
   string UIName = "LineBlurLen";
   string UIWidget = "Slider";
   string UIHelp = "残像長さ";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 4;
> = 1.5;

//残像濃さ
float LineBlurStrength <
   string UIName = "LineBlurStr";
   string UIWidget = "Slider";
   string UIHelp = "残像濃さ";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 2;
> = 1;

//速度の上限値
float VelocityLimit <
   string UIName = "VelocityLimit";
   string UIWidget = "Slider";
   string UIHelp = "速度の上限値";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 0.5;
> = 0.12;

//速度の下限値
float VelocityUnderCut <
   string UIName = "VelocityUnder";
   string UIWidget = "Slider";
   string UIHelp = "速度の下限値";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 0.02;
> = 0.006;

//シーン切り替え閾値
float SceneChangeThreshold <
   string UIName = "SCThreshold";
   string UIWidget = "Slider";
   string UIHelp = "シーン切り替え判定の移動量閾値";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 100;
> = 20;

//シーン切り替え角度閾値
float SceneChangeAngleThreshold <
   string UIName = "SCAngle";
   string UIWidget = "Slider";
   string UIHelp = "シーン切り替え判定の角度閾値";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 90;
> = 25;

//ラインブラーの解像度を倍にします。1で有効、0で無効
#define LINEBLUR_QUAD  1


// AutoLuminousパラメータ ////////////////////////////////////////////////

#ifdef MIKUMIKUMOVING

int Glare <
   string UIName = "Glare";
   string UIWidget = "Slider";
   string UIHelp = "光芒の数を指定します。";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 6;
> = 0;

#endif

//MMM用グレア角度
float GlareAngle2 <
   string UIName = "GlareAngle";
   string UIWidget = "Slider";
   string UIHelp = "光芒角度";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 180;
> = 0.0;

//MMM用グレア長さ
float GlareLength <
   string UIName = "GlareLength";
   string UIWidget = "Slider";
   string UIHelp = "光芒長さ";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 2.0;
> = 1.0;


//MMM用発光強度
float Power2 <
   string UIName = "LightPower";
   string UIWidget = "Slider";
   string UIHelp = "発光強度";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 20;
> = 1.0;

// ぼかし範囲
float AL_Extent <
   string UIName = "AL_Extent";
   string UIWidget = "Slider";
   string UIHelp = "発光ぼかし範囲";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 0.2;
> = 0.07;


//グレア強度　1.0前後
float GlarePower <
   string UIName = "GlarePower";
   string UIWidget = "Slider";
   string UIHelp = "グレア強度";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 3;
> = 1.2;

//白飛び係数　0～1
float OverExposureRatio <
   string UIName = "OverExposure";
   string UIWidget = "Slider";
   string UIHelp = "白飛び係数";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 3;
> = 0.85;

//弱光減衰　0～1
float Modest <
   string UIName = "Modest";
   string UIWidget = "Slider";
   string UIHelp = "弱い光があまり拡散しなくなります";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 2.0;
> = 1.0;

#ifdef MIKUMIKUMOVING

float ScreenToneCurve <
   string UIName = "ToneCurve";
   string UIWidget = "Slider";
   string UIHelp = "トーンカーブ変更";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 1;
> = 0;

#endif



//残像強度　0～50程度　0で無効
#define AFTERGLOW  0

//一方向のサンプリング数
#define AL_SAMP_NUM   6

//グレアの一方向のサンプリング数
#define AL_SAMP_NUM2  12




//DOFのサンプリング数
#define LightDOF_SAMP_NUM  4


//編集中の点滅をフレーム数に同期させる
//trueだとフレーム数に応じて光の強さが変化
//falseだと編集中も点滅し続けます
#define SYNC false

//トーンカーブの適用を強制
//0がオフ、1がオンです
//ToneCurve.xを読み込むのが面倒であればオンにします
#define SCREEN_TONECURVE  0

//グレアを１方向だけ強調します
//0がオフ、1がオンです
//グレアのサンプリング数もそれに応じて増やします
#define GLARE_LONGONE  0

//厳密アルファ出力モード
//MMD上での表示はおかしくなりますが、動画や画像出力としては
//厳密に正しいアルファ付きデータが得られます
//現在のところ、モーションブラーやDOF要素には適用されません
//0がオフ、1がオンです
#define ALPHA_OUT  0



// 魚眼レンズパラメータ ////////////////////////////////////////////////


//魚眼レンズエフェクトを有効にします　1で有効、0で無効
#define FISHEYE_ENABLE 0


#if FISHEYE_ENABLE!=0
    
    //レンズ歪み強度
    float FishEyeStregth <
       string UIName = "FishEye";
       string UIWidget = "Slider";
       string UIHelp = "レンズ歪み強度";
       bool UIVisible =  true;
       float UIMin = 0;
       float UIMax = 3;
    > = 0.9;

    //黒ベタ追加サイズ
    float BetaSize <
       string UIName = "Beta";
       string UIWidget = "Slider";
       string UIHelp = "黒ベタ追加サイズ";
       bool UIVisible =  true;
       float UIMin = 0;
       float UIMax = 1;
    > = 0.095;

#endif


// 共通パラメータ //////////////////////////////////////////////////////


//簡易色調補正・ホワイトバランス調整用
//const float3 ColorCorrection = float3( 1, 1, 1 );

//一方向のサンプリング数
#define SAMP_NUM   8

//背景色
const float4 BackColor <
   string UIName = "BackColor";
   string UIWidget = "Color";
   string UIHelp = "背景色";
   bool UIVisible =  true;
> = float4( 0, 0, 0, 0 );



///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと


//スケール係数
#define SCALE_VALUE 4

//int LightSamplingLoopIndex = 0;
int AL_LoopIndex = 0;

int ShallowBlurLoopIndex = 0;
int ShallowBlurLoopCount = DOF_Shallow_LOOP;


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


#define PI 3.14159
#define DEG_TO_RAD (PI / 180)


#define VPRATIO 1.0



//オートフォーカスの使用
bool UseAF : CONTROLOBJECT < string name = "TCLXAutoFocus.x"; >;
float3 AFPos : CONTROLOBJECT < string name = "TCLXAutoFocus.x"; >;
float AFScale : CONTROLOBJECT < string name = "TCLXAutoFocus.x"; >;

//マニュアルフォーカスの使用
bool UseMF : CONTROLOBJECT < string name = "TCLXManualFocus.x"; >;
float MFScale : CONTROLOBJECT < string name = "TCLXManualFocus.x"; >;
float4x4 MFWorld : CONTROLOBJECT < string name = "TCLXManualFocus.x"; >; 
static float MF_y = MFWorld._42;


//フォーカスの使用
bool FocusEnable : CONTROLOBJECT < string name = "TCLX_Focus.x"; >;
float FocusMode : CONTROLOBJECT < string name = "TCLX_Focus.x"; string item = "Ry"; >;
float FocusDeep : CONTROLOBJECT < string name = "TCLX_Focus.x"; string item = "Tr"; >;
float FocusScale : CONTROLOBJECT < string name = "TCLX_Focus.x"; >;
float4x4 FocusWorld : CONTROLOBJECT < string name = "TCLX_Focus.x"; >;
static float FocusY = FocusWorld._42;

//static float DOF_scaling = (UseMF ? MFScale : (UseAF ? AFScale : 0)) * 0.05;
static float DOF_scaling = FocusScale * 0.05;


//視野角によりぼかし強度可変
float4x4 ProjMatrix      : PROJECTION;
static float viewangle = atan(1 / ProjMatrix[0][0]);
static float viewscale = (45 / 2 * DEG_TO_RAD) / viewangle;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

//ぼかしサンプリング間隔
static float2 DOF_SampStep = (float2(DOF_Extent,DOF_Extent)/ViewportSize*ViewportSize.y);
static float2 DOF_SampStepScaled = DOF_SampStep  * DOF_scaling * viewscale / SAMP_NUM * 8.0;

static float DOF_BlurLimitScaled = DOF_BlurLimit / DOF_scaling;



// アルファ取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 
static float pos_y = matWorld._42;
static float pos_z = matWorld._43;

static float OverLight = (pos_y + 100) / 100;


// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1 * (1.0 + pos_z / 100) * Power2;

// X回転
float3 rot : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;

static float Power3 = scaling * (1.0 + pos_z / 100) * Power2;

//光芒の数

#ifndef MIKUMIKUMOVING

float Glare : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;

#endif

//光芒の長さ
static float GlareAspect = (rot.y * 180 / PI + 100) / 100.0 * GlareLength;

//光芒角度
static float GlareAngle = rot.x + GlareAngle2 * PI / 180.0;


#ifndef MIKUMIKUMOVING
    #if SCREEN_TONECURVE==0
        bool ScreenToneCurve : CONTROLOBJECT < string name = "ToneCurve.x"; >;
    #else
        bool ScreenToneCurve = true;
    #endif
#endif

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;

static float timerate = (rot.z > 0) ? ((1 + cos(ftime * 2 * PI / (rot.z / PI * 180))) * 0.4 + 0.2)
                     : ((rot.z < 0) ? (frac(ftime / (-rot.z / PI * 180)) < 0.5) : 1.0);


//static float2 AL_SampStep = (float2(AL_Extent,AL_Extent) / ViewportSize * ViewportSize.y);
static float2 AL_SampStep = (AL_Extent * float2(1/ViewportAspect, 1));
static float2 AL_SampStepScaled = AL_SampStep * alpha1 / (float)AL_SAMP_NUM * 0.08;

static float AL_SampStep2 = AL_Extent * alpha1 / (float)AL_SAMP_NUM2 * GlareAspect;



bool ExternLightSampling : CONTROLOBJECT < string name = "LightSampling.x"; >;


bool TestMode : CONTROLOBJECT < string name = "AL_Test.x"; >;
float TestValue : CONTROLOBJECT < string name = "AL_Test.x"; >;




static float2 MBlurSampStep = (float2(DirectionalBlurStrength, DirectionalBlurStrength)/ViewportSize*ViewportSize.y);
static float2 MBlurSampStepScaled = MBlurSampStep * 1 / SAMP_NUM * 8;


////////////////////////////////////////////////////////////////////////////////////

//ベロシティマップバッファフォーマット
#define VM_TEXFORMAT "A32B32G32R32F"
//#define VM_TEXFORMAT "A16B16G16R16F"

//描画バッファフォーマット
//#define DB_TEXFORMAT "A8R8G8B8"
#define DB_TEXFORMAT "A16B16G16R16F" //HDR化
//#define DB_TEXFORMAT "A32B32G32R32F" //HDR化

//発光バッファフォーマット
#define AL_TEXFORMAT "D3DFMT_A16B16G16R16F"

////////////////////////////////////////////////////////////////////////////////////

#define TEXSIZE1  1
#define TEXSIZE2  0.5
#define TEXSIZE3  0.25
#define TEXSIZE4  0.125
#define TEXSIZE5  0.0625


///////////////////////////////////////////////////////////////////////////////////////////////
// 光放射オブジェクト描画先

texture AL_EmitterRT: OFFSCREENRENDERTARGET <
    string Description = "EmitterDrawRenderTarget for AutoLuminous";
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int MipLevels = 0;
    string Format = AL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        
        //------------------------------------
        //セレクタエフェクトはここで指定します
        
        
        
        //------------------------------------
        
        //"*=hide"
        "* = AL_Object.fxsub;" 
    ;
>;


sampler EmitterView = sampler_state {
    texture = <AL_EmitterRT>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

////////////////////////////////////////////////////////////////////////////////////////////////

// 高輝度部分を記録するためのレンダーターゲット
texture2D HighLight : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 0;
    string Format = AL_TEXFORMAT ;
    
>;
sampler2D HighLightView = sampler_state {
    texture = <HighLight>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Border;
    AddressV = Border;
};

// 外部から高輝度部分を取得するためのレンダーターゲット
shared texture2D ExternalHighLight : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
    
>;
sampler2D ExternalHighLightView = sampler_state {
    texture = <ExternalHighLight>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = NONE;
    AddressU  = Border;
    AddressV = Border;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX = sampler_state {
    texture = <ScnMapX>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut = sampler_state {
    texture = <ScnMapOut>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX2 = sampler_state {
    texture = <ScnMapX2>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut2 = sampler_state {
    texture = <ScnMapOut2>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX3 = sampler_state {
    texture = <ScnMapX3>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut3 = sampler_state {
    texture = <ScnMapOut3>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX4 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX4 = sampler_state {
    texture = <ScnMapX4>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut4 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut4 = sampler_state {
    texture = <ScnMapOut4>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX5 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX5 = sampler_state {
    texture = <ScnMapX5>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut5 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut5 = sampler_state {
    texture = <ScnMapOut5>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// グレアを記録するためのレンダーターゲット
texture2D ScnMapGlare : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampGlare = sampler_state {
    texture = <ScnMapGlare>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};



////////////////////////////////////////////////////////////////////////////////////////////////

//深度付きベロシティマップ作成
shared texture DVMapDraw: OFFSCREENRENDERTARGET <
    string Description = "Depth && Velocity Map Drawing";
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    float4 ClearColor = { 0.5, 0.5, 100, 1 };
    float ClearDepth = 1.0;
    string Format = VM_TEXFORMAT ;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = TCLX_Object.fxsub;"
        ;
>;

sampler DVSampler = sampler_state {
    texture = <DVMapDraw>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};


// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    string Format = "D24S8";
>;
texture2D DepthBuffer2 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    string Format = "D24S8";
>;
texture2D DepthBuffer3 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    string Format = "D24S8";
>;
texture2D DepthBuffer4 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    string Format = "D24S8";
>;
texture2D DepthBuffer5 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    int MipLevels = 0;
    string Format = DB_TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    int MipLevels = 1;
    string Format = DB_TEXFORMAT;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


//ラインブラー出力バッファ

#if LINEBLUR_QUAD==0
    #define LINEBLUR_GRIDSIZE 128
    #define LINEBLUR_BUFSIZE  256
#else
    #define LINEBLUR_GRIDSIZE 256
    #define LINEBLUR_BUFSIZE  512
    
    int loopindex = 0;
    int loopcount = 4;
    
#endif

texture2D LineBluerDepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width = LINEBLUR_BUFSIZE;
    int Height = LINEBLUR_BUFSIZE;
    string Format = "D24S8";
>;
texture2D LineBluerTex : RENDERCOLORTARGET <
    int Width = LINEBLUR_BUFSIZE;
    int Height = LINEBLUR_BUFSIZE;
    int MipLevels = 1;
    string Format = DB_TEXFORMAT;
>;
sampler2D LineBluerSamp = sampler_state {
    texture = <LineBluerTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D LineBluerInfoTex : RENDERCOLORTARGET <
    int Width = LINEBLUR_BUFSIZE;
    int Height = LINEBLUR_BUFSIZE;
    int MipLevels = 1;
    string Format = VM_TEXFORMAT;
>;
sampler2D LineBluerInfoSamp = sampler_state {
    texture = <LineBluerInfoTex>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//元スクリーン参照時のミップレベル
static float ScnMipLevel1 = log2(ViewportSize.y / LINEBLUR_GRIDSIZE) + 0.5;
static float ScnMipLevel2 = log2(ViewportSize.y / LINEBLUR_BUFSIZE) + 0.5;


//カメラ位置の記録

#define INFOBUFSIZE 2

float2 InfoBufOffset = float2(0.5 / INFOBUFSIZE, 0.5);

texture CameraBufferMB : RenderDepthStencilTarget <
   int Width=INFOBUFSIZE;
   int Height=1;
    string Format = "D24S8";
>;
texture CameraBufferTex : RenderColorTarget
<
    int Width=INFOBUFSIZE;
    int Height=1;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;

float4 CameraBuffer[INFOBUFSIZE] : TEXTUREVALUE <
    string TextureName = "CameraBufferTex";
>;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;
float3 CameraDirection : DIRECTION < string Object = "Camera"; >;

//シーン切り替えかどうか判別
static bool IsSceneChange = (length(CameraPosition - CameraBuffer[0].xyz) > SceneChangeThreshold)
                            || (dot(CameraDirection, CameraBuffer[1].xyz) < cos(SceneChangeAngleThreshold * 3.14 / 180));




////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//DOFぼかし強度マップ取得関数群

float DOF_GetDepthMap(float2 screenPos){
    return tex2Dlod( DVSampler, float4(screenPos, 0, 0) ).z;
    
}

// 焦点より奥側 ////////////////////////////////////////////

float DOF_DeepDepthToBlur(float depth){
    float blrval = max(depth - (1.0 / SCALE_VALUE), 0);
    blrval = pow(blrval, 0.6);
    return blrval;
}

float GetDeepBlurMap(float2 screenPos){
    float depth = DOF_GetDepthMap(screenPos);
    float blr = DOF_DeepDepthToBlur(depth);
    blr = min(DOF_BlurLimitScaled, blr);
    return blr;
}


// 焦点より手前側 ////////////////////////////////////////////

float DOF_GetShallowBlurMap(float2 screenPos){
    float depth = DOF_GetDepthMap(screenPos);
    float blr = max((depth - (1.0 / SCALE_VALUE)) * -SCALE_VALUE, 0);
    
    return blr;
}

float DOF_ShallowBlurLoopValue(){
    float val = (float)(ShallowBlurLoopIndex + 1) / DOF_Shallow_LOOP;
    val = pow(val, 1 + ShallowDOFPower * 0.1);
    return val;
}

float DOF_GetShallowBlurMapLoopAlpha(float2 screenPos){
    float blrval = DOF_GetShallowBlurMap(screenPos);
    float blrtgt = DOF_ShallowBlurLoopValue();
    //blrval = sqrt(blrval);
    blrtgt = sqrt(blrtgt);
    return max(0, 1.0 - (abs(blrval - blrtgt) * (float)ShallowBlurLoopCount));
}


////////////////////////////////////////////////////////////////////////////////////////////////

float DOF_BlurRate(float blr_samp, float blr_cnt){
    float r = blr_samp / blr_cnt;
    return pow(saturate(r), 2);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// バッファのコピー

float4 PS_BufCopy( float2 Tex: TEXCOORD0 , uniform sampler2D samp ) : COLOR {   
    return tex2Dlod( samp , float4(Tex, 0, 0) );
}


////////////////////////////////////////////////////////////////////////////////////////////////
//深度付きベロシティマップ参照関数群

#define VELMAP_SAMPLER  DVSampler
#define MB_DEPTH w

//マップ格納情報から速度ベクトルを得る
float2 MB_VelocityPreparation(float4 rawvec){
    float2 vel = rawvec.xy - 0.5;
    float len = length(vel);
    vel = max(0, len - VelocityUnderCut) * normalize(vel);
    
    vel = min(vel, float2(VelocityLimit, VelocityLimit));
    vel = max(vel, float2(-VelocityLimit, -VelocityLimit));
    
    return vel;
}

float2 MB_GetBlurMap(float2 Tex){
    return MB_VelocityPreparation(tex2Dlod( VELMAP_SAMPLER, float4(Tex, 0, 0) ));
}

float MB_GetDepthMap(float2 Tex){
    return tex2Dlod( VELMAP_SAMPLER, float4(Tex, 0, 0) ).MB_DEPTH;
}

float2 MB_GetBlurMapAround(float2 Tex){
    float4 vm, vms;
    const float step = 4.5 / LINEBLUR_BUFSIZE;
    float z0, n = 1;
    
    vms = tex2Dlod( VELMAP_SAMPLER, float4(Tex, 0, 0) );
    
    z0 = vms.MB_DEPTH;
    
    vm = tex2Dlod( VELMAP_SAMPLER, float4( Tex.x + step, Tex.y , 0, 0) );
    vms += vm * (vm.MB_DEPTH >= z0);
    n += (vm.MB_DEPTH >= z0);
    
    vm = tex2Dlod( VELMAP_SAMPLER, float4( Tex.x - step, Tex.y , 0, 0) );
    vms += vm * (vm.MB_DEPTH >= z0);
    n += (vm.MB_DEPTH >= z0);
    
    vm = tex2Dlod( VELMAP_SAMPLER, float4( Tex.x, Tex.y + step , 0, 0) );
    vms += vm * (vm.MB_DEPTH >= z0);
    n += (vm.MB_DEPTH >= z0);
    
    vm = tex2Dlod( VELMAP_SAMPLER, float4( Tex.x, Tex.y - step , 0, 0) );
    vms += vm * (vm.MB_DEPTH >= z0);
    n += (vm.MB_DEPTH >= z0);
    
    vms /= n;
    
    return MB_VelocityPreparation(vms);
}



////////////////////////////////////////////////////////////////////////////////////////////////
// DOF

////////////////////////////////////////////////////////////////////////////////////////////////
// 奥側ぼかし

float4 PS_DeepDOF( VS_OUTPUT IN , uniform bool Horizontal, uniform sampler2D Samp ) : COLOR {   
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float centerblr = GetDeepBlurMap(IN.Tex);
    float step = (Horizontal ? DOF_SampStepScaled.x : DOF_SampStepScaled.y) * centerblr;
    float depth, centerdepth = DOF_GetDepthMap(IN.Tex) - 0.01;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = IN.Tex + float2(Horizontal, !Horizontal) * (step * (float)i);
        
        //手前かつピントの合っている部分からのサンプリングは弱く
        depth = DOF_GetDepthMap(stex);
        float blrrate = DOF_BlurRate(DOF_DeepDepthToBlur(depth), centerblr);
        e *= max(blrrate, (depth >= centerdepth));
        
        #if DOF_EXPBLUR==0
            sum += tex2D( Samp, stex ) * e;
        #else
            sum += exp(tex2D( Samp, stex )) * e;
        #endif
        
        n += e;
    }
    
    Color = sum / n;
    
    #if DOF_EXPBLUR!=0
        Color = log(Color);
    #endif
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 手前側X方向ぼかし

float4 PS_ShallowDOF_X(float2 Tex: TEXCOORD0) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    float loopval = DOF_ShallowBlurLoopValue();
    float step = DOF_SampStepScaled.x * min(DOF_BlurLimitScaled, loopval) * ShallowDOFPower;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM ; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(1, 0) * (float)i * step;
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        
        float4 org_color = tex2D( ScnSampX , stex );
        org_color.a *= DOF_GetShallowBlurMapLoopAlpha(stex);
        sum += org_color * e;
        n += e;
    }
    
    Color = sum / n;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 手前側X方向ぼかし

float4 PS_ShallowDOF_Y( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    float loopval = DOF_ShallowBlurLoopValue();
    float step = DOF_SampStepScaled.y * min(DOF_BlurLimitScaled, loopval) * ShallowDOFPower;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(0, 1) * (float)i * step;
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        sum += tex2D( ScnSamp2, stex ) * e;
        n += e;
    }
    
    Color = sum / n;
    
    float ar = (2.5 + step * (350 * SAMP_NUM / 8));
    Color.a = saturate(min(Color.a * ar, loopval * ar * 0.4));
    
    //float p = DOF_GetShallowBlurMap(Tex);
    //Color = float4(p,p,p,1);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// MotionBlur
////////////////////////////////////////////////////////////////////////////////////////////////
//ベロシティマップに従い方向性ブラーをかける

struct PS_OUTPUT_DBL
{
   float4 Color0 : COLOR0;
   float4 Color1 : COLOR1;
};

PS_OUTPUT_DBL PS_DirectionalBlur( float2 Tex: TEXCOORD0, uniform sampler2D samp , uniform sampler2D samp2 ) {   
    float e, n = 0;
    float2 stex;
    //float4 Color;
    PS_OUTPUT_DBL Out = (PS_OUTPUT_DBL)0;
    float4 sum = 0, sum2 = 0;
    float2 vel = MB_GetBlurMap(Tex);
    
    float4 info;
    float2 step = MBlurSampStepScaled * vel / SAMP_NUM;
    float depth, centerdepth = MB_GetDepthMap(Tex) - 0.01;
    
    float bp = saturate(length(vel) * 10);
    
    step *= (!IsSceneChange); //シーン切り替えはブラー無効
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = Tex + (step * (float)i);
        
        //手前かつあまり動いていない部分からのサンプリングは弱く
        if(i != 0){
            depth = MB_GetDepthMap(stex);
            e *= max(saturate(length(MB_GetBlurMap(stex)) / 0.02), (depth > centerdepth));
        }
        
        //サンプリング
        sum += tex2D( samp, stex ) * e;
        sum2 += tex2D( samp2, stex ) * e;
        n += e;
    }
    
    Out.Color0 = sum / n;
    Out.Color1 = sum2 / n;
    
    return Out;
    
}



////////////////////////////////////////////////////////////////////////////////////////////////
//ラインブラー出力バッファの初期値設定


struct PS_OUTPUT_CLB
{
   float4 Color : COLOR0;
   float4 Info  : COLOR1;
};

PS_OUTPUT_CLB PS_ClearLineBluer( float2 Tex: TEXCOORD0 ) {
    
    PS_OUTPUT_CLB OUT = (PS_OUTPUT_CLB)0;
    
    //アルファ値を0にした元スクリーン画像で埋める
    OUT.Color = tex2D( ScnSamp, Tex );
    OUT.Color.a = 0;
    
    //ラインブラーで使用する情報マップを出力
    OUT.Info.xy = MB_GetBlurMapAround( Tex );
    OUT.Info.z = MB_GetDepthMap( Tex );
    OUT.Info.w = 1;
    
    return OUT;
}


/////////////////////////////////////////////////////////////////////////////////////
//ラインブラー描画

struct VS_OUTPUT3 {
    float4 Pos: POSITION;
    float4 Color: COLOR0;
    float3 Tex : TEXCOORD0;
    float2 BaseVel : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
};

VS_OUTPUT3 VS_LineBluer(float4 Pos : POSITION, int index: _INDEX)
{
    VS_OUTPUT3 Out;
    float2 PosEx = Pos.xy;
    //bool IsTip = (Pos.x > 0); //ラインの伸びた先端
    
    float findex = Pos.z;
    
#if LINEBLUR_QUAD!=0
    findex += loopindex * (128 * 128);
#endif
    
    float2 findex_xy = float2(findex % LINEBLUR_GRIDSIZE, trunc(findex / LINEBLUR_GRIDSIZE));
    
    float2 TexPos = findex_xy / LINEBLUR_GRIDSIZE;
    float2 ScreenPos = (TexPos * 2 - 1) * float2(1,-1);
    
    //ベロシティマップ参照
    float4 VelMap = tex2Dlod( VELMAP_SAMPLER, float4(TexPos, 0, 0) );
    float2 Velocity = MB_VelocityPreparation(VelMap);
    
    float2 AspectedVelocity = -Velocity / float2(ViewportAspect, 1);
    
    float VelLen = length(Velocity) * alpha1;
    
    Out.BaseVel = Velocity; //PSに速度を渡す。
    
    Out.Tex2 = Pos.xy;
    
    //ライン幅
    PosEx *= (1.0 / LINEBLUR_GRIDSIZE);
    //ライン長さ
    PosEx.x += Pos.x * sqrt(VelLen) * 0.08 * LineBlurLength;
    
    
    //斜めラインは太く
    PosEx.y *= 1.5 + 0.4 * abs(sin(atan2(AspectedVelocity.x, AspectedVelocity.y) * 2));
    
    //ライン回転
    float2 AxU = normalize(AspectedVelocity);
    float2 AxV = float2(AxU.y, -AxU.x);
    
    PosEx = PosEx.x * AxU + PosEx.y * AxV;
    
    //頂点位置によるサンプリング位置のオフセット
    //TexPos += (-Pos.y * AxV) / (LINEBLUR_GRIDSIZE * 2);
    
    //元スクリーン参照
    Out.Color = tex2Dlod( ScnSamp, float4(TexPos, 0, ScnMipLevel1) );
    
    //ブラー強度からアルファ設定・ライン先端は透明に
    //Out.Color.a *= saturate(VelLen * 250) * (1 - IsTip);
    Out.Color.a *= saturate(VelLen * 250);
    
    Out.Color.a *= (!IsSceneChange); //シーン切り替えはブラー無効
    
    //バッファ出力
    Out.Pos.xy = ScreenPos + PosEx + (2000 * (Out.Color.a < 0.01));
    Out.Pos.z = 0;
    Out.Pos.w = 1;
    
    //スクリーンテクスチャ座標
    Out.Tex.xy = (Out.Pos.xy * float2(1,-1) + 1) * 0.5 + (0.5 / LINEBLUR_BUFSIZE);
    Out.Tex.z = VelMap.z; //TEXCOORD0のZを借りて、残像の発生源のZ値を渡す
    
    return Out;
}

float4 PS_LineBluer( VS_OUTPUT3 IN ) : COLOR0
{
    
    float4 Info = tex2D( LineBluerInfoSamp, IN.Tex.xy);
    float4 Color = IN.Color;
    float alpha = 1.0 - abs(IN.Tex2.x); //先端を透明に
    
    Color.a *= alpha;
    
    float BaseZ = Info.z; //元画像のZ
    float AfImZ = IN.Tex.z; //残像のZ
    
    //手前のオブジェクト上の残像は隠す
    Color.a *= saturate(1 - (AfImZ - BaseZ) * 3);
    //Color.a *= saturate(1 - (AfImZ - BaseZ) * 200);
    
    float2 vel = Info.xy;
    
    //背景の速度ベクトルが一致しているときは薄く
    float vdrate = max(length(vel), length(IN.BaseVel));
    vdrate = (vdrate == 0) ? 0 : (1 / vdrate);
    float VelDif = length(vel - IN.BaseVel) * vdrate;
    Color.a *= saturate(VelDif);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//ラインブラーの合成

VS_OUTPUT VS_MixLineBluer( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + (0.5 / LINEBLUR_BUFSIZE);
    
    return Out;
}

#define LBSAMP LineBluerSamp

float4 PS_MixLineBluer( float2 Tex: TEXCOORD0 ) : COLOR {   
    float2 step = 1.4 / LINEBLUR_BUFSIZE;
    float4 Color = tex2D( LineBluerSamp, Tex);
    
    //元が低解像度なので、ジャギー消しのために軽くぼかす
    [unroll] for(int j = -1; j <= 1; j++){
        [unroll] for(int i = -1; i <= 1; i++){
            Color += tex2D( LineBluerSamp, Tex + step * float2(i,j) );
            
        }
    }
    
    Color /= 10;
    
    Color.a *= LineBlurStrength;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//カメラ位置の記録

VS_OUTPUT VS_CameraBuffer( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + InfoBufOffset;
    
    return Out;
}

float4 PS_CameraBuffer( float4 Tex : TEXCOORD0 ) : COLOR {   
    float4 Color = float4(CameraPosition, 1);
    Color = (Tex.x >= 0.5) ? float4(CameraDirection, 1) : Color;
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 魚眼処理

#if FISHEYE_ENABLE!=0

float4 PS_FishEye( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float2 tex_conv;
    
    if(true){
        tex_conv = Tex - 0.5;
        tex_conv.x *= ViewportAspect;
        
        float D = 1;
        float r = length(tex_conv);
        float2 dir = normalize(tex_conv);
        
        float vang1 = viewangle * 2 * FishEyeStregth;
        float resize = 1;
        
        float phai = r * vang1;
        r = asin(phai);
        r /= (vang1);
        
        tex_conv = r * dir;
        tex_conv.x /= ViewportAspect;
        tex_conv += 0.5;
        
        Color = tex2D( ScnSamp, tex_conv );
        
        //表示領域外は黒で塗りつぶす
        Color = (0 <= phai && phai <= 1) ? Color : float4(0,0,0,1);
        Color = (0 <= tex_conv.x && tex_conv.x <= 1 && 0 <= tex_conv.y && tex_conv.y <= 1) ? Color : float4(0,0,0,1);
        
        Color = (BetaSize <= Tex.x && Tex.x <= (1 - BetaSize) && BetaSize <= Tex.y && Tex.y <= (1 - BetaSize)) ? Color : float4(0,0,0,1);
        
    }else{
        
        Color = tex2D( ScnSamp2, Tex );
        
    }
    
    return Color;
}

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
//AutoLuminous


float4 PS_HighLightDOF( float2 Tex: TEXCOORD0, uniform sampler2D Samp ) : COLOR {
    /*
    float4 Color;
    
    Color = tex2Dlod(Samp, float4(Tex,0,0));
    
    return Color;
    */
    
    
    ///*
    
    if(!FocusEnable) {
        return tex2Dlod(Samp, float4(Tex,0,0));
        
    }else{
    
    //簡易玉ボケ表現
    int x, y;
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float centerblr = GetDeepBlurMap(Tex);
    float2 step = DOF_SampStepScaled * centerblr * (1.0 * SAMP_NUM / LightDOF_SAMP_NUM);
    float depth, centerdepth = DOF_GetDepthMap(Tex) - 0.01;
    
    [unroll] //ループ展開
    for(y = -LightDOF_SAMP_NUM; y <= LightDOF_SAMP_NUM; y++){
        [unroll] //ループ展開
        for(x = -LightDOF_SAMP_NUM; x <= LightDOF_SAMP_NUM; x++){
            
            e = (x*x+y*y <= LightDOF_SAMP_NUM*LightDOF_SAMP_NUM); //円形
            stex = Tex + float2(x, y) * step;
            
            //手前かつピントの合っている部分からのサンプリングは弱く
            //depth = DOF_GetDepthMap(stex);
            //float blrrate = DOF_BlurRate(DOF_DeepDepthToBlur(depth), centerblr);
            //e *= max(blrrate, (depth >= centerdepth));
            
            sum += exp(tex2D( Samp, stex )) * e;
            n += e;
            
        }
    }
    
    Color = log(sum / n);
    
    return Color;
    
    }
    //*/
    
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 白とび表現関数
float4 OverExposure(float4 color){
    float4 newcolor = color;
    
    //ある色が1を超えると、他の色にあふれる
    newcolor.gb += max(color.r - 1, 0) * OverExposureRatio * float2(0.65, 0.6);
    newcolor.rb += max(color.g - 1, 0) * OverExposureRatio * float2(0.5, 0.6);
    newcolor.rg += max(color.b - 1, 0) * OverExposureRatio * float2(0.5, 0.6);
    
    return newcolor;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//トーンカーブの調整
//自分でも何がどうなっているかよくわからない関数になってしまったが、
//何となくうまく動いているので怖くていじれない

float4 ToneCurve(float4 Color){
    float3 newcolor;
    const float th = 0.65;
    newcolor = normalize(Color.rgb) * (th + sqrt(max(0, (length(Color.rgb) - th) / 2)));
    newcolor.r = (Color.r > 0) ? newcolor.r : Color.r;
    newcolor.g = (Color.g > 0) ? newcolor.g : Color.g;
    newcolor.b = (Color.b > 0) ? newcolor.b : Color.b;
    
    Color.rgb = min(Color.rgb, newcolor);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//AL共通頂点シェーダ

VS_OUTPUT VS_ALDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 , uniform int miplevel) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    #ifdef MIKUMIKUMOVING
    float ofsetsize = 1;
    #else
    float ofsetsize = pow(2, miplevel);
    #endif
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y) * ofsetsize;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//高輝度成分の抽出

float4 PS_DrawHighLight( float2 Tex: TEXCOORD0 ) : COLOR0 {
    float4 Color, OrgColor, OverLightColor, ExtColor;
    
    Color = tex2Dlod(EmitterView, float4(Tex, 0, 0));
    //Color.a = 0;
    
    //元スクリーンの高輝度成分の抽出
    OrgColor = tex2Dlod(ScnSamp, float4(Tex, 0, 0));
    OverLightColor = OrgColor * OverLight;
    OverLightColor = max(0, OverLightColor - 0.98);
    OverLightColor = ToneCurve(OverLightColor);
    
    Color *= timerate;
    
    ExtColor = tex2Dlod(ExternalHighLightView, float4(Tex, 0, 0));
    Color.rgb += (OverLightColor.rgb * !ExternLightSampling + ExtColor.rgb);
    
    Color *= scaling * 2;
    
    Color.a = 1;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

#define HLSampler HighLightView

////////////////////////////////////////////////////////////////////////////////////////////////
// MipMap利用ぼかし

float4 PS_AL_Gaussian( float2 Tex: TEXCOORD0, 
           uniform bool Horizontal, uniform sampler2D Samp, 
           uniform int miplevel, uniform int scalelevel
           ) : COLOR {
    
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float scalepow = pow(2, scalelevel);
    float step = (Horizontal ? AL_SampStepScaled.x : AL_SampStepScaled.y) * scalepow;
    const float2 dir = float2(Horizontal, !Horizontal);
    float4 scolor;
    
    [unroll] //ループ展開
    for(int i = -AL_SAMP_NUM; i <= AL_SAMP_NUM; i++){
        e = exp(-pow((float)i / (AL_SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = Tex + dir * (step * (float)i);
        scolor = tex2Dlod( Samp, float4(stex, 0, miplevel));
        sum += scolor * e;
        n += e;
    }
    
    Color = sum / n;
    
    //低輝度領域の光の広がりを制限
    //if(!Horizontal) Color = max(0, abs(Color) - scalepow * (2 - alpha1) * 0.002) * sign(Color);
    //Color = max(0, abs(Color) - scalepow * 0.0007) * sign(Color);
    if(!Horizontal) Color = min(abs(Color), pow(abs(Color), 1 + scalelevel * 0.1 * (2 - alpha1) * Modest)) * sign(Color);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_AL_DirectionalBlur( float2 Tex: TEXCOORD0 , uniform sampler2D Samp, uniform bool isfirst) : COLOR {   
    float e, n = 0;
    float2 stex1, stex2, stex3, stex4;
    float4 Color, sum = 0;
    float4 sum1 = 0, sum2 = 0, sum3 = 0, sum4 = 0;
    
    float step = AL_SampStep2 * (1.0 + cos(AL_LoopIndex * 5.1 + rot.x * 10) * 0.3);
    
    float ang = (AL_LoopIndex * 180.0 / (int)Glare) * PI / 180 + GlareAngle;
    float2 dir = float2(cos(ang) / ViewportAspect, sin(ang)) * step;
    float p = 1;
    
    #if GLARE_LONGONE!=0
        p = (1 + (AL_LoopIndex == 0)) * 0.7;
        dir *= p;
    #endif
    
    [unroll] //ループ展開
    for(int i = -AL_SAMP_NUM2; i <= AL_SAMP_NUM2; i++){
        e = exp(-pow((float)i / (AL_SAMP_NUM2 / 2.0), 2) / 2); //正規分布
        if(isfirst){
            stex1 = Tex + dir * ((float)i * 1.0);
            stex2 = Tex + dir * ((float)i * 1.8);
            stex3 = Tex + dir * ((float)i * 3.9);
            //stex4 = Tex + dir * ((float)i * 7.7);
        }else{
            stex1 = Tex + dir * ((float)i * 0.75);
        }
        if(isfirst){
            sum1 += max(0, tex2Dlod( Samp, float4(stex1, 0, 1) )) * e;
            sum2 += max(0, tex2Dlod( Samp, float4(stex2, 0, 2) )) * e;
            sum3 += max(0, tex2Dlod( Samp, float4(stex3, 0, 3) )) * e;
            //sum4 += max(0, tex2Dlod( Samp, float4(stex4, 0, 4) )) * e;
        }else{
            sum1 += max(0, tex2Dlod( Samp, float4(stex1, 0, 0) )) * e;
        }
        
        n += e;
    }
    
    sum1 /= n;
    sum2 /= n;
    sum3 /= n;
    //sum4 /= n;
    
    sum1 = max(0, sum1 - 0.006); sum2 = max(0, sum2 - 0.015); sum3 = max(0, sum3 - 0.029); //sum4 = max(0, sum4 - 0.032);
    
    Color = sum1 + sum2 + sum3 + sum4;
    
    if(isfirst){
        Color *= GlareAspect;
        Color *= p;
        Color /= sqrt(0.2 + (float)((int)Glare));
        Color = ToneCurve(Color * GlarePower);
    }
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_AL_Mix( float2 Tex: TEXCOORD0 , uniform bool FullOut) : COLOR {
    
    float4 Color;
    
    float crate1 = 1, crate2 = 1, crate3 = 1, crate4 = 0.8;
    
    Color = tex2D(ScnSampOut, Tex);
    Color += tex2D(ScnSampOut2, Tex) * crate1;
    Color += tex2D(ScnSampOut3, Tex) * crate2;
    Color += tex2D(ScnSampOut4, Tex) * crate3;
    Color += tex2D(ScnSampOut5, Tex) * crate4;
    
    Color *= (1 - 0.3 * (Glare >= 1));
    
    Color += tex2D(ScnSampGlare, Tex);
    
    if(!ScreenToneCurve) Color = ToneCurve(Color); //トーンカーブの調整
    
    if(!FullOut){
        Color.a = saturate(Color.a);
        return Color;
    }
    
    
    float4 basecolor = tex2D(ScnSamp2, Tex);
    basecolor.rgb *= OverLight;
    Color = Color + basecolor;
    
    //白とび表現
    Color = OverExposure(Color);
    
    if(ScreenToneCurve) Color = ToneCurve(Color); //トーンカーブの調整
    
    Color.a = basecolor.a + length(Color.rgb);
    Color.a = saturate(Color.a);
    Color.rgb /= Color.a;
    
    return Color;
}



////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_Test( float2 Tex: TEXCOORD0 ) : COLOR {
    //return float4(tex2D(HighLightView, Tex).rgb, 1);
    //return float4(tex2D(EmitterView, Tex).rgb, 1);
    return float4(tex2D(ScnSamp, Tex).rgb, 1);
    
}

////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float4 ClearColor2 = {0,0,0,0};
float ClearDepth  = 1.0;


technique TrueCameraLX <
    string Script = 
        
        "RenderColorTarget0=ExternalHighLight;"
        "ClearSetColor=ClearColor;"
        "Clear=Color;"
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        
        "RenderColorTarget0=HighLight;"
        "ClearSetColor=ClearColor;"
        "Clear=Color;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Depth;"
        "Pass=DrawHighLight;"
        
        
        "LoopByCount=FocusEnable;"
        
            "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2; Clear=Color;"
            "ClearSetDepth=ClearDepth; Clear=Depth;"
            "Pass=DeepDOF_X;"
            
            "RenderColorTarget0=ScnMapX;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2; Clear=Color;"
            "ClearSetDepth=ClearDepth; Clear=Depth;"
            "Pass=DeepDOF_Y;"
            
            
            "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2; Clear=Color;"
            "ClearSetDepth=ClearDepth; Clear=Depth;"
            "Pass=BufCopy;"
            
            
            /*
            
            //テスト
            "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
            "Clear=Depth;"
            "Clear=Color;"
            "Pass=AL_Test;"
            */
            
            "LoopByCount=ShallowBlurLoopCount;"
            "LoopGetIndex=ShallowBlurLoopIndex;"
                
                "RenderColorTarget0=ScnMap2;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor2; Clear=Color;"
                "ClearSetDepth=ClearDepth; Clear=Depth;"
                "Pass=ShallowDOF_X;"
                
                "RenderColorTarget0=ScnMap;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "Pass=ShallowDOF_Y;"
                
            "LoopEnd=;"
        
        "LoopEnd=;"
        
        
        "RenderColorTarget0=ScnMap2;"
        "RenderColorTarget1=ScnMapX;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=DirectionalBlur;"
        
        
        "RenderColorTarget0=LineBluerTex;"
        "RenderColorTarget1=LineBluerInfoTex;"
        "RenderDepthStencilTarget=LineBluerDepthBuffer;"
        "ClearSetColor=ClearColor2; Clear=Color;"
        "ClearSetDepth=ClearDepth; Clear=Depth;"
        "Pass=ClearLineBluer;"
        
        "RenderColorTarget0=LineBluerTex;"
        "RenderColorTarget1=;"
        "Clear=Depth;"
        
        #if LINEBLUR_QUAD==0
            //1回だけ
            "Pass=DrawLineBluer;"
        #else
            //4回繰り返す
            "LoopByCount=loopcount;"
            "LoopGetIndex=loopindex;"
            "Pass=DrawLineBluer;"
            "LoopEnd=;"
        #endif
        
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        //"Clear=Color;"
        "Pass=MixLineBluer;"
        
        
        
        
        
        
        "RenderColorTarget0=HighLight;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=HighLightDOF;"
        
        
        "RenderColorTarget0=ScnMapGlare;"
        "RenderColorTarget1=;"
        "RenderDepthStencilTarget=DepthBuffer2;"
        "Clear=Color; Clear=Depth;"
        
        "LoopByCount=Glare;"
        "LoopGetIndex=AL_LoopIndex;"
            
            "RenderColorTarget0=ScnMapX2;"
            "Clear=Color; Clear=Depth;"
            "Pass=AL_DirectionalBlur1;"
            
            "RenderColorTarget0=ScnMapGlare;"
            "Clear=Depth;"
            "Pass=AL_DirectionalBlur2;"
            
        "LoopEnd=;"
        
        
        "RenderColorTarget0=ScnMapX;"
        "RenderColorTarget1=;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X;"
        
        "RenderColorTarget0=ScnMapOut;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y;"
        
        "RenderColorTarget0=ScnMapX2;"
        "RenderDepthStencilTarget=DepthBuffer2;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X2;"
        
        "RenderColorTarget0=ScnMapOut2;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y2;"
        
        "RenderColorTarget0=ScnMapX3;"
        "RenderDepthStencilTarget=DepthBuffer3;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X3;"
        
        "RenderColorTarget0=ScnMapOut3;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y3;"
        
        "RenderColorTarget0=ScnMapX4;"
        "RenderDepthStencilTarget=DepthBuffer4;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X4;"
        
        "RenderColorTarget0=ScnMapOut4;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y4;"
        
        
        "RenderColorTarget0=ScnMapX5;"
        "RenderDepthStencilTarget=DepthBuffer5;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X5;"
        
        "RenderColorTarget0=ScnMapOut5;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y5;"
        
        
        #if FISHEYE_ENABLE==0
            "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
        #else
            "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
        #endif
        
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Depth;"
        "Clear=Color;"
        "Pass=AL_Mix;"
        
        
        
        
        
        #if FISHEYE_ENABLE!=0
            "RenderColorTarget=;"
            "RenderDepthStencilTarget=;"
            "Pass=FishEye;"
        #endif
        
        
        
        "RenderColorTarget=CameraBufferTex;"
        "RenderDepthStencilTarget=CameraBufferMB;"
        "Pass=DrawCameraBuffer;"
        
    ;
    
> {
    
    
    //DOF
    
    pass DeepDOF_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DeepDOF(true, ScnSamp);
    }
    pass DeepDOF_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DeepDOF(false, ScnSamp2);
    }
    
    pass BufCopy < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_BufCopy(ScnSampX);
    }
    
    
    pass ShallowDOF_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_ShallowDOF_X();
    }
    pass ShallowDOF_Y < string Script= "Draw=Buffer;"; > {
        DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_ShallowDOF_Y();
    }
    
    
    
    
    //方向性ブラー
    pass DirectionalBlur < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DirectionalBlur( ScnSamp, HighLightView );
    }
    
    
    //ラインブラー
    pass ClearLineBluer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_ClearLineBluer();
    }
    
    pass DrawLineBluer < string Script= "Draw=Geometry;"; > {
        DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        CullMode = none;
        ZEnable = false;
        VertexShader = compile vs_3_0 VS_LineBluer();
        PixelShader  = compile ps_3_0 PS_LineBluer();
    }
    
    pass MixLineBluer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = true;
        //AlphaBlendEnable = false;AlphaTestEnable = false;
        DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
        
        VertexShader = compile vs_3_0 VS_MixLineBluer();
        PixelShader  = compile ps_3_0 PS_MixLineBluer();
    }
    
    
    
    //AL
    
    pass HighLightDOF < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_HighLightDOF(ScnSampX);
    }
    
    
    pass AL_Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 0, 0);
    }
    pass AL_Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX, 0, 0);
    }
    
    pass AL_Gaussian_X2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 2, 2);
    }
    pass AL_Gaussian_Y2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX2, 0, 2);
    }
    
    pass AL_Gaussian_X3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(2);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 4, 4);
    }
    pass AL_Gaussian_Y3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(2);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX3, 0, 4);
    }
    
    pass AL_Gaussian_X4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(3);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 5, 5);
    }
    pass AL_Gaussian_Y4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(3);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX4, 0, 5);
    }
    
    pass AL_Gaussian_X5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(4);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 7, 7);
    }
    pass AL_Gaussian_Y5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(4);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX5, 0, 7);
    }
    
    
    
    pass AL_DirectionalBlur1 < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_DirectionalBlur(HLSampler, true);
    }
    
    pass AL_DirectionalBlur2 < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_DirectionalBlur(ScnSampX2, false);
    }
    pass AL_DirectionalBlur3 < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_DirectionalBlur(ScnSampOut2, false);
    }
    
    
    
    
    pass DrawHighLight < string Script= "Draw=Buffer;"; > {
        AlphaTestEnable = false;
        AlphaBlendEnable = false;
        
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_DrawHighLight();
    }
    
    pass AL_Mix < string Script= "Draw=Buffer;"; > {
        
        #if ALPHA_OUT!=0
            AlphaBlendEnable = false;
            AlphaTestEnable = false;
        #endif
        
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Mix(true);
    }
    
    pass AL_Test < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_Test();
    }
    
    
    //カメラ位置保存
    pass DrawCameraBuffer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_CameraBuffer();
        PixelShader  = compile ps_3_0 PS_CameraBuffer();
    }
    
    #if FISHEYE_ENABLE!=0
        //魚眼
        pass FishEye < string Script= "Draw=Buffer;"; > {
            AlphaBlendEnable = false;
            AlphaTestEnable = false;
            VertexShader = compile vs_3_0 VS_passDraw();
            PixelShader  = compile ps_3_0 PS_FishEye();
        }
    #endif
    
    
    
    
    
    
}
////////////////////////////////////////////////////////////////////////////////////////////////

