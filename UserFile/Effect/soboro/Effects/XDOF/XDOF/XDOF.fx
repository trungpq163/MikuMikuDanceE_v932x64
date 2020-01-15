////////////////////////////////////////////////////////////////////////////////////////////////
//
//  新・被写界深度エフェクト
//  作成: そぼろ
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

// ぼかし範囲(大きくしすぎると縞が出ます)
float DOF_Extent
<
   string UIName = "DOF_Extent";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.0004 );

//ぼかし制限値
float BlurLimit
<
   string UIName = "BlurLimit";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 30.0;
> = 10;

//背景色
float4 ClearColor
<
   string UIName = "ClearColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4(0,0,0,0);

//一方向のサンプリング数
#define SAMP_NUM   8

//手前側DOFループ数
#define DOF_Shallow_LOOP 4

///////////////////////////////////////////////////////////////////////////////////


int ShallowBlurLoopIndex = 0;
int ShallowBlurLoopCount = DOF_Shallow_LOOP;


//スケール係数
#define SCALE_VALUE 4

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


#define PI 3.14159
#define DEG_TO_RAD (PI / 180)

// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

//視野角によりぼかし強度可変
float4x4 ProjMatrix      : PROJECTION;
static float viewangle = atan(1 / ProjMatrix[0][0]);
static float viewscale = (45 / 2 * DEG_TO_RAD) / viewangle;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(DOF_Extent,DOF_Extent)/ViewportSize*ViewportSize.y);
static float2 SampStepScaled = SampStep  * scaling * viewscale / SAMP_NUM * 8.0;

static float BlurLimitScaled = BlurLimit / scaling;


//深度マップ作成
texture DepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for XDOF.fx";
    float4 ClearColor = { 1, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_R32F" ;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = XDOF_DepthOut.fx;";
>;

sampler DepthView = sampler_state {
    texture = <DepthRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};


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
    MipFilter = LINEAR;
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
    MipFilter = LINEAR;
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
//DOFぼかし強度マップ取得関数群

float DOF_GetDepthMap(float2 screenPos){
    return tex2Dlod( DepthView, float4(screenPos, 0, 0) ).r;
    //return tex2D( DepthView, screenPos ).r;
}

// 焦点より奥側 ////////////////////////////////////////////

float DOF_DeepDepthToBlur(float depth){
    float blrval = max(depth - (1.0 / SCALE_VALUE), 0);
    return blrval;
}

float GetDeepBlurMap(float2 screenPos){
    float depth = DOF_GetDepthMap(screenPos);
    float blr = DOF_DeepDepthToBlur(depth);
    blr = min(BlurLimitScaled, blr);
    return blr;
}


// 焦点より手前側 ////////////////////////////////////////////

float DOF_GetShallowBlurMap(float2 screenPos){
    float depth = DOF_GetDepthMap(screenPos);
    float blr = max((depth - (1.0 / SCALE_VALUE)) * -SCALE_VALUE, 0);
    
    return blr;
}

float DOF_ShallowBlurLoopValue(){
    return (float)(ShallowBlurLoopIndex + 1) / DOF_Shallow_LOOP;
}

float DOF_GetShallowBlurMapLoopAlpha(float2 screenPos){
    float blrval = DOF_GetShallowBlurMap(screenPos);
    float blrtgt = DOF_ShallowBlurLoopValue();
    //blrval = sqrt(blrval);
    blrtgt = sqrt(blrtgt);
    return max(0, 1.0 - (abs(blrval - blrtgt) * (float)ShallowBlurLoopCount));
}


////////////////////////////////////////////////////////////////////////////////////////////////

float DOF_BlurRate(float blr_samp, float blr_cnt){
    float r = blr_samp / blr_cnt;
    return pow(saturate(r), 2);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 奥側ぼかし

float4 PS_DeepDOF( VS_OUTPUT IN , uniform bool Horizontal, uniform sampler2D Samp ) : COLOR {   
    float e, n = 0;
    float2 stex;
    float4 Color, sum = 0;
    float centerblr = GetDeepBlurMap(IN.Tex);
    float step = (Horizontal ? SampStepScaled.x : SampStepScaled.y) * centerblr;
    float depth, centerdepth = DOF_GetDepthMap(IN.Tex) - 0.01;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = IN.Tex + float2(Horizontal, !Horizontal) * (step * (float)i);
        
        //手前かつピントの合っている部分からのサンプリングは弱く
        depth = DOF_GetDepthMap(stex);
        float blrrate = DOF_BlurRate(DOF_DeepDepthToBlur(depth), centerblr);
        e *= max(blrrate, (depth >= centerdepth));
        
        sum += tex2D( Samp, stex ) * e;
        n += e;
    }
    
    Color = sum / n;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// バッファのコピー

float4 PS_BufCopy( float2 Tex: TEXCOORD0 , uniform sampler2D samp ) : COLOR {   
    return tex2D( /*ScnSamp*/ samp  , Tex );
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 手前側X方向ぼかし

float4 PS_ShallowDOF_X(float2 Tex: TEXCOORD0) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    float loopval = DOF_ShallowBlurLoopValue();
    float step = SampStepScaled.x * min(BlurLimitScaled, loopval);
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM ; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(1, 0) * (float)i * step;
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        
        float4 org_color = tex2D( ScnSamp , stex );
        org_color.a *= DOF_GetShallowBlurMapLoopAlpha(stex);
        sum += org_color * e;
        n += e;
    }
    
    Color = sum / n;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 手前側X方向ぼかし

float4 PS_ShallowDOF_Y( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    float loopval = DOF_ShallowBlurLoopValue();
    float step = SampStepScaled.y * min(BlurLimitScaled, loopval);
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(0, 1) * (float)i * step;
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        sum += tex2D( ScnSamp2, stex ) * e;
        n += e;
    }
    
    Color = sum / n;
    
    float ar = (2.5 + step * (350 * SAMP_NUM / 8));
    Color.a = saturate(min(Color.a * ar, loopval * ar * 0.4));
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////

float4 ClearColor2 = {0,0,0,0};

technique XDOF <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; Clear=Color;"
        "ClearSetDepth=ClearDepth; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor2; Clear=Color;"
        "ClearSetDepth=ClearDepth; Clear=Depth;"
        "Pass=DeepDOF_X;"
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor2; Clear=Color;"
        "ClearSetDepth=ClearDepth; Clear=Depth;"
        "Pass=DeepDOF_Y;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor2; Clear=Color;"
        "ClearSetDepth=ClearDepth; Clear=Depth;"
        "Pass=BufCopy;"
        
        "LoopByCount=ShallowBlurLoopCount;"
        "LoopGetIndex=ShallowBlurLoopIndex;"
            
            "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor2; Clear=Color;"
            "ClearSetDepth=ClearDepth; Clear=Depth;"
            "Pass=ShallowDOF_X;"
            
            "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=ShallowDOF_Y;"
            
        "LoopEnd=;"
        
    ;
    
> {
    
    pass DeepDOF_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DeepDOF(true, ScnSamp);
    }
    pass DeepDOF_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_DeepDOF(false, ScnSamp2);
    }
    
    pass BufCopy < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_BufCopy(ScnSamp);
    }
    
    
    pass ShallowDOF_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_ShallowDOF_X();
    }
    pass ShallowDOF_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = true;
        AlphaTestEnable = true;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_ShallowDOF_Y();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////

