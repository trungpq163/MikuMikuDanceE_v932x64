//水面ぼかし

//ブラー強さ
static float w_s = WaterGause;

//ブラー作業用
texture2D w_ScnBuf : RENDERCOLORTARGET <
	int Width = WAVE_TEXSIZE;
	int Height = WAVE_TEXSIZE;
	string Format = BUF_FORMAT;
>;
sampler2D w_ScnSamp = sampler_state {
    texture = <w_ScnBuf>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

static float2 w_SampStep = (float2(w_s,w_s)/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT w_VS_passX( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 w_PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    	
	Color  = WT_0 *   tex2D( HeightSampler1, Tex );
	Color += WT_1 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x  ,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*2,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*3,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*4,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*5,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*6,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( HeightSampler1, Tex+float2(w_SampStep.x*7,0) ) + tex2D( HeightSampler1, Tex-float2(w_SampStep.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT w_VS_passY( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 w_PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	    
	Color  = WT_0 *   tex2D( w_ScnSamp, Tex );
	Color += WT_1 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y  ) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*2) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*3) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*4) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*5) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*6) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( w_ScnSamp, Tex+float2(0,w_SampStep.y*7) ) + tex2D( w_ScnSamp, Tex-float2(0,w_SampStep.y*7) ) );
	Color.a = saturate(Color.a);
		
    return Color;
}