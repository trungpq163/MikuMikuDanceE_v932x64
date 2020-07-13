////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

// ぼかし範囲(大きくしすぎると縞が出ます)
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


//背景色
float4 ClearColor
<
   string UIName = "ClearColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4(0,0,0,0);


//合成方法の選択
// 0: オリジナル画像と合成
// 1: 自己乗算画像と合成
#define MIX_TYPE  1


//明度比較法の選択
// 0: フォトショップ方式
// 1: ベクトル長比較
// 2: 各色加算比較
// 3: 各色個別比較
#define BCOMP_TYPE  0


//ぼかしのサンプリング数
#define SAMP_NUM  7


///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと


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

float3 objpos : CONTROLOBJECT < string name = "(self)"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static const float2 SampStep = (float2(Extent,Extent)/ViewportSize*ViewportSize.y) * scaling;

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
// 明度比較

float4 BrightnessCompare(float4 color1, float4 color2){
    
    color1.a = color2.a > color1.a ? color2.a : color1.a;
    
    #if BCOMP_TYPE==0
        float brightness1 = (color1.r * 0.29 + color1.g * 0.59 + color1.b * 0.12);
        float brightness2 = (color2.r * 0.29 + color2.g * 0.59 + color2.b * 0.12 );
        
        if(brightness2 > brightness1) color1 = color2;
        
    #elif BCOMP_TYPE==1
        float brightness1 = length(color1.rgb);
        float brightness2 = length(color2.rgb);
        
        if(brightness2 > brightness1) color1 = color2;
        
    #elif BCOMP_TYPE==2
        float brightness1 = (color1.r + color1.g + color1.b );
        float brightness2 = (color2.r + color2.g + color2.b );
        
        if(brightness2 > brightness1) color1 = color2;
        
    #elif BCOMP_TYPE==3
        color1.r = color2.r > color1.r ? color2.r : color1.r;
        color1.g = color2.g > color1.g ? color2.g : color1.g;
        color1.b = color2.b > color1.b ? color2.b : color1.b;
        
    #endif
    
    return color1;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(SampStep.x * (float)i, 0);
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        
        float4 org_color = tex2D( ScnSamp, stex );
        org_color.rgb = pow(org_color.rgb, 2); //RGBを2乗
        sum += org_color * e;
        n += e;
    }
    
    Color = sum / n;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color, sum = 0;
    float4 ColorSrc, ColorOrg;
    
    float e, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(0, SampStep.y * (float)i);
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        sum += tex2D( ScnSamp2, stex ) * e;
        n += e;
    }
    
    Color = sum / n;
    ColorOrg = tex2D( ScnSamp, Tex );
    ColorSrc = float4(pow(ColorOrg.rgb, 2), ColorOrg.a);
    
    //スクリーン合成
    Color.rgb = Color.rgb + ColorSrc.rgb - Color.rgb * ColorSrc.rgb;
    
    //比較(明)
    #if MIX_TYPE==0
        Color = BrightnessCompare(Color, ColorOrg);
    #else
        Color = BrightnessCompare(Color, ColorSrc);
    #endif
    
    //簡易色調補正
    Color.rgb *= (objpos + 1);
    
    //フィルタ強度を元にオリジナルと合成
    Color = lerp(ColorOrg, Color, Strength * alpha1);
    
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
    
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
