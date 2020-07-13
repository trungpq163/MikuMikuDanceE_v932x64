//-----------------------------------------------------------------------------
// PBR風シェーダー
//-----------------------------------------------------------------------------

#include "ikPolishShader.fxsub"

#include "Sources/structs.fxsub"
#include "Sources/colorutil.fxsub"


// オフスクリーンレンダリングで無視する対象：
#define HIDE_EFFECT	\
	"self = hide;" \
	CONTROLLER_NAME " = hide;" \
	"PPointLight*.* = hide;"

// テスト用
//#define DISP_AMBIENT


//****************** 以下は弄らないほうがいい項目

// 出力形式
#define OutputTexFormat		"A16B16G16R16F"

// 環境マップのテクスチャ形式
#define EnvTexFormat		"A16B16G16R16F"

// 映り込み計算用 (RGB+ボカし係数/陰影)
#define ReflectionTexFormat		"A16B16G16R16F"

// シャドウマップの結果を格納 (陰影+厚み)
#define ShadowMapTexFormat		"G16R16F"


//-----------------------------------------------------------------------------

// レンダリングターゲットのクリア値
const float4 BackColor = float4(0,0,0,0);
const float4 ShadowBackColor = float4(0,0,0,0);
const float ClearDepth = 1.0;
const int ClearStencil = 0;

// float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
// float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#if defined(WORKSPACE_RES)
#undef WORKSPACE_RES
#endif
#define WORKSPACE_RES	2

#define COLORMAP_SCALE		(1.0)
#define WORKSPACE_SCALE		(1.0 / WORKSPACE_RES)

#define	PI		(3.14159265359)
#define LOG2_E	(1.44269504089)		// log(e)/log(2)

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
static float ExposureBias = exp2((mExposureP * 0.5 - mExposureM) * DefaultExposureScale);

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

//-----------------------------------------------------------------------------
// 
#include "Sources/textures.fxsub"
#include "Sources/commons.fxsub"
#include "Sources/environmentmap.fxsub"
#include "Sources/rsm.fxsub"
#include "Sources/ssao.fxsub"
#include "Sources/shadowmap.fxsub"
#include "Sources/indirectlight.fxsub"
#include "Sources/sss.fxsub"
#include "Sources/reflection.fxsub"
#include "Sources/antialias.fxsub"


//-----------------------------------------------------------------------------
// 合成
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
	float3 BaseColor = GetScreenPixel(Tex);
	float3 RefColor = tex2D(ReflectionMapSamp, Tex).rgb;

	// for debug
	#if defined(DISP_AMBIENT)
	return float4(RefColor, 1);
	#endif

	// return tex2D(EnvMapWorkSamp, Tex);
	// return tex2D(EnvMapSamp, Tex);
	// return tex2D(EnvMapSamp0, Tex);
	// return float4(tex2D(RSMAlbedoSamp, Tex ).rgb, 1);
	// return float4(GetSSAO(Tex).xxx, 1);
	// return float4(GetSSAOFull(Tex).rgb,1);
	// return float4(tex2D( MaterialMap, Tex ).xyz, 1);
	// return float4(RefColor.rgb, 1);
	// return float4(RefColor.www, 1);
	// return float4(tex2D(ShadowmapSamp, Tex ).xxx, 1);
	// return float4(tex2D(SSDOSamp, Tex ).rgb, 1);
	// return float4(normalize(tex2Dlod( NormalSamp, float4(Tex,0,0)).xyz) * 0.5 + 0.5, 1);

	float3 Color = BaseColor + RefColor;

	Color.rgb *= ExposureBias;

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	// アンチエイリアスが有効な場合は、AA後にカラーコレクトを行う。
	#else
	Color.rgb = ColorCorrectToOutput(Color.rgb);
	#endif

	return float4(Color.rgb, 1);
}


//-----------------------------------------------------------------------------
// ステンシルバッファの作成

float4 PS_DrawStencilSky( float2 texCoord: TEXCOORD0 ) : COLOR0
{
	MaterialParam material = GetMaterial(texCoord);
	clip(epsilon - material.intensity);
	return float4(0,0,0,1);
}

float4 PS_DrawStencilSkin( float2 texCoord: TEXCOORD0 ) : COLOR0
{
	MaterialParam material = GetMaterial(texCoord);
	clip(material.sssValue - epsilon);
	return float4(0,0,0,1);
}


//-----------------------------------------------------------------------------

#define BufferRenderStates	\
		AlphaBlendEnable = false;	AlphaTestEnable = false; \
		ZEnable = false;	ZWriteEnable = false;

#define STENCIL_BIT_SKY		1
#define STENCIL_BIT_SKIN	2
#define STENCIL_BIT_METAL	4

#define	StencilSet(n)	\
		StencilEnable = true;	\
		StencilFunc = ALWAYS;	StencilRef = n;	\
		StencilPass = REPLACE;	StencilFail = REPLACE;	\

#define	StencilTestAll(n)	\
		StencilEnable = true;	\
		StencilFunc = EQUAL;	StencilRef = n;	StencilMask = n; \
		StencilPass = KEEP; StencilFail = KEEP; \

#define	StencilTestAny(n)	\
		StencilEnable = true;	\
		StencilFunc = NOTEQUAL;	StencilRef = 0;	StencilMask = n; \
		StencilPass = KEEP; StencilFail = KEEP; \

#define	StencilTestNot(n)	\
		StencilEnable = true;	\
		StencilFunc = EQUAL;	StencilRef = 0;	StencilMask = n;	\
		StencilPass = KEEP; StencilFail = KEEP; \


technique PolishShader <
string Script = 
	"ClearSetColor=BackColor;"
	"ClearSetDepth=ClearDepth;"
	"ClearSetStencil=ClearStencil;"

	// 環境マップの生成
	"RenderDepthStencilTarget=EnvDepthBuffer;"
	"RenderColorTarget0=EnvMap2;	Pass=SynthEnvPass;"
	#if ENV_MIPMAP > 0
	"RenderColorTarget0=EnvMap3;	Pass=EnvMipmapPass;"
	#endif

	// ステンシルバッファの生成
	"RenderColorTarget0=FullWorkMap;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Depth; Clear=Stencil;"
	"Pass=DrawStencilSkyPass;"
	"Pass=DrawStencilSkinPass;"

	// シャドウマップ
	"RenderColorTarget0=SSAOWorkMap;	Pass=ShadowMapPass;"
	"RenderColorTarget0=FullWorkMap;	Pass=ShadowBlurPassX;"
	"RenderColorTarget0=ShadowmapMap;	Pass=ShadowBlurPassY;"

	// SSDOの計算
	#if SSAORayCount > 0
	// 直接光の床・壁での反射
	#if defined(RSMCount) && RSMCount > 0
	"RenderColorTarget0=HalfWorkMap2;	Pass=CalcRSMPass;"
	#endif

	"RenderColorTarget0=HalfWorkMap;	Pass=SSAOPass;"
	"RenderColorTarget0=HalfWorkMap2;	Pass=HalfBlurXPass;"
	"RenderColorTarget0=HalfWorkMap;	Pass=HalfBlurYPass;"
	"RenderColorTarget0=SSAOWorkMap;	Pass=UpscalePass;"
	#endif

	// デフューズの計算
	"RenderColorTarget0=PPPReflectionMap;	Clear=Color;	Pass=CalcDiffusePass;"
	// 皮下散乱の計算
	#if SSSBlurCount > 0
	"RenderColorTarget0=FullWorkMap;		Clear=Color;	Pass=SSSBlurXPass;"
	"RenderColorTarget0=PPPReflectionMap;	Pass=SSSBlurYPass;"
	#endif

	// 通常のモデル描画
	"RenderColorTarget0=ScnMap;"
	"RenderDepthStencilTarget=;"
	"Clear=Color; Clear=Depth;"
	"ScriptExternal=Color;"
	// ステンシルバッファを残すためにデプスバッファを切り替えている
	"RenderDepthStencilTarget=DepthBuffer;"

	// RLRの計算
	#if !defined(DISP_AMBIENT)
	#if RLRRayCount > 0
	"RenderColorTarget0=HalfWorkMap;		Clear=Color;	Pass=RLRPass;"
	"RenderColorTarget0=FullWorkMap;		Clear=Color;	Pass=RLRPass2;"
	"RenderColorTarget0=PPPReflectionMap;	Clear=Color;	Pass=RLRBlurXPass;"
	"RenderColorTarget0=FullWorkMap;						Pass=RLRBlurYPass;"
	"RenderColorTarget0=PPPReflectionMap;					Pass=CalcSpecularPass;"
	#else
	"RenderColorTarget0=PPPReflectionMap;	Clear=Color;	Pass=CalcSpecularPass;"
	#endif
	#endif

	#if defined(ENABLE_AA) && ENABLE_AA > 0
	// 合成
	"RenderColorTarget0=FullWorkMap;"
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
;> {
	//-------------------------------------------------
	// 環境マップ
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
	// Stencil Mask
	pass DrawStencilSkyPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		ColorWriteEnable = false;
		StencilSet(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_DrawStencilSky();
	}

	pass DrawStencilSkinPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		ColorWriteEnable = false;
		StencilSet(STENCIL_BIT_SKIN)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_DrawStencilSkin();
	}

	//-------------------------------------------------
	// Shadow Map
	pass ShadowMapPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Shadowmap();
		PixelShader  = compile ps_3_0 PS_Shadowmap();
	}
	pass ShadowBlurPassX < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_BlurShadow(true);
		PixelShader  = compile ps_3_0 PS_BlurShadow(SSAOWorkSamp);
	}
	pass ShadowBlurPassY < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_BlurShadow(false);
		PixelShader  = compile ps_3_0 PS_BlurShadow(FullWorkSamp);
	}

	//-------------------------------------------------
	// SSAO + RSM
	#if SSAORayCount > 0
	#if defined(RSMCount) && RSMCount > 0
	pass CalcRSMPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_CalcRSM();
		PixelShader  = compile ps_3_0 PS_CalcRSM();
	}
	#endif

	pass SSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_SSAO();
		PixelShader  = compile ps_3_0 PS_SSAO();
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

	pass UpscalePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_Upscale(HalfWorkSamp);
	}
	#endif

	pass CalcDiffusePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_CalcDiffuse();
	}

	#if SSSBlurCount > 0
	pass SSSBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestAll(STENCIL_BIT_SKIN)
		VertexShader = compile vs_3_0 VS_SSS();
		PixelShader  = compile ps_3_0 PS_SSS(ReflectionMapSamp);
	}
	pass SSSBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestAll(STENCIL_BIT_SKIN)
		VertexShader = compile vs_3_0 VS_BlurSSS();
		PixelShader  = compile ps_3_0 PS_BlurSSS(FullWorkSamp);
	}
	#endif

	//-------------------------------------------------
	// 
	#if RLRRayCount > 0
	pass RLRPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_RLR();
		PixelShader  = compile ps_3_0 PS_RLR();
	}
	pass RLRPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_RLR2();
		PixelShader  = compile ps_3_0 PS_RLR2();
	}
	pass RLRBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_BlurRLR(true);
		PixelShader  = compile ps_3_0 PS_BlurRLR(FullWorkSamp);
	}
	pass RLRBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_BlurRLR(false);
		PixelShader  = compile ps_3_0 PS_BlurRLR(ReflectionMapSamp);
	}
	#endif
	pass CalcSpecularPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_CalcSpecular();
	}

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
		VertexShader = compile vs_3_0 VS_Antialias();
		PixelShader  = compile ps_3_0 PS_Antialias(AntialiasWorkSamp);
	}
	#endif
}

//-----------------------------------------------------------------------------
