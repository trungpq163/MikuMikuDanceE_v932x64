////////////////////////////////////////////////////////////////////////////////////////////////
//
// EmittionDraw for AutoLuminous.fx : Flocking.x(Flocking_Obj1.fx)専用
//    AutoLuminous対応モデルの発光部を描画します
//    ｢MMEffect｣→｢エフェクト割当｣のAL_EmitterRTタブからモデルを指定して、本エフェクトファイルを適用する
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

int ObjCount = 100;   // モデル複製数(Flocking_Multi.fxのObjCount[1]と同じ値にする必要あり)
int StartCount = 80;  // グループの先頭インデックス(Flocking_Multi.fxのStartCount[1]と同じ値にする必要あり)

//テクスチャ高輝度識別フラグ
//#define TEXTURE_SELECTLIGHT

//閾値
float LightThreshold = 0.9;


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

int Index;  // 複製モデルカウンタ

#define TEX_WIDTH_W   4            // ユニット配置変換行列テクスチャピクセル幅
#define TEX_WIDTH     1            // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

#define SPECULAR_BASE 100
#define SYNC false

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;

//カメラ位置
float3 CameraPosition   : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;

#define PI 3.14159

float LightUp : CONTROLOBJECT < string name = "(self)"; string item = "LightUp"; >;
float LightUpE : CONTROLOBJECT < string name = "(self)"; string item = "LightUpE"; >;
float LightOff : CONTROLOBJECT < string name = "(self)"; string item = "LightOff"; >;
float Blink : CONTROLOBJECT < string name = "(self)"; string item = "LightBlink"; >;
float BlinkSq : CONTROLOBJECT < string name = "(self)"; string item = "LightBS"; >;
float BlinkDuty : CONTROLOBJECT < string name = "(self)"; string item = "LightDuty"; >;
float BlinkMin : CONTROLOBJECT < string name = "(self)"; string item = "LightMin"; >;

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;

static float duty = (BlinkDuty <= 0) ? 0.5 : BlinkDuty;
static float timerate = ((Blink > 0) ? ((1 - cos(saturate(frac(ftime / (Blink * 10)) / (duty * 2)) * 2 * PI)) * 0.5) : 1.0)
                      * ((BlinkSq > 0) ? (frac(ftime / (BlinkSq * 10)) < duty) : 1.0);
static float timerate1 = timerate * (1 - BlinkMin) + BlinkMin;

static bool IsEmittion = (SPECULAR_BASE < SpecularPower)/* && (SpecularPower <= (SPECULAR_BASE + 100))*/ && (length(MaterialSpecular) < 0.01);
static float EmittionPower0 = IsEmittion ? ((SpecularPower - SPECULAR_BASE) / 7.0) : 1;
static float EmittionPower1 = EmittionPower0 * (LightUp * 2 + 1.0) * pow(400, LightUpE) * (1.0 - LightOff);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// ユニット配置変換行列が記録されているテクスチャ
shared texture Flocking_TransMatrixTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH_W;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler TransMatrixSmp : register(s3) = sampler_state
{
   Texture = <Flocking_TransMatrixTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの配置変換行列
float4x4 SetTransMatrix()
{
    int i = ((Index + StartCount) / TEX_HEIGHT) * 4;
    int j = (Index + StartCount) % TEX_HEIGHT;
    float y = (j+0.5f)/TEX_HEIGHT;

    // モデルの配置変換行列
    return float4x4( tex2Dlod(TransMatrixSmp, float4((i+0.5f)/TEX_WIDTH_W, y, 0, 0)), 
                     tex2Dlod(TransMatrixSmp, float4((i+1.5f)/TEX_WIDTH_W, y, 0, 0)), 
                     tex2Dlod(TransMatrixSmp, float4((i+2.5f)/TEX_WIDTH_W, y, 0, 0)), 
                     tex2Dlod(TransMatrixSmp, float4((i+3.5f)/TEX_WIDTH_W, y, 0, 0)) );
}

////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifdef MIKUMIKUMOVING
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define GETPOS MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
    #define GETVPMAT(eye) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(eye))) : ViewProjMatrix)
#else
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
        float4 AddUV1 : TEXCOORD1;
        float4 AddUV2 : TEXCOORD2;
    };
    #define GETPOS (IN.Pos)
    #define GETVPMAT(eye) (ViewProjMatrix)
#endif

///////////////////////////////////////////////////////////////////////////////////////////////

float texlight(float3 rgb){
    float val = saturate((length(rgb) - LightThreshold) * 3);
    
    val *= 0.2;
    
    return val;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 追加UVがAL用データかどうか判別

bool DecisionSystemCode(float4 SystemCode){
    bool val = (0.199 < SystemCode.r) && (SystemCode.r < 0.201)
            && (0.699 < SystemCode.g) && (SystemCode.g < 0.701);
    return val;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Tex        : TEXCOORD1;   // テクスチャ
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT VS_Selected(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    bool IsALCode = DecisionSystemCode(IN.AddUV1);

    // 素材モデルのワールド座標変換
    float4 Pos = mul( GETPOS, WorldMatrix );

    // 複製モデルの配置座標変換
    float4x4 TransMatrix = SetTransMatrix();
    Pos = mul( Pos, TransMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GETVPMAT(CameraPosition-Pos.xyz) );

    // セレクト色 計算
    Out.Color = MaterialDiffuse;
    Out.Color.rgb += MaterialEmmisive / 2;
    Out.Color.rgb *= 0.5;
    Out.Color.rgb = IsEmittion ? Out.Color.rgb : float3(0,0,0);

    float3 UVColor = IN.AddUV2.rgb * IN.AddUV2.a;

    Out.Color.rgb += IsALCode ? UVColor : float3(0,0,0);

    float timerate2 = (IN.AddUV1.z > 0) ? ((1 - cos(saturate(frac(ftime / IN.AddUV1.z) / (duty * 2)) * 2 * PI)) * 0.5)
                     : ((IN.AddUV1.z < 0) ? (frac(ftime / (-IN.AddUV1.z )) < duty) : 1.0);
    Out.Color.rgb *= max(timerate2 * (1 - BlinkMin) + BlinkMin, !IsALCode);
    Out.Color.rgb *= max(timerate1, IN.AddUV1.z != 0);

    // テクスチャ座標
    Out.Tex.xy = IN.Tex; //テクスチャUV
    Out.Tex.w = IsALCode && (0.99 < IN.AddUV1.w && IN.AddUV1.w < 1.01);

    return Out;
}

// ピクセルシェーダ
float4 PS_Selected(VS_OUTPUT IN, uniform bool useTexture, uniform bool useToon) : COLOR0
{
    float4 Color = IN.Color;
    
    if(useTexture){
        #ifdef TEXTURE_SELECTLIGHT
            Color = tex2D(ObjTexSampler,IN.Tex.xy);
            Color.rgb *= texlight(Color.rgb);
        #else
            Color *= max(tex2D(ObjTexSampler,IN.Tex.xy), IN.Tex.w);
        #endif
    }
    
    if(useToon){
        Color.rgb *= EmittionPower1;
    }else{
        Color.rgb *= EmittionPower0;
    }
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

//セルフシャドウなし
technique Select1 < string MMDPass = "object"; bool UseTexture = false; bool UseToon = false; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false, false);
    }
}

technique Select2 < string MMDPass = "object"; bool UseTexture = true; bool UseToon = false; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true, false);
    }
}
technique Select3 < string MMDPass = "object"; bool UseTexture = false; bool UseToon = true; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false, true);
    }
}

technique Select4 < string MMDPass = "object"; bool UseTexture = true; bool UseToon = true; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true, true);
    }
}

//セルフシャドウあり
technique SelectSS1 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseToon = false; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false, false);
    }
}

technique SelectSS2 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseToon = false; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true, false);
    }
}

technique SelectSS3 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseToon = true; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false, true);
    }
}

technique SelectSS4 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseToon = true; 
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true, true);
    }
}


//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

