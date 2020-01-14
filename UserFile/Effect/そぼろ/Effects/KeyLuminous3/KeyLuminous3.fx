////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

// ぼかし範囲 (サンプリング数は固定のため、大きくしすぎると縞が出ます) 
float Extent_S
<
   string UIName = "Extent_S";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.004 ); // にじみ

float Extent_G
<
   string UIName = "Extent_G";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.005 ); // ガウス

//発光強度
float Strength_A
<
   string UIName = "Strength_A";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 3.0;
> = float( 1.5 );

float Strength_B
<
   string UIName = "Strength_B";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 3.0;
> = float( 1.5 );


//コア部の境界をなじませる
bool core_AntiAliasing = true;

//キーカラー (R,G,B 各要素 0.0～1.0)
//黒(0,0,0) で無効
float3 Key_Color1 < string UIName = "Key Color 1"; string UIWidget = "Color"; bool UIVisible =  true;>
 = float3( 1, 0, 1 );

float3 Key_Color2 < string UIName = "Key Color 2"; string UIWidget = "Color"; bool UIVisible =  true;>
 = float3( 0, 0, 1 );

float3 Key_Color3 < string UIName = "Key Color 3"; string UIWidget = "Color"; bool UIVisible =  true;>
 = float3( 0, 0, 0 );

float3 Key_Color4 < string UIName = "Key Color 4"; string UIWidget = "Color"; bool UIVisible =  true;>
 = float3( 0, 0, 0 );

float3 Key_Color5 < string UIName = "Key Color 5"; string UIWidget = "Color"; bool UIVisible =  true;>
 = float3( 0, 0, 0 );

//キーカラー認識閾値
float KeyThreshold
<
   string UIName = "Key Threshold";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.35 );

//コア色および発光色 (R,G,B 各要素 0.0～1.0)
float3 Core_Color1 < string UIName = "Core Color 1"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.2, 0.2, 0.1 );
float3 Emittion_Color1 < string UIName = "Emittion Color 1"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.8, 0.5, 0.3 );

float3 Core_Color2 < string UIName = "Core Color 2"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 1.0, 0.8, 1.0 );
float3 Emittion_Color2 < string UIName = "Emittion Color 2"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.2, 0.4, 1.0 );

float3 Core_Color3 < string UIName = "Core Color 3"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );
float3 Emittion_Color3 < string UIName = "Emittion Color 3"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );

float3 Core_Color4 < string UIName = "Core Color 4"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );
float3 Emittion_Color4 < string UIName = "Emittion Color 4"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );

float3 Core_Color5 < string UIName = "Core Color 5"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );
float3 Emittion_Color5 < string UIName = "Emittion Color 5"; string UIWidget = "Color"; bool UIVisible =  true; >
 = float3( 0.0, 0.0, 0.0 );



//点滅周期、単位：フレーム、0で停止
int Interval
<
   string UIName = "Interval";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 300;
> = 0;

//編集中の点滅をフレーム数に同期
#define SYNC true

////////////////////////////////////////////////////////////////////////////////////////////////

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

#define PI 3.14159


//キーカラーの使用を選択
static const bool UseKey1 = (length(Key_Color1) > 0.01);
static const bool UseKey2 = (length(Key_Color2) > 0.01);
static const bool UseKey3 = (length(Key_Color3) > 0.01);
static const bool UseKey4 = (length(Key_Color4) > 0.01);
static const bool UseKey5 = (length(Key_Color5) > 0.01);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
//static float alpha1 = MaterialDiffuse.a;
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//スケール
//float4x4 WorldMatrix : WORLD;
//static float scaling = length(WorldMatrix._11_12_13) * 0.1;
float scaling0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float scaling = scaling0 * 0.1;

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;
static float timerate = Interval ? ((1 + cos(ftime * 2 * PI * 30 / (float)Interval)) * 0.4 + 0.2) : 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

static float2 SampStep = (float2(Extent_G,Extent_G)/ViewportSize*ViewportSize.y);
static float2 SampStep2 = (float2(Extent_S,Extent_S)/ViewportSize*ViewportSize.y);


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float4 ClearColorTr = {0,0,0,0};
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

// 放射光を記録するためのレンダーターゲット
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

// X方向のぼかし結果を記録するためのレンダーターゲット
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

bool ColorMuch(float4 color1, float3 key){
	float3 s = color1.rgb - key;
    return (length(s) <= KeyThreshold);
}

////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
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
// キーイング

float4 PS_passKeyEmit( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 csamp = tex2D( ScnSamp, Tex );
    float4 color = float4(0,0,0,0);
    
    if(UseKey1) color = ColorMuch(csamp, Key_Color1) ? float4(Emittion_Color1,1) : color;
    if(UseKey2) color = ColorMuch(csamp, Key_Color2) ? float4(Emittion_Color2,1) : color;
    if(UseKey3) color = ColorMuch(csamp, Key_Color3) ? float4(Emittion_Color3,1) : color;
    if(UseKey4) color = ColorMuch(csamp, Key_Color4) ? float4(Emittion_Color4,1) : color;
    if(UseKey5) color = ColorMuch(csamp, Key_Color5) ? float4(Emittion_Color5,1) : color;
    
    return color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 

float4 PS_passKeyCore(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color = float4(0,0,0,0);
    float4 csamp = tex2D( ScnSamp, Tex );
    
    if(UseKey1)  Color = ColorMuch(csamp, Key_Color1) ? float4(Core_Color1,1) : Color;
    if(UseKey2)  Color = ColorMuch(csamp, Key_Color2) ? float4(Core_Color2,1) : Color;
    if(UseKey3)  Color = ColorMuch(csamp, Key_Color3) ? float4(Core_Color3,1) : Color;
    if(UseKey4)  Color = ColorMuch(csamp, Key_Color4) ? float4(Core_Color4,1) : Color;
    if(UseKey5)  Color = ColorMuch(csamp, Key_Color5) ? float4(Core_Color5,1) : Color;
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// コアを太らせ、エッジを隠す

float4 PS_passCoreBold(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color;
    
    Color = tex2D( ScnSamp2, Tex );
    
    if(core_AntiAliasing){
	    /*Color = max(Color, 0.6 * tex2D( ScnSamp2, Tex+float2(0,OnePx.y)));
	    Color = max(Color, 0.6 * tex2D( ScnSamp2, Tex+float2(0,-OnePx.y)));
	    Color = max(Color, 0.6 * tex2D( ScnSamp2, Tex+float2(OnePx.x,0)));
	    Color = max(Color, 0.6 * tex2D( ScnSamp2, Tex+float2(-OnePx.x,0)));*/
		
		Color = max(Color, 1 * tex2D( ScnSamp2, Tex+float2(0,OnePx.y)));
	    Color = max(Color, 1 * tex2D( ScnSamp2, Tex+float2(0,-OnePx.y)));
	    Color = max(Color, 1 * tex2D( ScnSamp2, Tex+float2(OnePx.x,0)));
	    Color = max(Color, 1 * tex2D( ScnSamp2, Tex+float2(-OnePx.x,0)));
		
		Color = max(Color, 0.5 * tex2D( ScnSamp2, Tex+float2(OnePx.x,OnePx.y)));
	    Color = max(Color, 0.5 * tex2D( ScnSamp2, Tex+float2(OnePx.x,-OnePx.y)));
	    Color = max(Color, 0.5 * tex2D( ScnSamp2, Tex+float2(-OnePx.x,OnePx.y)));
	    Color = max(Color, 0.5 * tex2D( ScnSamp2, Tex+float2(-OnePx.x,-OnePx.y)));
    }
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// コアのエッジをぼかす

float4 PS_passDrawCore(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color;
    float4 csamp;
    float4 core;
    
    //オリジナル色
    csamp = tex2D( ScnSamp, Tex );
    //コア色
    if(core_AntiAliasing){
	    
	    core = 0.2 * tex2D( ScnSamp3, Tex);
	    
	    core += 0.12 * tex2D( ScnSamp3, Tex+float2(0,OnePx.y));
	    core += 0.12 * tex2D( ScnSamp3, Tex+float2(0,-OnePx.y));
	    core += 0.12 * tex2D( ScnSamp3, Tex+float2(OnePx.x,0));
	    core += 0.12 * tex2D( ScnSamp3, Tex+float2(-OnePx.x,0));
	    
	    core += 0.08 * tex2D( ScnSamp3, Tex+float2(OnePx.x,OnePx.y));
	    core += 0.08 * tex2D( ScnSamp3, Tex+float2(OnePx.x,-OnePx.y));
	    core += 0.08 * tex2D( ScnSamp3, Tex+float2(-OnePx.x,OnePx.y));
	    core += 0.08 * tex2D( ScnSamp3, Tex+float2(-OnePx.x,-OnePx.y));
	    
	    /*core = 0.4 * tex2D( ScnSamp3, Tex);
	    
	    core += 0.15 * tex2D( ScnSamp3, Tex+float2(0,OnePx.y));
	    core += 0.15 * tex2D( ScnSamp3, Tex+float2(0,-OnePx.y));
	    core += 0.15 * tex2D( ScnSamp3, Tex+float2(OnePx.x,0));
	    core += 0.15 * tex2D( ScnSamp3, Tex+float2(-OnePx.x,0));*/
	    
    }else{
    	core = tex2D( ScnSamp3, Tex);
    }
    
    Color = lerp(csamp, core, core.a);
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// X方向にじみ

float4 PS_passSX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep2.x * scaling * timerate;
    
    Color = tex2D( ScnSamp2, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp2, Tex+float2(step     ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp2, Tex+float2(step * 7 ,0)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp2, Tex-float2(step     ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp2, Tex-float2(step * 7 ,0)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向にじみ

float4 PS_passSY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float step = SampStep2.y * scaling * timerate;
    
    Color = tex2D( ScnSamp3, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step    )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, step * 7)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step    )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, step * 7)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep.x * scaling * timerate;
    
    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color.rgb *= Strength_A;
    
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(step    ,0) ) + tex2D( ScnSamp2, Tex-float2(step    ,0) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(step * 2,0) ) + tex2D( ScnSamp2, Tex-float2(step * 2,0) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(step * 3,0) ) + tex2D( ScnSamp2, Tex-float2(step * 3,0) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(step * 4,0) ) + tex2D( ScnSamp2, Tex-float2(step * 4,0) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(step * 5,0) ) + tex2D( ScnSamp2, Tex-float2(step * 5,0) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(step * 6,0) ) + tex2D( ScnSamp2, Tex-float2(step * 6,0) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(step * 7,0) ) + tex2D( ScnSamp2, Tex-float2(step * 7,0) ) );
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float step = SampStep.y * scaling * timerate;
    
    Color  = WT_0 *   tex2D( ScnSamp3, Tex );
    Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(0,step    ) ) + tex2D( ScnSamp3, Tex-float2(0,step    ) ) );
    Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(0,step * 2) ) + tex2D( ScnSamp3, Tex-float2(0,step * 2) ) );
    Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(0,step * 3) ) + tex2D( ScnSamp3, Tex-float2(0,step * 3) ) );
    Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(0,step * 4) ) + tex2D( ScnSamp3, Tex-float2(0,step * 4) ) );
    Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(0,step * 5) ) + tex2D( ScnSamp3, Tex-float2(0,step * 5) ) );
    Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(0,step * 6) ) + tex2D( ScnSamp3, Tex-float2(0,step * 6) ) );
    Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(0,step * 7) ) + tex2D( ScnSamp3, Tex-float2(0,step * 7) ) );
    
    Color.rgb *= (Strength_B * alpha1 * timerate);
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique KeyLuminous <
    string Script = 
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=KeyingCore;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=CoreBold;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=DrawCore;"
        
        
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=KeyingEmit;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_X;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_Y;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColorTr; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_X;"
        
        /*"RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_Y;"*/
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=Mix;"
    ;
    
> {
    pass KeyingCore < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passKeyCore();
    }
    pass KeyingEmit < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passKeyEmit();
    }
    pass CoreBold < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passCoreBold();
    }
    pass DrawCore < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passDrawCore();
    }
    pass Spread_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passSX();
    }
    pass Spread_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passSY();
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
    pass Mix < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
