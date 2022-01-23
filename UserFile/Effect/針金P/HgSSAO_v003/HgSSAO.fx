////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgSSAO.fx ver0.0.3  SSAO(Screen Space Ambient Occlusion)エフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define UseHDR  0   // HDRレンダリングの有無
// 0 : 通常の256階調で処理
// 1 : 高照度情報をそのまま処理

// SSAOを行う際のパラメータ
float RayLength <
   string UIName = "レイ長さ";
   string UIHelp = "SSAOで光線を飛ばす際の最大長さ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 1.0;
   float UIMax = 100.0;
> = float( 5.0 );

float DepLength <
   string UIName = "遮蔽判定深度";
   string UIHelp = "SSAOで光線が遮蔽されているかを判定する際の光線位置とマップの深度差\nこれ以下の時に遮蔽とする";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 1.0;
   float UIMax = 500.0;
> = float( 15.0 );

float OccDensity <
   string UIName = "遮蔽濃度";
   string UIHelp = "光線が遮蔽されることによる陰の濃度";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 500.0;
> = float( 1.0 );

int RayCount <
   string UIName = "光線の数";
   string UIHelp = "1ピクセルで遮蔽判定を行う際の光線の数";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 30;
> = int( 10 );

// ブラーをかける際のパラメータ
float BlurPower <
   string UIName = "ブラー強度";
   string UIHelp = "ブラーをかける際のサンプリング間隔";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = float( 3.0 );

float OutlineDepth <
   string UIName = "輪郭判定深度";
   string UIHelp = "ぼかし処理時に輪郭の内外を判定する深度";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.5 );

float OutlineNormal <
   string UIName = "輪郭判定法線";
   string UIHelp = "ぼかし処理時に輪郭の内外を判定する法線(内積)";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.2 );

bool FlagVisibleAO <
   string UIName = "AO表\示";
   bool UIVisible =  true;
> = false;
//> = true;


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// コントロールパラメータ
float3 AcsXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float RayLen = max(RayLength + AcsXYZ.x, 0.1f);
static float DepLen = max(DepLength + AcsXYZ.y, 0.1f);
static float BlurPow = max(BlurPower + AcsXYZ.z, 0.0f);

// スクリーン内描画範囲の倍率(画面縁SSAO処理のため広範囲を描画)
#define ScrSizeRatio  1.1

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(BlurPow,BlurPow)/ViewportSize);

// 作業用スクリーンサイズ
static float2 WorkViewportSize = float2( floor(ViewportSize*ScrSizeRatio) );
static float2 TrueScnScale = WorkViewportSize / ViewportSize;
static float2 WorkViewportOffset = float2(0.5,0.5) / WorkViewportSize;

// 座標変換行列
float4x4 ProjMatrix0    : PROJECTION;
static float4x4 ProjMatrix = float4x4( ProjMatrix0[0] / TrueScnScale.x,
                                       ProjMatrix0[1] / TrueScnScale.y,
                                       ProjMatrix0[2],
                                       ProjMatrix0[3] );

// オフスクリーン法線マップ
texture HgSSAO_NmlRT: OFFSCREENRENDERTARGET <
    string Description = "HgSSAO.fxの法線マップ";
    float2 ViewPortRatio = {ScrSizeRatio, ScrSizeRatio};
    float4 ClearColor = {0.5, 0.5 ,0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "MMM_DummyModel = HgSSAO_Cancel.fxsub;"
        "* = HgSSAO_Normal.fxsub;";
>;
sampler NormalMapSmp = sampler_state {
    texture = <HgSSAO_NmlRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// オフスクリーン深度マップ
texture HgSSAO_DepRT: OFFSCREENRENDERTARGET <
    string Description = "HgSSAO.fxの深度マップ";
    float2 ViewPortRatio = {ScrSizeRatio, ScrSizeRatio};
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0f;
    string Format = "D3DFMT_R32F";
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "MMM_DummyModel = HgSSAO_Cancel.fxsub;"
        "* = HgSSAO_Depth.fxsub;"
    ;
>;
sampler DepthMapSmp = sampler_state {
    texture = <HgSSAO_DepRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

#if UseHDR==0
    #define TEX_FORMAT "D3DFMT_A8R8G8B8"
#else
    #define TEX_FORMAT "D3DFMT_A16B16G16R16F"
    //#define TEX_FORMAT "D3DFMT_A32B32G32R32F"
#endif

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
texture2D ScnMapDepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D3DFMT_D24S8";
>;


// SSAO項の結果を記録するためのレンダーターゲット
texture2D SSAO_Tex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {ScrSizeRatio, ScrSizeRatio};
    int MipLevels = 0;
    string Format = "D3DFMT_R16F";
>;
sampler2D SSAOSamp = sampler_state {
    texture = <SSAO_Tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D SSAO_Tex2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {ScrSizeRatio, ScrSizeRatio};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D SSAOSamp2 = sampler_state {
    texture = <SSAO_Tex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {ScrSizeRatio, ScrSizeRatio};
    string Format = "D3DFMT_D24S8";
>;

// 乱数テクスチャ
texture RandomTex <
    string ResourceName = "Random.png";
    int MipLevels = 1;
>;
sampler RandomSmp = sampler_state {
    texture = <RandomTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV  = WRAP;
};


////////////////////////////////////////////////////////////////////////////////////////////////

#define DEPTH_FAR  5000.0f   // 深度最遠値

// マップから法線と深度を取得
void GetNormalDepth(float2 Tex, out float3 Normal, out float Depth)
{
    // 法線
    float4 ColorN = tex2D( NormalMapSmp, Tex );
    Normal = normalize( ColorN.xyz*2.0f - 1.0f );

    // 深度
    Depth = tex2D( DepthMapSmp, Tex ).r * DEPTH_FAR;
}


// マップから法線とビュー座標を取得
void GetNormalVPos(float2 Tex, out float3 Normal, out float3 VPos)
{
    // 法線,深度
    float Depth;
    GetNormalDepth(Tex, Normal, Depth);

    // ビュー座標に戻す
    float2 PPos = float2(2.0f*Tex.x-1.0f, 1.0f-2.0f*Tex.y);
    VPos = float3(PPos.x / ProjMatrix._11, PPos.y / ProjMatrix._22, 1.0f) * Depth;
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
    Out.Tex = Tex + WorkViewportOffset;
    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// SSAO項

float4 PS_SSAO( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 法線,ビュー座標
    float3 Normal, VPos;
    GetNormalVPos( Tex, Normal, VPos);

    float OccRate = 0.0; // 遮蔽確率

    for(int i=0; i<RayCount; i++){
        // ランダムベクトル
        float4 ColorRand = tex2D( RandomSmp, Tex+float2(cos(13.0f*i), sin(17.0f*i)) );
        float3 randVec = normalize(2.0f * ColorRand.xyz - 1.0f) * ColorRand.a * RayLen;

        // レイの飛ばし先座標(法線と逆方向のレイは反対方向に飛ばす)
        float3 RayVPos = VPos.xyz + sign(dot(Normal,randVec)) * randVec;
        float2 RayPPos = RayVPos.xy * float2(ProjMatrix._11, ProjMatrix._22) / RayVPos.z;

        // レイの飛ばし先の法線と深度
        float2 RayTex = float2( (1.0f+RayPPos.x)*0.5f, (1.0f-RayPPos.y)*0.5f );
        float3 RayNormal;
        float RayDepth;
        GetNormalDepth(RayTex, RayNormal, RayDepth);

        // レイが遮蔽されている確率
        float NormalRate = 1.0f - max( dot(Normal, RayNormal), 0.0f );
        float DepthRate = step(RayDepth, RayVPos.z) * smoothstep(-DepLen, 0.0f, RayDepth-RayVPos.z);
        OccRate += NormalRate * DepthRate;
    }

    float ssao = OccDensity * OccRate / float(RayCount);

    return float4(ssao, 0, 0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// SSAOマップのぼかし

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

// サンプリングするミップマップレベル
static float MipLv = log2( max(ViewportSize.x*SampStep.x, 1.0f) );

// ぼかしサンプリング範囲の境界判定
bool IsSameArea(float Depth0, float Depth, float3 Normal0, float3 Normal)
{
    float edgeDepthThreshold = min(OutlineDepth + 0.05f * max(Depth0-10.0f, 0.0f), 7.0f);
    return (abs(Depth0 - Depth) < edgeDepthThreshold && abs(Normal0 - Normal) < OutlineNormal);
}

// ガウスフィルターによるぼかし
float SSAOGaussianXY(float2 Tex, sampler2D Samp, float2 smpVec, bool isMipMap)
{
    float mipLv = isMipMap ? MipLv : 0.0f;
    float3 Normal0, Normal;
    float Depth0, Depth;
    GetNormalDepth(Tex, Normal0, Depth0);

    float ssao = tex2Dlod( Samp, float4(Tex,0,mipLv) ).r;
    float sumSSAO = WT_COEF[0] * ssao;
    float sumRate = WT_COEF[0];

    // 境界の反対側にある色はサンプリングしない
    [unroll]
    for(int i=1; i<8; i++){
        float2 Tex1 = Tex - smpVec * SampStep * i;
        GetNormalDepth(Tex1, Normal, Depth);
        if( IsSameArea(Depth0, Depth, Normal0, Normal) ){
            ssao = tex2Dlod( Samp, float4(Tex1,0,mipLv) ).r;
            sumSSAO += WT_COEF[i] * ssao;
            sumRate += WT_COEF[i];
        }

        Tex1 = Tex + smpVec * SampStep * i;
        GetNormalDepth(Tex1, Normal, Depth);
        if( IsSameArea(Depth0, Depth, Normal0, Normal) ){
            ssao = tex2Dlod( Samp, float4(Tex1,0,mipLv) ).r;
            sumSSAO += WT_COEF[i] * ssao;
            sumRate += WT_COEF[i];
        }
    }

    return (sumSSAO / sumRate);
}

// Y方向
float4 PS_SSAOGaussianY( float2 Tex: TEXCOORD0 ) : COLOR
{
    float ssao = SSAOGaussianXY( Tex, SSAOSamp, float2(0,1), true );
    return float4(ssao, 0, 0, 1);
}

// X方向
float4 PS_SSAOGaussianX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float ssao = SSAOGaussianXY( Tex, SSAOSamp2, float2(1,0), false );
    return float4(ssao, 0, 0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////

// RGBからYCbCrへの変換
void RGBtoYCbCr(float3 rgbColor, out float Y, out float Cb, out float Cr)
{
    Y  =  0.298912f * rgbColor.r + 0.586611f * rgbColor.g + 0.114478f * rgbColor.b;
    Cb = -0.168736f * rgbColor.r - 0.331264f * rgbColor.g + 0.5f      * rgbColor.b;
    Cr =  0.5f      * rgbColor.r - 0.418688f * rgbColor.g - 0.081312f * rgbColor.b;
}


// YCbCrからRGBへの変換
float3 YCbCrtoRGB(float Y, float Cb, float Cr)
{
    float R = Y - 0.000982f * Cb + 1.401845f * Cr;
    float G = Y - 0.345117f * Cb - 0.714291f * Cr;
    float B = Y + 1.771019f * Cb - 0.000154f * Cr;
    return float3( R, G, B );
}


////////////////////////////////////////////////////////////////////////////////////////////////
// スクリーンバッファの合成

VS_OUTPUT VS_MixScreen( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

float4 PS_MixScreen( float2 Tex: TEXCOORD0 ) : COLOR
{
    // SSAOのマップ座標に修正
    float2 offset = float2(1.0f - 1.0f/TrueScnScale.x, 1.0f - 1.0f/TrueScnScale.y) * 0.5f;
    float2 Tex0 = Tex / TrueScnScale + offset;

    float ssao = tex2D( SSAOSamp, Tex0 ).r;

    // 輪郭部のジャギーをなじませる
    float2 SmpStep = float2(1,1)/WorkViewportSize;
    ssao += ssao;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2( 0,-1) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2( 0, 1) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2(-1, 0) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2( 1, 0) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2(-1,-1) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2( 1,-1) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2(-1, 1) ).r;
    ssao += tex2D( SSAOSamp, Tex0+SmpStep*float2( 1, 1) ).r;
    ssao *= 0.1f;

    // 元画像の色
    float4 Color = tex2D( ScnSamp, Tex );

    // RGBからYCbCrへの変換
    float Y, Cb, Cr;
    RGBtoYCbCr( Color.rgb, Y, Cb, Cr);

    // 合成
    float a = clamp(1.0f - 0.15f * AcsSi * ssao, 0.1f, 1.0f);
    float density = 1.0f / a;
    Color.rgb = lerp(YCbCrtoRGB( Y*a, Cb, Cr), pow(Color.rgb, density), 0.5f*AcsTr);

    if( FlagVisibleAO ) {
        // AO表示
        float ao = saturate(1.0f - ssao*3.0f);
        Color = float4(ao, ao, ao, 1);
    }

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        // オリジナルの描画
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=ScnMapDepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        // SSAO処理
        "RenderColorTarget0=SSAO_Tex;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=SSAODraw;"

        // SSAOマップのぼかしY方向
        "RenderColorTarget0=SSAO_Tex2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=SSAOGaussianY;"
        // SSAOマップのぼかしX方向
        "RenderColorTarget0=SSAO_Tex;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=SSAOGaussianX;"

        // 描画結果書き出し
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=MixPass;"
    ;
> {
    pass SSAODraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_SSAO();
    }
    pass SSAOGaussianY < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_SSAOGaussianY();
    }
    pass SSAOGaussianX < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_SSAOGaussianX();
    }
    pass MixPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MixScreen();
        PixelShader  = compile ps_2_0 PS_MixScreen();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
