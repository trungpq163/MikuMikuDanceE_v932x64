////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HayabusaLastShot.fx ver0.0.1  はやぶさラストショットフィルタです
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float Alpha = 0.6;   // 合成α値(0.0～1.0で設定)


// 解らない人はここから下はいじらないでね

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;

// マスクに用いるテクスチャ
texture2D mask_tex <
    string ResourceName = "mask.png";
    int MipLevels = 1;
>;
sampler MaskSamp = sampler_state {
    texture = <mask_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 画面に貼り付けるテクスチャ
texture2D front_tex <
    string ResourceName = "hayabusaLastShot.png";
    int MipLevels = 1;
>;
sampler FrontSamp = sampler_state {
    texture = <front_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャフィルタシェーダ

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_HayabusaTex( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex+ViewportOffset;

    return Out;
}

float4 PS_HayabusaTex( float2 Tex: TEXCOORD0 ) : COLOR {
    float x = Tex.x + ViewportOffset.x;
    float y = Tex.y * 4.0/3.0 * ViewportSize.y/ViewportSize.x + ViewportOffset.y;

    // マスクするテクスチャの色
    float4 TexColor1 = tex2D( MaskSamp, float2(x,y) );
    // 貼り付けるテクスチャの色
    float4 TexColor2 = tex2D( FrontSamp, float2(x,y) );
    // 元の画面の色
    float4 Color = tex2D( ScnSamp, Tex );

    // グレイスケール計算(NTSC系加重平均法)
    float v1 = 0.298912 * TexColor1.r + 0.586611 * TexColor1.g + 0.114478 * TexColor1.b;
    float v2 = 0.298912 * TexColor2.r + 0.586611 * TexColor2.g + 0.114478 * TexColor2.b;
    float v = 0.298912 * Color.r + 0.586611 * Color.g + 0.114478 * Color.b;

    // マスク&線形合成
    Color.rgb = Alpha * v * v1 + (1.0 - Alpha * v1) * v2;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique HayabusaTexTech <
    string Script = 
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=HayabusaTexPass;"
    ;
> {
    pass HayabusaTexPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_HayabusaTex();
        PixelShader  = compile ps_2_0 PS_HayabusaTex();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////

