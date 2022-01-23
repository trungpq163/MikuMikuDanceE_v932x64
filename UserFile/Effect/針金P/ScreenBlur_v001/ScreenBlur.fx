////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ScreenBlur.fx ver0.0.1  Screen.bmpを利用した簡易モーションブラー
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// アクセサリパラメータ
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float AcsAlpha = MaterialDiffuse.a;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler TexSampler = sampler_state {
    texture = <ObjectTexture>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT ScreenBlur_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    return Out;
}

// ピクセルシェーダ
float4 ScreenBlur_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    // テクスチャ適用
    float4 Color = tex2D( TexSampler, Tex );
    Color.a *= AcsAlpha;
    return Color;
}

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        ZENABLE = false;
        VertexShader = compile vs_1_1 ScreenBlur_VS();
        PixelShader  = compile ps_2_0 ScreenBlur_PS();
    }
}

