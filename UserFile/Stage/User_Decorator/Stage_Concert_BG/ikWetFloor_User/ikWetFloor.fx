// ikWetFloor
//		針金PのWorkingFloorXをポストエフェクトに置き換えたもの。
//		ついでに、少しの段差を無視したり写り込みを加工したりする。
//		Xシャドウ機能はありません。

#include "ikWetFloorSettings.fxsub"

#define ENABLE_POSTPROCESS	1

//******************設定はここまで

#define USE_BLUR	1		// テスト用


float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
// 透過値
float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float FloorHeight: CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float FloorXOffset: CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float FloorZOffset: CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;

//テクスチャフォーマット
#define TEXFORMAT "D3DFMT_A16B16G16R16F"
#define REF_TEXFORMAT "D3DFMT_A16B16G16R16F"

////////////////////////////////////////////////////////////////////////////////////////////////
#if defined(ENABLE_POSTPROCESS) && ENABLE_POSTPROCESS > 0
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
#endif

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);

float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float4x4 matP		: PROJECTION;
float4x4 matV		: VIEW;
float4x4 matVP		: VIEWPROJECTION;
float4x4 matVPInv	: VIEWPROJECTIONINVERSE;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

#if defined(ENABLE_POSTPROCESS) && ENABLE_POSTPROCESS > 0
// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	// string Format = "D3DFMT_A16B16G16R16F";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

//-----------------------------------------------------------------------------
// 深度マップ
//
//-----------------------------------------------------------------------------
texture FloorHeightRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikWetFloor";
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = TEXFORMAT;
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"
		"* = ikFloorHeight.fxsub";
>;

sampler FloorHeightSamp = sampler_state {
	texture = <FloorHeightRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

#if defined(MaterialTextureName)
texture2D MaterialTex <
	string ResourceName = MaterialTextureName;
>;
sampler MaterialSamp = sampler_state {
	texture = <MaterialTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = WRAP;
	AddressV  = WRAP;
};

#endif

////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

#ifndef MIKUMIKUMOVING
    #if(FLG_EXCEPTION == 0)
		#if USE_HDR == 1
	        #define OFFSCREEN_FX_OBJECT  "WF_ObjectAL.fxsub"      // オフスクリーン鏡像描画エフェクト
		#else
	        #define OFFSCREEN_FX_OBJECT  "WF_Object.fxsub"      // オフスクリーン鏡像描画エフェクト
		#endif
    #else
        #define OFFSCREEN_FX_OBJECT  "WF_ObjectExc.fxsub"   // オフスクリーン鏡像描画エフェクト
    #endif
    #define ADD_HEIGHT   (0.05f)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define OFFSCREEN_FX_OBJECT  "WF_Object_MMM.fxsub"  // オフスクリーン鏡像描画エフェクト
    #define ADD_HEIGHT   (0.01f)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


// 床面鏡像描画のオフスクリーンバッファ
texture WetFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for ikWetFloor";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
#if USE_HDR == 1
	string Format = "D3DFMT_A16B16G16R16F";
#endif
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"

        "*.pmd =" OFFSCREEN_FX_OBJECT ";"
        "*.pmx =" OFFSCREEN_FX_OBJECT ";"
        #if(XFileMirror == 1)
        "*.x=   " OFFSCREEN_FX_OBJECT ";"
        "*.vac =" OFFSCREEN_FX_OBJECT ";"
        #endif

        "* = hide;" ;
>;
sampler WorkingFloorView = sampler_state {
    texture = <WetFloorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


texture2D ReflectionMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = REF_TEXFORMAT;
>;

sampler ReflectionMapSamp = sampler_state {
	texture = <ReflectionMap>;
	Filter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D ReflectionMapBlur : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = REF_TEXFORMAT;
>;

sampler ReflectionMapBlurSamp = sampler_state {
	texture = <ReflectionMapBlur>;
	Filter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


//乱数テクスチャ(3D)
texture2D RandomTex3D <
	string ResourceName = "Random.png";
>;
sampler RandomSamp3D = sampler_state {
	texture = <RandomTex3D>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU  = WRAP;
	AddressV  = WRAP;
};

#define RANDOM_TEX_SIZE		256

// ガンマ補正
const float gamma = 2.2;
inline float3 Degamma(float3 col) { return pow(col, gamma); }
inline float3 Gamma(float3 col) { return pow(col, 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

static float2 SampStep = (float2(BlurSize, BlurSize) / (ViewportSize.xy / 1.0));

#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

//-----------------------------------------------------------------------------
// 固定定義
//
//-----------------------------------------------------------------------------
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};


//-----------------------------------------------------------------------------
// 共通のVS
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex.xy + ViewportOffset.xy;

	return Out;
}


float2 GetUV(float2 wpos)
{
	float invScale = 1.0 / (AcsSi * 0.1 * MaterialTextureScale);
	return frac(wpos * invScale + float2(FloorXOffset, FloorZOffset) * 0.1);
}
//-----------------------------------------------------------------------------
//
float4 PS_Reflection( VS_OUTPUT IN ) : COLOR
{
	float4 dist = tex2D( FloorHeightSamp, IN.TexCoord );

	float4 wpos0 = float4(dist.xyz, 1);

	// 視線方向にズラす
	float3 v = normalize(wpos0.xyz - CameraPosition) * LightTail;
	v.y = 0;

	float3 MirrorColor = 0;
	// float3 MirrorColorMax = 0;

	#if defined(MaterialTextureName)
	float2 uv = GetUV(wpos0.xz);
	float roughnessScale = tex2D(MaterialSamp, uv).a;
	#else
	float roughnessScale = Roughness;
	#endif

	float2 uv0 = IN.TexCoord * ViewportSize.xy / RANDOM_TEX_SIZE;

	for(int i = 0; i < NUM_LOOP; i++) {
		float4 ColorRand = tex2D( RandomSamp3D, uv0 + float2(0.033, 0.051) * i);
		float3 randVec = normalize(2.0f * ColorRand.xyz - 1.0f);
		float4 wpos = wpos0;
		wpos.xyz += (v + randVec * Roughness) * (abs(ColorRand.w + 0.01) * roughnessScale);
			// 中心から離れるほど影響力を下げるべき?
			// weight = exp(-((LightTail + 1) * ColorRand.w))

		// 鏡像のスクリーンの座標(左右反転しているので元に戻す)
		float4 PPos2 = mul(wpos, matVP );
		float2 texCoord = (-PPos2.xy / PPos2.w) * (0.5 * FrameScale) + 0.5 + ViewportOffset;

		float3 col = Degamma(tex2Dlod(WorkingFloorView, float4(texCoord,0,0)).rgb);
		MirrorColor += col;
		// MirrorColorMax = max(MirrorColorMax, col);
	}

	MirrorColor /= NUM_LOOP;
	// MirrorColor = (MirrorColor + MirrorColorMax) * 0.5;

	return float4(MirrorColor, saturate(roughnessScale * 0.8 + 0.2));
}


//-----------------------------------------------------------------------------
//
float4 PS_Blur( float2 TexCoord: TEXCOORD0, uniform bool isXBlur, uniform sampler Samp) : COLOR
{
	float2 Offset = (isXBlur) ? float2(SampStep.x, 0) : float2(0, SampStep.y);

	float4 Color;
	float4 Color0 = tex2D( Samp, TexCoord );

	Color  = WT_0 * Color0;
	Color += WT_1 * ( tex2D( Samp, TexCoord+Offset  ) + tex2D( Samp, TexCoord-Offset  ) );
	Color += WT_2 * ( tex2D( Samp, TexCoord+Offset*2) + tex2D( Samp, TexCoord-Offset*2) );
	Color += WT_3 * ( tex2D( Samp, TexCoord+Offset*3) + tex2D( Samp, TexCoord-Offset*3) );
	Color += WT_4 * ( tex2D( Samp, TexCoord+Offset*4) + tex2D( Samp, TexCoord-Offset*4) );
	Color += WT_5 * ( tex2D( Samp, TexCoord+Offset*5) + tex2D( Samp, TexCoord-Offset*5) );
	Color += WT_6 * ( tex2D( Samp, TexCoord+Offset*6) + tex2D( Samp, TexCoord-Offset*6) );
	Color += WT_7 * ( tex2D( Samp, TexCoord+Offset*7) + tex2D( Samp, TexCoord-Offset*7) );

	return float4(lerp(Color0.rgb, Color.rgb, Color0.a), Color0.a);
}

//-----------------------------------------------------------------------------
// 最後に元画面と計算結果を合成する
float4 PS_Last( VS_OUTPUT IN ) : COLOR
{
	float4 Mirror = tex2D(ReflectionMapSamp, IN.TexCoord ).rgba;
	float4 dist = tex2D( FloorHeightSamp, IN.TexCoord );

	#if defined(MaterialTextureName)
	float2 wpos = dist.xz;
	float2 uv = GetUV(wpos);
	float3 matColor = Degamma(tex2D(MaterialSamp, uv).rgb);
	Mirror.rgb *= matColor.rgb;
	#endif

	Mirror.rgb *= ReflectionColor;

	#if defined(ENABLE_POSTPROCESS) && ENABLE_POSTPROCESS > 0
	float4 Color = Degamma4(tex2D( ScnSamp, IN.TexCoord ));
	float darken = saturate(1.0 - FloorDarkenRate);
	Color.rgb = lerp(Color.rgb, Color.rgb * darken + Mirror.rgb, AcsTr * dist.a);
	Color.rgb = Gamma(Color.rgb);
	#else
	float4 Color = float4(Gamma(Mirror.rgb * AcsTr * dist.a), 1);
	#endif

	return Color;

}
////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
	string Script = 
		"RenderDepthStencilTarget=DepthBuffer;"

#if defined(ENABLE_POSTPROCESS) && ENABLE_POSTPROCESS > 0
		"RenderColorTarget0=ScnMap;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
#endif

		"RenderColorTarget0=ReflectionMap;"
		"Pass=Reflection;"
#if defined(USE_BLUR) && USE_BLUR > 0
		"RenderColorTarget0=ReflectionMapBlur;"
		"Pass=BlurXPass;"

		"RenderColorTarget0=ReflectionMap;"
		"Pass=BlurYPass;"
#endif
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=LastPass;"
	;
> {
	pass Reflection < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Reflection();
	}

	pass BlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(true, ReflectionMapSamp);
	}

	pass BlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Blur(false, ReflectionMapBlurSamp);
	}

	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = true;
		AlphaTestEnable = true;
		ZWriteEnable = false;

#if defined(ENABLE_POSTPROCESS) && ENABLE_POSTPROCESS > 0
#else
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
#endif
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Last();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
