////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Earthquake.fx ver0.0.4  地震エフェクト
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float AmplitudeX = 0.015; // 横揺れ振幅(画面幅の比率で入力)
float AmplitudeY = 0.012; // 縦揺れ振幅(画面高の比率で入力)

float Frequency <  
   string UIName = "周波数";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 30.0;
> = 10.0;   // 周波数(大きくすると振動が速くなります)

#define MODE_BLUR  1       // 揺れによるブラー効果, 0:入れない, 1:入れる
float BlurPowerMax = 1.0;  // 最大ブラー強度(ここに最大値を入れてTrで調整する)

#define ScnScale 1.00      // 外縁の歪みが気になる場合はこの数値を上げる(1～1.25程度)

#define BORDER_BRACK  0    // 外縁のはみ出し部を 0:外縁色で補間, 1:黒で塗りつぶし


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～15 について計算したのち、
//    (WT_1 + WT_0 + WT_1 + … + WT_15) が 1 になるように正規化したもの
#define  WT_00  0.14804608
#define  WT_01  0.14511458
#define  WT_02  0.13666376
#define  WT_03  0.12365848
#define  WT_04  0.10750352
#define  WT_05  0.08979449
#define  WT_06  0.07206177
#define  WT_07  0.05556334
#define  WT_08  0.04116233
#define  WT_09  0.02929813
#define  WT_10  0.02003586
#define  WT_11  0.01316450
#define  WT_12  0.00831053
#define  WT_13  0.00504059
#define  WT_14  0.00293740
#define  WT_15  0.00164464

float time : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 画面サイズは整数であるため実際のスケール比に補正
static float2 TrueScnScale = float2( floor(ViewportSize*ScnScale) ) / ViewportSize;

static float2 ViewportOffset = float2(0.5,0.5) / (ViewportSize*TrueScnScale);
static float2 SampStep = float2(1.0,1.0) / (ViewportSize*TrueScnScale);

// アクセサリパラメータ
float AcsZ  : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float AcsScaling = AcsSi * 0.1f; 
static float AcsAlpha = AcsTr;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {ScnScale, ScnScale};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
#if( BORDER_BRACK != 1 )
    AddressU  = CLAMP;
    AddressV = CLAMP;
#else
    AddressU  = BORDER;
    AddressV  = BORDER;
    BorderColor = float4(0,0,0,1);
#endif
};

// 1次ブラー処理結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {ScnScale, ScnScale};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {ScnScale, ScnScale};
    string Format = "D24S8";
>;

// 振動によるスクリーン移動量を記録するためのレンダーターゲット
texture2D CoordTex : RENDERCOLORTARGET <
    int Width=1;
    int Height=1;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;
sampler2D CoordSamp = sampler_state {
    texture = <CoordTex>;
    Filter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture CoordDepthBuffer : RenderDepthStencilTarget <
    int Width=1;
    int Height=1;
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 振動によるスクリーン移動量

// 頂点シェーダ
float4 VS_Coord(float4 Pos : POSITION, float2 Tex: TEXCOORD) : POSITION
{
   return Pos;
}

// ピクセルシェーダ
float4 PS_Coord() : COLOR
{
    float4 pos0 = tex2D(CoordSamp, float2(0.5, 0.5));

    float ax = AmplitudeX * AcsScaling;
    float ay = AmplitudeY * AcsScaling;
    float freq = max(Frequency + AcsZ, 0.001f);

    float x = ax * ( 0.66 * sin(2*floor(time*freq+2)) + 0.33*cos(3*floor(time*freq/2)) );
    float y = ay * ( 0.66 * sin(3*floor(time*freq)) + 0.33*cos(2*floor(time*freq/1.2+1)) );

    float len = length(float2(x,y)-pos0.xy);

    return (len>0.00001f || AcsScaling<0.01f) ? float4(x, y, pos0.xy) : float4(x, y, pos0.zw);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 振動によるスクリーンのぶれ描画

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Earthquake( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 PS_Earthquake( float2 Tex: TEXCOORD0, uniform sampler2D samp, uniform int blurCount ) : COLOR
{
    float4 Color;

    float4 coord = tex2D(CoordSamp, float2(0.5, 0.5));
    coord = float4(round(coord.xy/SampStep)*SampStep, coord.zw);

    float2 scrScale = (MODE_BLUR && blurCount==0) ? float2(1.0f, 1.0f) : float2(1.0f, 1.0f)/TrueScnScale;
    float2 offset = floor((float2(0.5f, 0.5f) - float2(0.5, 0.5f) * scrScale)/SampStep)*SampStep;
    float2 xy0 = Tex*scrScale + coord.xy + offset;

#if MODE_BLUR==1
    float2 xy1 = Tex*scrScale + coord.zw*BlurPowerMax + offset;
    xy1 = lerp(xy0, xy1, AcsAlpha/pow(6.0f, blurCount));
    float s = AcsAlpha / 16.0f;

    Color  = WT_00 * tex2D( samp, xy0 );
    Color += WT_01 * tex2D( samp, lerp(xy0, xy1,  1.0f * s) );
    Color += WT_02 * tex2D( samp, lerp(xy0, xy1,  2.0f * s) );
    Color += WT_03 * tex2D( samp, lerp(xy0, xy1,  3.0f * s) );
    Color += WT_04 * tex2D( samp, lerp(xy0, xy1,  4.0f * s) );
    Color += WT_05 * tex2D( samp, lerp(xy0, xy1,  5.0f * s) );
    Color += WT_06 * tex2D( samp, lerp(xy0, xy1,  6.0f * s) );
    Color += WT_07 * tex2D( samp, lerp(xy0, xy1,  7.0f * s) );
    Color += WT_08 * tex2D( samp, lerp(xy0, xy1,  8.0f * s) );
    Color += WT_09 * tex2D( samp, lerp(xy0, xy1,  9.0f * s) );
    Color += WT_10 * tex2D( samp, lerp(xy0, xy1, 10.0f * s) );
    Color += WT_11 * tex2D( samp, lerp(xy0, xy1, 11.0f * s) );
    Color += WT_12 * tex2D( samp, lerp(xy0, xy1, 12.0f * s) );
    Color += WT_13 * tex2D( samp, lerp(xy0, xy1, 13.0f * s) );
    Color += WT_14 * tex2D( samp, lerp(xy0, xy1, 14.0f * s) );
    Color += WT_15 * tex2D( samp, lerp(xy0, xy1, 15.0f * s) );
#else
    Color = tex2D( samp, xy0 );
#endif

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique EarthquakeTech <
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

        "RenderColorTarget0=CoordTex;"
            "RenderDepthStencilTarget=CoordDepthBuffer;"
            "Pass=CoordPass;"

#if MODE_BLUR==1
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=EarthquakePass0;"

        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=EarthquakePass1;"
#else
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=EarthquakePass0;"
#endif
    ;
> {
    pass CoordPass < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 VS_Coord();
        PixelShader  = compile ps_2_0 PS_Coord();
    }
    pass EarthquakePass0 < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 VS_Earthquake();
        PixelShader  = compile ps_2_0 PS_Earthquake(ScnSamp, 0);
    }
    pass EarthquakePass1 < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 VS_Earthquake();
        PixelShader  = compile ps_2_0 PS_Earthquake(ScnSamp2, 1);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////

