////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

//探索半径
#define SEARCH_RADIUS 4

//分散
#define H2 50

float4 ClearColor
<
   string UIName = "ClearColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4(0,0,0,0);

//描画順テスト
#define ORDER_TEST 0

///////////////////////////////////////////////////////////////////////////////////


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
static float2 textureSizeInverse = (float2(1,1)/ViewportSize);

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
// NL_Means 実装

static const float2 DELTA[9] = {
    float2(-1, -1),
    float2( 0, -1),
    float2( 1, -1),
    float2(-1,  0),
    float2( 0,  0),
    float2( 1,  0),
    float2(-1,  1),
    float2( 0,  1),
    float2( 1,  1)
};

static const float2 delta[9] = {
    DELTA[0] * textureSizeInverse,
    DELTA[1] * textureSizeInverse,
    DELTA[2] * textureSizeInverse,
    DELTA[3] * textureSizeInverse,
    DELTA[4] * textureSizeInverse,
    DELTA[5] * textureSizeInverse,
    DELTA[6] * textureSizeInverse,
    DELTA[7] * textureSizeInverse,
    DELTA[8] * textureSizeInverse,
};

float4 PS_NL_Means( float2 pos: TEXCOORD0 ) : COLOR {   
    
    float3 sum = 0;
    float3 value = 0;
    
    const float3 currentPixels[9] = {
        tex2D(ScnSamp, pos + delta[0]).xyz,
        tex2D(ScnSamp, pos + delta[1]).xyz,
        tex2D(ScnSamp, pos + delta[2]).xyz,
        tex2D(ScnSamp, pos + delta[3]).xyz,
        tex2D(ScnSamp, pos + delta[4]).xyz,
        tex2D(ScnSamp, pos + delta[5]).xyz,
        tex2D(ScnSamp, pos + delta[6]).xyz,
        tex2D(ScnSamp, pos + delta[7]).xyz,
        tex2D(ScnSamp, pos + delta[8]).xyz,
    };
    
    [loop] for (int dx = -SEARCH_RADIUS; dx <= SEARCH_RADIUS; ++dx) {
        [loop] for (int dy = -SEARCH_RADIUS; dy <= SEARCH_RADIUS; ++dy) {
            const float2 targetPos = pos + float2(dx, dy) * textureSizeInverse;
            
            float3 sum2 = 0;
            float3 targetCenter;
            float3 diff;
            
            diff = currentPixels[0] - tex2Dlod(ScnSamp, float4(targetPos + delta[0], 0, 0));
            sum2 += diff * diff * 0.07;
            diff = currentPixels[1] - tex2Dlod(ScnSamp, float4(targetPos + delta[1], 0, 0));
            sum2 += diff * diff * 0.12;
            diff = currentPixels[2] - tex2Dlod(ScnSamp, float4(targetPos + delta[2], 0, 0));
            sum2 += diff * diff * 0.07;
            diff = currentPixels[3] - tex2Dlod(ScnSamp, float4(targetPos + delta[3], 0, 0));
            sum2 += diff * diff * 0.12;
            diff = currentPixels[4] - (targetCenter = tex2Dlod(ScnSamp, float4(targetPos + delta[4], 0, 0)));
            sum2 += diff * diff * 0.20;
            diff = currentPixels[5] - tex2Dlod(ScnSamp, float4(targetPos + delta[5], 0, 0));
            sum2 += diff * diff * 0.12;
            diff = currentPixels[6] - tex2Dlod(ScnSamp, float4(targetPos + delta[6], 0, 0));
            sum2 += diff * diff * 0.07;
            diff = currentPixels[7] - tex2Dlod(ScnSamp, float4(targetPos + delta[7], 0, 0));
            sum2 += diff * diff * 0.12;
            diff = currentPixels[8] - tex2Dlod(ScnSamp, float4(targetPos + delta[8], 0, 0));
            sum2 += diff * diff * 0.07;
            
            const float3 w = exp(-sqrt(sum2) * H2);
            sum += w;
            value += targetCenter * w;
            
            
        }
    }
    
    float4 Color = float4(value / sum, tex2D( ScnSamp, pos ).a);
    
    //描画順テスト
    #if ORDER_TEST!=0
        if(pos.x < 0.1) Color = float4(1,0,0,1); else if(pos.x < 0.2) Color = float4(0,1,0,1);
    #endif
    
    return Color;
    
}


////////////////////////////////////////////////////////////////////////////////////////////////

technique ColorShift <
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
        "Pass=NL_Means_Pass;"
        
    ;
    
> {
    pass NL_Means_Pass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_NL_Means();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
