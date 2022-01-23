////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Line.fx 空間歪みエフェクト(ラインエフェクト,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ライン節点数設定
#define UNIT_COUNT   2   // ←この数×1024 が一度に描画出来るライン節点の数になる(整数値で指定すること)

// ライン節点パラメータ設定
float LineThick <
   string UIName = "線太さ";
   string UIHelp = "ラインの太さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );

float LineThick0 <
   string UIName = "線初期太さ";
   string UIHelp = "ラインの初期太さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 0.5 );

float LineScaleUp <
   string UIName = "線太変化";
   string UIHelp = "ライン発生後の拡大度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 0.3 );

float LineLife <
   string UIName = "線寿命";
   string UIHelp = "ライン節点の寿命(秒)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 30.0;
> = float( 4.0 );

float LineDecrement <
   string UIName = "線消失比";
   string UIHelp = "ライン節点が消失を開始する時間(0.0～1.0:線寿命との比)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.2 );

float DistRandomRate <
   string UIName = "揺らぎ度";
   string UIHelp = "ラインの細かい揺らぎ度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 3.0;
> = float( 1.0 );

float DistRandomFreqU <
   string UIName = "U揺周波数";
   string UIHelp = "ライン進行方向の細かい揺らぎ周波数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 4.0 );

float DistRandomFreqV <
   string UIName = "V揺周波数";
   string UIHelp = "ライン直角方向の細かい揺らぎ周波数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );


// オプションのコントロールファイル名
#define BackgroundCtrlFileName  "BackgroundControl.x" // 背景座標コントロールファイル名
#define TimrCtrlFileName        "TimeControl.x"       // 時間制御コントロールファイル名


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define RandomFileName "Random.bmp" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  4            // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH    UNIT_COUNT   // テクスチャピクセル幅
#define TEX_HEIGHT   1024         // テクスチャピクセル高さ

#define PAI 3.14159265f   // π

#define DEPTH_FAR  5000.0f   // 深度最遠値

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

// オプションのコントロールパラメータ
bool IsBack : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;
float4x4 BackMat : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 座標変換行列
float4x4 WorldMatrix : WORLD;
float4x4 ViewMatrix  : VIEW;
float4x4 ProjMatrix  : PROJECTION;

// ノーマルマップテクスチャ
texture2D NormalMapTex <
    string ResourceName = "NormalMapSample.png";
    int MipLevels = 0;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMapTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

// ライン座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s3) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// 1フレーム前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmpOld = sampler_state
{
   Texture = <CoordTexOld>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 時間間隔設定

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

float time1 : Time;
float time2 : Time < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;

#ifndef MIKUMIKUMOVING

float elapsed_time : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = (TimeSync ? clamp(elapsed_time, 0.001f, 0.1f) : clamp(elapsed_time2, 0.0f, 0.1f)) * TimeRate;

#else

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_R32F" ;
>;
sampler TimeTexSmp : register(s1) = sampler_state
{
   Texture = <TimeTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_D24S8";
>;
static float Dt = clamp(time - tex2D(TimeTexSmp, float2(0.5f, 0.5f)).r, 0.0f, 0.1f) * TimeRate;

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}

#endif


////////////////////////////////////////////////////////////////////////////////////////////////

// 背景アクセ基準のワールド座標→MMDワールド座標
float3 InvBackWorldCoord(float3 pos)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        pos = mul( float4(pos, 1), float4x4( BackMat[0]*scaling,
                                             BackMat[1]*scaling,
                                             BackMat[2]*scaling,
                                             BackMat[3] )      ).xyz;
    }
    return pos;
}

// MMDワールド座標→背景アクセ基準のワールド座標
float3 BackWorldCoord(float3 pos)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        float3x3 mat3x3_inv = transpose((float3x3)BackMat) * scaling;
        pos = mul( float4(pos, 1), float4x4( mat3x3_inv[0], 0, 
                                             mat3x3_inv[1], 0, 
                                             mat3x3_inv[2], 0, 
                                            -mul(BackMat._41_42_43,mat3x3_inv), 1 ) ).xyz;
    }
    return pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////
// 現座標値を1フレーム前の座標にコピー

float4 CopyPos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(CoordSmp, Tex);
   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////
// ライン節点の追加・座標更新計算(xyz:座標,w:経過時間+1sec,wは更新時に1に初期化されるため+1sからスタート)

float4 UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // ライン節点の座標
   float4 Pos;

   // 現在のオブジェクト座標
   float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);

   // 1フレーム前のオブジェクト座標
   float3 WPos0 = tex2D(CoordSmpOld, float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT)).xyz;

   // ライン節点インデックス
   int i = floor( Tex.x*TEX_WIDTH );
   int j = floor( Tex.y*TEX_HEIGHT );
   int index = i*TEX_HEIGHT + j;

   if( distance(WPos1, WPos0) > 0.001f ){
      if(index == 0){
         Pos = float4( WPos1, 1.0011f );  // Pos.w>1.001でライン節点追加
      }else{
         j--;
         if(j<0){
            i--;
            j = TEX_HEIGHT - 1;
         }
         Pos = tex2D(CoordSmpOld, float2((0.5f+i)/TEX_WIDTH, (0.5f+j)/TEX_HEIGHT));
         if(Pos.w > 1.001f){
            // すでに追加しているライン節点は経過時間を進める
            Pos.w += Dt;
            Pos.w *= step(Pos.w-1.0f, LineLife); // 指定時間を超えると0(ライン節点消失)
         }
      }
   }else{
      Pos = tex2D(CoordSmp, Tex);
      if(Pos.w > 1.001f){
         // すでに追加しているライン節点は経過時間を進める
         Pos.w += Dt;
         Pos.w *= step(Pos.w-1.0f, LineLife); // 指定時間を超えると0(ライン節点消失)
      }
   }

   // 0フレーム再生でライン節点初期化
   if(time < 0.001f) Pos = float4(WorldMatrix._41_42_43, 0.0f);

   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_PMAT(p) (ProjMatrix)
#else
    #define GET_PMAT(p) (MMM_IsDinamicProjection ? MMM_DynamicFov(ProjMatrix, length(p.xyz)) : ProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos       : POSITION;    // 射影変換座標
    float2 Tex       : TEXCOORD0;   // テクスチャ
    float2 Dir       : TEXCOORD1;   // 進行方向
    float4 VPos      : TEXCOORD2;   // ビュー座標
    float4 Color     : COLOR0;      // ライン節点の色
};

// 頂点シェーダ
VS_OUTPUT2 Line_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out = (VS_OUTPUT2)0;

   int i1 = RepertIndex;
   int j1 = round( Pos.x * 100.0f );
   int Index = i1 * TEX_HEIGHT + j1;
   float2 texCoord = float2((i1+0.5f)/TEX_WIDTH, (j1+0.5f)/TEX_HEIGHT);

   int i0 = i1;
   int j0 = j1 - 1;
   if(j0 < 0){ i0--; j0=TEX_HEIGHT-1; }
   float2 texCoordPrev = float2((i0+0.5f)/TEX_WIDTH, (j0+0.5f)/TEX_HEIGHT);

   int i2 = i1;
   int j2 = j1 + 1;
   if(j2 > TEX_HEIGHT-1){ i2++; j2=0; }
   float2 texCoordNext = float2((i2+0.5f)/TEX_WIDTH, (j2+0.5f)/TEX_HEIGHT);

   // ライン節点の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoordPrev, 0, 0));
   float4 Pos1 = tex2Dlod(CoordSmp, float4(texCoord,     0, 0));
   float4 Pos2 = tex2Dlod(CoordSmp, float4(texCoordNext, 0, 0));

   // 経過時間
   float etime = Pos1.w - 1.0f;
   float etimeNext = Pos2.w;

   // 経過時間に対するライン節点拡大度
   float scale = lerp(LineThick0*0.5f, LineThick*0.5f + LineScaleUp * sqrt(etime), smoothstep(0.0f, 0.5f, etime));

   // ライン節点のワールド座標
   Pos0 = float4(InvBackWorldCoord(Pos0.xyz), 1.0f);
   Pos1 = float4(InvBackWorldCoord(Pos1.xyz), 1.0f);
   Pos2 = float4(InvBackWorldCoord(Pos2.xyz), 1.0f);

   // ライン節点のビュー座標
   float4 VPos0 = mul( Pos0, ViewMatrix );
   float4 VPos1 = mul( Pos1, ViewMatrix );
   float4 VPos2 = mul( Pos2, ViewMatrix );

   // ラインの前後方向
   float2 prevVec = normalize( VPos0.xy - VPos1.xy );
   float2 nextVec = normalize( VPos2.xy - VPos1.xy );
   if(Index == 0) prevVec = -nextVec;
   if(etimeNext <= 1.0f) nextVec = -prevVec;

   // 頂点のビュー座標
   float2 vec1 = (Pos.y > 0) ? float2(prevVec.y, -prevVec.x) : float2(-prevVec.y, prevVec.x);
   float2 vec2 = (Pos.y > 0) ? float2(-nextVec.y, nextVec.x) : float2(nextVec.y, -nextVec.x);
   float2 vec =  normalize(vec1+vec2) / max( sqrt((dot(vec1,vec2) + 1.0f) * 0.5f), 0.5f );
   Out.VPos.xyz = VPos1.xyz + float3(vec * scale * AcsSi*0.1f, 0.0f);
   Out.VPos.w = 1.0f;

   // 進行方向ベクトル
   Out.Dir = normalize( (Pos.y > 0) ? float2(-vec.y, vec.x) : float2(vec.y, -vec.x) );

   // カメラ視点のビュー射影変換
    Out.Pos = mul( Out.VPos, GET_PMAT(Out.VPos) );

   // ライン節点の乗算色
   float alpha = step(0.001f, etime) * smoothstep(-LineLife, -LineLife*LineDecrement, -etime) * AcsTr;
   Out.Color = float4(0, 0, 0, alpha);

   // テクスチャ座標
   Out.Tex = float2(-etime, sign(Pos.y));

   return Out;
}

// ピクセルシェーダ
float4 Line_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // 透明部位は描画しない
    clip( IN.Color.a - 0.005f );

    // 法線(0～1になるよう補正)
    float s = 1.0f - abs(IN.Tex.y);
    float3 Normal = float3(IN.Dir * sin(0.5f*PAI*s),  -cos(0.5f*PAI*s));
    float3 randNormal = tex2D(NormalMapSamp, float2(IN.Tex.x*DistRandomFreqU, (IN.Tex.y+1.0f)*0.5f*DistRandomFreqV)).rgb - 0.5f;
    Normal += DistRandomRate * randNormal;
    Normal = normalize(Normal);
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, IN.Color.a);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=CoordTexOld;"
            "RenderDepthStencilTarget=CoordDepthBuffer;"
            "Pass=CopyPos;"
        "RenderColorTarget0=CoordTex;"
            "RenderDepthStencilTarget=CoordDepthBuffer;"
            "Pass=UpdatePos;"
       #ifdef MIKUMIKUMOVING
       "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
       #endif
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;"
        ;
>{
    pass CopyPos < string Script = "Draw=Buffer;";>{
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 CopyPos_PS();
    }
    pass UpdatePos < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 UpdatePos_PS();
    }
    #ifdef MIKUMIKUMOVING
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
    #endif
    pass DrawObject {
        ZENABLE = TRUE;
        ZWRITEENABLE = FALSE;
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 Line_VS();
        PixelShader  = compile ps_3_0 Line_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// エッジ・地面影・ZPlotは表示しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot";> { }

