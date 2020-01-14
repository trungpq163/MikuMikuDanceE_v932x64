////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PanelLight.fx ver1.3
//  作成: そぼろ
//
////////////////////////////////////////////////////////////////////////////////////////////////

//ライト発光強度
float LightPower <
   string UIName = "LightPower";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.0;
> = 1;

//ライト色
const float3 LightColor <
   string UIName = "LightColor";
   string UIWidget = "Color";
   string UIHelp = "背景色";
   bool UIVisible =  true;
> = float3( 1, 0.92, 0.9 );


//背景色
const float4 BackColor <
   string UIName = "BackColor";
   string UIWidget = "Color";
   string UIHelp = "背景色";
   bool UIVisible =  true;
> = float4( 0, 0, 0, 0 );


//テクスチャフォーマット
//#define PPL_TEXFORMAT "D3DFMT_A32B32G32R32F" //HDR:有効
#define PPL_TEXFORMAT "D3DFMT_A16B16G16R16F" //HDR:有効
//#define PPL_TEXFORMAT "D3DFMT_A8B8G8R8"      //HDR:無効


///////////////////////////////////////////////////////////////////////////////////////////////
// スポットライト反射光描画先

texture PanelLightDraw: OFFSCREENRENDERTARGET <
    string Description = "PanelLightObjectRenderTarget for PanelLight.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int Miplevels = 1;
    string Format = PPL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        
        "* = PanelLightObject.fxsub;" 
        
    ;
>;

sampler PanelLightView = sampler_state {
    texture = <PanelLightDraw>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



////////////////////////////////////////////////////////////////////////////////////////////////

//PMX入力
float power_pmx : CONTROLOBJECT < string name = "(self)"; string item = "Power"; >;
float size_pmx : CONTROLOBJECT < string name = "(self)"; string item = "Size"; >;
float lightup_pmx : CONTROLOBJECT < string name = "(self)"; string item = "LightUp"; >;
float color_r_pmx : CONTROLOBJECT < string name = "(self)"; string item = "R"; >;
float color_g_pmx : CONTROLOBJECT < string name = "(self)"; string item = "G"; >;
float color_b_pmx : CONTROLOBJECT < string name = "(self)"; string item = "B"; >;

bool exist_acc : CONTROLOBJECT < string name = "PanelLight.x"; >;

static bool IsPMX = (power_pmx > 0) || (size_pmx > 0) || (!exist_acc);

static float3 pmxcolor = float3(color_r_pmx, color_g_pmx, color_b_pmx);

//パラメータ入力選択
static float power_selected = IsPMX ? (lightup_pmx * 9 + 1) : LightPower;

static float3 lightcolor_selected = IsPMX ? pmxcolor : LightColor;

////////////////////////////////////////////////////////////////////////////////////////////////

const float4 Color_Black = {0,0,0,1};
const float4 Color_White = {1,1,1,1};


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

// レンダリングターゲットのクリア値
//float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ

float4 PS_copy( float2 Tex: TEXCOORD0 ) : COLOR {
    float4 color = tex2D( PanelLightView, Tex );
    
    color.rgb *= lightcolor_selected;
    color.rgb *= power_selected;
    
    return color;
    
}


////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique PanelLight <
    string Script = 
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=BackColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        //"Pass=CopyPass;"
        "Pass=AddMix;"
        
    ;
    
> {
    
    pass CopyPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_copy();
    }
    
    pass AddMix < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_copy();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////



