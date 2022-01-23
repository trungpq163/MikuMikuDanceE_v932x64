////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Wind.fx 空間歪みエフェクト(風エフェクトの改造,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define WIND_COUNT   30      // 風オブジェクト数

// 時間制御コントロールファイル名
#define TimrCtrlFileName  "TimeControl.x"

#ifndef MIKUMIKUMOVING
// ↓MME使用時のみ変更(MMMはUIコントロールより変更可)

float WindLife = 0.5;        // 風オブジェクトの寿命(秒)
float WindDecrement = 0.7;   // 風オブジェクトが消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float WindSize = 2.0;        // 風オブジェクトの大きさ
float WindSizeRand = 1.0;    // 風オブジェクトの大きさのばらつき
float WindThick = 0.05;      // 風オブジェクトの太さ
float WindScaleUp = 2.0;     // 風オブジェクトの発生後の拡大度
float WindPosHeight = 20.0;  // 風オブジェクト中心位置最大高さ
float WindPosRadius = 5.0;   // 風オブジェクト中心位置水平ばらつき度
float WindRotX = 10.0;       // 風オブジェクトX軸回転角(deg)
float WindRotZ = 10.0;       // 風オブジェクトZ軸回転角(deg)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#else
// MMMパラメータ

float WindLife <
   string UIName = "寿命(秒)";
   string UIHelp = "風オブジェクトの寿命(秒)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 0.5 );

float WindDecrement <
   string UIName = "消失開始率";
   string UIHelp = "風オブジェクトが消失を開始する時間(0.0～1.0:ParticleLifeとの比)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.3 );

float WindSize <
   string UIName = "大きさ";
   string UIHelp = "風オブジェクトの大きさ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 2.0 );

float WindSizeRand <
   string UIName = "大きさ分散";
   string UIHelp = "風オブジェクトの大きさのばらつき";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );

float WindThick <
   string UIName = "太さ";
   string UIHelp = "風オブジェクトの太さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 0.2;
> = float( 0.03 );

float WindScaleUp <
   string UIName = "拡大度";
   string UIHelp = "風オブジェクトの発生後の拡大度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 2.0 );

float WindPosHeight <
   string UIName = "高さ分散";
   string UIHelp = "風オブジェクト中心位置最大高さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = float( 20.0 );

float WindPosRadius <
   string UIName = "水平分散";
   string UIHelp = "風オブジェクト中心位置水平ばらつき度さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = float( 5.0 );

float WindRotX <
   string UIName = "X回転";
   string UIHelp = "風オブジェクトX軸回転角(deg)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = float( 10.0 );

float WindRotZ <
   string UIName = "Z回転";
   string UIHelp = "風オブジェクトZ軸回転角(deg)";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 50.0;
> = float( 10.0 );

#endif


#define WindRandFileName "WindRand.pfm" // 乱数情報ファイル名
#define TEX_WIDTH_A  2            // 乱数情報テクスチャピクセル幅
#define TEX_WIDTH    1            // テクスチャピクセル幅
#define TEX_HEIGHT   1024         // テクスチャピクセル高さ

#define PAI 3.14159265f   // π

#define DEPTH_FAR  5000.0f   // 深度最遠値

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int RepertCount = WIND_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 座標変換行列
float4x4 WorldMatrix       : WORLD;
float4x4 ViewMatrix        : VIEW;
float4x4 ProjMatrix        : PROJECTION;
float4x4 ViewProjMatrix    : VIEWPROJECTION;


// 法線マップテクスチャ
texture2D NormalMapTex <
    string ResourceName = "NormalMapSample.png";
    int MipLevels = 0;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMapTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 乱数情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = WindRandFileName;
>;
sampler ArrangeSmp : register(s3) = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 時間設定

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

float time1 : Time;
float time2 : Time < bool SyncInEditMode = true; >;
static float time0 = TimeSync ? time1 : time2;

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_G32R32F" ;
>;
sampler TimeTexSmp = sampler_state
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
static float time = tex2Dlod(TimeTexSmp, float4(0.5f,0.5f,0,0)).y;

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   float2 timeDat = tex2D(TimeTexSmp, float2(0.5f,0.5f)).xy;
   float etime = timeDat.y + clamp(time0 - timeDat.x, 0.0f, 0.1f) * TimeRate;
   if(time0 < 0.001f) etime = 0.0;
   return float4(time0, etime, 0, 1);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float3 Color2Float(int index, int item)
{
    return tex2Dlod(ArrangeSmp, float4((item+0.5f)/TEX_WIDTH_A, (index+0.5f)/TEX_HEIGHT, 0, 0)).xyz;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 整数除算
int div(int a, int b) {
    return floor((a+0.1f)/b);
}

// 整数剰余算
int mod(int a, int b) {
    return (a - div(a,b)*b);
};

////////////////////////////////////////////////////////////////////////////////////////////////
// ワールド変換行列取得
float4x4 GetWorldMatrix(float3 pos, float3 rot, float scale)
{
   float3x3 wldRotX = { 1,           0,          0,
                        0,  cos(rot.x), sin(rot.x),
                        0, -sin(rot.x), cos(rot.x) };

   float3x3 wldRotY = { cos(rot.y), 0, -sin(rot.y),
                                 0, 1,           0,
                        sin(rot.y), 0,  cos(rot.y) };

   float3x3 wldRotZ = { cos(rot.z), sin(rot.z), 0,
                       -sin(rot.z), cos(rot.z), 0,
                                 0,          0, 1 };

   float3x3 wldRot = mul(mul(wldRotY, wldRotX), wldRotZ);

   float4x4 wldMat = float4x4( wldRot[0]*scale, 0,
                               wldRot[1]*scale, 0,
                               wldRot[2]*scale, 0,
                                           pos, 1 );

   return mul(wldMat, WorldMatrix);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 接空間回転行列取得

float3x3 GetTangentFrame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}


///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////
// 風オブジェクト描画

struct VS_OUTPUT
{
    float4 Pos    : POSITION;    // 射影変換座標
    float3 Normal : TEXCOORD0;   // 法線
    float4 VPos   : TEXCOORD1;   // ビュー座標
    float2 Tex    : TEXCOORD2;   // テクスチャ
    float  Alpha  : TEXCOORD3;   // α値
};

// 頂点シェーダ
VS_OUTPUT Wind_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // オブジェクトインデックス
    float ds = (time - WindLife) * WIND_COUNT / WindLife;
    float stage = float(RepertIndex + 1.0f - frac(ds)) / float(WIND_COUNT);
    int i = floor( ds );
    i = mod(i, TEX_HEIGHT);
    i += RepertIndex;
    if(i >= TEX_HEIGHT) i -= TEX_HEIGHT;

    // 乱数設定
    float3 rand1 = Color2Float(i, 0);
    float3 rand2 = Color2Float(i, 1);

    // オブジェクトのワールド変換行列
    float pos_r = lerp(0.0f, WindPosRadius*0.1f, rand1.x);
    float pos_h = lerp(0.0f, WindPosHeight*0.1f, rand1.y);
    float pos_s = lerp(-PAI, PAI, rand1.z);
    float rot_x = lerp(-radians(WindRotX), radians(WindRotX), rand2.x);
    float rot_y = lerp(-PAI, PAI, rand2.y);
    float rot_z = lerp(-radians(WindRotZ), radians(WindRotZ), rand2.z);
    float scale = max(lerp(WindSize-WindSizeRand*0.5f, WindSize+WindSizeRand*0.5f, (rand1.x+rand1.z)*0.5f), 0.0f)
                   - WindScaleUp * WindLife * stage;

    float3 pos0 = float3(pos_r*cos(pos_s), pos_h, pos_r*sin(pos_s));
    float3 rot0 = float3(rot_x, rot_y, rot_z);
    float4x4 wldMat = GetWorldMatrix(pos0, rot0, scale);

    // オブジェクトのワールド座標変換
    Pos.y *= WindThick * (1.0f - stage);
    Pos = mul(Pos, wldMat);

    // カメラ視点のビュー変換
    Out.VPos = mul( Pos, ViewMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 法線のカメラ視点のワールドビュー変換
    Out.Normal = mul( Normal, (float3x3)mul(wldMat, ViewMatrix) );

    // テクスチャ座標
    Out.Tex = Tex;

    // α値
    Out.Alpha = smoothstep(0.0f, 1.0f-WindDecrement, stage) * smoothstep(-1.0f, -0.9f, -stage);

    return Out;
}

// ピクセルシェーダ
float4 Wind_PS( VS_OUTPUT IN ) : COLOR0
{
    // ノーマルマップを含む法線取得
    float3 eye = -IN.VPos.xyz / IN.VPos.w;
    float3x3 tangentFrame = GetTangentFrame(IN.Normal, eye, IN.Tex);
    float3 Normal = normalize(mul(2.0f * tex2D(NormalMapSamp, IN.Tex).rgb - 1.0f, tangentFrame));

    // 法線(0～1になるよう補正)
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, AcsTr * IN.Alpha);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;"
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
        ;
>{
    pass DrawObject {
        ZEnable = TRUE;
        ZwriteEnable = FALSE;
        ALPHABLENDENABLE = FALSE;
        CULLMODE = NONE;
        VertexShader = compile vs_3_0 Wind_VS();
        PixelShader  = compile ps_3_0 Wind_PS();
    }
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// エッジ・地面影・ZPlotは表示しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot";> { }

