
//色の濃さ1
float3 p_ToonCol = float3(1,1,1);
//色の濃さ2
float p_ToonPow = 8;
//色差エッジ閾値
float p_ThresholdC = 0.5;
//深度エッジ閾値
float p_ThresholdZ = 100.0;
//法線エッジ閾値
float p_ThresholdN = 0.5;

//色差エッジの濃さ
float p_ColorEdge = 1.0;
//深度エッジの濃さ
float p_DepthEdge = 1.0;
//法線エッジの濃さ
float p_NormalEdge = 1.0;


//線太さ(最小は0.5)
float p_LineSize = 1;
//エッジのぼかし
float p_Gause = 1;

//ここから触らない

#define CONTROLLER_NAME "MultiEdge.pmd"

float m_ToonCol : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "色の濃さ1"; >;
float m_ToonPow : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "色の濃さ2"; >;
float m_ThresholdC : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "色差閾値"; >;
float m_ThresholdZ : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "深度閾値"; >;
float m_ThresholdN : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "法線閾値"; >;
float m_ColorEdge : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "色差濃さ"; >;
float m_DepthEdge : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "深度濃さ"; >;
float m_NormalEdge : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "法線濃さ"; >;
float m_LineSize : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "太さ"; >;
float m_Gause : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ぼかし"; >;
float m_DispCol : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "画面色"; >;

//色の濃さ1
static float3 ToonCol = p_ToonCol * m_ToonCol;
//色の濃さ2
static float ToonPow = p_ToonPow * m_ToonPow;
//色差エッジ閾値
static float ThresholdC = p_ThresholdC * m_ThresholdC;
//深度エッジ閾値
static float ThresholdZ = p_ThresholdZ * m_ThresholdZ;
//法線エッジ閾値
static float ThresholdN = p_ThresholdN * m_ThresholdN;

//色差エッジの濃さ
static float ColorEdge = p_ColorEdge * m_ColorEdge;
//深度エッジの濃さ
static float DepthEdge = p_DepthEdge * m_DepthEdge;
//法線エッジの濃さ
static float NormalEdge = p_NormalEdge * m_NormalEdge;

//線太さ(最小は0.5)
static float LineSize = p_LineSize * m_LineSize;
//エッジのぼかし
static float Gause = p_Gause * m_Gause + LineSize;


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

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
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

//Z深度用RT
texture EdgeDepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DrawZ.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float2 ViewPortRatio = {1.0,1.0};
    string Format="R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler DepthSamp = sampler_state
{
   Texture = (EdgeDepthRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
//法線用RT
texture EdgeNormalRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DrawNormal.fx";
    float4 ClearColor = { 0, 0, 0, 0 };
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "A8R8G8B8" ;
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawNormal.fx;";
>;

texture EdgeMask: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DrawNormal.fx";
    float4 ClearColor = { 0, 0, 0, 0 };
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "A8R8G8B8" ;
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = hide;";
>;
sampler2D MaskSamp = sampler_state {
    texture = <EdgeMask>;
	FILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

sampler NormalSamp = sampler_state
{
   Texture = (EdgeNormalRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    bool AntiAlies = true;
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
// レンダーターゲット
texture2D EdgeBuf : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    bool AntiAlies = true;
    string Format = "A8R8G8B8" ;
>;
sampler2D EdgeSamp = sampler_state {
    texture = <EdgeBuf>;
	FILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D GWorkX : RENDERCOLORTARGET <
    bool AntiAlies = true;
    string Format = "A8R8G8B8" ;
>;
sampler2D GXSamp = sampler_state {
    texture = <GWorkX>;
	FILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D GWorkY : RENDERCOLORTARGET <
    bool AntiAlies = true;
    string Format = "A8R8G8B8" ;
>;
sampler2D GYSamp = sampler_state {
    texture = <GWorkY>;
	FILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D FatTex : RENDERCOLORTARGET <
    bool AntiAlies = true;
    string Format = "A8R8G8B8" ;
>;
sampler2D FatSamp = sampler_state {
    texture = <FatTex>;
	FILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

static float2 SampStep = (float2(1,1)/ViewportSize);

static float2 test[4] = 
		{
			{0,1},{1,0},{-1,0},{0,-1}
		};

VS_OUTPUT VS_Base( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = Pos; 
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


float4 PS_Edge(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 col = tex2D(ScnSamp,Tex);
	float4 z = tex2D(DepthSamp,Tex);
	float4 nor = tex2D(NormalSamp,Tex);
	
	float4 Out;
	Out.a = 1;
	
	//深度の差異を保存する変数
	float sabun = 0;
	float add = 0;
	for(int i=0;i<4;i++)
	{
		float4 w = tex2D(DepthSamp,Tex + test[i]*SampStep);	
		//Zの差分を加算
		add += (ThresholdZ < (w.r - z.r));
	}
	Out.r = saturate(add);

	add = 0;
	for(int i=0;i<4;i++)
	{
		//法線の差分を計算
		float4 w = tex2D(NormalSamp,Tex + test[i]*SampStep);	
		add += (ThresholdN < (w.r - nor.r) || w.a == 0)*nor.a;	
	}
	Out.g = saturate(add);
	
	add = 0;
	for(int i=0;i<2;i++)
	{
		float4 w;
		//色の差分を計算
		w = tex2D(ScnSamp,Tex + test[i]*SampStep);
		
		
		add += (ThresholdC < length(w - col));	 
	}
	Out.b = add;
	
	return Out;
}
float4 PS_Mix(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 col = tex2D(EdgeSamp,Tex)*1;
	
	float add = 0;
	for(int i=0;i<4;i++)
	{
		float4 w = tex2D(EdgeSamp,Tex + test[i]*SampStep);	
		add += w.r * DepthEdge + w.g * NormalEdge + w.b * ColorEdge;
	}
	col.r = saturate(add/4);
	col.r += tex2D(GYSamp,Tex);
	//return float4(col.r,0,0,1);
	
	float edge = col.r;
	//色計算
	
	col = tex2D(ScnSamp,Tex);
	float4 buf = 0;
	for(int i=0;i<4;i++)
	{
		buf += tex2D(ScnSamp,Tex + test[i]*SampStep);	
	}
	buf /= 4.0;
	buf.a = col.a;
	buf.rgb = pow(buf.rgb*ToonCol,ToonPow);
	//buf.rgb *= ToonCol;
	
	
	//return float4(1-edge,1-edge,1-edge,1);
	col = saturate(col + 1 * m_DispCol);
	float Mask = 1-tex2D(MaskSamp,Tex).a;
	col = lerp(col,buf,saturate(edge)*Mask);
	
	return col;
}

static float2 ViewportOffset_G = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep_G = (float2(Gause,Gause)/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

struct VS_OUTPUT_G {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT_G VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT_G Out = (VS_OUTPUT_G)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	
	Color  = WT_0 *   tex2D( EdgeSamp, Tex );
	Color += WT_1 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x  ,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x  ,0) ) );
	Color += WT_2 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*2,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*2,0) ) );
	Color += WT_3 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*3,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*3,0) ) );
	Color += WT_4 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*4,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*4,0) ) );
	Color += WT_5 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*5,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*5,0) ) );
	Color += WT_6 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*6,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*6,0) ) );
	Color += WT_7 * ( tex2D( EdgeSamp, Tex+float2(SampStep_G.x*7,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_G.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT_G VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT_G Out = (VS_OUTPUT_G)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = WT_0 *   tex2D( GXSamp, Tex );
	Color += WT_1 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y  ) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y  ) ) );
	Color += WT_2 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*2) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*2) ) );
	Color += WT_3 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*3) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*3) ) );
	Color += WT_4 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*4) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*4) ) );
	Color += WT_5 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*5) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*5) ) );
	Color += WT_6 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*6) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*6) ) );
	Color += WT_7 * ( tex2D( GXSamp, Tex+float2(0,SampStep_G.y*7) ) + tex2D( GXSamp, Tex-float2(0,SampStep_G.y*7) ) );
	
	Color.r *= Gause;
    return Color;
}

static float2 SampStep_Fat = (float2(LineSize,LineSize)/ViewportSize);

float4 PS_EdgeFat(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = tex2D( EdgeSamp, Tex );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x  ,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x  ,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*2,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*2,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*3,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*3,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*4,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*4,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*5,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*5,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*6,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*6,0) ) );
	Color += ( tex2D( EdgeSamp, Tex+float2(SampStep_Fat.x*7,0) ) + tex2D( EdgeSamp, Tex-float2(SampStep_Fat.x*7,0) ) );
	
	
    return Color;
}
float4 PS_Cpy(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = tex2D( FatSamp, Tex );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y  ) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y  ) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*2) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*2) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*3) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*3) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*4) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*4) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*5) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*5) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*6) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*6) ) );
	Color += ( tex2D( FatSamp, Tex+float2(0,SampStep_Fat.y*7) ) + tex2D( FatSamp, Tex-float2(0,SampStep_Fat.y*7) ) );


    return Color;
}


texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
////////////////////////////////////////////////////////////////////////////////////////////////

technique Edge <
    string Script = 
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=EdgeBuf;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Edge;"
	    
        "RenderColorTarget0=FatTex;"
        "Pass=EdgeFat;"
        "RenderColorTarget0=EdgeBuf;"
        "Pass=Cpy;"
        
        "RenderColorTarget0=GWorkX;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=GWorkY;"
	    "Pass=Gaussian_Y;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Mix;"
    ;
> {
    pass Edge < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = SRCALPHA;
        DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 VS_Base();
        PixelShader  = compile ps_3_0 PS_Edge();
    }
    pass EdgeFat < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = SRCALPHA;
        DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 VS_Base();
        PixelShader  = compile ps_3_0 PS_EdgeFat();
    }
    pass Cpy < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = SRCALPHA;
        DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 VS_Base();
        PixelShader  = compile ps_3_0 PS_Cpy();
    }
    pass Mix < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = SRCALPHA;
        DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 VS_Base();
        PixelShader  = compile ps_3_0 PS_Mix();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////

