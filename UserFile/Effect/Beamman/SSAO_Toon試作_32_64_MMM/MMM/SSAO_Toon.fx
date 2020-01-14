//-----------------------------------------------------
//
// SSAO.fx
//
//-----------------------------------------------------

float totStrength = 30.0;
float strength = 0.04;
float falloff = 0.000001;
float rad = 0.04;
float blur = 0.8;
//追加
float ZCheck = 0.001;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

//******************設定はここまで
float offset = 18.0;
float invSamples = 1.0/16.0;

float3 samples[16] = {
	float3(0.53812504, 0.18565957, -0.43192),
	float3(0.13790712, 0.24864247, 0.44301823),
	float3(0.33715037, 0.56794053, -0.005789503),
	float3(-0.6999805, -0.04511441, -0.0019965635),
	float3(0.06896307, -0.15983082, -0.85477847),
	float3(0.056099437, 0.006954967, -0.1843352),
	float3(-0.014653638, 0.14027752, 0.0762037),
	float3(0.010019933, -0.1924225, -0.034443386),
	float3(-0.35775623, -0.5301969, -0.43581226),
	float3(-0.3169221, 0.106360726, 0.015860917),
	float3(0.010350345, -0.58698344, 0.0046293875),
	float3(-0.08972908, -0.49408212, 0.3287904),
	float3(0.7119986, -0.0154690035, -0.09183723),
	float3(-0.053382345, 0.059675813, -0.5411899),
	float3(0.035267662, -0.063188605, 0.54602677),
	float3(-0.47761092, 0.2847911, -0.0271716)
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


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(blur,blur)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
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
    string Description = "OffScreen RenderTarget for NormalMap.fxsub";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* = NormalMap.fxsub";
>;

sampler NormalMap = sampler_state {
    texture = <NormalMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

//-----------------------------------------------------------------------------
// 深度マップ
//
//-----------------------------------------------------------------------------
texture DepthMapRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DepthMap.fxsub";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_R32F" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* = DepthMap.fxsub";
>;

sampler DepthMap = sampler_state {
    texture = <DepthMapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
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
// SSAO
//-----------------------------------------------------------------------------
VS_OUTPUT VS_SSAO( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.TexCoord = Tex + ViewportOffset;

    return Out;
}

float4 PS_SSAO( VS_OUTPUT IN ) : COLOR {   
    float4 Color;
	
	// grab a normal for reflecting the sample rays later on
	float3 fres = normalize((tex2D(RandomMap,IN.TexCoord*offset).xyz*2.0) - 1.0);

	float4 currentPixelSample = tex2D(NormalMap,IN.TexCoord);
	float currentPixelDepth = tex2D(DepthMap,IN.TexCoord).r;

	// get the normal of current fragment
	float3 norm = currentPixelSample.xyz * 2.0f - 1.0f;


	float bl = 0.0;
	// adjust for the depth ( not shure if this is good..)
	float radD = rad/currentPixelDepth;

	float3 ray, occNorm;
	float2 se;
	float occluderDepth, depthDifference, normDiff;
	
	
	for(int i=0; i<16;++i)
	{
		// get a vector (randomized inside of a sphere with radius 1.0) from a texture and reflect it
		ray = radD * reflect(samples[i], fres);

		// if the ray is outside the hemisphere then change direction
		se = IN.TexCoord + sign(dot(ray,norm)) * ray * float2(1.0f, -1.0f);

		// get the depth of the occluder fragment
		float4 occluderFragment = tex2D(NormalMap, se);
		
		// get the normal of the occluder fragment
		occNorm = occluderFragment.xyz * 2.0f - 1.0f;

		// if depthDifference is negative = occluder is behind current fragment
		depthDifference = currentPixelDepth - tex2D(DepthMap, se).r;
		
		if(length(depthDifference) > ZCheck)
		{
			continue;
		}
		
		// calculate the difference between the normals as a weight
		normDiff = (1.0 - dot(normalize(occNorm), normalize(norm)));
		
		// the falloff equation, starts at falloff and is kind of 1/x^2 falling
		bl +=  step(falloff,depthDifference) *normDiff * (1.0 - smoothstep(falloff, strength, depthDifference));
	}


	// output the result
	float ao = 1.0 - totStrength * bl * invSamples * scaling;

	//Color = float4(ao,ao,ao,1); return real ao color
	
	Color = lerp(tex2D( ScnSamp, IN.TexCoord ) , float4(1,1,1,1),ao);

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
	float4 Color;
	float4 ssao = tex2D( ScnSamp3, IN.TexCoord );
	ssao = saturate(pow(ssao*1,1)*1);
	float comp = saturate((ssao.r+ssao.g+ssao.b)/3);
	comp = saturate(pow(comp*2,8));
	
	Color = tex2D( ScnSamp, IN.TexCoord );
	
	float4 ShadowColor = pow(Color*1,1.5);
	Color = lerp(Color,ShadowColor,1-comp);
	Color.a = tex2D( ScnSamp, IN.TexCoord ).a;
	
	//Color = float4(comp,comp,comp,1);
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
        "Pass=SSAOPass;"
        
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
    pass SSAOPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_SSAO();
        PixelShader  = compile ps_3_0 PS_SSAO();
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
