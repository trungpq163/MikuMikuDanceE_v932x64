//===================================================================
// ikGouache
// 画像を不透明水彩風にするエフェクト
//===================================================================

//パラメータ

// 計算用バッファの縮小率。1で1/1、2で1/2。1～4あたりで調整。
// 数値が大きいほど不正確＆高速になる。
#define MINI_BUFFER_SCALE	2.0

// エフェクトを重ね掛けする回数。0～4程度。
// 回数が多いほどグラデーション部分が平坦になる。
#define ITERATION_COUNT		2

// ブラーでの色の差に対する重み。0.0～10.0程度。
// 小さいほど、色の差を無視してボカす。
#define BLUR_WEIGHT		10.0


//****************** 設定はここまで

//テクスチャフォーマット
//#define TEXFORMAT "A16B16G16R16F"
#define TEXFORMAT "A8B8G8R8"

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

////////////////////////////////////////////////////////////////////////////////////////////////

#define TEXBUFFRATE_MINI {1.0/MINI_BUFFER_SCALE, 1.0/MINI_BUFFER_SCALE}

#define	PI	(3.14159265359)

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

texture DetailMap: OFFSCREENRENDERTARGET <
	string Description = "Detail Map for ikGouache";
	float4 ClearColor = { 1, 1, 0, 1 };
	float2 ViewportRatio = {1/2.0, 1/2.0};
	float ClearDepth = 1.0;
	string Format = "G16R16";
	string DefaultEffect = 
		"self = hide;"
		"* = DetailMap.fx";
>;
sampler2D DetailSamp = sampler_state {
	texture = <DetailMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};



// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float2 SampStep = 1.0 / ViewportSize.xy;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float4 ClearColorBlack = {0,0,0,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "A8B8G8R8";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;


texture2D MiniMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE_MINI;
	string Format = TEXFORMAT;
>;
sampler2D MiniSamp1 = sampler_state {
	texture = <MiniMap1>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D MiniMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE_MINI;
	string Format = TEXFORMAT;
>;
sampler2D MiniSamp2 = sampler_state {
	texture = <MiniMap2>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D ScnWorkMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;
sampler2D ScnWorkSamp1 = sampler_state {
	texture = <ScnWorkMap1>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D ScnWorkMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;
sampler2D ScnWorkSamp2 = sampler_state {
	texture = <ScnWorkMap2>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


// エッジ保存用
texture2D EdgeWorkMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1/2.0, 1/2.0};
	string Format = "R16F";
>;
sampler2D EdgeWorkSamp1 = sampler_state {
	texture = <EdgeWorkMap1>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
texture2D EdgeWorkMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1/2.0, 1/2.0};
	string Format = "R16F";
>;
sampler2D EdgeWorkSamp2 = sampler_state {
	texture = <EdgeWorkMap2>;
	MinFilter = LINEAR;	MagFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


// ぼかし処理の重み係数：
float WT[] = {
	0.0920246,
	0.0902024,
	0.0849494,
	0.0768654,
	0.0668236,
	0.0558158,
	0.0447932,
	0.0345379,
};

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}

// YUV変換
static float3x3 matToYUV = {
	 0.2126,	-0.09991,	 0.615,
	 0.7152,	-0.33609,	-0.55861,
	 0.0722,	 0.436,		-0.05639
};

static float3x3 matToRGB = {
	 1.0,		 1.0,		 1.0,
	 0.0,		-0.21482,	 2.12798,
	 1.28033,	-0.38059,	 0.0
};

inline float3 rgb2yuv(float3 rgb) { return mul(rgb, matToYUV);}
inline float3 yuv2rgb(float3 yuv) { return mul(yuv, matToRGB);}


// 二つの色の差を返す
inline float CalcError(float3 col0, float3 col1)
{
	float3 diff0 = col0.rgb - col1.rgb;
	return dot(diff0, diff0);
}

// srcに近いほうの色を返す
inline float3 GetNearestColor(float3 src, float3 col0, float3 col1)
{
	return (CalcError(src, col0) < CalcError(src, col1)) ? col0 : col1;
}

inline float CalcWeight(float4 col0, float4 col1)
{
	return exp(-CalcError(col0.rgb, col1.rgb) * (BLUR_WEIGHT * 10.0 + 20));
}


//-----------------------------------------------------------------------------
// 固定定義
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
};


//-----------------------------------------------------------------------------
// VS
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.TexCoord.xy = Tex + ViewportOffset.xy;
	Out.TexCoord.zw = SampStep;
	return Out;
}

// 縮小バッファ用
VS_OUTPUT VS_SetTexCoordMini( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.TexCoord.xy = Tex + ViewportOffset.xy * MINI_BUFFER_SCALE;
	Out.TexCoord.zw = SampStep * MINI_BUFFER_SCALE;
	return Out;
}


//-----------------------------------------------------------------------------
// PS

// 適当なソベルフィルタ
float4 PS_EdgeDownscale( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 s = SampStep * 0.5;

	float col7 = rgb2gray(tex2D( smp, uv + float2(-1,-1) * s).rgb);
	float col8 = rgb2gray(tex2D( smp, uv + float2( 0,-1) * s).rgb);
	float col9 = rgb2gray(tex2D( smp, uv + float2( 1,-1) * s).rgb);

	float col4 = rgb2gray(tex2D( smp, uv + float2(-1, 0) * s).rgb);
	// float col5 = rgb2gray(tex2D( smp, uv + float2( 0, 0) * s).rgb);
	float col6 = rgb2gray(tex2D( smp, uv + float2( 1, 0) * s).rgb);

	float col1 = rgb2gray(tex2D( smp, uv + float2(-1, 1) * s).rgb);
	float col2 = rgb2gray(tex2D( smp, uv + float2( 0, 1) * s).rgb);
	float col3 = rgb2gray(tex2D( smp, uv + float2( 1, 1) * s).rgb);

	float v = abs(col7 + col8 * 2 + col9 - (col1 + col2 * 2 + col3));
	float h = abs(col7 + col4 * 2 + col1 - (col9 + col6 * 2 + col3));
	float r = abs(col4 + col7 * 2 + col8 - (col2 + col3 * 2 + col6));
	float l = abs(col4 + col1 * 2 + col2 - (col8 + col9 * 2 + col6));

	float edge = saturate(max(max(v,h), max(r, l)) * 2.0);
	float lod = tex2D( DetailSamp, uv).x;

	return float4(edge * lod, 0,0,1);
}

float4 PS_EdgeBlur(VS_OUTPUT IN, uniform bool isXBlur, uniform sampler2D smp) : COLOR
{
	float2 TexCoord = IN.TexCoord.xy;
	float2 s = SampStep * 2.0;
	float2 Offset = isXBlur ? float2(s.x, 0) : float2(0, s.y);

	float4 Color0 = tex2D( smp, TexCoord);
	float4 Color = float4(Color0.rgb, 1) * WT[0];

	[unroll] for(int i = 1; i < 8; i++) {
		float w = WT[i];
		float4 Color1 = tex2D( smp, TexCoord + Offset*i);
		Color += float4(Color1.rgb, 1) * w;
		float4 Color2 = tex2D( smp, TexCoord - Offset*i);
		Color += float4(Color2.rgb, 1) * w;
	}

	return float4(Color.rgb / Color.w, 1);
}


// 小さくする
float4 PS_Downscale( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 s = SampStep * 0.5;

	float3 col7 = tex2D( smp, uv + float2(-1,-1) * s).rgb;
	float3 col9 = tex2D( smp, uv + float2( 1,-1) * s).rgb;
//	float3 col5 = tex2D( smp, uv).rgb;
	float3 col1 = tex2D( smp, uv + float2(-1, 1) * s).rgb;
	float3 col3 = tex2D( smp, uv + float2( 1, 1) * s).rgb;

//	return float4((col7+col9+col1+col3+col5)*0.2, 1);
	return float4((col7+col9+col1+col3)*0.25, 1);
}


// Symmetric Nearest Neighbor
float4 PS_SNN( VS_OUTPUT IN, uniform bool isUpscale, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 s = SampStep * MINI_BUFFER_SCALE;
	float3 col7 = tex2D( smp, uv + float2(-1,-1) * s).rgb;
	float3 col8 = tex2D( smp, uv + float2( 0,-1) * s).rgb;
	float3 col9 = tex2D( smp, uv + float2( 1,-1) * s).rgb;

	float3 col4 = tex2D( smp, uv + float2(-1, 0) * s).rgb;
	// 元画像を復元するかどうか?
	float3 col5 = isUpscale
		? tex2D( ScnSamp, uv).rgb
		: tex2D( smp, uv + float2( 0, 0) * s).rgb;
	float3 col6 = tex2D( smp, uv + float2( 1, 0) * s).rgb;

	float3 col1 = tex2D( smp, uv + float2(-1, 1) * s).rgb;
	float3 col2 = tex2D( smp, uv + float2( 0, 1) * s).rgb;
	float3 col3 = tex2D( smp, uv + float2( 1, 1) * s).rgb;

	float3 col = 0;
	col += GetNearestColor(col5, col4, col6);
	col += GetNearestColor(col5, col7, col3);
	col += GetNearestColor(col5, col8, col2);
	col += GetNearestColor(col5, col9, col1);
	col = col / 4.0;

	if (isUpscale)
	{
		// 詳細の復帰(明度のみ)
		float3 orig = rgb2yuv(col5); // col5には元画像の色が入っている。
		float3 yuv = rgb2yuv(col.rgb);
		float3 Restore = saturate(yuv2rgb(float3(orig.x, yuv.yz)));
		float detail = tex2D(EdgeWorkSamp1, uv).x;
		col.rgb = lerp(col.rgb, Restore, detail);

		// Trに応じて色を戻す
		float alpha = tex2D( DetailSamp, uv).y * AcsTr;
		col.rgb = lerp(col5, col.rgb, alpha);
	}

	return float4(col, 1);
}


float4 PS_Blur(VS_OUTPUT IN, uniform bool isXBlur, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 Offset = isXBlur ? float2(IN.TexCoord.z, 0) : float2(0 , IN.TexCoord.w);

	float4 Color0 = tex2D( smp, uv);
	float4 Color = float4(Color0.rgb, 1) * WT[0];

	[unroll] for(int i = 1; i < 8; i++) {
		float w = WT[i];
		float4 Color1 = tex2D( smp, uv + Offset*i);
		Color += float4(Color1.rgb, 1) * w * CalcWeight(Color0, Color1);

		float4 Color2 = tex2D( smp, uv - Offset*i);
		Color += float4(Color2.rgb, 1) * w * CalcWeight(Color0, Color2);
	}

	return float4(Color.rgb / Color.w, 1);
}



////////////////////////////////////////////////////////////////////////////////////////////////

#if defined(ITERATION_COUNT) && ITERATION_COUNT > 1
int RepeatCount = ITERATION_COUNT;
int RepeatIndex;
#endif

technique OilPaint <
	string Script = 
		// オリジナル画像の作成
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		// エッジの検出
		"RenderColorTarget0=EdgeWorkMap1; Pass=EdgeDownscalePass;"
		"RenderColorTarget0=EdgeWorkMap2; Pass=EdgeBlurXPass;"
		"RenderColorTarget0=EdgeWorkMap1; Pass=EdgeBlurYPass;"

		// SNN
		"RenderColorTarget0=MiniMap1; Pass=DownscalePass;"
		#if defined(ITERATION_COUNT) && ITERATION_COUNT > 1
		"LoopByCount=RepeatCount; LoopGetIndex=RepeatIndex;"
		#endif
			"RenderColorTarget0=MiniMap2; Pass=SNNPass1;"
			"RenderColorTarget0=MiniMap1; Pass=SNNPass2;"
		#if defined(ITERATION_COUNT) && ITERATION_COUNT > 1
		"LoopEnd=;"
		#endif
		"RenderColorTarget0=ScnWorkMap2; Pass=UpscalePass;"

		// スマートブラー
		"RenderColorTarget0=ScnWorkMap1; Pass=BlurXPass;"
		"RenderDepthStencilTarget=;"
		"RenderColorTarget0=;			 Pass=BlurYPass;"
	;
> {
	pass EdgeDownscalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordMini();
		PixelShader  = compile ps_3_0 PS_EdgeDownscale(ScnSamp);
	}
	pass EdgeBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeBlur(true, EdgeWorkSamp1);
	}
	pass EdgeBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_EdgeBlur(false, EdgeWorkSamp2);
	}

	pass DownscalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordMini();
		PixelShader  = compile ps_3_0 PS_Downscale(ScnSamp);
	}

	pass SNNPass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordMini();
		PixelShader  = compile ps_3_0 PS_SNN(false, MiniSamp1);
	}
	pass SNNPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordMini();
		PixelShader  = compile ps_3_0 PS_SNN(false, MiniSamp2);
	}
	pass UpscalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_SNN(true, MiniSamp1);
	}

	pass BlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(true, ScnWorkSamp2);
	}
	pass BlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(false, ScnWorkSamp1);
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
