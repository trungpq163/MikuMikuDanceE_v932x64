//-----------------------------------------------------------------------------
// PBR風シェーダー
//-----------------------------------------------------------------------------

#include "ikPolishShader.fxsub"

#include "Sources/structs.fxsub"
#include "Sources/colorutil.fxsub"


//****************** 以下は弄らないほうがいい項目

// 出力形式
#define OutputTexFormat		"A16B16G16R16F"
//#define OutputTexFormat		"A8R8G8B8"

// 環境マップのテクスチャ形式
//#define EnvTexFormat		"A8R8G8B8"
#define EnvTexFormat		"A16B16G16R16F"

// 映り込み計算用 (RGB+ボカし係数/陰影)
#define ReflectionTexFormat		"A16B16G16R16F"

// シャドウマップの結果を格納 (陰影+厚み)
#define ShadowMapTexFormat		"G16R16F"

#define AntiAliasMode		false
#define MipMapLevel			1

// レンダリングターゲットのクリア値
const float4 BackColor = float4(0,0,0,0);
const float ClearDepth  = 1.0;

// オフスクリーンレンダリングで無視する対象：
#define HIDE_EFFECT	\
	"self = hide;" \
	CONTROLLER_NAME " = hide;" \
	"PPointLight*.* = hide;"

// テスト用
//#define DISP_AMBIENT

//-----------------------------------------------------------------------------

// float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
// float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define COLORMAP_SCALE		(1.0)
#define WORKSPACE_SCALE		(1.0 / WORKSPACE_RES)

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 WorkSize = floor(ViewportSize * WORKSPACE_SCALE);
static float2 ViewportOffset = float2(0.5,0.5) / ViewportSize;
static float2 ViewportOffset2 = float2(0.5,0.5) / WorkSize;
static float2 ViewportWorkScale = ViewportSize / WorkSize;
static float2 ViewportAspect = float2(1, ViewportSize.x/ViewportSize.y);
static float2 SampStep = float2(1.0,1.0) / ViewportSize;

float4x4 matV			: VIEW;
float4x4 matP			: PROJECTION;
float4x4 matVP			: VIEWPROJECTION;
float4x4 matInvV		: VIEWINVERSE;
float4x4 matInvP		: PROJECTIONINVERSE;
float4x4 matInvVP		: VIEWPROJECTIONINVERSE;

float3 LightSpecular	: SPECULAR  < string Object = "Light"; >;
float3 LightDirection	: DIRECTION < string Object = "Light"; >;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;
float3 CameraDirection	: DIRECTION < string Object = "Camera"; >;

float time : TIME;

bool mExistPolish : CONTROLOBJECT < string name = CONTROLLER_NAME; >;
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
float mSoftShadow : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "シャドウ"; >;

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

#if (defined(ENABLE_SSDO) && ENABLE_SSDO > 0) || SSAORayCount > 0
float mGIP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "GI+"; >;
float mGIM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "GI-"; >;
static float GIScale = CalcLightValue(mGIP, mGIM, DefaultGIScale);
#endif


static float3 LightColor = LightSpecular * LightScale;

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


//-----------------------------------------------------------------------------
// テクスチャ

// スクリーン
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
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

// ベースカラーマップ(スペキュラ色として使う)
texture ColorMapRT: OFFSCREENRENDERTARGET <
	float2 ViewPortRatio = {COLORMAP_SCALE, COLORMAP_SCALE};
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "A8R8G8B8" ;	// 陰影計算なしの色。リフレクタンスの元データとして使用。
	int Miplevels = MipMapLevel;
	bool AntiAlias = AntiAliasMode;
	string Description = "MaterialMap for ikPolishShader";
	string DefaultEffect = 
		HIDE_EFFECT
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
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

// アルベドマップ
shared texture PPPAlbedoMapRT: RENDERCOLORTARGET <
	float2 ViewPortRatio = {COLORMAP_SCALE, COLORMAP_SCALE};
	string Format = "A8R8G8B8" ;
	int Miplevels = 1;
	bool AntiAlias = AntiAliasMode;
	float4 ClearColor = { 0.0, 0.0, 0.0, 0.0};
>;
sampler AlbedoSamp = sampler_state {
	texture = <PPPAlbedoMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};


// アンビエントと映り込みを格納する。
shared texture2D PPPReflectionMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1, 1};
	string Format = ReflectionTexFormat;
>;
sampler ReflectionMapSamp = sampler_state {
	texture = <PPPReflectionMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

// ワーク
texture2D FullWorkMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1, 1};
	string Format = ReflectionTexFormat;
>;
sampler FullWorkSamp = sampler_state {
	texture = <FullWorkMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
sampler FullWorkSampPoint = sampler_state {
	texture = <FullWorkMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

#if WORKSPACE_RES != 1
// 縮小バッファ
texture2D HalfWorkMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ReflectionTexFormat;
>;
sampler HalfWorkSamp = sampler_state {
	texture = <HalfWorkMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
texture2D HalfWorkMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {WORKSPACE_SCALE, WORKSPACE_SCALE};
	string Format = ReflectionTexFormat;
>;
sampler HalfWorkSamp2 = sampler_state {
	texture = <HalfWorkMap2>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
#endif


// シャドウマップの計算結果格納用
texture2D ShadowmapMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1, 1};
	string Format = ShadowMapTexFormat;
>;
sampler ShadowmapSamp = sampler_state {
	texture = <ShadowmapMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

// SSDOの計算と結果格納用 (SSDO.rgb + 遮蔽度)
texture2D SSAOWorkMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1, 1};
	string Format = ReflectionTexFormat;
>;
sampler SSAOWorkSamp = sampler_state {
	texture = <SSAOWorkMap>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};


//-----------------------------------------------------------------------------
// 

#include "Sources/commons.fxsub"

#include "Environments/environmentmap.fxsub"
#include "Sources/rsm.fxsub"
#include "Sources/ssao.fxsub"
#include "Shadows/shadowmap.fxsub"
#include "Sources/indirectlight.fxsub"
#include "Sources/sss.fxsub"
#include "Sources/reflection.fxsub"
#include "Sources/antialias.fxsub"


// 合成
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
	float3 BaseColor = ColorCorrectFromInput(tex2D(ScnSamp, Tex).rgb);

	// for debug
	#if defined(DISP_AMBIENT)
	return float4(tex2D(ReflectionMapSamp, Tex ).rgb, 1);
	#endif

	//-------------------------------------------------
	// gather indirect specular
	GeometryInfo geom = GetWND(Tex);
	MaterialParam material = GetMaterial(Tex);
	float3 RefColor = tex2D(ReflectionMapSamp, Tex + ViewportOffset).rgb;
	float3 V = normalize(CameraPosition - geom.wpos);
	float3 N = geom.nd.normal;
	float3 f0 = tex2D( ColorMap, Tex).rgb;
	float ao = lerp(GetSSAO(Tex), 1, material.smoothness);
	RefColor.rgb *= CalcReflectance(material, N, V, f0);
	RefColor.rgb += CalcMultiLightSpecular(geom.wpos, N, V, material.smoothness, f0);
	RefColor.rgb *= ao * ReflectionScale;
	//-------------------------------------------------

	// return tex2D(EnvMapSamp, Tex);
	// return tex2D(EnvMapSamp0, Tex);
	// return float4(tex2D(RSMAlbedoSamp, Tex ).rgb, 1);
	// return float4(GetSSAO(Tex).xxx, 1);
	// return float4(tex2D( MaterialMap, Tex ).xyz, 1);
	// return float4(RefColor.rgb, 1);
	// return float4(RefColor.www, 1);
	// return float4(tex2D(ShadowmapSamp, Tex ).xxx, 1);
	// return float4(tex2D(SSDOSamp, Tex ).rgb, 1);
	// return float4(normalize(tex2Dlod( NormalSamp, float4(Tex,0,0)).xyz) * 0.5 + 0.5, 1);

	float3 Color = BaseColor + RefColor.rgb;

	Color.rgb *= ExposureScale;

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	// アンチエイリアスが有効な場合は、AA後にカラーコレクトを行う。
	#else
	Color.rgb = ColorCorrectToOutput(Color.rgb);
	#endif

	return float4(Color.rgb, 1);
}



//-----------------------------------------------------------------------------

#define BufferRenderStates	\
		AlphaBlendEnable = false;	AlphaTestEnable = false; \
//		ZEnable = false;	ZWriteEnable = false;	ZFunc = ALWAYS;

technique PolishShader <
	string Script = 
		"ClearSetColor=BackColor;"
		"ClearSetDepth=ClearDepth;"

		// 環境マップの生成
		"RenderDepthStencilTarget=EnvDepthBuffer;"
		"RenderColorTarget0=EnvMap2;	Pass=SynthEnvPass;"
		#if ENV_MIPMAP > 0
		"RenderColorTarget0=EnvMap3;	Pass=EnvMipmapPass;"
		#endif

		// シャドウマップ
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=SSAOWorkMap;		Pass=ShadowMapPass;"
		"RenderColorTarget0=FullWorkMap;		Pass=ShadowBlurPassX;"
		"RenderColorTarget0=ShadowmapMap;		Pass=ShadowBlurPassY;"

		// 直接光の床・壁での反射
		#if defined(RSMCount) && RSMCount > 0
		#if WORKSPACE_RES != 1
			"RenderColorTarget0=HalfWorkMap2;	Pass=CalcRSMPass;"
		#else
			"RenderColorTarget0=FullWorkMap;	Pass=CalcRSMPass;"
		#endif
		#endif

		// SSDOの計算
		#if SSAORayCount > 0
		#if WORKSPACE_RES != 1
			"RenderColorTarget0=HalfWorkMap;	Pass=SSAOPass;"
			"RenderColorTarget0=HalfWorkMap2;	Pass=HalfBlurXPass;"
			"RenderColorTarget0=HalfWorkMap;	Pass=HalfBlurYPass;"
			"RenderColorTarget0=SSAOWorkMap;	Pass=UpscalePass;"
		#else
			"RenderColorTarget0=SSAOWorkMap;	Pass=SSAOPass;"
			"RenderColorTarget0=FullWorkMap;	Pass=BlurXSSAOPass;"
			"RenderColorTarget0=SSAOWorkMap;	Pass=BlurYSSAOPass;"
		#endif
		#endif

		// デフューズの計算
		"RenderColorTarget0=PPPReflectionMap;	Pass=CalcDiffusePass;"
		// 皮下散乱の計算
		#if SSSBlurCount > 0
		"RenderColorTarget0=FullWorkMap;		Pass=SSSBlurXPass;"
		"RenderColorTarget0=PPPReflectionMap;	Pass=SSSBlurYPass;"
		#endif

		// 通常のモデル描画
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		// RLRの計算
		#if !defined(DISP_AMBIENT)
		#if RLRRayCount > 0
		#if WORKSPACE_RES != 1
			"RenderColorTarget0=HalfWorkMap;	Pass=RLRPass;"
		#else
			"RenderColorTarget0=FullWorkMap;	Pass=RLRPass;"
		#endif
		"RenderColorTarget0=PPPReflectionMap;	Pass=RLRPass2;"
		"RenderColorTarget0=FullWorkMap;		Pass=RLRBlurXPass;"
		"RenderColorTarget0=PPPReflectionMap;	Pass=RLRBlurYPass;"
		#else
		// RLRを使用しない場合は環境マップのみから反射成分を作成する。
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
	pass SynthEnvPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_EnvBuffer();
		PixelShader  = compile ps_3_0 PS_SynthEnv();
	}
	#if ENV_MIPMAP > 0
	pass EnvMipmapPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_EnvBuffer();
		PixelShader  = compile ps_3_0 PS_CreateEnvMipmap();
	}
	#endif

	//-------------------------------------------------
	// Shadow map

	pass ShadowMapPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_Shadowmap();
	}
	pass ShadowBlurPassX < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurShadow(true);
		PixelShader  = compile ps_3_0 PS_BlurShadow(SSAOWorkSamp);
	}
	pass ShadowBlurPassY < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurShadow(false);
		PixelShader  = compile ps_3_0 PS_BlurShadow(FullWorkSamp);
	}

	//-------------------------------------------------
	// 

	#if WORKSPACE_RES != 1
	pass UpscalePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_Upscale(HalfWorkSamp);
	}
	pass HalfBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSAO(true);
		PixelShader  = compile ps_3_0 PS_BlurSSAO(HalfWorkSamp);
	}
	pass HalfBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSAO(false);
		PixelShader  = compile ps_3_0 PS_BlurSSAO(HalfWorkSamp2);
	}
	#endif

	#if defined(RSMCount) && RSMCount > 0
	pass CalcRSMPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_CalcRSM();
	}
	#endif

	#if SSAORayCount > 0
	pass SSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_SSAO();
	}
	#if WORKSPACE_RES == 1
	pass BlurXSSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSAO(true);
		PixelShader  = compile ps_3_0 PS_BlurSSAO(SSAOWorkSamp);
	}
	pass BlurYSSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSAO(false);
		PixelShader  = compile ps_3_0 PS_BlurSSAO(FullWorkSamp);
	}
	#endif
	#endif

	pass CalcDiffusePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_CalcDiffuse();
	}
	#if SSSBlurCount > 0
	pass SSSBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_BlurSSS1(ReflectionMapSamp);
	}
	pass SSSBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_BlurSSS2(FullWorkSamp);
	}
	#endif

	//-------------------------------------------------
	// 

	#if RLRRayCount > 0
	pass RLRPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_RLR();
	}
	pass RLRPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_RLR2();
	}
	pass RLRBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurRLR(true);
		PixelShader  = compile ps_3_0 PS_BlurRLR(true, ReflectionMapSamp);
	}
	pass RLRBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurRLR(false);
		PixelShader  = compile ps_3_0 PS_BlurRLR(false, FullWorkSamp);
	}
	#else
	pass WriteEnvPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_WriteEnvAsReflection();
	}
	#endif

	//-------------------------------------------------
	// 

	pass DrawPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_Draw();
	}

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	pass AntialiasPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_Antialias(RENDERTARGET_ANTIALIAS_SAMPLER);
	}
	#endif
}

//-----------------------------------------------------------------------------
