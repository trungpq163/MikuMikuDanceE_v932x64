////////////////////////////////////////////////////////////////////////////////////////////////
//
//  被写界深度＋モーションブラー 統合エフェクト Ver.2.0
//  作成: そぼろ
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ


// DOFパラメータ //////////////////////////////////////////////////////////

// ぼかし範囲(大きくしすぎると縞が出ます)
float DOF_Extent = 0.0003;

//ぼかし制限値
float BlurLimit = 8;

//高品質DOFモード　1で有効、0で無効
#define DOF_HIGHQUALITY  1


// モーションブラーパラメータ //////////////////////////////////////////////

// ぼかし強度(大きくしすぎると縞が出ます)
float DirectionalBlurStrength = 0.35;

//残像長さ
float LineBlurLength = 1.8;

//残像濃さ
float LineBlurStrength = 1;

//速度の上限値
float VelocityLimit = 0.1;

//速度の下限値
float VelocityUnderCut = 0.006;

//シーン切り替え閾値
float SceneChangeThreshold = 20;

//シーン切り替え角度閾値
float SceneChangeAngleThreshold = 25;

//ラインブラーの解像度を倍にします。1で有効、0で無効
#define LINEBLUR_QUAD  1


// 魚眼レンズパラメータ ////////////////////////////////////////////////


//魚眼レンズエフェクトを有効にします　1で有効、0で無効
#define FISHEYE_ENABLE 0

//レンズ歪み強度
float FishEyeStregth = 0.75;

//黒ベタ追加サイズ
float BetaSize = 0.095;

//自動的にサイズ変更　1で有効、0で無効
#define AUTO_RESIZE  0

//自動サイズ変更使用時の、解像度の倍率です
//画面サイズおよび出力サイズ × この値 が
//ディスプレイ解像度を絶対に超えないようにしてください。
#define RESOLUTION_RATIO 1.5


// 共通パラメータ //////////////////////////////////////////////////////


//簡易色調補正・ホワイトバランス調整用
const float3 ColorCorrection = float3( 1, 1, 1 );

//一方向のサンプリング数
#define SAMP_NUM   8

//背景色
const float4 BackColor = float4( 0, 0, 0, 0 );



///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと


//スケール係数
#define SCALE_VALUE 4

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


#define PI 3.14159
#define DEG_TO_RAD (PI / 180)

#if FISHEYE_ENABLE==0
    #define VPRATIO 1.0
#else
    #if AUTO_RESIZE==0
        #define VPRATIO 1.0
    #else
        #define VPRATIO RESOLUTION_RATIO
    #endif
#endif

//アルファ値取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1 * 0.5;

//視野角によりぼかし強度可変
float4x4 ProjMatrix      : PROJECTION;
static float viewangle = atan(1 / ProjMatrix[0][0]);
static float viewscale = (45 / 2 * DEG_TO_RAD) / viewangle;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//ぼかしサンプリング間隔
static float2 SampStep = (float2(DOF_Extent,DOF_Extent)/ViewportSize*ViewportSize.y);
static float2 SampStepScaled = SampStep  * scaling * viewscale;


static float BlurLimitScaled = BlurLimit / pow(scaling, 0.7);



static float2 MBlurSampStep = (float2(DirectionalBlurStrength, DirectionalBlurStrength)/ViewportSize*ViewportSize.y);
static float2 MBlurSampStepScaled = MBlurSampStep * alpha1;


#define VM_TEXFORMAT "A32B32G32R32F"
//#define VM_TEXFORMAT "A16B16G16R16F"

//深度付きベロシティマップ作成
texture DVMapDraw: OFFSCREENRENDERTARGET <
    string Description = "Depth && Velocity Map Drawing";
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    float4 ClearColor = { 0.5, 0.5, 1, 1 };
    float ClearDepth = 1.0;
    string Format = VM_TEXFORMAT ;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = TrueCameraObject.fx;"
        ;
>;

sampler DVSampler = sampler_state {
    texture = <DVMapDraw>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};


#if DOF_HIGHQUALITY!=0
    // 深度マップのX方向のぼかし結果を記録するためのレンダーターゲット
    texture2D DpMapX : RENDERCOLORTARGET <
        float2 ViewPortRatio = {0.5,0.5};
        int MipLevels = 1;
        string Format = "D3DFMT_R32F" ;
    >;
    sampler2D DpSampX = sampler_state {
        texture = <DpMapX>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        AddressU  = CLAMP;
        AddressV = CLAMP;
    };
    // 深度マップのY方向のぼかし結果を記録するためのレンダーターゲット
    texture2D DpMapY : RENDERCOLORTARGET <
        float2 ViewPortRatio = {0.5,0.5};
        int MipLevels = 1;
        string Format = "D3DFMT_R32F" ;
    >;
    sampler2D DpSampY = sampler_state {
        texture = <DpMapY>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        AddressU  = CLAMP;
        AddressV = CLAMP;
    };
#endif


// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    string Format = "D24S8";
>;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    int MipLevels = 0;
    string Format = "A8R8G8B8" ;
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
    string Format = "A8R8G8B8" ;
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
    string Format = "A8R8G8B8";
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

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
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

#if DOF_HIGHQUALITY==0
    
    #define DOF_GetDepthMapMix DOF_GetDepthMap
#else
    
    float DOF_GetDepthMapBlr(float2 screenPos){
        return tex2Dlod( DpSampY, float4(screenPos, 0, 0) ).r;
    }
    float DOF_GetDepthMapMix(float2 screenPos){
        float depth1 = DOF_GetDepthMap(screenPos);
        float depth2 = DOF_GetDepthMapBlr(screenPos);
        
        float blrval = (depth1 - (1.0 / SCALE_VALUE));
        
        return lerp(depth1, depth2, saturate(blrval * 2));
        
    }
#endif

float DOF_DepthToBlur(float depth){
    float blrval = abs(depth - (1.0 / SCALE_VALUE));
    //手前側のブラー強度はちょっと嘘つき
    if(depth < (1.0 / SCALE_VALUE)) blrval = pow(blrval * 15, 2) / 15; 
    return blrval;
}
float DOF_DepthComp(float dsrc, float ddst){
    return ((ddst < (1.0 / SCALE_VALUE)) && (DOF_DepthToBlur(dsrc) < DOF_DepthToBlur(ddst))) ? ddst : 1000;
}
float DOF_GetBlurMap(float2 screenPos){
    float depth = DOF_GetDepthMapMix(screenPos);
    float depth2 = depth;
    
    depth2 = min(depth2, DOF_DepthComp(depth, DOF_GetDepthMap(screenPos + float2( SampStepScaled.x * 2 , 0))));
    depth2 = min(depth2, DOF_DepthComp(depth, DOF_GetDepthMap(screenPos + float2(-SampStepScaled.x * 2 , 0))));
    depth2 = min(depth2, DOF_DepthComp(depth, DOF_GetDepthMap(screenPos + float2(0,  SampStepScaled.y * 2 ))));
    depth2 = min(depth2, DOF_DepthComp(depth, DOF_GetDepthMap(screenPos + float2(0, -SampStepScaled.y * 2 ))));
    
    depth2 = min(BlurLimitScaled, depth2);
    
    return DOF_DepthToBlur(depth2);
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
//深度マップぼかし

#if DOF_HIGHQUALITY!=0
    
    
    //深度マップぼかしパラメータ
    #define SAMP_NUM_D  3
    const float ext2 = 0.0015;
    static const float2 SampStepD = (float2(ext2, ext2)/ViewportSize*ViewportSize.y);
    
    float4 PS_passDX( VS_OUTPUT IN ) : COLOR {   
        float e, n = 0, sum = 0;
        
        [unroll] //ループ展開
        for(int i = -SAMP_NUM_D; i <= SAMP_NUM_D; i++){
            float2 stex = IN.Tex + float2(SampStepD.x * (float)i, 0);
            e = exp(-pow((float)i / (SAMP_NUM_D / 2.0), 2) / 2); //正規分布
            sum += tex2Dlod( DVSampler, float4(stex, 0, 0) ).z * e;
            n += e;
        }
        
        return float4(sum / n, 0, 0, 1);
    }
    
    float4 PS_passDY( VS_OUTPUT IN ) : COLOR {   
        float e, n = 0, sum = 0;
        
        [unroll] //ループ展開
        for(int i = -SAMP_NUM_D; i <= SAMP_NUM_D; i++){
            float2 stex = IN.Tex + float2(0, SampStepD.y * (float)i);
            e = exp(-pow((float)i / (SAMP_NUM_D / 2.0), 2) / 2); //正規分布
            sum += tex2Dlod( DpSampX, float4(stex, 0, 0) ).r * e;
            n += e;
        }
        
        return float4(sum / n, 0, 0, 1);
    }
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// DOF X方向ぼかし

#define DOF_X_SAMPLER ScnSamp

float4 PS_DOF_X( VS_OUTPUT IN ) : COLOR {   
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float step = SampStepScaled.x * DOF_GetBlurMap(IN.Tex);
    float depth, centerdepth = DOF_GetDepthMap(IN.Tex) - 0.01;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = IN.Tex + float2(step * (float)i, 0);
        
        if(i!=0){
            //手前かつピントの合っている部分からのサンプリングは弱く
            depth = DOF_GetDepthMap(stex);
            if(depth < centerdepth) e *= saturate(DOF_DepthToBlur(depth) * 2);
        }
        
        sum += tex2Dlod( DOF_X_SAMPLER, float4(stex, 0, 0) ) * e;
        n += e;
    }
    
    Color = sum / n;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// DOF Y方向ぼかし

#define DOF_Y_SAMPLER ScnSamp2

float4 PS_DOF_Y( VS_OUTPUT IN ) : COLOR {   
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float step = SampStepScaled.y * DOF_GetBlurMap(IN.Tex);
    float depth, centerdepth = DOF_GetDepthMap(IN.Tex) - 0.01;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        e = exp(-pow((float)i / (SAMP_NUM / 2.0 ), 2) / 2); //正規分布
        stex = IN.Tex + float2(0, step * (float)i);
        
        if(i!=0){
            //手前かつピントの合っている部分からのサンプリングは弱く
            depth = DOF_GetDepthMap(stex);
            if(depth < centerdepth) e *= saturate(DOF_DepthToBlur(depth) * 2);
        }
        
        sum += tex2Dlod( DOF_Y_SAMPLER, float4(stex, 0, 0) ) * e;
        n += e;
    }
    
    Color = sum / n;
    
    //簡易色調補正
    Color.rgb *= ColorCorrection;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//ベロシティマップに従い方向性ブラーをかける

float4 PS_DirectionalBlur( float2 Tex: TEXCOORD0 ) : COLOR {   
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float2 vel = MB_GetBlurMap(Tex);
    
    float4 info;
    float2 step = (MBlurSampStepScaled / SAMP_NUM) * vel;
    float depth, centerdepth = MB_GetDepthMap(Tex) - 0.01;
    
    float bp = saturate(length(vel) * 10);
    
    step *= (!IsSceneChange); //シーン切り替えはブラー無効
    
    float4 samps[SAMP_NUM * 2 + 1];
    
    
    //命令数が莫大なので、条件分岐した方が速い
    [branch]
    if(length(step) <= 0){
        Color = tex2Dlod( ScnSamp, float4(Tex, 0, 0) );
        
    }else{
        
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
            sum += tex2Dlod( ScnSamp, float4(stex, 0, 0) ) * e;
            n += e;
        }
        
        Color = sum / n;
        
    }
    
    return Color;
    
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
    OUT.Color = tex2Dlod( ScnSamp, float4(Tex, 0, ScnMipLevel2) );
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
    float3 Tex: TEXCOORD0;
    float2 BaseVel : TEXCOORD1;
    
};

VS_OUTPUT3 VS_LineBluer(float4 Pos : POSITION, int index: _INDEX)
{
    VS_OUTPUT3 Out;
    float2 PosEx = Pos.xy;
    bool IsTip = (Pos.x > 0); //ラインの伸びた先端
    
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
    float VelLen = length(Velocity) * alpha1;
    
    Out.BaseVel = Velocity; //PSに速度を渡す。
    
    //速度ベクトルと反対側にラインを伸ばす
    Velocity = -Velocity;
    
    //ライン幅
    PosEx *= (1.0 / LINEBLUR_GRIDSIZE);
    //ライン長さ
    PosEx.x += VelLen * IsTip * LineBlurLength;
    //ライン広がり
    PosEx.y *= 1 + 0.2 * IsTip;
    
    //斜めラインは太く
    //PosEx.y *= 1 + 0.4 * abs(sin(atan2(Velocity.x, Velocity.y) * 2));
    
    //ライン回転
    float2 AxU = normalize(Velocity);
    float2 AxV = float2(AxU.y, -AxU.x);
    
    PosEx = PosEx.x * AxU + PosEx.y * AxV;
    
    //頂点位置によるサンプリング位置のオフセット
    //TexPos += (-Pos.y * AxV) / (LINEBLUR_GRIDSIZE * 2);
    
    //元スクリーン参照
    Out.Color = tex2Dlod( ScnSamp, float4(TexPos, 0, ScnMipLevel1) );
    
    //ブラー強度からアルファ設定・ライン先端は透明に
    Out.Color.a *= saturate(VelLen * 250) * (1 - IsTip);
    
    Out.Color.a *= (!IsSceneChange); //シーン切り替えはブラー無効
    
    //バッファ出力
    Out.Pos.xy = ScreenPos + PosEx;
    Out.Pos.z = 0;
    Out.Pos.w = 1;
    
    //スクリーンテクスチャ座標
    Out.Tex.xy = (Out.Pos.xy * float2(1,-1) + 1) * 0.5 + (0.5 / LINEBLUR_BUFSIZE);
    Out.Tex.z = VelMap.MB_DEPTH; //TEXCOORD0のZを借りて、残像の発生源のZ値を渡す
    
    return Out;
}

float4 PS_LineBluer( VS_OUTPUT3 IN ) : COLOR0
{
    float4 Color = IN.Color;
    
    float4 Info = tex2Dlod( LineBluerInfoSamp, float4(IN.Tex.xy, 0, 0));
    
    float BaseZ = Info.z; //元画像の深度
    float AfImZ = IN.Tex.z; //残像の深度
    
    //手前のオブジェクト上の残像は隠す
    Color.a *= saturate(1 - (AfImZ - BaseZ) * 200);
    
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

VS_OUTPUT VS_MixLineBluer( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + (0.5 / LINEBLUR_BUFSIZE);
    
    return Out;
}

#define LBSAMP LineBluerSamp

float4 PS_MixLineBluer( float2 Tex: TEXCOORD0 ) : COLOR {   
    float2 step = 1.1 / LINEBLUR_BUFSIZE;
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
        
        #if AUTO_RESIZE!=0
            resize = (1 + vang1 * vang1 / 9 * ViewportAspect);
            r /= resize;
        #endif
        
        float phai = r * vang1;
        r = asin(phai);
        r /= (vang1);
        
        tex_conv = r * dir;
        tex_conv.x /= ViewportAspect;
        tex_conv += 0.5;
        
        Color = tex2D( ScnSamp2, tex_conv );
        
        //表示領域外は黒で塗りつぶす
        Color = (0 <= phai && phai <= 1) ? Color : float4(0,0,0,1);
        Color = (0 <= tex_conv.x && tex_conv.x <= 1 && 0 <= tex_conv.y && tex_conv.y <= 1) ? Color : float4(0,0,0,1);
        
        #if AUTO_RESIZE==0
            Color = (BetaSize <= Tex.x && Tex.x <= (1 - BetaSize) && BetaSize <= Tex.y && Tex.y <= (1 - BetaSize)) ? Color : float4(0,0,0,1);
            //Color = (BetaSize <= Tex.y && Tex.y <= (1 - BetaSize) ) ? Color : float4(0,0,0,1);
        #endif
        
    }else{
        
        Color = tex2D( ScnSamp2, Tex );
        
    }
    
    return Color;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////

// レンダリングターゲットのクリア値
float4 ClearColor2 = {0,0,0,0};
float ClearDepth  = 1.0;


technique TrueCamera <
    string Subset = "0";
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        #if DOF_HIGHQUALITY!=0
            "RenderColorTarget0=DpMapX;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=Gaussian_DX;"
             
            "RenderColorTarget0=DpMapY;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=Gaussian_DY;"
            
        #endif
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=DOF_X;"
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=DOF_Y;"
        
        #if FISHEYE_ENABLE==0
            "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
        #else
            "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
        #endif
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
        
        
        #if FISHEYE_ENABLE==0
            "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
        #else
            "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
        #endif
        "Pass=MixLineBluer;"
        
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
    
    #if DOF_HIGHQUALITY!=0
        pass Gaussian_DX < string Script= "Draw=Buffer;"; > {
            AlphaBlendEnable = FALSE;
            VertexShader = compile vs_3_0 VS_passDraw();
            PixelShader  = compile ps_3_0 PS_passDX();
        }
        pass Gaussian_DY < string Script= "Draw=Buffer;"; > {
            AlphaBlendEnable = FALSE;
            VertexShader = compile vs_3_0 VS_passDraw();
            PixelShader  = compile ps_3_0 PS_passDY();
        }
    #endif
    
    pass DOF_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DOF_X();
    }
    pass DOF_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DOF_Y();
    }
    
    
    
    
    //方向性ブラー
    pass DirectionalBlur < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DirectionalBlur();
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

