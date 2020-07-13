//-----------------------------------------------------------------------------
// PBR風シェーダー
//-----------------------------------------------------------------------------

#include "ikPolishShader.fxsub"

#include "Sources/constants.fxsub"
#include "Sources/structs.fxsub"
#include "Sources/colorutil.fxsub"
#include "Sources/mmdparameter.fxsub"


#define HIDE_EFFECT	\
	"self = hide;" \
	CONTROLLER_NAME " = hide;" \
	"GlassTester.pmx =  hide;" \
	"PointLight*.pmx = hide;" \
	"SpotLight*.pmx = hide;" \

// テスト用
#define DISP_INTERMEDIATE		0

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
const float ClearDepth = 1.0;

//float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
//float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

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


// スクリーンサイズ
static float2 WorkSize = floor(ViewportSize * WORKSPACE_SCALE);
static float2 ViewportOffset2 = float2(0.5,0.5) / WorkSize;
static float2 ViewportWorkScale = ViewportSize / WorkSize;
static float2 ViewportAspect = float2(1, ViewportSize.x/ViewportSize.y);

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

#define DECLARE_PARAM(_t,_var,_item)	\
	_t _var : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = _item;>;

bool mExistPolish : CONTROLOBJECT < string name = CONTROLLER_NAME; >;
DECLARE_PARAM(float, mDirectLightP, "直接光+");
DECLARE_PARAM(float, mDirectLightM, "直接光-");
DECLARE_PARAM(float, mIndirectLightP, "間接光+");
DECLARE_PARAM(float, mIndirectLightM, "間接光-");
DECLARE_PARAM(float, mSSAOP, "SSAO+");
DECLARE_PARAM(float, mSSAOM, "SSAO-");
DECLARE_PARAM(float, mSSAOBias, "SSAOバイアス");
DECLARE_PARAM(float, mReflectionP, "映り込み+");
DECLARE_PARAM(float, mReflectionM, "映り込み-");
//DECLARE_PARAM(float, mExposureP, "露光+");
//DECLARE_PARAM(float, mExposureM, "露光-");
DECLARE_PARAM(float, mSoftShadow, "シャドウ");
DECLARE_PARAM(float, mFogDistance, "フォグ距離");
DECLARE_PARAM(float, mFogDensity, "フォグ濃度");

static float LightScale = CalcLightValue(mDirectLightP, mDirectLightM, DefaultLightScale);
static float AmbientScale = CalcMorphValue(mIndirectLightP, mIndirectLightM, DefaultAmbientScale);
static float AmbientPower = CalcMorphValue(mSSAOP, mSSAOM, DefaultAmbientPower);
static float ReflectionScale = CalcMorphValue(mReflectionP, mReflectionM, DefaultReflectionScale);
//static float ExposureBias = exp2((mExposureP * 0.5 - mExposureM) * DefaultExposureScale);
static float FogDistance = lerp(FOG_DISTANCE_MAX, FOG_DISTANCE_MIN, mFogDistance);
static float FogDensity = lerp(1.0, 0.0, mFogDensity);

#if defined(SSSBlurCount) && SSSBlurCount > 0
DECLARE_PARAM(float, mSSSP, "SSS+");
DECLARE_PARAM(float, mSSSM, "SSS-");
static float SSSScale = CalcMorphValue(mSSSP, mSSSM, DefaultSSSScale);
#endif

#if ENABLE_SSGI > 0 || SSAORayCount > 0
DECLARE_PARAM(float, mGIP, "GI+");
DECLARE_PARAM(float, mGIM, "GI-");
static float GIScale = CalcMorphValue(mGIP, mGIM, DefaultGIScale);
#endif

static float3 LightColor = LightSpecular * LightScale;

//-----------------------------------------------------------------------------
// 
#include "Sources/textures.fxsub"

#include "Sources/commons.fxsub"
#include "Sources/gbuffer.fxsub"
#include "Sources/lighting.fxsub"
#include "Sources/octahedron.fxsub"
#include "Sources/environmentmap.fxsub"
#include "Sources/rsm.fxsub"
#include "Sources/ssao.fxsub"
#include "Sources/ssgi.fxsub"
#include "Sources/shadowmap.fxsub"
#include "Sources/diffuse.fxsub"
#include "Sources/sss.fxsub"
#include "Sources/reflection.fxsub"
#include "Sources/refraction.fxsub"
#include "Sources/fog.fxsub"



//-----------------------------------------------------------------------------
// debug code
#if DISP_INTERMEDIATE > 0
float4 PS_TestDraw( float4 Tex: TEXCOORD0 ) : COLOR
{
	float2 texCoord = Tex;
	float3 DifColor = tex2D(DiffuseMapSamp, Tex).rgb;
	float3 RefColor = tex2D(ReflectionMapSamp, Tex).rgb;
	float3 Color = DifColor + RefColor;
//	Color.rgb = RefColor;
//	Color.rgb = DifColor;

	/*
	#if EXTRA_LIGHTS > 0
	return tex2D(LightMapSamp, Tex) + tex2D(SpecularMapSamp, Tex);
	#endif

	float4 albedo = tex2D(ColorMap, texCoord);
	MaterialParam material = GetMaterial(texCoord, 1);
	clip(IsNotMask(material) - 0.1);

	Color.rgb = DifColor;
	Color.rgb = RefColor;
	Color = tex2D(ShadowmapSamp, Tex ).xxx;
	Color = tex2D(HalfWorkSamp, Tex ).rgb;

	return tex2D(EnvMapWorkSamp, Tex);
	return tex2D(EnvMapSamp, Tex);
	return tex2D(EnvMapSamp0, Tex);
	return float4(tex2D(RSMAlbedoSamp, Tex ).rgb, 1);
	Color.rgb = GetSSAO(Tex);
	Color.rgb = GetSSAODepth(Tex) / 1024.0;

	return float4(tex2D( MaterialMap, Tex ).xyz, 1);
	return float4(RefColor.rgb, 1);
	return float4(RefColor.www, 1);
	return float4(normalize(tex2Dlod( NormalSamp, float4(Tex.xy,0,0)).xyz) * 0.5 + 0.5, 1);
	return tex2D(LightMapSamp, Tex) + tex2D(SpecularMapSamp, Tex);

	MaterialParam material = GetMaterial(texCoord, 1);
	Color = IsNotMask(material);
	Color = material.f0; // metalness;
	Color = material.attribute == MT_LEAF;
	Color = material.roughness;
	Color = material.metalness;

	GeometryInfo geom = GetWND(Tex);
	float3 V = normalize(CameraPosition - geom.wpos);
	float3 N = geom.nd.normal;
	Color = log2(geom.nd.depth / 50.0);
	Color.rgb = tex2D(RefractionMapSamp, Tex).rgb;
	*/

	Color = ColorCorrectToOutput(Color);
	return float4(Color.rgb, 1);
}
#endif

//-----------------------------------------------------------------------------
// ステンシルバッファの作成

float4 PS_DrawStencilSky( float2 texCoord: TEXCOORD0 ) : COLOR0
{
	MaterialParam material = GetMaterial(texCoord, 1);
	clip(epsilon - IsNotMask(material));
	return float4(0,0,0,1);
}

float4 PS_DrawStencilSkin( float2 texCoord: TEXCOORD0 ) : COLOR0
{
	MaterialParam material = GetMaterial(texCoord, 1);
	clip(material.sssValue - epsilon);
	return float4(0,0,0,1);
}


//-----------------------------------------------------------------------------

#define BufferRenderStates	\
		AlphaBlendEnable = false;	AlphaTestEnable = false; \
		ZEnable = false;	ZWriteEnable = false;

#define AdditiveBufferRenderStates	\
		AlphaBlendEnable = true;	AlphaTestEnable = false; \
		SrcBlend = ONE; DestBlend = ONE; \
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

	// 環境マップの生成
	"RenderDepthStencilTarget=EnvDepthBuffer;"
	"RenderColorTarget0=PPPEnvMap2;	Pass=SynthEnvPass;"
	#if ENV_MIPMAP > 0
	"RenderColorTarget0=EnvMap3;	Pass=EnvMipmapPass;"
	#endif

	// ステンシルバッファの生成
	"RenderColorTarget0=FullWorkMap;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Depth;"
	"Pass=DrawStencilSkyPass;"
	"Pass=DrawStencilSkinPass;"

	// シャドウマップ
	#if ENABLE_LSM > 0
	"RenderColorTarget0=SSAOWorkMap;	Pass=LSMPass;"
	#endif
	"RenderColorTarget0=PPPDiffuseMap;	Pass=ShadowMapPass;"
	"RenderColorTarget0=FullWorkMap;	Pass=ShadowBlurPassX;"
	"RenderColorTarget0=ShadowmapMap;	Pass=ShadowBlurPassY;"

	//---------------------------------------------------------------
	// SSAOの計算
	#if SSAORayCount > 0
	#if SSAO_QUALITY >= 2
	"RenderColorTarget0=HalfWorkMap2;	Pass=SSAOPass;"
	"RenderColorTarget0=HalfWorkMap;	Pass=SSAO2Pass;"
	#else
	"RenderColorTarget0=HalfWorkMap;	Pass=SSAOPass;"
	#endif
	"RenderColorTarget0=HalfWorkMap2;	Pass=HalfBlurXPass;"
	"RenderColorTarget0=HalfWorkMap;	Pass=HalfBlurYPass;"
	"RenderColorTarget0=SSAOWorkMap;	Pass=UpscalePass;"
	// SSGI
	#if ENABLE_SSGI > 0
	"RenderColorTarget0=HalfWorkMap3;	Pass=CreateSSGIBasePass;"
	#if RSMCount > 0
	"RenderColorTarget0=HalfWorkMap2;	Pass=CalcRSMPass;"
	#endif
	"RenderColorTarget0=HalfWorkMap;	Pass=SSGIPass;"
	"RenderColorTarget0=HalfWorkMap2;	Pass=SSGIBlurXPass;"
	"RenderColorTarget0=HalfWorkMap;	Pass=SSGIBlurYPass;"
	"RenderColorTarget0=HalfWorkMap2;	Pass=SSGIBlurXPass2;"
	"RenderColorTarget0=HalfWorkMap;	Pass=SSGIBlurYPass2;"
	"RenderColorTarget0=FullWorkMap;	Pass=SSGIUpscalePass;"
	#endif
	#endif

	//---------------------------------------------------------------
	// 拡散反射の計算
	"RenderColorTarget0=PPPDiffuseMap;	Clear=Color;	Pass=CalcDiffusePass;"
	// 皮下散乱の計算
	#if SSSBlurCount > 0
	"RenderColorTarget0=FullWorkMap;	Clear=Color;	Pass=SSSBlurXPass;"
	"RenderColorTarget0=PPPDiffuseMap;					Pass=SSSBlurYPass;"
	#endif

	//---------------------------------------------------------------
	// 鏡面反射の計算
	#if RLRRayCount > 0
	"RenderColorTarget0=HalfWorkMap;	Pass=RLRPass;"
	"RenderColorTarget1=HalfWorkMap3;"
	"RenderColorTarget0=HalfWorkMap2;	Pass=RLRCollectTexCoordPass;"
	"RenderColorTarget1=;"
	"RenderColorTarget0=HalfWorkMap;	Pass=RLRPass2;"
	"RenderColorTarget0=HalfWorkMap2;	Pass=RLRBlurXPass;"
	"RenderColorTarget0=HalfWorkMap;	Pass=RLRBlurYPass;"
	"RenderColorTarget0=FullWorkMap;	Pass=RLRUpscalePass;"
	#endif
	"RenderColorTarget0=PPPReflectionMap;	Clear=Color;	Pass=CalcSpecularPass;"

	// 屈折用の背景画像作成
	#if REFRACTION_TYPE > 0
	"RenderColorTarget0=PPPRefractionMap1;		Pass=SynthRefractionPass;"
	#if REFRACTION_TYPE > 1
	"RenderColorTarget0=RefractionWorkMap4;		Pass=DownScaleRefraction1Pass;"
	"RenderColorTarget0=RefractionWorkMap16;	Pass=DownScaleRefraction2Pass;"
	"RenderColorTarget0=RefractionWorkMap64;	Pass=DownScaleRefraction3Pass;"
	"RenderColorTarget0=PPPRefractionMap4;		Pass=UpScaleRefraction11Pass;"
	"RenderColorTarget0=RefractionWorkMap4;		Pass=UpScaleRefraction21Pass;"
	"RenderColorTarget0=PPPRefractionMap16;		Pass=UpScaleRefraction22Pass;"
	"RenderColorTarget0=RefractionWorkMap16;	Pass=UpScaleRefraction31Pass;"
	"RenderColorTarget0=RefractionWorkMap4;		Pass=UpScaleRefraction32Pass;"
	"RenderColorTarget0=PPPRefractionMap64;		Pass=UpScaleRefraction33Pass;"
	#endif
	#endif

	#if DISP_INTERMEDIATE == 0 && EXTRA_LIGHTS > 0
	"RenderColorTarget0=PPPSpecularMapRT;	Clear=Color;"
	#endif

	//---------------------------------------------------------------
	// 通常のモデル描画
	#if FOG_TYPE == 2
	"RenderColorTarget0=ScnMap;"
	#else
	"RenderColorTarget0=;"
	#endif
	"RenderDepthStencilTarget=;"
	"Clear=Color; Clear=Depth;"
	"ScriptExternal=Color;"

	//---------------------------------------------------------------
	// フォグ
	#if FOG_TYPE == 2
	#if DISP_INTERMEDIATE == 0
	#if ENABLE_MAIN_LIGHT_FOG > 0
	"RenderColorTarget0=PPPFogMapRT;		Pass=FogMainLightPass;"
	#endif
	"RenderColorTarget0=FullWorkMap;		Pass=FogDensityPass;"
	"RenderColorTarget0=PPPFogMapRT;		Pass=FogBlurXPass;"
	"RenderColorTarget0=FullWorkMap;		Pass=FogBlurYPass;"
	"RenderColorTarget0=PPPFogMapRT;		Clear=Color;"
	"RenderColorTarget0=;					Pass=DrawFogPass;"
	#endif
	#endif

	//---------------------------------------------------------------
	// テスト
	#if DISP_INTERMEDIATE > 0
	"RenderColorTarget0=;"
	"Pass=DrawPass;"
	// デバッグのDrawPassで表示するためにここでクリアしている。
	#if EXTRA_LIGHTS > 0
	"RenderColorTarget0=PPPSpecularMapRT;	Clear=Color;"
	#endif
	"RenderColorTarget0=;"
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

	#if ENABLE_LSM > 0
	pass LSMPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_LSM();
		PixelShader  = compile ps_3_0 PS_LSM();
	}
	#endif
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
		PixelShader  = compile ps_3_0 PS_BlurShadow(DiffuseMapSamp);
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
	pass SSAOPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_SSAO();
		PixelShader  = compile ps_3_0 PS_SSAO();
	}
	#if SSAO_QUALITY >= 2
	pass SSAO2Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_SSAO2();
		PixelShader  = compile ps_3_0 PS_SSAO2();
	}
	#endif

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

	//---------------------
	#if ENABLE_SSGI > 0
	#if RSMCount > 0
	pass CalcRSMPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_CalcRSM();
		PixelShader  = compile ps_3_0 PS_CalcRSM();
	}
	#endif

	pass CreateSSGIBasePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_CreateSSGIBase();
	}
	pass SSGIPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_SSGI();
		PixelShader  = compile ps_3_0 PS_SSGI();
	}
	pass SSGIBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSGI(true, 4);
		PixelShader  = compile ps_3_0 PS_BlurSSGI(HalfWorkSamp, 4);
	}
	pass SSGIBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSGI(false, 4);
		PixelShader  = compile ps_3_0 PS_BlurSSGI(HalfWorkSamp2, 4);
	}
	pass SSGIBlurXPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSGI(true, 1);
		PixelShader  = compile ps_3_0 PS_BlurSSGI(HalfWorkSamp, 1);
	}
	pass SSGIBlurYPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurSSGI(false, 1);
		PixelShader  = compile ps_3_0 PS_BlurSSGI(HalfWorkSamp2, 1);
	}
	pass SSGIUpscalePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_SSGIUpscale(HalfWorkSamp);
	}
	#endif
	#endif

	//-------------------------------------------------
	// 
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
		PixelShader  = compile ps_3_0 PS_SSS(DiffuseMapSamp);
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

	pass RLRCollectTexCoordPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_RLRCollectTexCoord();
		PixelShader  = compile ps_3_0 PS_RLRCollectTexCoord();
	}
	pass RLRPass2 < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_RLR2();
		PixelShader  = compile ps_3_0 PS_RLR2();
	}
	pass RLRBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurRLR(true);
		PixelShader  = compile ps_3_0 PS_BlurRLR(HalfWorkSamp);
	}
	pass RLRBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurRLR(false);
		PixelShader  = compile ps_3_0 PS_BlurRLR(HalfWorkSamp2);
	}
	pass RLRUpscalePass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		StencilTestNot(STENCIL_BIT_SKY)
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_RLRUpscale(HalfWorkSamp);
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
	#if REFRACTION_TYPE > 0
	pass SynthRefractionPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_SynthRefraction();
	}

	#if REFRACTION_TYPE > 1
	pass DownScaleRefraction1Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_DownsampleRefraction(1);
		PixelShader  = compile ps_3_0 PS_DownsampleRefraction(RefractionSamp1);
	}
	pass DownScaleRefraction2Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_DownsampleRefraction(4);
		PixelShader  = compile ps_3_0 PS_DownsampleRefraction(RefractionWorkSamp4);
	}
	pass DownScaleRefraction3Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_DownsampleRefraction(16);
		PixelShader  = compile ps_3_0 PS_DownsampleRefraction(RefractionWorkSamp16);
	}

	pass UpScaleRefraction11Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(1);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp4);
	}
	pass UpScaleRefraction21Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(4);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp16);
	}
	pass UpScaleRefraction22Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(1);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp4);
	}
	pass UpScaleRefraction31Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(16);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp64);
	}
	pass UpScaleRefraction32Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(4);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp16);
	}
	pass UpScaleRefraction33Pass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_UpsampleRefraction(1);
		PixelShader  = compile ps_3_0 PS_UpsampleRefraction(RefractionWorkSamp4);
	}
	#endif
	#endif

	//-------------------------------------------------
	// 
	#if FOG_TYPE == 2
	pass FogMainLightPass < string Script= "Draw=Buffer;"; > {
		AdditiveBufferRenderStates // 各ライトの明るさを加算していく
		VertexShader = compile vs_3_0 VS_VolumeLight();
		PixelShader  = compile ps_3_0 PS_VolumeLight();
	}
	pass FogDensityPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_FogDensity();
		PixelShader  = compile ps_3_0 PS_FogDensity();
	}
	pass FogBlurXPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurFog();
		PixelShader  = compile ps_3_0 PS_BlurFog(FullWorkSamp, true);
	}
	pass FogBlurYPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_BlurFog();
		PixelShader  = compile ps_3_0 PS_BlurFog(FogMapSampLinear, false);
	}
	pass DrawFogPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_DrawFog();
		PixelShader  = compile ps_3_0 PS_DrawFog();
	}
	#endif

	//-------------------------------------------------
	//
	#if DISP_INTERMEDIATE > 0
	pass DrawPass < string Script= "Draw=Buffer;"; > {
		BufferRenderStates
		VertexShader = compile vs_3_0 VS_Buffer();
		PixelShader  = compile ps_3_0 PS_TestDraw();
	}
	#endif
}

//-----------------------------------------------------------------------------
