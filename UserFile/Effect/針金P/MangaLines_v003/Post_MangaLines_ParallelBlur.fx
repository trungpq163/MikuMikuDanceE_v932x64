////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Post_MangaLines_ParallelBlur.fx ver0.0.3  漫画･アニメの効果線エフェクト(平行線,ポストフェクト版,背景ブラー付き)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int LineCount = 87;       // 効果線の本数
float LineThick = 0.5;    // 効果線の基準太さ
float LineAlpha = 0.7;    // 効果線の最大透過値
float PosParam = 0.65;    // より分けパラメータ(0で均等,1に近づくほど外側により分けられる)
float AreaScale = 1.0;    // 効果線が描画される範囲(中心位置変更で効果線外端が見える時はここを大きくする)
float3 LineColor = {0.0, 0.0, 0.0}; // 効果線色(RBG)

float BlurPower = 8.0;      // 背景ブラー強度
float LineBlurPower = 2.0;  // 効果線方向ブラー強度
float NoiseRate = 0.5;      // 背景ブラーのノイズ付加率(0～1)
float NoiseScale = 0.5;     // 背景ブラーのノイズスケール

int SeedThick = 9;     // 太さに関する乱数シード
int SeedPos = 14;      // 配置に関する乱数シード
int SeedAnime = 78;    // アニメーションに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define PAI 3.14159265f   // π

bool flagCenterControl   : CONTROLOBJECT < string name = "CentetControl.pmx"; >;
float4x4 CenterControlMat  : CONTROLOBJECT < string name = "CentetControl.pmx"; string item = "センター"; >;
static float2 CenterCtrlRzVec = flagCenterControl ? normalize(CenterControlMat._11_12) : float2(1,0); // Z軸回転ベクトル

float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsZ  : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;
float AcsRx : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;
float AcsRz : CONTROLOBJECT < string name = "(self)"; string item = "Rz"; >;
float AcsRy : CONTROLOBJECT < string name = "(self)"; string item = "Ry"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float xAlpha = saturate( 1.0f - degrees(AcsRx) );

float time : Time;

int LineIndex;

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;

static float R = length( float2( ViewportSize.x/ViewportSize.y, 1.0f) )*AreaScale;  // 画面対角線長さと高さの比

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// レンダリングターゲットのクリア値
float4 ClearColor = {0.0, 0.0, 0.0, 1.0};
float  ClearDepth  = 1.0;

#ifndef MIKUMIKUMOVING
    #define TEX_FORMAT  "D3DFMT_A8"
#else
    #define TEX_FORMAT  "D3DFMT_A8R8G8B8"
#endif

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

int BlurCount = 3;  // ブラー強度処理反復回数
int BlurIndex;      // ブラー強度処理反復回数のカウンタ

// ブラー用サンプリング間隔
static float2 SampStep = float2(BlurPower, BlurPower) / ViewportSize / pow(6.0f, BlurIndex);

// ラインノイズテクスチャ
texture2D NoiseTex <
    string ResourceName = "LineNoise.png";
>;
sampler NoiseSamp = sampler_state {
    texture = <NoiseTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 効果線描画結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 0;
    string Format = "D3DFMT_A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// ブラー処理を記録するためのレンダーターゲットX
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// ブラー処理を記録するためのレンダーターゲットX
texture2D ScnMap4 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSamp4 = sampler_state {
    texture = <ScnMap4>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float2 rotVec)
{
    float x = pos.x * rotVec.x - pos.y * rotVec.y;
    float y = pos.x * rotVec.y + pos.y * rotVec.x;

    return float2(x, y);
}

static float2 RotZVec = Rotation2D( CenterCtrlRzVec, float2(cos(AcsRz), sin(AcsRz)) ); // Z軸回転ベクトル


////////////////////////////////////////////////////////////////////////////////////////////////
// 中心座標
float2 GetCenterPos()
{
    float2 Pos;
    if ( flagCenterControl ){
       float4 centerPos = mul(CenterControlMat[3], ViewProjMatrix);
       Pos.x = centerPos.x / centerPos.w * ViewportSize.x/ViewportSize.y;
       Pos.y = centerPos.y / centerPos.w;
    } else {
       Pos.x = AcsX*ViewportSize.x/ViewportSize.y;
       Pos.y = AcsY;
    }
    return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////
// 効果線描画

struct VS_OUTPUT
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 VPos  : TEXCOORD0;   // ローカル･アニメーション座標
    float2 Tex   : TEXCOORD1;   // テクスチャ座標
};

// 頂点シェーダ
VS_OUTPUT Line_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 乱数設定
    float rand1 = 0.5f * (0.66f * sin(22.1f * SeedThick * LineIndex) + 0.33f * cos(33.6f * SeedThick * LineIndex) + 1.0f);
    float rand2 = 0.5f * (0.31f * sin(45.3f * SeedPos * LineIndex) + 0.69f * cos(73.4f * SeedPos * LineIndex) + 1.0f);
    float rand3 = 0.5f * (0.38f * sin(55.1f * SeedAnime * LineIndex) + 0.62f * cos(44.4f * SeedAnime * LineIndex) + 1.0f);

    // ローカル･アニメーション座標
    Out.VPos.x = Pos.x;
    Out.VPos.y = step(0.0, AcsZ)*(2.0f*R+abs(AcsZ))
               - sign(AcsZ)*fmod(lerp(0.0f, 2.0f*(R+abs(AcsZ)), rand3)+time*AcsSi, 2.0f*(R+abs(AcsZ)));

    // 線の太さ
    Pos.y *= max((LineThick+degrees(AcsRy)*0.2f)*(0.5+rand1)*(1.0f+Pos.x)*0.1f, 0.3f);

    // 平行線配置
    float2 Pos0 = float2(-R-0.4*rand2, lerp(-R, R, (float)LineIndex/(float)LineCount) + ((rand2-0.5f) * 1.5f * R / LineCount));
    Pos0.y = sign(Pos0.y)*R*pow(abs(Pos0.y/R), max(1.0f-PosParam, 0.0f));
    Pos.xy += Pos0;

    // 座標回転
    Pos.xy = Rotation2D(Pos.xy, RotZVec);

    // 配置移動
    Pos.xy += GetCenterPos();

    // スクリーン座標に変換
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Out.Pos = Pos;

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

struct PS_OUTPUT {
    float4 Color0 : COLOR0;
    float4 Color1 : COLOR1;
};

// ピクセルシェーダ
PS_OUTPUT Line_PS( VS_OUTPUT IN )
{
    PS_OUTPUT Out = (PS_OUTPUT)0;

    // 線先端透過値設定
    float alpha1 = smoothstep((1.0f-AcsTr)*(1.0f+R), 1.0f+(1.0f-AcsTr)*5.0f, IN.VPos.x)*AcsTr;
    // アニメーション透過値設定
    float alpha2 = smoothstep(-max(abs(AcsZ),0.0001f), 0.0f, -abs(IN.VPos.x-IN.VPos.y));
    if( abs(AcsZ) < 0.0001f ) alpha2 = 1.0f;
    // 線側境界透過値設定
    float alpha3 = 1.0f - smoothstep(0.0f, 0.5f, abs(IN.Tex.y-0.5f));

    // 効果線の色
    Out.Color0 = float4( 1.0f, 1.0f, 1.0f, alpha1*alpha3*LineAlpha );
    Out.Color1 = float4( 1.0f, 1.0f, 1.0f, alpha1*alpha2*alpha3*LineAlpha );

    return Out;
}


///////////////////////////////////////////////////////////////////////////////////////
// 背景ブラー処理

struct VS_OUTPUT2 {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 共通頂点シェーダ
VS_OUTPUT2 VS_Common(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ブラー強度X方向ぼかし
float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color;
    Color  = WT_0 *   tex2D( ScnSamp4, Tex );
    Color += WT_1 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x  , 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x  , 0) ) );
    Color += WT_2 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*2, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*2, 0) ) );
    Color += WT_3 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*3, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*3, 0) ) );
    Color += WT_4 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*4, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*4, 0) ) );
    Color += WT_5 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*5, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*5, 0) ) );
    Color += WT_6 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*6, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*6, 0) ) );
    Color += WT_7 * ( tex2D( ScnSamp4, Tex+float2(SampStep.x*7, 0) ) + tex2D( ScnSamp4, Tex-float2(SampStep.x*7, 0) ) );
    return Color;
}

// ブラー強度Y方向ぼかし
float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;
    Color  = WT_0 *   tex2D( ScnSamp3, Tex );
    Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y  ) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*2) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*2) ) );
    Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*3) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*3) ) );
    Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*4) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*4) ) );
    Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*5) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*5) ) );
    Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*6) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*6) ) );
    Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(0, SampStep.y*7) ) + tex2D( ScnSamp3, Tex-float2(0, SampStep.y*7) ) );
    return Color;
}

// 背景ブラー処理
float4 PS_Blur(float2 Tex: TEXCOORD0, uniform sampler2D samp, uniform float blurPower) : COLOR
{
    // ブラー強度にラインノイズ追加
    float2 centerPos = GetCenterPos();
    float2 speed = RotZVec*time * sign(AcsZ) * AcsSi*0.4;
    float2 texCoord = float2(Tex.x*ViewportSize.x/ViewportSize.y, Tex.y) / NoiseScale + float2(speed.x, -speed.y);
    texCoord = Rotation2D( texCoord - float2(centerPos.x, centerPos.y), RotZVec );
    float noisePower = (1.0f-NoiseRate+NoiseRate*tex2D( NoiseSamp, texCoord ).r) * tex2D( ScnSamp4, Tex ).r;
    //return float4(noisePower,noisePower,noisePower,1);

    // 背景ブラー処理
    float2 xySmpStep = float2(RotZVec.x, -RotZVec.y) * SampStep * blurPower * noisePower * LineBlurPower;
    float2 xySmpStepF = clamp(xySmpStep, -blurPower*0.2f/ViewportSize, blurPower*0.2f/ViewportSize);
    float sgn = sign(AcsZ + 0.001f);
    float4 Color;
    Color  = WT_0 *   tex2D( samp, Tex );
    Color += WT_1 * ( tex2D( samp, Tex+sgn*xySmpStep   )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF   )*0.6f );
    Color += WT_2 * ( tex2D( samp, Tex+sgn*xySmpStep*2 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*2 )*0.6f );
    Color += WT_3 * ( tex2D( samp, Tex+sgn*xySmpStep*3 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*3 )*0.6f );
    Color += WT_4 * ( tex2D( samp, Tex+sgn*xySmpStep*4 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*4 )*0.6f );
    Color += WT_5 * ( tex2D( samp, Tex+sgn*xySmpStep*5 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*5 )*0.6f );
    Color += WT_6 * ( tex2D( samp, Tex+sgn*xySmpStep*6 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*6 )*0.6f );
    Color += WT_7 * ( tex2D( samp, Tex+sgn*xySmpStep*7 )*1.4f + tex2D( samp, Tex-sgn*xySmpStepF*7 )*0.6f );
    return Color;
}

// スクリーンバッファの合成
float4 PS_Mix(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color = tex2D( ScnSamp, Tex );
    Color.rgb = lerp(Color.rgb, LineColor, tex2D(ScnSamp2, Tex).r * xAlpha);
    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        // オリジナルの描画
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

        // 効果線の元描画
        "RenderColorTarget0=ScnMap4;"
        "RenderColorTarget1=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "LoopByCount=LineCount;"
               "LoopGetIndex=LineIndex;"
               "Pass=DrawLines;"
            "LoopEnd=;"
        "RenderColorTarget1=;"

        // 背景ブラー範囲設定のためのぼかし
        "LoopByCount=BlurCount;"
            "LoopGetIndex=BlurIndex;"
            "RenderColorTarget0=ScnMap3;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=Gaussian_X;"
            "RenderColorTarget0=ScnMap4;"
                "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=Gaussian_Y;"
        "LoopEnd=;"

        // 背景ブラー処理
        "RenderColorTarget0=ScnMap3;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=BlurPass1;"
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=BlurPass2;"

        // 背景と効果線の合成
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=MixPass;"
        ;
> {
    pass DrawLines {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_1_1 Line_VS();
        PixelShader  = compile ps_2_0 Line_PS();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass BlurPass1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_1_1 VS_Common();
        PixelShader  = compile ps_2_0 PS_Blur(ScnSamp, 60.0);
    }
    pass BlurPass2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_1_1 VS_Common();
        PixelShader  = compile ps_2_0 PS_Blur(ScnSamp3, 10.0);
    }
    pass MixPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_1_1 VS_Common();
        PixelShader  = compile ps_2_0 PS_Mix();
    }
}

