////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ActiveDistortion.fx ver0.0.2  空間歪みエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define FLAG_DEPTH  1   // 深度に応じて 1:歪み度合いを調節, 0:歪み全画面均一

// 歪みぼかしが雑になる時はここを上げる(少し重くなります)
#define BLUR_COUNT  2   // (Si=0～2で1, Si=2～10で2, Si=10～で3 くらいが目安)

#define UseHDR  0   // HDRレンダリングの有無
// 0 : 通常の256階調で処理
// 1 : 高照度情報をそのまま処理

float3 BlendColor <
   string UIName = "歪みブレンド色";
   string UIHelp = "歪みにブレンドする色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(1.0, 1.0, 1.0);

float BlendColorRate <
   string UIName = "ブレンド率";
   string UIHelp = "色のブレンド率";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.05 );

float DistPowerMax <
   string UIName = "歪み強度";
   string UIHelp = "歪み最大強度(最大値を決めてTrで調整)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 3.0;
> = float( 0.5 );


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

float BlurPower = 0.05f;  // 歪みぼかし強度
float BlurPowerB = 5.0f;  // 深度マップ歪みぼかし強度
//float BlurPowerB = 0.0f;  // 深度マップ歪みぼかし強度

float DistBlur <
   string UIName = "歪み拡散";
   string UIHelp = "歪みのぼかし度(大きくすると歪み方がマイルドになります)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int RepertCount = BLUR_COUNT;  // 描画反復回数
int RepertCountB = 2;          // 描画反復回数(深度マップ)
int RepertIndex;               // 描画反復回数のカウンタ

#define LOOP_COUNT  8   // 深度による歪み判定のサンプリング数

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5) / ViewportSize;
// サンプリング間隔
static float2 SampStep  = (float2(1,1) / ViewportSize) * AcsSi * DistBlur * BlurPower / pow(6.0f, RepertIndex);
static float2 SampStepB = (float2(1,1) / ViewportSize) * BlurPowerB / pow(6.0f, RepertIndex);
static float2 SampStep1 = float2(2,2) / ViewportSize;
static float2 SampStep0 = float2(1,1) / ViewportSize;

#define DEPTH_FAR   5000.0f  // 深度最遠値

#ifndef MIKUMIKUMOVING
    #define OFFSCREEN_MASK  "AD_Mask.fxsub"
#else
    #define OFFSCREEN_MASK  "AD_MaskMMM.fxsub"
#endif


//#define TEX_FORMAT "D3DFMT_A16B16G16R16F"
#define TEX_FORMAT "D3DFMT_A32B32G32R32F"

// オフスクリーン法線・深度マップ
texture DistortionRT: OFFSCREENRENDERTARGET <
    string Description = "ActiveDistortion.fxの法線・深度マップ, ここにAD_～.fxを適用";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = {0.5f, 0.5f, 0.0, 0.005};
    float ClearDepth = 1.0;
    string Format = TEX_FORMAT;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        #ifndef MIKUMIKUMOVING
        "DistObjPosControl.pmd = hide;"
        "DistObjUVControl.pmd = hide;"
        "DistJet.pmx = DistJet\\AD_Jet.fx;"
        "DistLine.x = DistLine\\AD_Line.fx;"
        "DistVortex.pmx = DistVortex\\AD_Vortex.fx;"
        "DistSpiral.x  = DistSpiral\\AD_Spiral.fx;"
        "DistParticle.x = DistParticle\\AD_Particle.fx;"
        "DistRipple.x = DistRipple\\AD_Ripple.fx;"
        "DistWind.x = DistWind\\AD_Wind.fx;"
        "DistFire.x = DistFire\\AD_Fire.fx;"
        "DistMangaTears.x = DistMangaTears\\AD_MangaTears.fx;"
        #endif
        "* =" OFFSCREEN_MASK ";";
>;
sampler NormalDepthMap = sampler_state {
    texture = <DistortionRT>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

//#define TEX_FORMATB "D3DFMT_R16F"
#define TEX_FORMATB "D3DFMT_R32F"

// 歪み部位を含まない深度マップ
shared texture2D DepthTexB : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 0;
    string Format = TEX_FORMATB;
>;
sampler2D DepthMapB = sampler_state {
    texture = <DepthTexB>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

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

#if UseHDR==0
    #define TEX_SCRFORMAT "D3DFMT_A8R8G8B8"
#else
    #define TEX_SCRFORMAT "D3DFMT_A16B16G16R16F"
    //#define TEX_SCRFORMAT "D3DFMT_A32B32G32R32F"
#endif

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float4 ClearColorB = {1,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 0;
    string Format = TEX_SCRFORMAT;
>;
sampler2D ScnSmp = sampler_state {
    texture = <ScnTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// レンダーターゲットの深度ステンシルバッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D NormalDepthTexX : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D NormalDepthMapX = sampler_state {
    texture = <NormalDepthTexX>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D NormalDepthTexY : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D NormalDepthMapY = sampler_state {
    texture = <NormalDepthTexY>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 歪み部位を含まない深度マップぼかし用
shared texture2D DepthTexB2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMATB;
>;
sampler2D DepthMapB2 = sampler_state {
    texture = <DepthTexB2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 法線のぼかし,ぼかしによる深度補正

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT VS_Common(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// バッファのコピー
float4 PS_Copy( float2 Tex: TEXCOORD0 ) : COLOR0
{
    return tex2D( NormalDepthMap, Tex );
}

// X方向ぼかし
float4 PS_GaussianX( float2 Tex: TEXCOORD0 ) : COLOR0
{
    float4 Color;
    float3 normal;
    float  dep;

    Color  = tex2D( NormalDepthMapY, Tex );
    normal = WT_COEF[0] * Color.rgb;  dep = Color.a;

    [unroll]
    for(int i=1; i<8; i++){
        Color = tex2D( NormalDepthMapY, Tex+float2(SampStep.x*i, 0) );
        normal += WT_COEF[i] * Color.rgb;  if(Color.a > 0.5f && dep < Color.a) dep = Color.a;
        Color = tex2D( NormalDepthMapY, Tex-float2(SampStep.x*i, 0) );
        normal += WT_COEF[i] * Color.rgb;  if(Color.a > 0.5f && dep < Color.a) dep = Color.a;
    }

    return float4(normal, dep);
}

// Y方向ぼかし
float4 PS_GaussianY( float2 Tex: TEXCOORD0 ) : COLOR0
{
    float4 Color;
    float3 normal;
    float  dep;

    Color  = tex2D( NormalDepthMapX, Tex );
    normal = WT_COEF[0] * Color.rgb;  dep = Color.a;

    [unroll]
    for(int i=1; i<8; i++){
        Color = tex2D( NormalDepthMapX, Tex+float2(0, SampStep.y*i) );
        normal += WT_COEF[i] * Color.rgb;  if(Color.a > 0.5f && dep < Color.a) dep = Color.a;
        Color = tex2D( NormalDepthMapX, Tex-float2(0, SampStep.y*i) );
        normal += WT_COEF[i] * Color.rgb;  if(Color.a > 0.5f && dep < Color.a) dep = Color.a;
    }

    return float4(normal, dep);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 深度マップのぼかし

// X方向ぼかし
float4 PS_DepthGaussianX( float2 Tex: TEXCOORD0 ) : COLOR
{
    //float MipLv = log2( max(ViewportSize.x*SampStepB, 1.0f) );
    float MipLv = 0;

    float dep, sumRate = WT_COEF[0];
    float dep0 = tex2Dlod( DepthMapB, float4(Tex,0,MipLv) ).r;
    float sumDep = WT_COEF[0] * dep0;

    // 奥側にある深度はサンプリングしない
    [unroll]
    for(int i=1; i<8; i++){
        dep = tex2Dlod( DepthMapB, float4(Tex.x-SampStepB.x*i,Tex.y,0,MipLv) ).r;
        sumDep += WT_COEF[i] * dep * step(dep, dep0);  sumRate += WT_COEF[i] * step(dep, dep0);
        dep = tex2Dlod( DepthMapB, float4(Tex.x+SampStepB.x*i,Tex.y,0,MipLv) ).r;
        sumDep += WT_COEF[i] * dep * step(dep, dep0);  sumRate += WT_COEF[i] * step(dep, dep0);
    }

    dep = sumDep / sumRate;
    return float4(dep, 0, 0, 1);
}

// Y方向ぼかし
float4 PS_DepthGaussianY(float2 Tex: TEXCOORD0) : COLOR
{
    float dep, sumRate = WT_COEF[0];
    float dep0 = tex2D( DepthMapB2, Tex ).r;
    float sumDep = WT_COEF[0] * dep0;

    // 奥側にある深度はサンプリングしない
    [unroll]
    for(int i=1; i<8; i++){
        dep = tex2D( DepthMapB2, Tex-float2(0,SampStepB.y*i) ).r;
        sumDep += WT_COEF[i] * dep * step(dep, dep0);  sumRate += WT_COEF[i] * step(dep, dep0);
        dep = tex2D( DepthMapB2, Tex+float2(0,SampStepB.y*i) ).r;
        sumDep += WT_COEF[i] * dep * step(dep, dep0);  sumRate += WT_COEF[i] * step(dep, dep0);
    }

    dep = sumDep / sumRate;
    return float4(dep, 0, 0, 1);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// オリジナル描画の歪み処理

float4 PS_Object( float2 Tex: TEXCOORD0 ) : COLOR0
{
    // 元の法線・深度
    float4 Color0 = tex2D( NormalDepthMap, Tex );
    // ぼかし処理後の法線・深度
    float4 Color1 = tex2D( NormalDepthMapY, Tex );

    //float3 Normal = normalize( Color1.rgb*(255.0f/127.0f) - 1.0f ); // バッファが8bitだったらこちらを使う
    float3 Normal = normalize( Color1.rgb*2.0f - 1.0f ); // 法線
    float distDep = (Color1.a > 0.5f) ? (2.0f * Color1.a - 1.0f) * DEPTH_FAR : 0.0f; // ぼかし処理後の深度
    float srcDep  = abs(2.0f * Color0.a - 1.0f) * DEPTH_FAR;                         // ぼかし処理前の深度

    // 手前側にあるモデルのぼかしによるにじみをリセット
    if(Color0.a <= 0.5f && distDep > srcDep){
        Normal = float3(0,0,-1);
        distDep = 0.0f;
    }

    // 歪み強度
    #if(FLAG_DEPTH > 0)
    float  depB = max(tex2D( DepthMapB, Tex ).r * DEPTH_FAR - distDep, 0.0f);
    float2 dist = Normal.xy * DistPowerMax * AcsTr * clamp(depB / DEPTH_FAR + 0.1f, 0.1f, 1.0f);
    #else
    float2 dist = Normal.xy * DistPowerMax * AcsTr * min(20.0f / distDep, 1.0f);
    #endif
    dist *= float2(ViewportSize.y / ViewportSize.x, -1.0f);

    // 歪み処理
    float ex = pow(100.0f, 1.0f/float(LOOP_COUNT));
    float depStep = 1.0f;
    float4 Color = tex2D( ScnSmp, Tex );
    if(Color1.a > 0.5f){
        [unroll] //ループ展開
        for(int i=1; i<=LOOP_COUNT; i++){
            depStep *= ex;
            // サンプリング位置を徐々に拡げて手前にあるモデルを拾わないようにする
            float2 texCoord = Tex - dist * float(i) / float(LOOP_COUNT);
            float rayDep = distDep + depStep; // レイ位置の深度(適当)
            float smpDep  = tex2D( NormalDepthMap, texCoord ).a; // AAのブレンド位置を拾わないように4方もチェック
            float smpDepL = tex2D( NormalDepthMap, texCoord+float2(-SampStep1.x,0) ).a;
            float smpDepR = tex2D( NormalDepthMap, texCoord+float2( SampStep1.x,0) ).a;
            float smpDepB = tex2D( NormalDepthMap, texCoord+float2(0,-SampStep1.y) ).a;
            float smpDepT = tex2D( NormalDepthMap, texCoord+float2(0, SampStep1.y) ).a;
            if( (smpDep  > 0.5f || abs(2.0f * smpDep  - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepL > 0.5f || abs(2.0f * smpDepL - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepR > 0.5f || abs(2.0f * smpDepR - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepB > 0.5f || abs(2.0f * smpDepB - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepT > 0.5f || abs(2.0f * smpDepT - 1.0f) * DEPTH_FAR > distDep) ){
                // 深度がレイ位置の手前にある時は拾わない
                #if(FLAG_DEPTH > 0)
                depB = tex2D( DepthMapB, texCoord ).r * DEPTH_FAR + 0.01f;
                if(i==1 || rayDep < depB){
                    Color = tex2D( ScnSmp, texCoord );
                }
                #else
                    Color = tex2D( ScnSmp, texCoord );
                #endif
            }
        }
    }

    /*
    // 歪み処理
    float4 Color = tex2D( ScnSmp, Tex );
    if(Color1.a > 0.5f){
        // サンプリング位置を二分探索で求める
        float rayDepMin = distDep;
        float rayDepMax = distDep + 100.0f;
        for(int i=1; i<=LOOP_COUNT; i++){
            float rayDep = (rayDepMin + rayDepMax) * 0.5f; // レイ位置の深度(適当)
            float2 texCoord = Tex - dist * (rayDep - distDep) / 100.0f;
            // 手前にあるモデルを拾わないようにする
            float smpDep  = tex2D( NormalDepthMap, texCoord ).a; // AAのブレンド位置を拾わないように4方もチェック
            float smpDepL = tex2D( NormalDepthMap, texCoord+float2(-SampStep1.x,0) ).a;
            float smpDepR = tex2D( NormalDepthMap, texCoord+float2( SampStep1.x,0) ).a;
            float smpDepB = tex2D( NormalDepthMap, texCoord+float2(0,-SampStep1.y) ).a;
            float smpDepT = tex2D( NormalDepthMap, texCoord+float2(0, SampStep1.y) ).a;
            if( (smpDep  > 0.5f || abs(2.0f * smpDep  - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepL > 0.5f || abs(2.0f * smpDepL - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepR > 0.5f || abs(2.0f * smpDepR - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepB > 0.5f || abs(2.0f * smpDepB - 1.0f) * DEPTH_FAR > distDep) &&
                (smpDepT > 0.5f || abs(2.0f * smpDepT - 1.0f) * DEPTH_FAR > distDep) ){
                // 深度がレイ位置の手前にある時は拾わない
                #if(FLAG_DEPTH > 0)
                depB = tex2D( DepthMapB, texCoord ).r * DEPTH_FAR;
                if(i==1 || rayDep < depB){
                    Color = tex2D( ScnSmp, texCoord );
                }
                #else
                    Color = tex2D( ScnSmp, texCoord );
                #endif
                rayDepMin = rayDep;
            }else{
                rayDepMax = rayDep;
            }
        }
    }
    */

    // 指定色とブレンド
    float len = length(Normal.xy)*AcsTr;
    Color.xyz = lerp(Color.xyz, BlendColor, saturate(BlendColorRate*sqrt(len)));

    //Color = float4((Normal+1)*0.5,1);
    //Color = tex2D( NormalDepthMap, Tex );
    //Color = float4(tex2D( NormalDepthMap, Tex ).w,0,0,1);
    //Color = float4(distDep/30,0,0,1);
    //Color = float4(abs(2.0f * Color0.a - 1.0f) * DEPTH_FAR/200,0,0,1);
    //Color = float4(tex2D( DepthMapB, Tex ).r * DEPTH_FAR/200,0,0,1);

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=ScnTex;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

        "RenderColorTarget0=NormalDepthTexY;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=BuffCopy;"

        "LoopByCount=RepertCount;"
        "LoopGetIndex=RepertIndex;"
            "RenderColorTarget0=NormalDepthTexX;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=GaussianX;"
            "RenderColorTarget0=NormalDepthTexY;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=ClearColor;"
                "ClearSetDepth=ClearDepth;"
                "Clear=Color;"
                "Clear=Depth;"
                "Pass=GaussianY;"
        "LoopEnd=;"

        #if(FLAG_DEPTH > 0)
        "LoopByCount=RepertCountB;"
        "LoopGetIndex=RepertIndex;"
        "RenderColorTarget0=;"
        "RenderColorTarget0=DepthTexB2;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=GaussianXB;"
        "RenderColorTarget0=DepthTexB;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=GaussianYB;"
        "LoopEnd=;"
        #endif

        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"

        "RenderColorTarget0=DepthTexB;"
            "ClearSetColor=ClearColorB;"
            "Clear=Color;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
        ; >
{
    pass BuffCopy < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_1_1 VS_Common();
        PixelShader  = compile ps_2_0 PS_Copy();
    }
    pass GaussianX < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_GaussianX();
    }
    pass GaussianY < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_GaussianY();
    }
    #if(FLAG_DEPTH > 0)
    pass GaussianXB < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DepthGaussianX();
    }
    pass GaussianYB < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_DepthGaussianY();
    }
    #endif
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_Object();
    }
}



