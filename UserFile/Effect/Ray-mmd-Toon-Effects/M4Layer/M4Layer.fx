////////////////////////////////////////////////////////////////////////////////
//
//  M4Layer.fx
//  作成: ミーフォ茜
//
////////////////////////////////////////////////////////////////////////////////

// レイヤー名
#define LAYER_NAME Layer

// レイヤーモード
// 0: 通常
// 1: 加算
// 2: 減算
// 3: 乗算
// 4: スクリーン
// 5: オーバーレイ
// 6: ハードライト
// 7: ソフトライト
// 8: ビビッドライト
// 9: リニアライト
// 10: ピンライト
// 11: 覆い焼き
// 12: 焼き込み
// 13: 比較 (暗)
// 14: 比較 (明)
// 15: 差の絶対値
// 16: 除外
// 17: 色相
// 18: 彩度
// 19: カラー
// 20: 輝度
#define LAYER_MODE 0

// マスクを使用するか
#define LAYER_MASK 0

// マスクを反転するか
#define LAYER_MASK_INVERT 0

// レンダリングターゲットを使用するか
// 0 にすると描画結果をそのまま使用するようになりますが、
// 他のレンダリングターゲットに対して使用できるようになります。
#define LAYER_RT 1

#define ALPHA_ENABLED 1

////////////////////////////////////////////////////////////////

#define MERGE(a, b) a##b
#if LAYER_MODE == 17
#define IS_COMPOSITE_BLENDING
#elif LAYER_MODE == 18
#define IS_COMPOSITE_BLENDING
#elif LAYER_MODE == 19
#define IS_COMPOSITE_BLENDING
#elif LAYER_MODE == 20
#define IS_COMPOSITE_BLENDING
#endif

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL
<
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

////////////////////////////////////////////////////////////////
// 作業用テクスチャ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;
texture2D ScreenBuffer : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScreenSampler = sampler_state {
	texture = <ScreenBuffer>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#if LAYER_RT
texture MERGE(LAYER_NAME, RT) : OFFSCREENRENDERTARGET
<
	string Description = "Render Target for M4Layer.fx";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect = "self = hide; * = none;";
>;
sampler LayerSampler = sampler_state
{
	texture = <MERGE(LAYER_NAME, RT)>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

#endif

#if LAYER_MASK
texture MERGE(LAYER_NAME, MaskRT) : OFFSCREENRENDERTARGET
<
	string Description = "Masking Render Target for M4Layer.fx";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect = "self = hide; * = VisibleMask.fx;";
>;
sampler LayerMaskSampler = sampler_state
{
	texture = <MERGE(LAYER_NAME, MaskRT)>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
#endif

struct VS_OUTPUT
{
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT BlendVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{ 
	VS_OUTPUT Out;
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

#ifdef IS_COMPOSITE_BLENDING

float Lum(float3 rgb)
{
	return rgb.r * 0.3 + rgb.g * 0.59 + rgb.b * 0.11;
}

float3 ClipColor(float3 rgb)
{
	float l = Lum(rgb);
	float n = min(rgb.r, min(rgb.g, rgb.b));
	float x = max(rgb.r, max(rgb.g, rgb.b));
	
	if (n < 0)
	{
		float lMinusN = l - n;
		
		rgb = float3
		(
			l + (rgb.r - l) * l / lMinusN,
			l + (rgb.g - l) * l / lMinusN,
			l + (rgb.b - l) * l / lMinusN
		);
	}
	
	if (x > 1)
	{
		float oneMinusL = 1 - l;
		float xMinusL = x - l;
		
		rgb = float3
		(
			l + (rgb.r - l) * oneMinusL / xMinusL,
			l + (rgb.g - l) * oneMinusL / xMinusL,
			l + (rgb.b - l) * oneMinusL / xMinusL
		);
	}
	
	return rgb;
}

float3 SetLum(float3 rgb, float l)
{
	float d = l - Lum(rgb);
	
	rgb += float3(d, d, d);
	
	return ClipColor(rgb);
}

float Sat(float3 rgb)
{
	return max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
}

float3 SetSat(float3 rgb, float s)
{
	float3 rt = rgb;
	float maxValue = max(rgb.r, max(rgb.g, rgb.b));
	float minValue = min(rgb.r, min(rgb.g, rgb.b));
	float midValue =
		rgb.r < maxValue && rgb.r > minValue ? rgb.r :
		rgb.g < maxValue && rgb.g > minValue ? rgb.g :
		rgb.b < maxValue && rgb.b > minValue ? rgb.b : (maxValue + minValue) / 2;
	
	if (maxValue > minValue)
	{
		[unroll]
		for (int i = 0; i < 3; i++)
		{
			if (rgb[i] == midValue)
				rt[i] = (midValue - minValue) * s / (maxValue - minValue);
			else if (rgb[i] == maxValue)
				rt[i] = s;
			else
				rt[i] = 0;
		}
	}
	else
	{
		rt = 0;
	}
	
	return rt;
}

float3 Blend(float3 a, float3 b)
{
#if LAYER_MODE == 17
	return SetLum(SetSat(b, Sat(a)), Lum(a));	// 色相
#elif LAYER_MODE == 18
	return SetLum(SetSat(a, Sat(b)), Lum(a));	// 彩度
#elif LAYER_MODE == 19
	return SetLum(b, Lum(a));					// カラー
#elif LAYER_MODE == 20
	return SetLum(a, Lum(b));					// 輝度
#else
	return b;	// 通常
#endif
}

#else

float Blend(float a, float b)
{
#if LAYER_MODE == 1
	return a + b;	// 加算
#elif LAYER_MODE == 2
	return a - b;	// 減算
#elif LAYER_MODE == 3
	return a * b;	// 乗算
#elif LAYER_MODE == 4
	return 1 - (1 - a) * (1 - b);	// スクリーン
#elif LAYER_MODE == 5
	return a < 0.5
		? a * b * 2
		: 1 - (1 - a) * (1 - b) * 2;	// オーバーレイ
#elif LAYER_MODE == 6
	return b < 0.5
		? a * b * 2
		: 1 - (1 - a) * (1 - b) * 2;	// ハードライト
#elif LAYER_MODE == 7
	return (1 - b) * pow(a, 2) + b * (1 - pow(1 - b, 2));	// ソフトライト
#elif LAYER_MODE == 8
	return b < 0.5
		? (a >= 1 - b * 2 ? 0 : (a - (1 - b * 2)) / (b * 2))
		: (a < 2 - b * 2 ? a / (2 - b * 2) : 1);	// ビビッドライト
#elif LAYER_MODE == 9
	return b < 0.5
		? (a < 1 - b * 2 ? 0 : b * 2 + a - 1)
		: (a < 2 - b * 2 ? b * 2 + a - 1 : 1);	// リニアライト
#elif LAYER_MODE == 10
	return b < 0.5
		? (b * 2 < a ? b * 2 : a)
		: (b * 2 - 1 < a ? a : b * 2 - 1);	// ピンライト
#elif LAYER_MODE == 11
	return a > 0 ? a / (1 - b) : 0;	// 覆い焼き
#elif LAYER_MODE == 12
	return b > 0 ? 1 - (1 - a) / b : 0;	// 焼き込み
#elif LAYER_MODE == 13
	return min(a, b);	// 比較 (暗)
#elif LAYER_MODE == 14
	return max(a, b);	// 比較 (明)
#elif LAYER_MODE == 15
	return abs(a - b);	// 差の絶対値
#elif LAYER_MODE == 16
	return a + b - 2 * a * b;	// 除外
#else
	return b;		// 通常
#endif
}

#endif

float4 BlendPS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 background = tex2D(ScreenSampler, Tex);
	
#if LAYER_RT
	float4 foreground = tex2D(LayerSampler, Tex);
#else
	float4 foreground = background;
#endif
	
#if LAYER_MASK
	float4 m = tex2D(LayerMaskSampler, Tex);
	
	#if LAYER_MASK_INVERT
	foreground.a *= m.r * m.a;
	#else
	foreground.a *= 1 - m.r * m.a;
	#endif
#endif
	
#ifdef IS_COMPOSITE_BLENDING
	foreground.rgb = Blend(background.rgb, foreground.rgb);
#else
	[unroll]
	for (int i = 0; i < 3; i++)
		foreground[i] = Blend(background[i], foreground[i]);
#endif
	
	float a = Tr * (Si / 10) * foreground.a;
	
	background.a = min(1, background.a + a);
	background.rgb = lerp(background.rgb, foreground.rgb, a);
	
	return background;
}

////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float4 ClearColor = { 0, 0, 0, 0 };
float ClearDepth = 1;

technique PostEffectTec
<
	string Script =
		"RenderColorTarget0=ScreenBuffer;"
		"RenderDepthStencilTarget=DepthBuffer;"
#if ALPHA_ENABLED
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
#endif
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
#if ALPHA_ENABLED
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
#endif
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=PassBlend;";
>
{
	pass PassBlend < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = true;
		VertexShader = compile vs_3_0 BlendVS();
		PixelShader  = compile ps_3_0 BlendPS();
	}
};
