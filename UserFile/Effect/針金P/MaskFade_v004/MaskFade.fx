////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MaskFade.fx ver0.0.4  マスク画像を用いたフェードイン・フェードアウト
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define UseTex  1                   // フェードイン前・フェードアウト後が，0:単色，1:テクスチャ, 2:アニメGIF･APNG, 3:Screen.bmpアニメ
#define TexFile  "sample.png"       // 画面に貼り付けるテクスチャファイル名(単色,Screen.bmpの場合は無視)
#define AnimeStart 0.0              // アニメGIF･APNGの場合のアニメーション開始時間(単位：秒)(アニメGIF･APNG以外では無視)
#define MaskFile "sampleMask.png"   // マスクに用いるテクスチャファイル名

float TexWidthSize  = 1.0;       // 画面に対するテクスチャ画像の幅比率(単色の場合は無視)
float TexHeightSize = 1.0;       // 画面に対するテクスチャ画像の高さ比率(単色の場合は無視)


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

float time : TIME;

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
float3 AcsRound : CONTROLOBJECT < string name = "MaskFade.x"; string item = "Rxyz"; >;
static float2 AcsOffset = WorldMatrix._41_42;
static float AcsScaling = length(WorldMatrix._11_12_13)*0.1f; 
static float AcsAlpha = MaterialDiffuse.a;
static float TexScaling = abs(WorldMatrix._43)<1.0f ? 1.0f : (WorldMatrix._43>0.0f ? 1.0f/WorldMatrix._43 : abs(WorldMatrix._43));

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f) / ViewportSize;

// マスクに用いるテクスチャ
texture2D mask_tex <
    string ResourceName = MaskFile;
    int MipLevels = 0;
>;
sampler MaskSamp = sampler_state {
    texture = <mask_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

#if(UseTex == 1)
// 画面に貼り付けるテクスチャ
texture2D screen_tex <
    string ResourceName = TexFile;
    int MipLevels = 0;
>;
#endif

#if(UseTex == 2)
// 画面に貼り付けるアニメーションテクスチャ
texture screen_tex : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    int MipLevels = 1;
    float Offset = AnimeStart;
>;
#endif

#if(UseTex == 3)
// オブジェクトのテクスチャ
texture screen_tex: MATERIALTEXTURE;
#endif

#if(UseTex > 0)
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MagFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};
#endif


///////////////////////////////////////////////////////////////////////////////////////////////
// 画面描画

struct VS_OUTPUT
{
    float4 Pos  : POSITION;    // 射影変換座標
    float2 Tex  : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT MaskFade_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 MaskFade_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
#if(UseTex == 0)
    // 単色指定の場合の色
    float4 Color = saturate( float4(degrees(AcsRound), 1.0f) );
#else
    // 貼り付けるテクスチャの色
    float2 texCoord = float2( Tex.x/TexWidthSize + AcsOffset.x*time,
                              Tex.y/TexHeightSize + AcsOffset.y*time ) * TexScaling;
    float4 Color = tex2D( TexSampler, texCoord );
#endif

    // マスクするテクスチャの色
    float4 MaskColor = tex2D( MaskSamp, Tex );

    // グレイスケール計算
    float v = (MaskColor.r + MaskColor.g + MaskColor.b)*0.333333f;

    // フェード透過値計算
    float a = (1.0f+AcsScaling)*AcsAlpha - 0.5f*AcsScaling;
    float minLen = a - 0.5f*AcsScaling;
    float maxLen = a + 0.5f*AcsScaling;
    Color.a *= saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec < string MMDPass = "object"; >
{
    pass DrawObject < string Script= "Draw=Buffer;"; >
    {
        ZENABLE = false;
        VertexShader = compile vs_1_1 MaskFade_VS();
        PixelShader  = compile ps_2_0 MaskFade_PS();
    }
}

