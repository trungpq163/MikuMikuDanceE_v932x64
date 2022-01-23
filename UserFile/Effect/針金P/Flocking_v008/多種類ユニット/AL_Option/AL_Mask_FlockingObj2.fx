////////////////////////////////////////////////////////////////////////////////////////////////
//
// モデルを黒く塗りつぶすエフェクト
//    ｢MMEffect｣→｢エフェクト割当｣のAL_MaskRTタブからモデルを指定して、本エフェクトファイルを適用する
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

int ObjCount = 100;   // モデル複製数(Flocking_Multi.fxのObjCount[1]と同じ値にする必要あり)
int StartCount = 80;  // グループの先頭インデックス(Flocking_Multi.fxのStartCount[1]と同じ値にする必要あり)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

int Index;  // 複製モデルカウンタ

#define TEX_WIDTH_W   4            // ユニット配置変換行列テクスチャピクセル幅
#define TEX_WIDTH     1            // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;

//カメラ位置
float3 CameraPosition   : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

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
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT VS_Selected(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 素材モデルのワールド座標変換
    float4 Pos = mul( GETPOS, WorldMatrix );

    // 複製モデルの配置座標変換
    float4x4 TransMatrix = SetTransMatrix();
    Pos = mul( Pos, TransMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GETVPMAT(CameraPosition-Pos.xyz) );

    // テクスチャ座標
    Out.Tex = IN.Tex;

    return Out;
}

// ピクセルシェーダ
float4 PS_Selected(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
    float alpha = alpha1;
    if(useTexture){
        alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
    }
    return float4(0.0, 0.0, 0.0, alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

//セルフシャドウなし
technique Select1 < string MMDPass = "object"; bool UseTexture = false;
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false);
    }
}

technique Select2 < string MMDPass = "object"; bool UseTexture = true;
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true);
    }
}

//セルフシャドウあり
technique SelectSS1 < string MMDPass = "object_ss"; bool UseTexture = false;
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(false);
    }
}

technique SelectSS2 < string MMDPass = "object_ss"; bool UseTexture = true;
                    string Script = "LoopByCount=ObjCount;" "LoopGetIndex=Index;" "Pass=Single_Pass;" "LoopEnd=;"; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Selected();
        PixelShader  = compile ps_3_0 PS_Selected(true);
    }
}


//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

