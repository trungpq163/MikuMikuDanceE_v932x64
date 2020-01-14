//----垂直ブラー----//

//ブラー強さ
float s = 2;

//ブラー作業用
texture2D ScnBuf : RENDERCOLORTARGET <
	int Width = MIRROR_SIZE;
	int Height = MIRROR_SIZE;
	string Format = BUF_FORMAT;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnBuf>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ブラー保存用
texture MirrorBuf : RENDERCOLORTARGET
<
	int Width = MIRROR_SIZE;
	int Height = MIRROR_SIZE;
	string Format = BUF_FORMAT;
>;
sampler MirrorBufView = sampler_state {
    texture = <MirrorBuf>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D MirrorDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int Width = MIRROR_SIZE;
	int Height = MIRROR_SIZE;
    string Format = "D24S8";
>;

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


static float2 SampStep = (float2(s,s)/ViewportSize);

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT VS_passX( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

    float a = tex2D( MirrorView, Tex ).a;
    //ぼかし強さ
    SampStep *= saturate(tex2D(WaterDepthSamp,Tex).r*V_Gauss_pow)*a;
	
	Color  = WT_0 *   tex2D( MirrorView, Tex );
	Color += WT_1 * ( tex2D( MirrorView, Tex+float2(SampStep.x  ,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( MirrorView, Tex+float2(SampStep.x*2,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( MirrorView, Tex+float2(SampStep.x*3,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( MirrorView, Tex+float2(SampStep.x*4,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( MirrorView, Tex+float2(SampStep.x*5,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( MirrorView, Tex+float2(SampStep.x*6,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( MirrorView, Tex+float2(SampStep.x*7,0) ) + tex2D( MirrorView, Tex-float2(SampStep.x*7,0) ) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
    float a = tex2D( MirrorView, Tex ).a;
    //ぼかし強さ
    SampStep *= saturate(tex2D(WaterDepthSamp,Tex).r*V_Gauss_pow)*a;
    
	Color  = WT_0 *   tex2D( ScnSamp, Tex );
	Color += WT_1 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*7) ) );
	Color.a = saturate(Color.a);
	Color.a *= a;
    return Color;
}