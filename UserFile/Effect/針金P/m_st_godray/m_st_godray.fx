////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ScreenTex.fx ver0.0.4  テクスチャを画面サイズにスケーリングして貼り付けます
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define UseTex  1                   // 1:テクスチャ, 2:アニメGIF･APNG, 3:Screen.bmpアニメ
#define TexFile  "godray.png"       // 画面に貼り付けるテクスチャファイル名(単色の場合は無視)
#define AnimeStart 0.0              // アニメGIF･APNGの場合のアニメーション開始時間(単位：秒)(アニメGIF･APNG以外では無視)


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////


// MMM UIコントロール
float3 MMMColorKey <      // カラーキーの色(RGB指定)
   string UIName = "カラーキーの色";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.0, 0.0, 0.0);

float MMMThreshold <   // カラーキーの閾値
   string UIName = "キー閾値";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );


// アクセサリパラメータ
float3 AcsOffset : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsR : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;
float AcsAlpha : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float3 ColorKey = saturate( AcsOffset );               // カラーキーの色(RGB指定)
static float Threshold = saturate( degrees(AcsR) ) - 0.01f;   // カラーキーの閾値

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

#if(UseTex == 1)
// 画面に貼り付けるテクスチャ
texture2D screen_tex <
    string ResourceName = TexFile;
>;
sampler2D TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

#if(UseTex == 2)
// 画面に貼り付けるアニメーションテクスチャ
texture screen_tex : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    float Offset = AnimeStart;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

#if(UseTex == 3)
// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler TexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif


///////////////////////////////////////////////////////////////////////////////////////////////
// 画面描画

struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 射影変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT ScreenTex_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 ScreenTex_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    // テクスチャ適用
    float4 Color = tex2D( TexSampler, Tex );

    // カラーキー透過
    float len = length(Color.rgb - saturate(ColorKey+MMMColorKey));
    clip( len - (Threshold + MMMThreshold) );

    Color.a *= AcsAlpha;
    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        ZENABLE = false;
        VertexShader = compile vs_1_1 ScreenTex_VS();
        PixelShader  = compile ps_2_0 ScreenTex_PS();
    }
}



