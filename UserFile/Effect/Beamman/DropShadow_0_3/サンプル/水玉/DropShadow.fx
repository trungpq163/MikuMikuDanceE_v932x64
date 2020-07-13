//色
float3 DropColor
<
   string UIName = "DropColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float3(1,0,0);

///

float3 WorldPos : CONTROLOBJECT < string name = "(self)";>;
float Scale : CONTROLOBJECT < string name = "(self)";>;
float Alpha : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;

static float TexLoop = Scale*0.1;
static float GauseParam = (1-Alpha)*10;


//パターンテクスチャ
texture2D BackTex <
    string ResourceName = "Tex.png";
>;
sampler BackSamp = sampler_state {
    texture = <BackTex>;
    AddressU  = WRAP;
    AddressV = WRAP;
    Filter = LINEAR;
    
};
texture DropShadowRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DropShadow.fx";
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
    	"DropShadow.x = hide";
    >;

sampler DropMap = sampler_state {
    texture = <DropShadowRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = LINEAR;
};



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




// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(GauseParam,GauseParam)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

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

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

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
// X方向ぼかし

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
	float2 Tex2			: TEXCOORD1;
};

VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    
    Out.Pos = Pos;
    Out.Pos.zw = 1;
    
    WorldPos.x *= -1;
    Tex.xy += WorldPos.xy*0.01;
    Tex.xy += float2(-0.5,-0.5);
    Tex.xy *= 1+WorldPos.z*0.01;
    Tex.xy -= float2(-0.5,-0.5);
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	
	Color  = WT_0 *   tex2D( DropMap, Tex );
	Color += WT_1 * ( tex2D( DropMap, Tex+float2(SampStep.x  ,0) ) + tex2D( DropMap, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( DropMap, Tex+float2(SampStep.x*2,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( DropMap, Tex+float2(SampStep.x*3,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( DropMap, Tex+float2(SampStep.x*4,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( DropMap, Tex+float2(SampStep.x*5,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( DropMap, Tex+float2(SampStep.x*6,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( DropMap, Tex+float2(SampStep.x*7,0) ) + tex2D( DropMap, Tex-float2(SampStep.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    
    Out.Pos = Pos;
    Out.Pos.zw = 1;
    WorldPos.x *= -1;

    Tex.xy += WorldPos.xy*0.01;
    Tex.xy += float2(-0.5,-0.5);
    Tex.xy *= 1+WorldPos.z*0.01;
    Tex.xy -= float2(-0.5,-0.5);
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    Out.Tex2 = Tex;
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0,float2 Tex2: TEXCOORD1) : COLOR
{   
    float4 Color;
	
	Color  = WT_0 *   tex2D( ScnSamp2, Tex );
	Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*7) ) );
	
	Tex2 *= normalize(ViewportSize);
    Color.rgb = tex2D(BackSamp,Tex2*TexLoop);
	Color.rgb *= DropColor;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique DropShadow <
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
	    "Pass=Gaussian_Y;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {

        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
