////////////////////////////////////////////////////////////////////////////////////////////////
// PBR風シェーダー
////////////////////////////////////////////////////////////////////////////////////////////////

#include "ikPolishShader.fxsub"

// 設定は、ikPolishShader.fxsub に集約しました。


//****************** 以下は弄らないほうがいい項目

// 出力形式
#if defined(ENABLE_HDR) && ENABLE_HDR > 0
#define OutputTexFormat		"A16B16G16R16F"
#else
#define OutputTexFormat		"A8R8G8B8"
#endif

// 環境マップのテクスチャ形式
#define EnvTexFormat		"A8R8G8B8"
//#define EnvTexFormat		"A16B16G16R16F"

// 映り込み計算用 (RGB+ボカし係数/陰影)
//#define ReflectionTexFormat		"A8R8G8B8"
#define ReflectionTexFormat		"A16B16G16R16F"

// シャドウマップの結果を格納 (陰影+厚み)
#define ShadowMapTexFormat		"G16R16F"


#define AntiAliasMode		false
#define MipMapLevel			1

// レンダリングターゲットのクリア値
const float4 BackColor = float4(0,0,0,0);
const float ClearDepth  = 1.0;

// テスト用
//#define DISP_AMBIENT

////////////////////////////////////////////////////////////////////////////////////////////////

// float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
// float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;


// ワークテクスチャの縮小度 (1,2 または 4)
// 2なら画面の1/2の解像度。大きい値ほど画質が劣化する代わりに省メモリ・高速化になる
#define WORKSPACE_RES		1

#define COLORMAP_SCALE		(1.0)
#define WORKSPACE_SCALE		(1.0 / WORKSPACE_RES)

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 ViewportOffset2 = (float2(0.5,0.5)/(ViewportSize * WORKSPACE_SCALE));
static float2 ViewportAspect = float2(1, ViewportSize.x/ViewportSize.y);
static float2 SampStep = (float2(1.0,1.0) / (ViewportSize * WORKSPACE_SCALE));

float4x4 matV			: VIEW;
float4x4 matP			: PROJECTION;
float4x4 matVP			: VIEWPROJECTION;
float4x4 matInvVP		: VIEWPROJECTIONINVERSE;

float3 LightSpecular	: SPECULAR  < string Object = "Light"; >;
float3 LightDirection	: DIRECTION < string Object = "Light"; >;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;
//float3 CameraDirection	: DIRECTION < string Object = "Camera"; >;

float time : TIME;

float mDirectLightP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光+"; >;
float mDirectLightM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "直接光-"; >;
float mIndirectLightP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "間接光+"; >;
float mIndirectLightM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "間接光-"; >;
float mSSAOP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "SSAO+"; >;
float mSSAOM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "SSAO-"; >;
float mSSAOBias : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "SSAOバイアス"; >;
float mReflectionP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "映り込み+"; >;
float mReflectionM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "映り込み-"; >;
float mExposureP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "露光+"; >;
float mExposureM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "露光-"; >;

static float LightScale = CalcLightValue(mDirectLightP, mDirectLightM, DefaultLightScale);
static float AmbientScale = CalcLightValue(mIndirectLightP, mIndirectLightM, DefaultAmbientScale);
static float AmbientPower = CalcLightValue(mSSAOP, mSSAOM, DefaultAmbientPower);
static float ReflectionScale = CalcLightValue(mReflectionP, mReflectionM, DefaultReflectionScale);
static float ExposureScale = (CalcLightValue(mExposureP, mExposureM, DefaultExposureScale) - 1.0) * 0.5 + 1.0;
	// log2(1.0 + val) で0～1～1.6

#if defined(SSSBlurCount) && SSSBlurCount > 0
float mSSSP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "SSS+"; >;
float mSSSM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "SSS-"; >;
static float SSSScale = CalcLightValue(mSSSP, mSSSM, DefaultSSSScale);
#endif

#if defined(ENABLE_SSGI) && ENABLE_SSGI > 0
float mGIP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "GI+"; >;
float mGIM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "GI-"; >;
static float GIScale = CalcLightValue(mGIP, mGIM, DefaultGIScale);
#endif

static float3 LightColor = LightSpecular * LightScale;
// sampler DefSampler : register(s0);

#define	PI	(3.14159265359)

// ぼかし処理の重み係数：
//	ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//	(WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
static const float BlurWeight[] = {
	0.0920246,
	0.0902024,
	0.0849494,
	0.0768654,
	0.0668236,
	0.0558158,
	0.0447932,
	0.0345379,
};


////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャ

// スクリーン
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	bool AntiAlias = false;
	string Format = OutputTexFormat;
>;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

// ベースカラーマップ
texture ColorMapRT: OFFSCREENRENDERTARGET <
	float2 ViewPortRatio = {COLORMAP_SCALE, COLORMAP_SCALE};
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "A8R8G8B8" ;	// 陰影計算なしの色。リフレクタンスの元データとして使用。
	int Miplevels = MipMapLevel;
	bool AntiAlias = AntiAliasMode;
	string Description = "MaterialMap for ikPolishShader";
	string DefaultEffect = 
		"self = hide;"
		CONTROLLER_NAME " = hide;"
		"*.pmd = ./Materials/MaterialMap.fx;"
		"*.pmx = ./Materials/MaterialMap.fx;"
		"*.x = ./Materials/MaterialMap.fx;"
		"* = hide;";
>;
sampler ColorMap = sampler_state {
	texture = <ColorMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// 材質マップ
shared texture PPPMaterialMapRT: RENDERCOLORTARGET <
	float2 ViewPortRatio = {COLORMAP_SCALE, COLORMAP_SCALE};
	string Format = "A8R8G8B8" ;		// メタルネス、スムースネス、インテンシティ。SSS。
	int Miplevels = 1;
	bool AntiAlias = AntiAliasMode;
	float4 ClearColor = { 0.0, 0.0, 0.0, 0.0};
>;
sampler MaterialMap = sampler_state {
	texture = <PPPMaterialMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// 法線マップ
shared texture PPPNormalMapRT: RENDERCOLORTARGET <
	float2 ViewPortRatio = {COLORMAP_SCALE, COLORMAP_SCALE};

	#if SSAO_QUALITY >= 3
		string Format = "A32B32G32R32F";		// RGBに法線。Aには深度情報
	#else
	string Format = "A16B16G16R16F";		// RGBに法線。Aには深度情報
	#endif
	float4 ClearColor = { 0, 0, 0, 1 };
	int Miplevels = 1;
	bool AntiAlias = AntiAliasMode;
>;
sampler NormalSamp = sampler_state {
	texture = <PPPNormalMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


// アンビエントと映り込みを格納する。
shared texture2D PPPReflectionMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ReflectionTexFormat;
>;
sampler ReflectionMapSamp = sampler_state {
	texture = <PPPReflectionMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// ワーク
texture2D ReflectionWorkMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ReflectionTexFormat;
>;
sampler ReflectionWorkMapSamp = sampler_state {
	texture = <ReflectionWorkMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
sampler ReflectionWorkMapSampPoint = sampler_state {
	texture = <ReflectionWorkMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

// シャドウマップの計算結果格納用
texture2D ShadowmapMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ShadowMapTexFormat;
>;
sampler ShadowmapSamp = sampler_state {
	texture = <ShadowmapMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// SSDOの計算と結果格納用 (SSDO.rgb + 遮蔽度)
texture2D SSAOWorkMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ReflectionTexFormat;
>;
sampler SSAOWorkMapSamp = sampler_state {
	texture = <SSAOWorkMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 

#include "Sources/commons.fxsub"

#include "Environments/environmentmap.fxsub"
#include "Shadows/shadowmap.fxsub"
#include "Sources/diffusion.fxsub"
#include "Sources/ssao.fxsub"
#include "RSM/rsm.fxsub"

// 拡散反射の計算
#include "Sources/indirectlight.fxsub"

// 鏡面反射の計算
#include "Sources/reflection.fxsub"

// 合成
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
	float3 BaseColor = Degamma(tex2D( ScnSamp, Tex ).rgb);
	float4 RefColor = tex2D(ReflectionMapSamp, Tex );

	#if defined(DISP_AMBIENT)
	return float4(RefColor.rgb, 1);
	#endif

	//-------------------------------------------------
	// 間接スペキュラ
	float3 WPos, N;
	float Depth;
	GetWND(Tex, WPos, N, Depth);
	float3 V = normalize(CameraPosition - WPos);
	float3 mat = tex2D( MaterialMap, Tex).xyz;
	float smoothness = mat.y;
	float3 f0 = tex2D( ColorMap, Tex).rgb;
	RefColor.rgb *= CalcReflectance(mat, N, V, f0);
	RefColor.rgb += CalcMultiLightSpecular(WPos, N, V, smoothness, f0);
	RefColor.rgb *= lerp(GetSSAO(Tex), 1, smoothness);
	//-------------------------------------------------

	// return float4(GetSSAO(Tex).xxx, 1);
	// return float4(tex2D( MaterialMap, Tex ).xyz, 1);
	// return float4(RefColor.rgb, 1);
	// return float4(RefColor.www, 1);
	// return float4(tex2D(ShadowmapSamp, Tex ).xxx, 1);
	// return float4(tex2D(SSGISamp, Tex ).rgb, 1);
	// return float4(normalize(tex2Dlod( NormalSamp, float4(Tex,0,0)).xyz) * 0.5 + 0.5, 1);
	// ambientOccu = 0;
	RefColor.rgb *= ReflectionScale;
	float3 Color = BaseColor + RefColor.rgb;
	Color.rgb *= ExposureScale;

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	// アンチエイリアス後にガンマ補正を掛ける。
	return float4(Color.rgb, 1);
	#else
	return float4(Gamma(Color.rgb), 1);
	#endif
}

// アンチエイリアス
#include "Sources/antialias.fxsub"


////////////////////////////////////////////////////////////////////////////////////////////////

#define BufferRenderStates	\
		AlphaBlendEnable = false;	AlphaTestEnable = false; \
//		ZEnable = false;	ZWriteEnable = false;	ZFunc = ALWAYS;

technique PolishShader <
	string Script = 
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=BackColor;"
		"ClearSetDepth=ClearDepth;"

		// 環境マップの生成
		#if !defined(USE_STATIC_ENV)
		"RenderDepthStencilTarget=EnvDepthBuffer;"
		"RenderColorTarget0=EnvMap2;	Clear=Color;	Pass=SynthEnvPass;"
		"RenderDepthStencilTarget=DepthBuffer;"
		#endif

		// シャドウマップのブラー
		"RenderColorTarget0=ReflectionWorkMap;	Pass=ShadowBlurPassX;"
		"RenderColorTarget0=ShadowmapMap;		Pass=ShadowBlurPassY;"

		// SSDOの計算
		#if SSAORayCount > 0
		"RenderColorTarget0=SSAOWorkMap;"
		"Clear=Color;"
		"Pass=SSAOPass;"
		"RenderColorTarget0=ReflectionWorkMap;	Pass=BlurXSSAOPass;"
		"RenderColorTarget0=SSAOWorkMap;		Pass=BlurYSSAOPass;"
		#endif

		// 直接光の床・壁での反射
		#if defined(RSMCount) && RSMCount > 0
		"RenderColorTarget0=RSMWorkMap;			Pass=CalcRSMPass;"
		"RenderColorTarget0=ReflectionWorkMap;	Pass=RSMBlurXPass;"
		"RenderColorTarget0=RSMWorkMap;			Pass=RSMBlurYPass;"
		#endif

		// デフューズの計算
		"RenderColorTarget0=PPPReflectionMap;	Pass=SSAOEnvPass;"
		#if SSSBlurCount > 0
		"RenderColorTarget0=ReflectionWorkMap;	Pass=SSSBlurXPass;"
		"RenderColorTarget0=PPPReflectionMap;	Pass=SSSBlurYPass;"
		#endif

		// 通常のモデル描画
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		// RLRの計算
		#if !defined(DISP_AMBIENT)
		#if RLRRayCount > 0
		"RenderColorTarget0=ReflectionWorkMap;	Pass=RLRPass;"
		"RenderColorTarget0=PPPReflectionMap;	Pass=RLRPass2;"
		"RenderColorTarget0=ReflectionWorkMap;	Pass=RLRBlurXPass;"
		"RenderColorTarget0=PPPReflectionMap;	Pass=RLRBlurYPass;"
		#else
		"RenderColorTarget0=PPPReflectionMap;	Pass=WriteEnvPass;"
		#endif
		#endif

		#if defined(ENABLE_AA) && ENABLE_AA > 0
		// 合成
		"RenderColorTarget0=" RENDERTARGET_ANTIALIAS_STRING ";"
		"Pass=DrawPass;"

		// アンチエイリアス
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=AntialiasPass;"
		#else
		// 合成
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawPass;"
		#endif
	;
> {
	#if !defined(USE_STATIC_ENV)
	pass SynthEnvPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_SynthEnv();
	}
	#endif

	/////////////////////////////////////////////////////////////////
	// Shadow map

	pass ShadowBlurPassX < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurShadow(ShadowSamp, true, true);
	}
	pass ShadowBlurPassY < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurShadow(ReflectionWorkMapSamp, false, false);
	}

	/////////////////////////////////////////////////////////////////
	// 

	#if SSAORayCount > 0
	pass SSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_SSAO();
	}

	pass BlurXSSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSAO(true, SSAOWorkMapSamp);
	}
	pass BlurYSSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSAO(false, ReflectionWorkMapSamp);
	}
	#endif

	#if defined(RSMCount) && RSMCount > 0
	pass CalcRSMPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_CalcRSM();
	}
	pass RSMBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSAO(true, RSMWorkLinear);
	}
	pass RSMBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSAO(false, ReflectionWorkMapSamp);
	}
	#endif

	pass SSAOEnvPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_SSAOEnv();
	}
	#if SSSBlurCount > 0
	pass SSSBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSS1(ReflectionMapSamp);
	}
	pass SSSBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurSSS2(ReflectionWorkMapSamp);
	}
	#endif

	/////////////////////////////////////////////////////////////////
	// 

	#if RLRRayCount > 0
	pass RLRPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_RLR();
	}
	pass RLRPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_RLR2();
	}
	pass RLRBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurRLR(true, ReflectionMapSamp);
	}
	pass RLRBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_BlurRLR(false, ReflectionWorkMapSamp);
	}
	#else
	pass WriteEnvPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_WriteEnvAsReflection();
	}
	#endif

	/////////////////////////////////////////////////////////////////
	// 

	pass DrawPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_Draw();
	}

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	pass AntialiasPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Common();
		PixelShader  = compile ps_3_0 PS_Antialias(RENDERTARGET_ANTIALIAS_SAMPLER);
	}
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////
