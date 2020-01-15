

//枠テクスチャ　コメントアウトで枠なし
#define MAPFLAME "MapFrame.png"

//マップ背景色
#define MapBackColor   float4(1, 1, 1, 1)


//背景色
const float4 BackColor <
   string UIName = "BackColor";
   string UIWidget = "Color";
   string UIHelp = "背景色";
   bool UIVisible =  true;
> = float4( 0, 0, 0, 0 );


///////////////////////////////////////////////////////////////////////////////////////////////


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;


//アルファ値取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;


float pos_x : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float pos_y : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);



///////////////////////////////////////////////////////////////////////////////////////////////
// マップオブジェクト描画先

texture MapDrawRT: OFFSCREENRENDERTARGET <
    string Description = "MapDrawRenderTarget for Map.fx";
    int Width = 512;
    int Height = 512;
    float4 ClearColor = MapBackColor;
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int MipLevels = 0;
    string Format = "A8R8G8B8";
    string DefaultEffect = 
        "self = hide;"
        "Map.x = hide;"
        "PostMap.x = hide;"
        
        "* = MapDraw.fxsub;" 
    ;
>;


sampler MapView = sampler_state {
    texture = <MapDrawRT>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    AddressU  = Clamp;
    AddressV = Clamp;
    MAXANISOTROPY = 16;
};

////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef MAPFLAME

//枠テクスチャ
texture2D MapFrame <
    string ResourceName = MAPFLAME;
    int MipLevels = 0;
>;
sampler MapFrameSamp = sampler_state {
    texture = <MapFrame>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    
    float2 tex = Tex;
    
    tex.x -= pos_x;
    tex.y -= pos_y;
    
    tex /= scaling;
    tex.x *= ViewportAspect;
    
    Out.Tex = tex + ViewportOffset;
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Map(VS_OUTPUT IN) : COLOR0
{
    
    float4 Color;
    
    Color = tex2D( MapView, IN.Tex );
    
    #ifdef MAPFLAME
    float4 FrameColor = tex2D( MapFrameSamp, IN.Tex );
    Color.rgb = lerp(Color.rgb, FrameColor.rgb, FrameColor.a);
    #endif
    
    Color.a = 1;
    Color.a *= (IN.Tex.x >= 0 && IN.Tex.x <= 1 && IN.Tex.y >= 0 && IN.Tex.y <= 1);
    
    Color.a *= alpha1;
    
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float4 ClearColor2 = {0,0,0,0};
float ClearDepth  = 1.0;


technique TrueCameraLX <
    string Script = 
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=BackColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "Pass=DrawMap;"
        
    ;
    
> {
    
    pass DrawMap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_Map();
    }

}

