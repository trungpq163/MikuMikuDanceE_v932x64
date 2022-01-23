////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HeatGround.fx ver0.0.1  陽炎＆逃げ水エフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define UseHDR  0   // HDRレンダリングの有無
// 0 : 通常の256階調で処理
// 1 : 高照度情報をそのまま処理

#ifndef MIKUMIKUMOVING
// ↓MME使用時のみ変更(MMMはUIコントロールより変更可)

// 陽炎に関するパラメータ
float HeightMax = 30.0;       // 揺らぎが起きる最大高さ
float HeightGrad = 0.05;      // カメラからの水平距離に対する揺らぎ最大高さの傾き
float LengthMin = 40.0;       // 屈折開始位置の最近傍距離
float RayLengthMax = 250.0;   // 屈折開始位置から飛ばすレイの最大距離
float DistFreq = 1.0;         // 揺らぎの細かさ
float DistSpeed = 0.05;       // 揺らぎの速さ

// 逃げ水に関するパラメータ
float MirrorFreq = 0.005;    // 鏡面の揺らぎ細かさ
float MirrorFreqSpeed = 0.3; // 鏡面の揺らぎ速さ
float MirrorDirec = 0.1;     // 逃げ水範囲,鏡面化するレイの角度(最大値を決めてTrで調整)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#else
// MMMパラメータ

// 陽炎に関するパラメータ
float DistPower <
   string UIName = "陽炎強さ";
   string UIHelp = "大きくすると揺らぎが激しくなる";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 1.0 );

float MirrorDirec <
   string UIName = "逃げ水範囲";
   string UIHelp = "鏡面化するレイの水平面に対する角度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 0.3;
> = float( 0.05 );

float heightMax <
   string UIName = "陽炎揺らぎ高";
   string UIHelp = "揺らぎが起きる最大高さ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = float( 30.0 );

float HeightGrad <
   string UIName = "陽炎揺らぎ傾き";
   string UIHelp = "カメラからの水平距離に対する揺らぎ最大高さの傾き";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.05 );

float LengthMin <
   string UIName = "陽炎開始距離";
   string UIHelp = "屈折開始位置の最近傍距離";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 200.0;
> = float( 40.0 );

float RayLengthMax <
   string UIName = "陽炎最大距離";
   string UIHelp = "屈折開始位置から飛ばすレイの最大距離";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 9999.0;
> = float( 250.0 );

float DistFreq <
   string UIName = "陽炎細かさ";
   string UIHelp = "大きくすると揺らぎが細かくなる";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );

float DistSpeed <
   string UIName = "陽炎速さ";
   string UIHelp = "大きくすると揺らぎが速くなる";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.05 );

// 逃げ水に関するパラメータ
float MirrorFreq <
   string UIName = "逃げ水細かさ";
   string UIHelp = "大きくすると揺らぎが細かくなる";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 0.1;
> = float( 0.005 );

float MirrorFreqSpeed <
   string UIName = "逃げ水速さ";
   string UIHelp = "大きくすると揺らぎが速くなる";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 0.2 );

#endif

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

float time : TIME;

float AcsY : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;
float4x4 ViewProjMatrix : VIEWPROJECTION;

// カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

#define LOOP_COUNT  8   // レイの深度判定のサンプリング数

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5) / ViewportSize;
static float2 SampStep1 = float2(2,2) / ViewportSize;

#define DEPTH_FAR   5000.0f  // 深度最遠値

#ifndef MIKUMIKUMOVING
    static float heightMax = HeightMax + AcsY;   // 揺らぎが起きる最大高さ
    static float DistPower = AcsSi * 0.1f;       // 陽炎強さ
    #define OFFSCREEN_NORMAL  "Heat_Normal.fxsub"
    #define OFFSCREEN_POSDEP  "Heat_PosDepth.fxsub"
#else
    #define OFFSCREEN_NORMAL  "Heat_NormalMMM.fxsub"
    #define OFFSCREEN_POSDEP  "Heat_PosDepthMMM.fxsub"
#endif


// オフスクリーン法線マップ
texture HeatNormalRT: OFFSCREENRENDERTARGET <
    string Description = "HeatGround.fxの法線マップ";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = {0, 0 ,0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_X8R8G8B8" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* =" OFFSCREEN_NORMAL ";";
>;
sampler NormalMapSmp = sampler_state {
    texture = <HeatNormalRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// オフスクリーン位置・深度マップ
texture HeatPosDepRT: OFFSCREENRENDERTARGET <
    string Description = "HeatGround.fxの位置・深度マップ";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = {0, 0 ,0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A32B32G32R32F";
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* =" OFFSCREEN_POSDEP ";";
>;
sampler PosDepMapSmp = sampler_state {
    texture = <HeatPosDepRT>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


#if UseHDR==0
    #define TEX_FORMAT "D3DFMT_A8R8G8B8"
#else
    #define TEX_FORMAT "D3DFMT_A16B16G16R16F"
    //#define TEX_FORMAT "D3DFMT_A32B32G32R32F"
#endif

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float  ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D ScnSmp = sampler_state {
    texture = <ScnTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// レンダーターゲットの深度ステンシルバッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D3DFMT_D24S8";
>;

// 逃げ水描画後の結果を記録するためのレンダーターゲット
texture2D RoadMirageTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = TEX_FORMAT;
>;
sampler2D RoadMirageSmp = sampler_state {
    texture = <RoadMirageTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// ノイズテクスチャ
texture2D NoiseTex <
    string ResourceName = "Noise1.png";
    int MipLevels = 0;
>;
sampler NoiseSmp = sampler_state {
    texture = <NoiseTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

// ノイズ法線テクスチャ
texture2D NoiseNormalTex <
    string ResourceName = "NoiseNormal.png";
    int MipLevels = 0;
>;
sampler NoiseNormalSmp = sampler_state {
    texture = <NoiseNormalTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Common(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 逃げ水反射面追加

float4 PS_RoadMirage( float2 Tex: TEXCOORD0 ) : COLOR0
{
    // 元画像のピクセル上のデータ
    float3 normal = normalize( tex2D( NormalMapSmp, Tex ).xyz * 2.0f - 1.0f ); // 法線
    float4 Color = tex2D( PosDepMapSmp, Tex );
    float3 wpos = Color.xyz;  // ワールド座標
    float  dep0 = Color.w;    // 深度
    float3 eye = normalize(CameraPosition - wpos);  // カメラ方向
    float  en_cos = dot(eye, float3(0,1,0));  // 水平面とカメラ方向のなす角
    float  maxDir = MirrorDirec * AcsTr;

    Color = tex2D( ScnSmp, Tex );  // 元画像の色

    // 法線が上向きでレイが鋭角に当たる位置が鏡面になる
    if((dot(normal, float3(0,1,0)) > 0.99f) && (0.0f < en_cos && en_cos < MirrorDirec) && (dep0 > 0.0f)){

        // 反射後のレイの向き
        float3 dirRay =  normalize(float3(0,1,0) * (2.0f * dot(eye, float3(0,1,0))) - eye);
        //float3 dirRay = normal * (2.0f * dot(eye, normal)) - eye;

        // レイ方向にノイズを加える
        float2 normalTexCoord = ( wpos.xz * 0.003f + time * MirrorFreqSpeed ) * 0.8f;
        float3 gnormal = normalize( tex2D( NoiseNormalSmp, normalTexCoord ).xyz * 2.0f - 1.0f );
        dirRay = normalize( dirRay + gnormal * MirrorFreq );

        // 鏡面の反射率
        float bordRate = smoothstep(-maxDir, -0.2f*maxDir, -en_cos);  // 境界付近の反射率
        bordRate *= smoothstep(0.0f, 0.8f, tex2D( NoiseSmp, wpos.xz / 200.0f + 0.1f * time ).x);  // ノイズで反射率を散らす

        // サンプリング位置を徐々に拡げて手前にあるモデルを拾わないようにする
        float ex = pow(1000.0f, 1.0f/float(LOOP_COUNT));
        float depStep = 1.0f;
        [unroll] //ループ展開
        for(int i=1; i<=LOOP_COUNT; i++){
            depStep *= ex;
            float3 posRay = wpos + dirRay * depStep; // レイ位置
            float4 posRayProj = mul( float4(posRay, 1), ViewProjMatrix );
            float2 texCoord = (posRayProj.xy / posRayProj.w * float2(1,-1) + 1.0f) * 0.5f + ViewportOffset; // レイ位置のスクリーン座標
            float dep = tex2D( PosDepMapSmp, texCoord ).w * DEPTH_FAR;
            // 深度がレイ位置の手前にある時は拾わない
            if(length(posRay - CameraPosition) < dep){
                Color = lerp( Color, tex2D( ScnSmp, texCoord ), bordRate );
            }
        }
    }

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 陽炎による揺らぎ追加

float4 PS_HeatHaze( float2 Tex: TEXCOORD0 ) : COLOR0
{
    float4 Color = tex2D( PosDepMapSmp, Tex );
    float3 wpos = Color.xyz;  // ワールド座標
    float  dep0 = Color.w;    // 深度
    float3 eye = normalize(wpos - CameraPosition);

    float3 spos = wpos;  // 屈折開始位置
    float3 epos = wpos;  // 屈折終了位置
    if(CameraPosition.y > heightMax){
        float a = CameraPosition.y - heightMax;
        float b = heightMax + HeightGrad * length(CameraPosition.xz - wpos.xz) - wpos.y;
        if(b > 0.0f){
            spos = lerp(CameraPosition, wpos, saturate(a/(a+b)));
            spos += eye * LengthMin;
        }
    }else{
        spos = CameraPosition + eye * LengthMin;
        float a = heightMax - CameraPosition.y;
        float b = wpos.y - heightMax - HeightGrad * length(CameraPosition.xz - wpos.xz);
        if(b > 0.0f){
            float a = heightMax - CameraPosition.y;
            float b = wpos.y - heightMax - HeightGrad * length(CameraPosition.xz - wpos.xz);
            epos = lerp(CameraPosition, wpos, saturate(a/(a+b)));
        }
    }

    // レイの屈折が起こる距離
    float depHeightMax = heightMax + HeightGrad * length(CameraPosition.xz - (spos.xz+epos.xz)*0.5f);
    float hdep = max(length(epos - CameraPosition) - length(spos - CameraPosition), 0) * saturate((depHeightMax-0.5f*(spos.y+epos.y))/depHeightMax);
    hdep = min(hdep, RayLengthMax);

    // 揺らぎによるレイ方向補正
    float2 normalTexCoord1 = (Tex + float2( time, time) * DistSpeed) * DistFreq * float2(ViewportSize.x / ViewportSize.y, -1.0f);
    float2 normalTexCoord2 = (Tex + float2(-time, time) * DistSpeed) * DistFreq * float2(ViewportSize.x / ViewportSize.y, -1.0f);
    float  mipLevel = max(3.0f - 0.1f*degrees(2.0f*atan(1.0f/ProjMatrix._22)), 0.0f);
    float3 normal1 = tex2Dlod( NoiseNormalSmp, float4(normalTexCoord1, 0, mipLevel) ).xyz * 2.0f - 1.0f;
    float3 normal2 = tex2Dlod( NoiseNormalSmp, float4(normalTexCoord2, 0, mipLevel) ).xyz * 2.0f - 1.0f;
    float3 normal = normalize(normal1 + normal2);
    float3 dirRay = normalize( lerp(eye, eye+normal*DistPower*0.004f/(mipLevel+1.0f), hdep/RayLengthMax) );

    Color = tex2D( RoadMirageSmp, Tex );  // 揺らぎ前の色

    if(hdep > 0.0f && dep0 > 0.0f){
        // サンプリング位置を徐々に拡げて手前にあるモデルを拾わないようにする
        float ex = pow(RayLengthMax, 1.0f/float(LOOP_COUNT));
        float depStep = 1.0f;
        [unroll] //ループ展開
        for(int i=1; i<=LOOP_COUNT; i++){
            depStep *= ex;
            float3 posRay = spos + dirRay * depStep; // レイ位置
            float4 posRayProj = mul( float4(posRay, 1), ViewProjMatrix );
            float2 texCoord = (posRayProj.xy / posRayProj.w * float2(1,-1) + 1.0f) * 0.5f + ViewportOffset; // レイ位置のスクリーン座標
            // レイ位置の深度(AAのブレンド位置を拾わないように4方もチェック)
            float dep = tex2D( PosDepMapSmp, texCoord ).w * DEPTH_FAR;
            float depL = tex2D( PosDepMapSmp, texCoord+float2(-SampStep1.x,0) ).w * DEPTH_FAR;
            float depR = tex2D( PosDepMapSmp, texCoord+float2( SampStep1.x,0) ).w * DEPTH_FAR;
            float depB = tex2D( PosDepMapSmp, texCoord+float2(0,-SampStep1.x) ).w * DEPTH_FAR;
            float depT = tex2D( PosDepMapSmp, texCoord+float2(0, SampStep1.x) ).w * DEPTH_FAR;
            float lenRay = length(posRay - CameraPosition);
            // 深度がレイ位置の手前にある時は拾わない
            if(lenRay < dep && lenRay < depL && lenRay < depR && lenRay < depB && lenRay < depT){
                Color = tex2D( RoadMirageSmp, texCoord );  // レイ位置の色
            }
        }
    }

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        // オリジナルの描画
        "RenderColorTarget0=ScnTex;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        // 逃げ水反射面追加
        "RenderColorTarget0=RoadMirageTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=DrawRoadMirage;"
        // 陽炎による揺らぎ追加
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawHeatHaze;"
        ; >
{
    pass DrawRoadMirage < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_RoadMirage();
    }
    pass DrawHeatHaze < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_HeatHaze();
    }
}



