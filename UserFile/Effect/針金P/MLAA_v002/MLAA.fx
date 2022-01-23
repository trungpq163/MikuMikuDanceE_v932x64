////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MLAA.fx ver0.0.2  Morphological Antialiasing : ポストエフェクトによるアンチエイリアシング処理
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ設定

// 輪郭抽出方法の有無
#define SamplingDepth    1   // 深度による抽出, 0:しない, 1:する
#define SamplingNormal   1   // 法線による抽出, 0:しない, 1:する
#define SamplingColor    1   // 色差による抽出, 0:しない, 1:する
#define SamplingMMDEdge  1   // MMDエッジの抽出, 0:しない, 1:する

// 輪郭抽出閾値設定
float DepthThreshold  = 1.0;    // 深度の閾値
float NormalThreshold = 0.9;    // 法線の閾値
float ColorThreshold  = 0.3;    // 色差の閾値


#define SAMP_NUM   8   // 一方向のサンプリング数


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

#define DEPTH_FAR  5000.0f   // 深度最遠値

#define TEX_FORMAT "A32B32G32R32F"
//#define TEX_FORMAT "A16B16G16R16F"

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_FX_DEPNORMAL  "MLAA_DepthNormal.fxsub"     // オフスクリーン深度・法線マップ描画エフェクト1
    #define MLAA_TEX_FORMAT         "D3DFMT_A4R4G4B4"
#else
    #define OFFSCREEN_FX_DEPNORMAL  "MLAA_DepthNormal_MMM.fxsub" // オフスクリーン深度・法線マップ描画エフェクト1
    #define MLAA_TEX_FORMAT         "D3DFMT_A8R8G8B8"
#endif

//深度・法線マップ作成
texture MLAA_RT : OFFSCREENRENDERTARGET <
    string Description = "Depth && Normal Map for MLAA.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    string Format = TEX_FORMAT;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = " OFFSCREEN_FX_DEPNORMAL ";" ;
>;
sampler DepthNormalSmap = sampler_state {
    texture = <MLAA_RT>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// 座標パラメータ
float4x4 ProjMatrix  : PROJECTION;

// カメラ操作のパースペクティブフラグ
static bool IsParth = ProjMatrix._44 < 0.5f;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(1,1)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// LeftRight境界のAA処理結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
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


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭抽出

float4 PS_PickupOutline( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 深度・法線マップデータ
    float4 data0 = tex2D( DepthNormalSmap, Tex );
    float4 dataL = tex2D( DepthNormalSmap, Tex-float2(SampStep.x,0) );
    float4 dataR = tex2D( DepthNormalSmap, Tex+float2(SampStep.x,0) );
    float4 dataB = tex2D( DepthNormalSmap, Tex+float2(0,SampStep.y) );
    float4 dataT = tex2D( DepthNormalSmap, Tex-float2(0,SampStep.y) );

    // 深度
    float dep0 = data0.x * DEPTH_FAR;
    float depL = dataL.x * DEPTH_FAR;
    float depR = dataR.x * DEPTH_FAR;
    float depB = dataB.x * DEPTH_FAR;
    float depT = dataT.x * DEPTH_FAR;

    // 法線
    float3 normal0 = (data0.yzw * 2.0f - 1.0f);
    float3 normalL = (dataL.yzw * 2.0f - 1.0f);
    float3 normalR = (dataR.yzw * 2.0f - 1.0f);
    float3 normalB = (dataB.yzw * 2.0f - 1.0f);
    float3 normalT = (dataT.yzw * 2.0f - 1.0f);

    // 色データ
    float3 color0 = saturate( tex2D( ScnSamp, Tex ).rgb );
    float3 colorL = saturate( tex2D( ScnSamp, Tex-float2(SampStep.x,0) ).rgb );
    float3 colorR = saturate( tex2D( ScnSamp, Tex+float2(SampStep.x,0) ).rgb );
    float3 colorB = saturate( tex2D( ScnSamp, Tex+float2(0,SampStep.y) ).rgb );
    float3 colorT = saturate( tex2D( ScnSamp, Tex-float2(0,SampStep.y) ).rgb );

    // 視点方向
    float2 pos = float2((2.0f*Tex.x-1.0f)*ViewportSize.x/ViewportSize.y, 1.0f-2.0f*Tex.y);
    float3 viewDirection = IsParth ? normalize( float3(pos/ProjMatrix._22, 1.0f) ) : float3(0,0,1);

    // 深度閾値
    float depThreshold = DepthThreshold/max(dot(normal0*step(data0.w,50.0f), viewDirection), 0.005f);

    // 輪郭フラグ
    float bflagL = 0.0f;
    float bflagR = 0.0f;
    float bflagB = 0.0f;
    float bflagT = 0.0f;

    // 深度による輪郭抽出
    #if SamplingDepth==1
    bflagL = step(depThreshold, abs(dep0 - depL));
    bflagR = step(depThreshold, abs(dep0 - depR));
    bflagB = step(depThreshold, abs(dep0 - depB));
    bflagT = step(depThreshold, abs(dep0 - depT));
    #endif

    // 法線による輪郭抽出
    #if SamplingNormal==1
    bflagL = max(bflagL, step(dot(normal0, normalL), NormalThreshold));
    bflagR = max(bflagR, step(dot(normal0, normalR), NormalThreshold));
    bflagB = max(bflagB, step(dot(normal0, normalB), NormalThreshold));
    bflagT = max(bflagT, step(dot(normal0, normalT), NormalThreshold));
    #endif

    // 色差による輪郭抽出
    #if SamplingColor==1
    bflagL = max(bflagL, step(ColorThreshold, length(color0 - colorL)));
    bflagR = max(bflagR, step(ColorThreshold, length(color0 - colorR)));
    bflagB = max(bflagB, step(ColorThreshold, length(color0 - colorB)));
    bflagT = max(bflagT, step(ColorThreshold, length(color0 - colorT)));
    #endif

    // MMDエッジ描画部の輪郭抽出
    #if SamplingMMDEdge==1
    float edge0 = step(50.0f, data0.w);
    float edgeL = step(50.0f, dataL.w);
    float edgeR = step(50.0f, dataR.w);
    float edgeB = step(50.0f, dataB.w);
    float edgeT = step(50.0f, dataT.w);
    bflagL = max(bflagL, abs(edge0 - edgeL));
    bflagR = max(bflagR, abs(edge0 - edgeR));
    bflagB = max(bflagB, abs(edge0 - edgeB));
    bflagT = max(bflagT, abs(edge0 - edgeT));
    #endif

    return float4(bflagL, bflagR, bflagB, bflagT);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// MLAA法によるアンチエイリアシング処理

// 境界色のブレンド
float4 AAColorBlend(float4 color0, float4 color1, float2 linePt1, float2 linePt2)
{
    float4 Color = color0;

    if(linePt1.y * linePt2.y == 0.0f){
        // L型境界の処理
        float x1 = (linePt1.y == 0.0f) ? max(linePt1.x, linePt2.x-SAMP_NUM-1) : linePt1.x;
        float x2 = (linePt2.y == 0.0f) ? min(linePt2.x, linePt1.x+SAMP_NUM+1) : linePt2.x;
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-x1)/(x2-x1));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-x1)/(x2-x1));
        if(h1 >= 0.0f && h2 >= 0.0f){
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(h1 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h1);
        }else if(h2 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h2);
        }
    }else if(linePt1.y * linePt2.y < 0.0f){
        // Z型境界の処理
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        if(h1 >= 0.0f && h2 >= 0.0f){
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(h1 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h1);
        }else if(h2 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h2);
        }
    }else if(linePt1.y > 0.0f && linePt2.y > 0.0f){
        // U型境界の処理
        float h1, h2;
        float x0 = (linePt1.x + linePt2.x) * 0.5f;
        if(x0 >= 0.5f){
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(x0-linePt1.x));
            h2 = lerp(linePt1.y, 0.0f, ( 0.5f-linePt1.x)/(x0-linePt1.x));
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(x0 <= -0.5f){
            h1 = lerp(0.0f, linePt2.y, (-0.5f-x0)/(linePt2.x-x0));
            h2 = lerp(0.0f, linePt2.y, ( 0.5f-x0)/(linePt2.x-x0));
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else{
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(-linePt1.x));
            h2 = lerp(0.0f, linePt2.y,   0.5f           /( linePt2.x));
            Color = lerp(color0, color1, 0.25f*(h1+h2));
        }
    }

    return Color;
}


// LeftRight境界のAA処理
float4 PS_MLAA_LeftRight(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color  = tex2D( ScnSamp, Tex );
    float4 colorL = tex2D( ScnSamp, Tex-float2(SampStep.x,0) );
    float4 colorR = tex2D( ScnSamp, Tex+float2(SampStep.x,0) );

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Left境界のAA処理
    if(bflag.x > 0.5f){
        // Left境界のジャギー形状解析
        float4 bflag0, bflagL;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         , SampStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x, SampStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagL.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         ,-SampStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x,-SampStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagL.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Left境界色ブレンド
        Color = AAColorBlend(Color, colorL, linePt1, linePt2);
    }

    // Right境界のAA処理
    if(bflag.y > 0.5f){
        // Right境界のジャギー形状解析
        float4 bflag0, bflagR;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         , SampStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( SampStep.x, SampStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagR.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         ,-SampStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( SampStep.x,-SampStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagR.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Right境界色ブレンド
        Color = AAColorBlend(Color, colorR, linePt1, linePt2);
    }

    return Color;
}


// BottomTop境界のAA処理
float4 PS_MLAA_BottomTop(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color  = tex2D( ScnSamp2, Tex );
    float4 colorB = tex2D( ScnSamp2, Tex+float2(0,SampStep.y) );
    float4 colorT = tex2D( ScnSamp2, Tex-float2(0,SampStep.y) );

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Bottom境界のAA処理
    if(bflag.z > 0.5f){
        // Bottom境界のジャギー形状解析
        float4 bflag0, bflagB;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, 0         ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, SampStep.y) );
            if(bflag0.z < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagB.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, 0         ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, SampStep.y) );
            if(bflag0.z < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagB.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Bottom境界色ブレンド
        Color = AAColorBlend(Color, colorB, linePt1, linePt2);
    }

    // Top境界のAA処理
    if(bflag.w > 0.5f){
        // Top境界のジャギー形状解析
        float4 bflag0, bflagT;
        float2 linePt1 = float2(-0.5f-SAMP_NUM, 0.0f);
        float2 linePt2 = float2( 0.5f+SAMP_NUM, 0.0f);
        [unroll] //ループ展開
        for(int i=SAMP_NUM; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, 0         ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, SampStep.y) );
            if(bflag0.w < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagT.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, 0         ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, SampStep.y) );
            if(bflag0.w < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagT.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Top境界色ブレンド
        Color = AAColorBlend(Color, colorT, linePt1, linePt2);
    }

    return Color;
    //return tex2D( OutlineMapSamp, Tex );
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique MLAA_Tech <
    string Script = 
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

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

        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=MLAA_BottomTop;"
    ;
> {
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
}

////////////////////////////////////////////////////////////////////////////////////////////////
