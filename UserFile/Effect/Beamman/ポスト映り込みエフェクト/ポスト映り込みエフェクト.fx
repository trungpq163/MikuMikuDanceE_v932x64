//パラメータ

//ブラー量
float blur = 1.0;

//レイの進行速度
float step_add = 0.005;
//最長うつりこみ距離
float len_max  = 0.1;

//******************設定はここまで
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float blur_tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//テクスチャフォーマット
//#define TEXFORMAT "D3DFMT_A32B32G32R32F"
#define TEXFORMAT "D3DFMT_A16B16G16R16F"

float offset = 18.0;


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


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(blur*blur_tr,blur*blur_tr)/ViewportSize);
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float4x4 matP      : PROJECTION;
float4x4 matV      : VIEW;
float4x4 matVP	   : VIEWPROJECTION;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    int MipLevels = 1;
    string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    string Format = "D24S8";
>;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    int MipLevels = 1;
    string Format = TEXFORMAT;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    int MipLevels = 1;
    string Format = TEXFORMAT;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//乱数テクスチャ
texture2D rndTex <
    string ResourceName = "rand.dds";
>;
sampler RandomMap = sampler_state {
    texture = <rndTex>;
};

//-----------------------------------------------------------------------------
// 法線マップ
//
//-----------------------------------------------------------------------------
texture NormalMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for NormalMap.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float2 ViewPortRatio = {0.5,0.5};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = NormalMap.fx";
>;

sampler NormalMap = sampler_state {
    texture = <NormalMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
};

//-----------------------------------------------------------------------------
// 座標マップ
//
//-----------------------------------------------------------------------------
texture PosMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for PosMap.fx";
    float4 ClearColor = { 0, 0, 0, 0 };
    float2 ViewPortRatio = {0.5,0.5};
    float ClearDepth = 1.0;
    string Format = TEXFORMAT;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = PosMap.fx";
>;

sampler PosMap = sampler_state {
    texture = <PosMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
};
//-----------------------------------------------------------------------------
// 深度マップ
//
//-----------------------------------------------------------------------------
texture DepthMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DepthMap.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float2 ViewPortRatio = {0.5,0.5};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_R32F" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = DepthMap.fx";
>;

sampler DepthMap = sampler_state {
    texture = <DepthMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
};

//-----------------------------------------------------------------------------
// 反射マップ
//
//-----------------------------------------------------------------------------
texture ReflectMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for ReflectMap.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float2 ViewPortRatio = {0.5,0.5};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = ReflectMap_反射弱.fx";
>;

sampler ReflectMap = sampler_state {
    texture = <ReflectMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
};
//-----------------------------------------------------------------------------
// 固定定義
//
//-----------------------------------------------------------------------------
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

//-----------------------------------------------------------------------------
// X Blur
//-----------------------------------------------------------------------------
VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.TexCoord = Tex + float2(0, ViewportOffset.y);

    return Out;
}

float4 PS_passX( VS_OUTPUT IN ) : COLOR {  
 
    float4 Color;

	Color  = WT_0 *   tex2D( ScnSamp3, IN.TexCoord );
	Color += WT_1 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x  ,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*2,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*3,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*4,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*5,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*6,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( ScnSamp3, IN.TexCoord+float2(SampStep.x*7,0) ) + tex2D( ScnSamp3, IN.TexCoord-float2(SampStep.x*7,0) ) );
	
    return Color;
	
}
//-----------------------------------------------------------------------------
// Y Blur
//-----------------------------------------------------------------------------

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.TexCoord = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY( VS_OUTPUT IN ) : COLOR
{   
    float4 Color;
    Color  =  tex2D( ScnSamp2, IN.TexCoord );

	Color  = WT_0 *   tex2D( ScnSamp2, IN.TexCoord );
	Color += WT_1 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y  ) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*2) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*3) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*4) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*5) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*6) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp2, IN.TexCoord+float2(0,SampStep.y*7) ) + tex2D( ScnSamp2, IN.TexCoord-float2(0,SampStep.y*7) ) );
	
    return Color;
}
//-----------------------------------------------------------------------------
// RLR(２Dベースの1バウンスレイトレース)
//-----------------------------------------------------------------------------
VS_OUTPUT VS_RLR( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.TexCoord = Tex + ViewportOffset;

    return Out;
}

float4 PS_RLR( VS_OUTPUT IN ) : COLOR {   
    float4 Color;

	float4 currentPixelSample = tex2D(NormalMap,IN.TexCoord);
	float4 PDMap = tex2D(PosMap,IN.TexCoord);
	PDMap.a = tex2D(DepthMap,IN.TexCoord).r;
	float currentPixelDepth = PDMap.a;

	// get the normal of current fragment
	float3 norm = normalize(currentPixelSample.xyz * 2.0f - 1.0f);
	
	float2 TgtPix = IN.TexCoord;
	float3 ray_base = reflect(-normalize(CameraPosition - PDMap.xyz),norm);
	float3 ray = mul(ray_base,matVP);

	ray.y *= -1;
	float3 Now = mul(PDMap.xyz,matVP);
	float4 Cam = mul(CameraPosition,matVP);
	float step = 0;
	float buf = 0.0;
	float2 se_w = 0;
	
	for(int i=0;i<32;i++)
	{
		float2 se = IN.TexCoord + ray.xy * step;
		step += step_add;
		
		float4 TgtPD = tex2D(PosMap,se);
		TgtPD.a = tex2D(DepthMap,se).r;
		float3 TgtNorm = normalize(tex2D(NormalMap,se).xyz * 2.0f - 1.0f);
		float d = 1-saturate(dot(TgtNorm,norm));
		float3 rw = PDMap.xyz - TgtPD.xyz;
		
		float len = 1-saturate(length(rw)*0.01);
		len *= len_max;
		rw = normalize(rw);
		float rd = 1-saturate(length(cross(rw,ray_base)));
		
		rd *= length(cross(TgtNorm,norm));
		rd = pow(rd,8);

		float dep = 1;//(PDMap.a < TgtPD.a ? 1 : 0);

		if(buf < rd * dep * len)
		{
			buf = rd * dep * len;
			TgtPix = se;
		}
	}

	Color.rgb = tex2D(ScnSamp,TgtPix);
	Color.a = buf;
	//Color.rgb += saturate(Color.rgb-1)*0;
	
	float4 RMap = tex2D(ReflectMap,IN.TexCoord);
	Color.a = saturate(RMap.rgb * RMap.a * Color.a * Scale * 5);

	
    return Color;
}



VS_OUTPUT VS_Last( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_Last( VS_OUTPUT IN ) : COLOR
{   
	float4 Color = tex2D( ScnSamp, IN.TexCoord );
	float4 rlr = tex2D( ScnSamp3, IN.TexCoord );
	float a = rlr.a;
	Color.rgb = lerp(Color.rgb,Color.rgb * rlr.rgb * Color.a,saturate(a));
	Color.rgb += saturate(rlr.rgb-1)*2*a;
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
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
        "Pass=RLRPass;"
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_Y;"
	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=LastPass;"
    ;
> {
    pass RLRPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_RLR();
        PixelShader  = compile ps_3_0 PS_RLR();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passX();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passY();
        PixelShader  = compile ps_3_0 PS_passY();
    }
    pass LastPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Last();
        PixelShader  = compile ps_3_0 PS_Last();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
