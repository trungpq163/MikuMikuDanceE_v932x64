////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgPointLight.fx ver0.0.2  点光源エフェクト(セルフシャドウあり)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024   // 512, 1024, 2048, 4096 のどれかで選択

// アンチエイリアスによる輪郭部の遮蔽誤判定対策
#define UseAAShadow  0   // 0:しない, 1:する
// (輪郭部のちらつきが目立つ場合はここを1にすると消える,ただしジャギーが出る)

// 輪郭抽出(深度)閾値設定
#define DepthThreshold  1.0


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_OBJ    "HgPL_Object.fxsub"
    #define OFFSCREEN_SMAP   "HgPL_ShadowMap.fxsub"
    #define OFFSCREEN_SMAPFA "おまけ\\床影対策\\HgPL_ShadowMap_FA.fxsub"
    #define OFFSCREEN_WPOS   "HgPL_WPosMap.fxsub"
    #define PLC_OBJNAME      "(self)"
    static bool flagPLC = true;
    float3 LightPosition : CONTROLOBJECT < string name = "(self)"; string item = "光源位置"; >;
#else
    #define OFFSCREEN_OBJ    "HgPL_ObjectMMM.fxsub"
    #define OFFSCREEN_SMAP   "HgPL_ShadowMapMMM.fxsub"
    #define OFFSCREEN_SMAPFA "おまけ\\床影対策\\HgPL_ShadowMapMMM_FA.fxsub"
    #define OFFSCREEN_WPOS   "HgPL_WPosMapMMM.fxsub"
    #define PLC_OBJNAME      "HgPointLight.pmx"
    bool flagPLC : CONTROLOBJECT < string name = PLC_OBJNAME; >;
    float3 LightPosition : CONTROLOBJECT < string name = PLC_OBJNAME; string item = "光源位置"; >;
    //float4x4 LightWorldMatrix : WORLD;
    //static float3 LightPosition = LightWorldMatrix._41_42_43;
#endif

// コントロールパラメータ
float MorphSdBulr : CONTROLOBJECT < string name = PLC_OBJNAME; string item = "影ぼかし"; >;
float MorphSdDens : CONTROLOBJECT < string name = PLC_OBJNAME; string item = "影濃度"; >;
static float ShadowBulrPower = flagPLC ? max( lerp(0.0f, 5.0f, MorphSdBulr), 0.0f) : 1.0f; // ソフトシャドウのぼかし強度
static float ShadowDensity = flagPLC ? saturate(1.0f - MorphSdDens) : 0.0f;                // セルフ影の濃度

// カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5) / ViewportSize;
static float2 SampStep = float2(1,1) / ViewportSize;

// オフスクリーン点光源ライティングバッファ
texture HgPL_Draw: OFFSCREENRENDERTARGET <
    string Description = "HgPointLight.fxのモデルの点光源オブジェクト描画";
    float2 ViewPortRatio = {1.0, 2.0};
    float4 ClearColor = {0, 0, 0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "HgPointLight.pmx = hide;"
        "* =" OFFSCREEN_OBJ ";";
>;
sampler ObjDrawSamp = sampler_state {
    texture = <HgPL_Draw>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// シャドウマップバッファサイズ
#if ShadowMapSize==512
    #define SMAPSIZE_WIDTH   512
    #define SMAPSIZE_HEIGHT  1024
#endif
#if ShadowMapSize==1024
    #define SMAPSIZE_WIDTH   1024
    #define SMAPSIZE_HEIGHT  2048
#endif
#if ShadowMapSize==2048
    #define SMAPSIZE_WIDTH   2048
    #define SMAPSIZE_HEIGHT  4096
#endif
#if ShadowMapSize==4096
    #define SMAPSIZE_WIDTH   4096
    #define SMAPSIZE_HEIGHT  8192
#endif

// オフスクリーン動的双放物面シャドウマップバッファ
texture HgPL_SMap : OFFSCREENRENDERTARGET <
    string Description = "HgPointLight.fxのシャドウマップ";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    #if UseSoftShadow==1
    string Format = "D3DFMT_G32R32F" ;
    #else
    string Format = "D3DFMT_R32F" ;
    #endif
    bool AntiAlias = false;
    int Miplevels = 0;
    string DefaultEffect = 
        "self = hide;"
        "HgPointLight.pmx = hide;"
        "FloorAssist.x =" OFFSCREEN_SMAPFA ";"
        "* =" OFFSCREEN_SMAP ";";
>;
sampler ShadowMapSamp = sampler_state {
    texture = <HgPL_SMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// オフスクリーンワールド座標バッファ
texture2D HgPL_WPos : OFFSCREENRENDERTARGET <
    string Description = "HgPointLight.fxのモデル座標バッファ";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A32B32G32R32F";
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "HgPointLight.pmx = hide;"
        "* =" OFFSCREEN_WPOS ";";
>;
sampler2D WPosSamp = sampler_state {
    texture = <HgPL_WPos>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


#ifdef MIKUMIKUMOVING
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// テクスチャフォーマット
#define TEX_FORMAT "D3DFMT_A16B16G16R16F"

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
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウマップ関連の処理

#if UseSoftShadow==1
// シャドウマップのサンプリング間隔
static float2 SMapSampStep = float2(ShadowBulrPower/1024.0f, ShadowBulrPower/2048.0f);

// シャドウマップの周辺サンプリング1
float4 GetZPlotSampleBase1(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv));
    return (Color / 6.0f);
}

// シャドウマップの周辺サンプリング2
float4 GetZPlotSampleBase2(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv));
    return (Color / 6.0f);
}
#endif

#define MSC   0.98  // マップ縮小率

// 双放物面シャドウマップよりZプロット読み取り
float2 GetZPlotDP(float3 Vec)
{
    Vec = normalize(Vec);
    bool flagFront = (Vec.z >= 0) ? true : false;

    if ( !flagFront ) Vec.yz = -Vec.yz;
    float2 Tex = Vec.xy * MSC / (1.0f + Vec.z);
    Tex.y = -Tex.y;
    Tex = (Tex + 1.0f) * 0.5f;
    Tex.y = flagFront ? 0.5f*Tex.y : 0.5f*(Tex.y+1.0f) + 1.0f/SMAPSIZE_HEIGHT;

    #if UseSoftShadow==1
    float4 Color;
    Color  = GetZPlotSampleBase1(Tex, 1.0f) * 0.508f;
    Color += GetZPlotSampleBase2(Tex, 2.0f) * 0.254f;
    Color += GetZPlotSampleBase1(Tex, 3.0f) * 0.127f;
    Color += GetZPlotSampleBase2(Tex, 4.0f) * 0.063f;
    Color += GetZPlotSampleBase1(Tex, 5.0f) * 0.032f;
    Color += GetZPlotSampleBase2(Tex, 6.0f) * 0.016f;
    #else
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex,0,0));
    #endif

    return Color.xy;
}

#if UseAAShadow==1
// アンチエイリアスブレンド位置では奥側の隣接ピクセルをサンプリング
float2 GetTexCoordAA(float2 Tex0)
{
    // 周辺のワールド座標と深度
    float Depth0 = distance( tex2D( WPosSamp, Tex0 ).xyz, CameraPosition );
    float DepthL = distance( tex2D( WPosSamp, Tex0+SampStep*float2(-1, 0) ).xyz, CameraPosition );
    float DepthR = distance( tex2D( WPosSamp, Tex0+SampStep*float2( 1, 0) ).xyz, CameraPosition );
    float DepthT = distance( tex2D( WPosSamp, Tex0+SampStep*float2( 0,-1) ).xyz, CameraPosition );
    float DepthB = distance( tex2D( WPosSamp, Tex0+SampStep*float2( 0, 1) ).xyz, CameraPosition );

    // 輪郭部では奥側のTex座標に補正
    float DepthMax = Depth0;
    float2 Tex = Tex0;
    if(abs(Depth0 - DepthL) > DepthThreshold){
       if( DepthMax < DepthL ){
           DepthMax = DepthL;
           Tex = Tex0 + SampStep * float2(-1, 0);
       }
    }
    if(abs(Depth0 - DepthR) > DepthThreshold){
       if( DepthMax < DepthR ){
           DepthMax = DepthR;
           Tex = Tex0 + SampStep * float2( 1, 0);
       }
    }
    if(abs(Depth0 - DepthT) > DepthThreshold){
       if( DepthMax < DepthT ){
           DepthMax = DepthT;
           Tex = Tex0 + SampStep * float2( 0,-1);
       }
    }
    if(abs(Depth0 - DepthB) > DepthThreshold){
       if( DepthMax < DepthB ){
           DepthMax = DepthB;
           Tex = Tex0 + SampStep * float2( 0, 1);
       }
    }

    return Tex;
}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// ライティング描画の加算合成

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Draw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

// ピクセルシェーダ
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 上下2画面のTex座標
    float2 TexUpper = float2(Tex.x, 0.5f*Tex.y);
    float2 TexUnder = float2(Tex.x, 0.5f*(Tex.y+1.0f));

    // ライティング処理の色
    float4 Color = tex2D( ObjDrawSamp, TexUpper );

    // 影の色
    float4 ShadowColor0 = float4(Color.rgb*ShadowDensity, Color.a);
    float4 ShadowColor = tex2D( ObjDrawSamp, TexUnder );
    ShadowColor = max(ShadowColor, ShadowColor0);

    // AAブレンド位置を考慮してTex座標を補正
    #if UseAAShadow==1
    Tex = GetTexCoordAA(Tex);
    #endif

    // ライトベクトル・Z値
    float4 ColorPos = tex2D( WPosSamp, Tex );
    float3 LtVec = ColorPos.xyz - LightPosition;
    float z = ColorPos.w;

    // シャドウマップZプロット
    float2 zplot = GetZPlotDP( LtVec );

    #if UseSoftShadow==1
    // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
    float variance = max( zplot.y - zplot.x * zplot.x, 0.002f );
    float Comp = variance / (variance + max(z - zplot.x, 0.0f));
    #else
    // 影部判定(ソフトシャドウ無し)
    float Comp = 1.0f - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
    #endif

    // 影の合成
    Color = lerp(ShadowColor, Color, Comp);

    #ifdef MIKUMIKUMOVING
    float4 Color0 = tex2D( ScnSamp, Tex );
    Color.rgb += Color0.rgb;
    Color.a = Color0.a;
    #endif

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        #ifdef MIKUMIKUMOVING
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        #endif
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            #ifndef MIKUMIKUMOVING
            "ScriptExternal=Color;"
            #endif
            "Pass=PostDraw;"
    ;
> {
    pass PostDraw < string Script= "Draw=Buffer;"; > {
        #ifndef MIKUMIKUMOVING
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        #endif
        VertexShader = compile vs_3_0 VS_Draw();
        PixelShader  = compile ps_3_0 PS_Draw();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
