////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ


//自動的にサイズ変更　1で有効、0で無効
#define AUTO_RESIZE  0

//解像度向上　1で有効、0で無効
#define HIGH_RESOLUTION  0

///////////////////////////////////////////////////////////////////////////////////


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 
static float pos_x = matWorld._41;
static float pos_y = matWorld._42;
static float pos_z = matWorld._43;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

//視野角
float4x4 ProjMatrix      : PROJECTION;
static float viewangle = atan(1 / ProjMatrix[0][0]);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    #if HIGH_RESOLUTION==1
        float2 ViewPortRatio = {2,2};
    #else
        float2 ViewPortRatio = {1,1};
    #endif
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;

sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = Border;
    AddressV = Border;
    BorderColor = {0,0,0,1};
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
// 魚眼処理

float4 PS_FishEye( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float2 tex_conv;
    
    tex_conv = Tex - 0.5;
    tex_conv.x *= ViewportAspect;
    
    float D = 1;
    float r0 = length(tex_conv);
    float r = r0;
    float2 dir = normalize(tex_conv);
    
    float vang1 = viewangle * 2 * scaling;
    
    #if AUTO_RESIZE==1
        r /= (1 + vang1 * vang1 / 8 * ViewportAspect);
    #endif
    
    r /= (pos_z / 100 + 1);
    
    float phai = r * vang1;
    r = asin(phai);
    r /= (vang1);
    
    tex_conv = r * dir;
    tex_conv.x /= ViewportAspect;
    tex_conv += 0.5;
    
    Color = tex2D( ScnSamp, tex_conv);
    
    //表示領域外は黒で塗りつぶす
    Color = (0 <= phai && phai <= 1) ? Color : float4(0,0,0,1);
    Color = (0 <= tex_conv.x && tex_conv.x <= 1 && 0 <= tex_conv.y && tex_conv.y <= 1) ? Color : float4(0,0,0,1);
    
    float2 beta = float2(pos_x / 200, pos_y / 200);
    
    Color = (beta.x <= Tex.x && Tex.x <= (1 - beta.x) && beta.y <= Tex.y && Tex.y <= (1 - beta.y)) ? Color : float4(0,0,0,1);
    
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique FishEye <
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
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=FishEyePass;"
    ;
    
> {
    pass FishEyePass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_FishEye();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
