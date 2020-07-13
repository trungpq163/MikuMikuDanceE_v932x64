////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

// ぼかし範囲(サンプリング数は固定のため、大きくしすぎると縞が出ます)
float Extent
<
   string UIName = "Extent";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.002 );

// フィルタ強度
float Strength
<
   string UIName = "Strength";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.7 );

float4 ClearColor
<
   string UIName = "ClearColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4(0,0,0,0);

///////////////////////////////////////////////////////////////////////////////////

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(Extent,Extent)/ViewportSize*ViewportSize.y) * scaling;

// レンダリングターゲットのクリア値
float ClearDepth  = 1.0;

// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
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

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 自己乗算の結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

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
// 自己乗算

float4 PS_passSM( float2 Tex: TEXCOORD0 ) : COLOR {   
    return pow(tex2D( ScnSamp, Tex ), 2);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep.x;
    
    Color  = WT_0 *   tex2D( ScnSamp3, Tex );
    Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(step  ,0) ) + tex2D( ScnSamp3, Tex-float2(step  ,0) ) );
    Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(step*2,0) ) + tex2D( ScnSamp3, Tex-float2(step*2,0) ) );
    Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(step*3,0) ) + tex2D( ScnSamp3, Tex-float2(step*3,0) ) );
    Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(step*4,0) ) + tex2D( ScnSamp3, Tex-float2(step*4,0) ) );
    Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(step*5,0) ) + tex2D( ScnSamp3, Tex-float2(step*5,0) ) );
    Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(step*6,0) ) + tex2D( ScnSamp3, Tex-float2(step*6,0) ) );
    Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(step*7,0) ) + tex2D( ScnSamp3, Tex-float2(step*7,0) ) );
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float4 ColorSrc;
    float4 ColorOrg;
    
    float step = SampStep.y;
    
    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,step  ) ) + tex2D( ScnSamp2, Tex-float2(0,step  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,step*2) ) + tex2D( ScnSamp2, Tex-float2(0,step*2) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,step*3) ) + tex2D( ScnSamp2, Tex-float2(0,step*3) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,step*4) ) + tex2D( ScnSamp2, Tex-float2(0,step*4) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,step*5) ) + tex2D( ScnSamp2, Tex-float2(0,step*5) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,step*6) ) + tex2D( ScnSamp2, Tex-float2(0,step*6) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,step*7) ) + tex2D( ScnSamp2, Tex-float2(0,step*7) ) );
    
    ColorOrg = tex2D( ScnSamp, Tex );
    ColorSrc = tex2D( ScnSamp3, Tex );
    
    //スクリーン合成
    Color = Color + ColorSrc - Color * ColorSrc;
    
    //比較(明)
    float brightness1 = (ColorSrc.r * 0.29 + ColorSrc.g * 0.59 + ColorSrc.b * 0.12);
    float brightness2 = (Color.r * 0.29 + Color.g * 0.59 + Color.b * 0.12 );
    
    if(brightness1 > brightness2) Color = ColorSrc;
    Color.a = ColorSrc.a;
    
    //フィルタ強度を元にオリジナルと合成
    Color = lerp(ColorOrg, Color ,Strength * alpha1);
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Diffusion <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=SelfMultiply;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_Y;"
    ;
    
> {
    pass SelfMultiply < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passSM();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
