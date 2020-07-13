///////////////////////////////////////////////////////////////////////////////////////////////
// 設定

// 鏡アクセサリのサイズ（横ｘ縦）
//   ※この値を変更した場合、必ずMirrorObject.fxの同名の設定も合わせて変更すること
float2 MirrorSize = { 1, 1.5 };

// 鏡の色（RGB）
//   ※透明度はMMDのアクセサリ操作パネルで設定可能 
float3 MirrorColor = { 1.0, 1.0, 1.0 };

// 鏡テクスチャのサイズ
#define WIDTH   1024
#define HEIGHT  1024

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix          : WORLDVIEW;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;


///////////////////////////////////////////////////////////////////////////////////////////////
// 鏡関連

texture MirrorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mirror.fx";
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "*=MirrorObject.fx;";
>;

sampler MirrorView = sampler_state {
    texture = <MirrorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Mirror_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Pos.xy *= MirrorSize;
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( dot(WorldViewMatrix[2].xyz,WorldViewMatrix[3].xyz) > 0 ) {
        // 鏡の表の面の場合、X軸を反転して描画しているので、ここで反転する。
        Out.Tex.x = 1 - Out.Tex.x;
    }
    
    return Out;
}

float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

// ピクセルシェーダ
float4 Mirror_PS(VS_OUTPUT IN) : COLOR0
{
    float4 color = tex2D(MirrorView, IN.Tex);
    color.rgb *= MirrorColor;
	color.a *= MaterialDiffuse.a * rgb2gray(color.rgb);

    return color;
}

technique MainTec {
    pass DrawObject {
        CULLMODE = NONE;
        VertexShader = compile vs_2_0 Mirror_VS();
        PixelShader  = compile ps_2_0 Mirror_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
