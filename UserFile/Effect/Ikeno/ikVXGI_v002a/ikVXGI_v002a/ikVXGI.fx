///////////////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////////////

// 設定ファイル
#include "settings.fxsub"

#define	BounceIntensity		0.4		// 間接光の反射強度 (0.1～2.0程度)
#define	EmissiveIntensity	1.0		// 自己発光物の強度
#define	IndirectLightIntensity		1.5		// 間接光の強度 (0.5～2.0程度)

// 前フレームを再利用する最大割合。(0.1～0.8程度)
// 小さい値ほどチラつきが目立つが、反応が早くなる。
// 大きいとモデルや光の変化に対する遅延が目立つ。
#define	ReprojectionRate	0.5

// 環境マップを参照する際のスムースネスの基準。0.0～1.0
// 小さいほどボケた環境マップを参照する。大きい値にするとノイズが目立つ。
#define EnvSmoothnessLevel	0.1

// スペキュラ用にレイを飛ばす
#define	ENABLE_SPECULAR_RAYCAST

// ポイントライトを使う
#define	ENABLE_POINTLIGHTS


// テスト：ボクセル表示
//#define	TEST_DISPLAY_VOXELS

// テスト：ブラー禁止
//#define	TEST_DISABLE_BLUR

//****************** 以下は弄らないほうがいい設定項目

// テクスチャフォーマット
#define TEXFORMAT "A16B16G16R16F"
//#define TEXFORMAT "A8R8G8B8"
// 法線と深度
#define NORMALDEPTH_TEXFORMAT "A16B16G16R16F"
//#define NORMALDEPTH_TEXFORMAT "A32B32G32R32F"

// 環境マップ
#define EnvTexFormat		"A8R8G8B8"
//#define EnvTexFormat		"A16B16G16R16F"
#define ENV_WIDTH		256
// 環境マップの描画スケール。やや小さく描画する
const float EnvFrameScale = 0.95;

// レイを飛ばす数 (14または16のみ)
#define DIRECTION_NUM		14

//****************** 設定はここまで

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 Tex			: TEXCOORD0;
};

struct PS_OUT_MRT
{
	float4 Color		: COLOR0;
	float4 Normal		: COLOR1;
};

struct PS_OUT_MRT2
{
	float4 Diffuse		: COLOR0;
	float4 Specular		: COLOR1;
};

//-----------------------------------------------------------------------------
// ガンマ補正
const float epsilon = 1.0e-6;
const float gamma = 2.2;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

#define PI		(3.141592653589793)
#define SQRT3		(1.7320508075688772935274463415059)
#define INVSQRT3	(1.0 / SQRT3)


////////////////////////////////////////////////////////////////////////////////////////////////

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5) / ViewportSize.xy);
static float2 SampleStep = (float2(1.0,1.0) / ViewportSize.xy);
static float2 ViewportAspect = float2(1, ViewportSize.x/ViewportSize.y);

float4x4 matW			: WORLD;
float4x4 matV			: VIEW;
float4x4 matP			: PROJECTION;
float4x4 matVP			: VIEWPROJECTION;
float4x4 matInvV		: VIEWINVERSE;
float4x4 matInvP		: PROJECTIONINVERSE;
float4x4 matInvVP		: VIEWPROJECTIONINVERSE;

float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float3	CameraDirection	: DIRECTION  < string Object = "Camera"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	LightSpecular     : SPECULAR  < string Object = "Light"; >;
//static float3 LightColor = Degamma(saturate(LightSpecular)) * 3.0;

float time : TIME;

float3 CenterPosition : CONTROLOBJECT < string name = "(self)"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;


static float GRID_SIZE_ = (AcsSi * 0.1 * GRID_SIZE);
#define		INV_GRID_SIZE	(1.0 / GRID_SIZE_)

#define		VOXEL_SIZE		(VOXEL_SIZE_SQRT * VOXEL_SIZE_SQRT)
static float FarDepth = (VOXEL_SIZE * GRID_SIZE_);

// ボクセル作成用のワークテクスチャサイズ
#define		TEX_WIDTH		(VOXEL_SIZE * VOXEL_SIZE_SQRT)
#define		TEX_HEIGHT		(VOXEL_SIZE * VOXEL_SIZE_SQRT)

// ボクセル情報格納用のテクスチャサイズ
#define		TEX_WIDTH2		(VOXEL_SIZE * VOXEL_SIZE)
#define		TEX_HEIGHT2		(VOXEL_SIZE)
// mipmap用のテクスチャサイズ
#define		TEX_WIDTH3		(VOXEL_SIZE * VOXEL_SIZE / 4)
#define		TEX_HEIGHT3		(VOXEL_SIZE / 2)

#define		TEX_WIDTH4		(VOXEL_SIZE * VOXEL_SIZE / 16)
#define		TEX_HEIGHT4		(VOXEL_SIZE / 4)


static float3 GridCenterPosition = (floor(CenterPosition * INV_GRID_SIZE + VOXEL_SIZE) - VOXEL_SIZE) * GRID_SIZE_;
static float3 GridOffset = floor(GridCenterPosition * INV_GRID_SIZE + VOXEL_SIZE) % VOXEL_SIZE;


//-----------------------------------------------------------------------------
// 

#define VOXEL_SAMPLE_ATTRIBUTE_POINT	\
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;	\
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);

#define VOXEL_SAMPLE_ATTRIBUTE_LINEAR	\
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;	\
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {1, 1};
	string Format = "D24S8";
>;

texture2D VoxelPackRT: OFFSCREENRENDERTARGET <
	string Description = "convert polygon to voxel for ikVXGI";
	int Width = TEX_WIDTH;
	int Height = TEX_HEIGHT * 4;
	string Format = "A8R8G8B8";
	int MipLevels = 1;
	bool AntiAlias = false;
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	string DefaultEffect = 
		"self = hide;"
		"PPointLight?.x = hide;"
// グリッドに比べて小さいものは頂点単位で処理する?
//		"*.pmx = Voxelize/VoxelizeVertex.fx;"
//		"*.pmd = Voxelize/VoxelizeVertex.fx;"
		"* = Voxelize/Voxelize.fx;";
>;
sampler2D VoxelPackSamp = sampler_state {
	texture = <VoxelPackRT>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};

shared texture2D VoxelPackNormal: RENDERCOLORTARGET <
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT * 4;
	string Format = NORMALDEPTH_TEXFORMAT;
	int MipLevels = 1;
	bool AntiAlias = false;
>;
sampler2D VoxelPackNormalSamp = sampler_state {
	texture = <VoxelPackNormal>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};

// スクリーンスペースでの材質情報
texture MaterialMapRT: OFFSCREENRENDERTARGET <
	string Description = "Material map for ikVXGI";
	float4 ClearColor = { 0, 0, 0, 0 };
	float2 ViewportRatio = {1, 1};
	float ClearDepth = 1.0;
	int MipLevels = 1;
	bool AntiAlias = false;
	string Format = "A8R8G8B8";		// 材質情報
//	string Format = "A16B16G16R16F";
	string DefaultEffect = 
		"self = hide;"
		"PPointLight?.x = hide;"
		"* = Materials/MaterialMap.fx";
>;
sampler MaterialSampPoint = sampler_state {
	texture = <MaterialMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
// スクリーンスペースでの法線と深度
shared texture VxNormalDepthMap: RENDERCOLORTARGET <
	string Format = NORMALDEPTH_TEXFORMAT;
	int MipLevels = 1;
>;
sampler NormalDepthSamp = sampler_state {
	texture = <VxNormalDepthMap>;
	MinFilter = LINEAR; MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};
sampler NormalDepthSampPoint = sampler_state {
	texture = <VxNormalDepthMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

// ボクセル再構築用のワーク
// アルベド
texture2D VoxelPack2: RENDERCOLORTARGET <
	int Width = TEX_WIDTH;
	int Height = TEX_HEIGHT * 3;
	string Format = "A8R8G8B8";
	int MipLevels = 1;
>;
sampler2D VoxelPackSamp2 = sampler_state {
	texture = <VoxelPack2>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// 法線
texture2D VoxelPackNormal2: RENDERCOLORTARGET <
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT * 3;
	string Format = NORMALDEPTH_TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelPackNormalSamp2 = sampler_state {
	texture = <VoxelPackNormal2>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// 深度
texture2D VoxelPackDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT * 3;
	string Format = "D24S8";
>;

// 構築したボクセルのアルベド
texture2D VoxelAlbedoMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2;
	string Format = "A8R8G8B8";
	int MipLevels = 1;
>;
sampler2D VoxelAlbedoSamp = sampler_state {
	texture = <VoxelAlbedoMap>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// 構築したボクセルの法線
texture2D VoxelNormalMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2;
	string Format = NORMALDEPTH_TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelNormalSamp = sampler_state {
	texture = <VoxelNormalMap>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR // 参照点の法線を得るのに補間する
};
sampler2D VoxelNormalSampPoint = sampler_state {
	texture = <VoxelNormalMap>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};

// 各ボクセルのSHを格納する
texture2D VoxelSHMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2 * 4;
	string Format = "A16B16G16R16F";
	int MipLevels = 1;
>;
sampler2D VoxelSHSamp = sampler_state {
	texture = <VoxelSHMap>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR
//	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// バックアップ
texture2D BackupVoxelSHMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2 * 4;
	string Format = "A16B16G16R16F";
	int MipLevels = 1;
>;
sampler2D BackupVoxelSHSamp = sampler_state {
	texture = <BackupVoxelSHMap>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR
//	VOXEL_SAMPLE_ATTRIBUTE_POINT
};


// ボクセル用の共通深度バッファ：ワーク用に縦が長い
texture2D VoxelDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2 * DIRECTION_NUM;
//	int Height=TEX_HEIGHT2;
	string Format = "D24S8";
>;

// mipmap付きのボクセル情報。コーントレースの対象。
texture2D VoxelMap2: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelSamp2 = sampler_state {
	texture = <VoxelMap2>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR
};
sampler2D VoxelSamp2Point = sampler_state {
	texture = <VoxelMap2>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// mip lv.2
texture2D VoxelMap3: RENDERCOLORTARGET <
	int Width=TEX_WIDTH3;
	int Height=TEX_HEIGHT3;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelSamp3 = sampler_state {
	texture = <VoxelMap3>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR
};
// mip lv.3
texture2D VoxelMap4: RENDERCOLORTARGET <
	int Width=TEX_WIDTH4;
	int Height=TEX_HEIGHT4;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelSamp4 = sampler_state {
	texture = <VoxelMap4>;
	VOXEL_SAMPLE_ATTRIBUTE_LINEAR
};

// ボクセル間の光の反射(ワーク。1ボクセル16方向を格納)
texture2D BounceWorkMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2 * DIRECTION_NUM;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D BounceWorkSamp = sampler_state {
	texture = <BounceWorkMap>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// ボクセル間の光の反射(結果)
texture2D BounceMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D BounceSamp = sampler_state {
	texture = <BounceMap>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};
// 中間結果格納用
texture2D VoxelWorkMap: RENDERCOLORTARGET <
	int Width=TEX_WIDTH2;
	int Height=TEX_HEIGHT2;
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VoxelWorkSamp = sampler_state {
	texture = <VoxelWorkMap>;
	VOXEL_SAMPLE_ATTRIBUTE_POINT
};



// ワーク用テクスチャの設定
#define FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
#define FILTER_MODE_POINT	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define ADDRESSING_MODE		AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
#define ADDRESSING_MODE_CLAMP	AddressU  = CLAMP;	AddressV = CLAMP;

#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		int MipLevels = 1; \
		float2 ViewportRatio = {1.0/(_size), 1.0/(_size)}; \
		string Format = TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		FILTER_MODE	ADDRESSING_MODE \
	}; \
	sampler2D _samp##Point = sampler_state { \
		texture = <_map>; \
		FILTER_MODE_POINT	ADDRESSING_MODE \
	}; \
	sampler2D _samp##Clamp = sampler_state { \
		texture = <_map>; \
		FILTER_MODE	ADDRESSING_MODE_CLAMP \
	}; \

DECL_TEXTURE( BlurMap0, BlurSamp0, 1)
DECL_TEXTURE( BlurMap1, BlurSamp1, 1)


// 前フレームのマトリクス
#define MatrixBufferSize	5
texture MatrixBufferMap : RENDERCOLORTARGET <
	int2 Dimensions = {MatrixBufferSize, 1};
	int Miplevels = 1;
	string Format="A32B32G32R32F";
>;
texture2D MatrixDepthBuffer : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {MatrixBufferSize, 1};
	string Format = "D24S8";
>;
float4 MatrixBuffer[MatrixBufferSize] : TEXTUREVALUE <
    string TextureName = "MatrixBufferMap";
>;
// static float4x4 lastMatVP = float4x4(MatrixBuffer[0], MatrixBuffer[1], MatrixBuffer[2], MatrixBuffer[3]);
static float4 lastVoxelPosition = MatrixBuffer[4];

// Mainに公開するためのデータ(ワークとしても使う)
shared texture2D VxDiffuseMap: RENDERCOLORTARGET <
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
shared texture2D VxSpecularMap: RENDERCOLORTARGET <
	string Format = TEXFORMAT;
	int MipLevels = 1;
>;
sampler2D VxDiffuseSamp = sampler_state {
	texture = <VxDiffuseMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = CLAMP;	AddressV = CLAMP;
};
sampler2D VxDiffuseSampClamp = sampler_state {
	texture = <VxDiffuseMap>;
	FILTER_MODE	ADDRESSING_MODE_CLAMP
};

sampler2D VxSpecularSamp = sampler_state {
	texture = <VxSpecularMap>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU = CLAMP;	AddressV = CLAMP;
};


//-----------------------------------------------------------------------------

#include	"Sources/commons.fxsub"
#include	"Sources/rsm_common.fxsub"
#include	"Sources/ssao.fxsub"
#include	"Sources/environmentmap.fxsub"

static float3x3 matLightBillboard = {
	normalize(matLightInvV[0].xyz),
	normalize(matLightInvV[1].xyz),
	normalize(matLightInvV[2].xyz),
};
inline float3 ReconstructWPosFromLight(float2 texCoord, float depth)
{
//	float2 uv = (texCoord * 2 - 1.0) * float2(1,-1) * 0.5;
	float2 uv = texCoord * float2(1,-1) - (float2(1,-1) * 0.5);
	return mul(float4(uv * RSM_ShadowSize, depth, 1), matLightInvV).xyz;
}

#include	"Shadows/shadowmap.fxsub"
#include	"Sources/sh.fxsub"
#include	"Sources/voxel.fxsub"
#include	"Sources/pointlight.fxsub"


// リセットする?
// リセットするなら0を返すので、x * IsNotTimeToReset()でxの値を残すか、0にするか決める。
// または clip(IsNotTimeToReset() - 0.01)とかで破棄する。
static bool bNotTimeToReset = (time > 1e-4) * (abs(lastVoxelPosition.w - GRID_SIZE_) < 0.01);
inline bool IsNotTimeToReset()
{
	return bNotTimeToReset;
}


//-----------------------------------------------------------------------------

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;

	Out.Tex = float4(TexCoord, Offset);

	return Out;
}

VS_OUTPUT VS_Voxel( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH2, 1.0/TEX_HEIGHT2);

	return Out;
}

VS_OUTPUT VS_VoxelSH( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH2, 1.0/(TEX_HEIGHT2 * 4));

	return Out;
}



//-----------------------------------------------------------------------------
//
VS_OUTPUT VS_UnpackVoxel( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH, 1.0/(TEX_HEIGHT*3));
	return Out;
}

// 4x4ブロックに確率的に分配したボクセル情報を正しい場所に再配置する。
// 何もないなら、Color.aを0にする。
PS_OUT_MRT PS_UnpackVoxel( VS_OUTPUT IN)
{
	float2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH, TEX_HEIGHT * 3));
	float2 texCoord0 = uv / float2(TEX_WIDTH, TEX_HEIGHT * 4);
	float2 offset = 2.0 * float2(1.0/TEX_WIDTH, 1.0/(TEX_HEIGHT*4));

	float u = uv.x % VOXEL_SIZE_SQRT;
	float v = uv.y % VOXEL_SIZE_SQRT;
	float mode = floor(uv.y / TEX_HEIGHT);
	int patternNo = (v * VOXEL_SIZE_SQRT + u) * 4 + mode;

	float4 col = 0;
	float4 nrm = 0;

	// TODO: 範囲制限を行う
	// NOTE: ボクセル内ならpatternNoで判別可能だが、最下段のRSMで偶然patternNoが一致する可能性がある。
	for(int x = 0; x < 4; x++)
	{
		for(int y = 0; y < 4; y++)
		{
			float2 texCoord = texCoord0 + float2(x, y) * offset;
			float4 col0 = tex2D(VoxelPackSamp, texCoord);
			float4 nrm0 = tex2D(VoxelPackNormalSamp, texCoord);
			// 実体のないものを無視
			bool isConcrete = (col0.a * 255) % 2;
			float alpha0 = isConcrete * (nrm0.w == patternNo);
			col += float4(col0.rgb, 1) * alpha0;
			nrm += NormalToSH(nrm0.xyz) * alpha0;
		}
	}

	nrm = nrm / max(col.a, 1);
	col.rgb = col.rgb / max(col.a, 1);
	col.a = (col.a > 0.0);

	PS_OUT_MRT Out;
	Out.Color = col;
	Out.Normal = nrm * col.a;

	return Out;
}


// ボクセルの構築
PS_OUT_MRT PS_ConstructVoxel( VS_OUTPUT IN)
{
	int2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2));
	int x = uv.x % VOXEL_SIZE;
	int y = uv.y;
	int z = floor(uv.x / VOXEL_SIZE);

	int ix = VOXEL_SIZE - 1 - x;
	int iy = VOXEL_SIZE - 1 - y;
	int iz = VOXEL_SIZE - 1 - z;

	float4 colXY, colYZ, colXZ;
	float4 nrmXY, nrmYZ, nrmXZ;

	GetColorAndNormalFromPack(x, iy, z + GridOffset.z, 0, colXY, nrmXY);
	GetColorAndNormalFromPack(iz,iy, x + GridOffset.x, 1, colYZ, nrmYZ);
	GetColorAndNormalFromPack(z, ix, y + GridOffset.y, 2, colXZ, nrmXZ);

	float4 col = colXY + colYZ + colXZ;
	float4 nrm = nrmXY + nrmYZ + nrmXZ;
	col.rgb = col.rgb / max(col.a, 1);
	nrm = nrm / max(col.a, 1);

	col.a = (col.a > 0.0);

	PS_OUT_MRT Out;
	Out.Color = col;
	Out.Normal = ToIrradianceProbe(nrm) * col.a;

	return Out;
}

// 光っている部分だけを集める
float4 PS_UnpackEmissiveVoxel( VS_OUTPUT IN) : COLOR
{
	float2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH, TEX_HEIGHT * 3));
	float2 texCoord0 = uv / float2(TEX_WIDTH, TEX_HEIGHT * 4);
	float2 offset = 2.0 * float2(1.0/TEX_WIDTH, 1.0/(TEX_HEIGHT*4));

	float u = uv.x % VOXEL_SIZE_SQRT;
	float v = uv.y % VOXEL_SIZE_SQRT;
	float mode = floor(uv.y / TEX_HEIGHT);
	int patternNo = (v * VOXEL_SIZE_SQRT + u) * 4 + mode;

	float4 col = 0;
	for(int x = 0; x < 4; x++)
	{
		for(int y = 0; y < 4; y++)
		{
			float2 texCoord = texCoord0 + float2(x, y) * offset;
			float4 col0 = tex2D(VoxelPackSamp, texCoord);
			float4 nrm0 = tex2D(VoxelPackNormalSamp, texCoord);
			// 光るものを集める
			float emissive = max(col0.a * 255 - 1, 0) / 255.0;
			float alpha0 = emissive * (nrm0.w == patternNo);
			col += float4(col0.rgb, 1) * alpha0;
		}
	}

	col.rgb = col.rgb / max(col.a, 1e-4);
	col.a = saturate(col.a);

	return col;
}

float4 PS_ConstructEmissiveVoxel( VS_OUTPUT IN) : COLOR
{
	int2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2));
	int x = uv.x % VOXEL_SIZE;
	int y = uv.y;
	int z = floor(uv.x / VOXEL_SIZE);

	int ix = VOXEL_SIZE - 1 - x;
	int iy = VOXEL_SIZE - 1 - y;
	int iz = VOXEL_SIZE - 1 - z;

	float4 colXY, colYZ, colXZ;

	GetColorFromPack(x, iy, z + GridOffset.z, 0, colXY);
	GetColorFromPack(iz,iy, x + GridOffset.x, 1, colYZ);
	GetColorFromPack(z, ix, y + GridOffset.y, 2, colXZ);

	float3 col = colXY.rgb * colXY.a + colYZ.rgb * colYZ.a + colXZ.rgb * colXZ.a;
	float alpha = colXY.a + colYZ.a + colXZ.a;
	col.rgb = col.rgb * (EmissiveIntensity * 2.0) / max(alpha, 1e-4);

	return float4(col, saturate(alpha));
}

//-----------------------------------------------------------------------------
// 光っているボクセルマップを作成。

inline float2 CalcLightProjPos(float3 wpos, float2 offset)
{
	float3 pos0 = mul(float3(offset, 0), matLightBillboard) + wpos;
	float4 lightPPos0 = mul(float4(pos0, 1), matLightVP);
	return lightPPos0.xy / lightPPos0.w;
}


float4 PS_InjectLightVoxel( VS_OUTPUT IN) : COLOR
{
	// uvからグリッドの中心位置を得る
	float2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2));
	float x = uv.x % VOXEL_SIZE;
	float y = uv.y;
	float z = floor(uv.x / VOXEL_SIZE);
	float3 vpos = float3(x,y,z);
	float3 wpos = VoxelPointToWorldPosition(vpos);

	//---------------------------------------------------------------
	// エミッシブなボクセルをライトとして追加。
	float4 col = tex2D(VoxelWorkSamp, IN.Tex.xy);
	float4 albedo = tex2D(VoxelAlbedoSamp, IN.Tex.xy);
	col.a = max(albedo.a, col.a);

	// 何もない空間なら、RSMの処理をスキップ
	clip(col.a - 1.0e-4);

	//---------------------------------------------------------------
	// ポイントライト 
	#if defined(ENABLE_POINTLIGHTS)
		[unroll] for(int i = 0; i < 4; i++)
		{
			col += InjectPointLightIntoVoxel(wpos, i) * albedo;
		}
	#endif

	//---------------------------------------------------------------
	// RSM
	// ビルボード風の4点でRSMの探索範囲を調べる。
	float w = GRID_SIZE_ * 0.5;
	float2 lightPPos0 = CalcLightProjPos(wpos, float2( w, w));
	float2 lightPPos1 = CalcLightProjPos(wpos, float2( w,-w));
	float2 lightPPos2 = CalcLightProjPos(wpos, float2(-w,-w));
	float2 lightPPos3 = CalcLightProjPos(wpos, float2(-w, w));

	float2 minPPos = min(lightPPos0, min(lightPPos1, min(lightPPos2, lightPPos3)));
	float2 maxPPos = max(lightPPos0, max(lightPPos1, max(lightPPos2, lightPPos3)));
	// saturateで適当な範囲制限
	minPPos = saturate(minPPos * float2(0.5, -0.5) + 0.5);
	maxPPos = saturate(maxPPos * float2(0.5, -0.5) + 0.5);

	#define RSM_STEP_COUNT	4
	float2 vPPos = (maxPPos - minPPos) * (1.0 / RSM_STEP_COUNT);
		// NOTE: vPPos > 1pixになるようにすべき?
	float4 rsmcol = 0;
	for(int sx = 0; sx < RSM_STEP_COUNT; sx++)
	{
		for(int sy = 0; sy < RSM_STEP_COUNT; sy++)
		{
			float2 texCoord0 = vPPos * float2(sx, sy) + minPPos;

			float2 texCoord = texCoord0;
			texCoord.y = (texCoord.y + 3.0) * 0.25; // yをつぶす
			float4 lightND0 = tex2Dlod(VoxelPackNormalSamp, float4(texCoord, 0,0));
			float depth0 = lightND0.w;
			float3 wpos0 = ReconstructWPosFromLight(texCoord0, depth0);
			// 適当な距離チェック
			float weight = (distance(wpos, wpos0) < GRID_SIZE_ * 2.0);

			float4 col0 = tex2Dlod(VoxelPackSamp, float4(texCoord, 0,0));
			rsmcol += col0 * (weight * col0.a);
		}
	}
	rsmcol.rgb /= max(rsmcol.a, 1.0e-4);

	#if defined(ENABLE_POINTLIGHTS)
	// ポイントライトだけが置かれた何もない空間ならRSMを適用しない。
	col += rsmcol * albedo.a;
	#else
	col += rsmcol;
	#endif

	//---------------------------------------------------------------
	// 前フレームの反射を追加する
	float4 lastVoxel = GetLastFrameVoxel(vpos);
	lastVoxel.a *= IsNotTimeToReset() * 0.9;
	col += float4(lastVoxel.rgb, 1) * lastVoxel.a;

	col.a = saturate(col.a);

	return col;
}


//-----------------------------------------------------------------------------
// mipmap用のダウンスケール処理
VS_OUTPUT VS_Downscale( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH3, 1.0/TEX_HEIGHT3);
	Out.Tex.zw = float2(TEX_WIDTH3, TEX_HEIGHT3);

	return Out;
}

VS_OUTPUT VS_Downscale2( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH4, 1.0/TEX_HEIGHT4);
	Out.Tex.zw = float2(TEX_WIDTH4, TEX_HEIGHT4);

	return Out;
}

float4 PS_Downscale( VS_OUTPUT IN, uniform sampler2D Samp) : COLOR
{
	const float Size = IN.Tex.w;
	const float BaseSize = IN.Tex.w * 2.0;
	const float InvBaseSize2 = 1.0 / (IN.Tex.z * 2.0 * 2.0);

	float2 uv = floor(IN.Tex.xy * IN.Tex.zw);
	float x = (uv.x % Size) * 2.0;
	float y = (uv.y) * 2.0;
	float z = floor(uv.x / Size) * 2.0;

	float oz0 = z * BaseSize;
	float ox0 = x;
	float oy0 = y / BaseSize;
	float oz1 = (z + 1) * BaseSize;
	float ox1 = x + 1;
	float oy1 = (y + 1) / BaseSize;
		// (1/(BaseSize*BaseSize), 1/BaseSize, 1/BaseSize) をVSからの結果に入れておく?

	float4 col000 = tex2D(Samp, float2((ox0 + oz0) * InvBaseSize2, oy0));
	float4 col010 = tex2D(Samp, float2((ox1 + oz0) * InvBaseSize2, oy0));
	float4 col100 = tex2D(Samp, float2((ox0 + oz0) * InvBaseSize2, oy1));
	float4 col110 = tex2D(Samp, float2((ox1 + oz0) * InvBaseSize2, oy1));

	float4 col001 = tex2D(Samp, float2((ox0 + oz1) * InvBaseSize2, oy0));
	float4 col011 = tex2D(Samp, float2((ox1 + oz1) * InvBaseSize2, oy0));
	float4 col101 = tex2D(Samp, float2((ox0 + oz1) * InvBaseSize2, oy1));
	float4 col111 = tex2D(Samp, float2((ox1 + oz1) * InvBaseSize2, oy1));

	float3 col;
	col  = col000.rgb * col000.a + col100.rgb * col100.a;
	col += col010.rgb * col010.a + col110.rgb * col110.a;
	col += col001.rgb * col001.a + col101.rgb * col101.a;
	col += col011.rgb * col011.a + col111.rgb * col111.a;

	float alpha = col000.a + col100.a + col010.a + col110.a
				+ col001.a + col101.a + col011.a + col111.a;

	col.rgb = col.rgb / max(alpha, 1e-4);

	// 2^3ブロック中、4ブロックも埋まってたら十分?
	// 法線も参照して、法線の向きが一致していたら＝長かったら、
	// 少ないブロックでも遮蔽度を上げる？
	return float4(col.rgb, saturate(alpha * (1.0 / 8.0)));
}

//-----------------------------------------------------------------------------
// ボクセル間のバウンスの計算

VS_OUTPUT VS_GenerateBounce( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + 0.5 * float2(1.0/TEX_WIDTH2, 1.0/(TEX_HEIGHT2 * DIRECTION_NUM));

	return Out;
}

float4 PS_GenerateBounce( VS_OUTPUT IN) : COLOR
{
	int2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2 * DIRECTION_NUM));

	int x = uv.x % VOXEL_SIZE;
	int y = uv.y / DIRECTION_NUM;
	int z = uv.x / VOXEL_SIZE;

	float2 vxTexcoord = float2(IN.Tex.x, (y + 0.5) * (1.0 / TEX_HEIGHT2));
	float4 albedo = tex2D(VoxelAlbedoSamp, vxTexcoord);
	clip(albedo.a - 1.0e-4);

	float3 n = normalize(tex2D(VoxelNormalSampPoint, vxTexcoord).xyz);
		// SH -> normal

	float3 vpos = float3(x,y,z);
	float3 wpos = VoxelPointToWorldPosition(vpos);
	float3 dv = GetUniformVector(uv.y % DIRECTION_NUM);
	float3 rv = RotateDirection(n, dv);
	float4 col = ConeTrace(wpos, rv, n);

	float3 envCol = GetEnvColor(rv, EnvSmoothnessLevel);
	col.rgb = lerp(envCol, col.rgb * BounceIntensity, col.a);
	col *= dv.z; // dot(n, rv)
	col.a = 1;

	col *= albedo;

	return col;
}

// バウンス情報の収集
float4 PS_GatherBounce( VS_OUTPUT IN) : COLOR
{
	float2 uv0 = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2));
	uv0.y *= DIRECTION_NUM;

	float2 k = float2(1.0 / TEX_WIDTH2, 1.0 / (TEX_HEIGHT2 * DIRECTION_NUM * 1.0));

	float4 col = 0;
	[unroll] for(int i = 0; i < DIRECTION_NUM; i++)
	{
		float2 uv1 = (uv0 + float2(0, i)) * k;
		float4 col1 = tex2D(BounceWorkSamp, uv1);
		col += float4(col1.rgb, 1) * col1.a;
	}

	col.rgb *= (1.0 / DIRECTION_NUM * PI);
	col.a *= (1.0 / DIRECTION_NUM);

	return col;
}

// 1次バウンスと2次バウンス以降を合成。
float4 PS_SynthLight( VS_OUTPUT IN) : COLOR
{
	float4 light1st = tex2D(VoxelSamp2Point, IN.Tex.xy);
	float4 light2nd = tex2D(BounceSamp, IN.Tex.xy);
	float4 albedo = tex2D(VoxelAlbedoSamp, IN.Tex.xy);

	float4 col = float4(albedo.rgb * light2nd.rgb * light2nd.a, albedo.a);
	float scatter = 1.0;
	float lightAlpha = max(light2nd.a - col.a, 0) * scatter;
	col += float4(light2nd.rgb, 1) * lightAlpha;

	col = light1st + col;
	col.a = saturate(col.a);

	return col;
}

// ボクセル情報のコピー 
float4 PS_CopyVoxel( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	return tex2D(smp, IN.Tex.xy);
}


//-----------------------------------------------------------------------------
// 
float4 PS_GenerateLightProbe( VS_OUTPUT IN) : COLOR
{
	int2 uv = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2 * DIRECTION_NUM));

	int x = uv.x % VOXEL_SIZE;
	int y = uv.y / DIRECTION_NUM;
	int z = uv.x / VOXEL_SIZE;

	float2 vxTexcoord = float2(IN.Tex.x, (y + 0.5) * (1.0 / TEX_HEIGHT2));

	float3 vpos = float3(x,y,z);
	float3 wpos = VoxelPointToWorldPosition(vpos);
	float3 v = GetSphericalVector(uv.y % DIRECTION_NUM);
	float4 col = ConeTrace(wpos, v, v);

	return col;
}

// SHを作成する。
float4 PS_GatherLightProbe( VS_OUTPUT IN) : COLOR
{
	int2 uv0 = floor(IN.Tex.xy * float2(TEX_WIDTH2, TEX_HEIGHT2 * 4));
	float x = uv0.x % VOXEL_SIZE;
	float y = uv0.y % TEX_HEIGHT2;
	float z = floor(uv0.x / VOXEL_SIZE);

	int ch = floor(uv0.y / TEX_HEIGHT2);
	uv0.y = y * DIRECTION_NUM;

	float4 mask = ChannelToMask(ch);
	float2 k = float2(1.0 / TEX_WIDTH2, 1.0 / (TEX_HEIGHT2 * DIRECTION_NUM * 1.0));

	float4 coef = 0;
	[unroll] for(int i = 0; i < DIRECTION_NUM; i++)
	{
		float2 uv1 = (uv0 + float2(0, i)) * k;
		float4 col1 = tex2D(BounceWorkSamp, uv1);
		col1 = float4(col1.rgb, 1) * col1.a;
		float3 v = GetSphericalVector(i);
		coef += CalcSHCoef(col1, v, mask);
	}

	coef *= (1.0 / DIRECTION_NUM);

	//---------------------------------------------------------------
	// 前フレームの係数を合成
	float3 lastVoxelTex = GetLastFrameVoxelTexCoord(float3(x,y,z));
	lastVoxelTex.y = (lastVoxelTex.y + ch) * (1.0 / 4.0);
	float4 lastCoef = tex2D(BackupVoxelSHSamp, lastVoxelTex.xy);
	float rate = lastVoxelTex.z * IsNotTimeToReset();
	coef = lerp(coef, lastCoef, rate * ReprojectionRate);

	return coef;
}


//-----------------------------------------------------------------------------
// リバースリプロジェクション用
// (現在はリバースリプロジェクションを廃止したので、センター位置しか使っていない)

VS_OUTPUT VS_CopyMatrix( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.Tex.xy = Tex.xy + float2(0.5 / MatrixBufferSize, 0.5);
	return Out;
}

float4 PS_CopyMatrix( float4 Tex: TEXCOORD0) : COLOR
{
	int x = floor(Tex.x * MatrixBufferSize);
	float4 result = 0;
	if (x < 4)
	{
		result = matVP[x];
	}
	else
	{
		result = float4(GridCenterPosition, GRID_SIZE_);
	}

	return result;
}


//-----------------------------------------------------------------------------
// スクリーンスペースで間接光を収集

#if defined(ENABLE_SPECULAR_RAYCAST)
float4 PS_RaycastSpecular( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.Tex.xy;
	float4 nd = tex2D(NormalDepthSampPoint, texCoord);
	float3 wpos = ReconstructWPos(texCoord, nd.w).xyz;
	float3 n = normalize(nd.xyz);

	float4 matparams = tex2D(MaterialSampPoint, texCoord);
	float smoothness = matparams.y;

	float3 v = normalize(CameraPosition - wpos);
	float3 ref = normalize(reflect(-v, n));

	int2 iuv = floor(texCoord * ViewportSize);
	float3 rndv = GetRandomVector(iuv);
	float3 rndpos = GetRandomPosition(iuv);
	float a2 = smoothness * smoothness;
	rndv.z += a2 * 10.0; // スームスなほどコーンを狭める。ad-hoc。
	float3 rv = RotateDirection(ref, normalize(rndv));
	float4 col = ConeTrace(wpos + rv + rndpos, rv, n);

	return col;
}
#endif

PS_OUT_MRT2 PS_GatherIndirectLight( VS_OUTPUT IN)
{
	float2 texCoord = IN.Tex.xy;
	float4 nd = tex2D(NormalDepthSampPoint, texCoord);
	float3 wpos = ReconstructWPos(texCoord, nd.w).xyz;
	float3 n = normalize(nd.xyz);

	float4 matparams = tex2D(MaterialSampPoint, texCoord);
	float smoothness = matparams.y;
	float sss = matparams.w;
	float envSmoothnes = smoothness * (1.0 - EnvSmoothnessLevel) + EnvSmoothnessLevel;

	float3 v = normalize(CameraPosition - wpos);
	float3 ref = normalize(reflect(-v, n));

	float4 colSpec;
	float4 colSss;
	float4 colDiff = GetSHColor2(wpos, n, ref, colSpec, colSss);

	// 適当なsssの処理
	colSss.rgb *= saturate(colSss.rgb);
	colDiff.rgb = lerp(colDiff.rgb, colSss.rgb, sss * 0.5);

	#if defined(ENABLE_SPECULAR_RAYCAST)
	float4 colSpecRay = tex2D(VxSpecularSamp, texCoord);
	colSpec = colSpecRay + colSpec * saturate(1 - colSpecRay.a);
	#endif

	float3 envColDiff = GetEnvColor(n, EnvSmoothnessLevel);
	float3 envColSpec = GetEnvColorParallax(ref, wpos, envSmoothnes);
	colDiff.rgb += envColDiff * saturate(1.0 - colDiff.a);
	colSpec.rgb += envColSpec * saturate(1.0 - colSpec.a);

	float a = max(1 - smoothness, 1e-3);
	float A = 1 / ((0.5 - 2.0/3.0/PI) * a * a + 1);
	colDiff.rgb *= IndirectLightIntensity * A;
	colSpec.rgb *= IndirectLightIntensity;

	//---------------------
	// ポイントライト 
	#if defined(ENABLE_POINTLIGHTS)
	[unroll] for(int index = 0; index < 4; index++)
	{
		float4 lightcolDiff = CalcDirectPointLightDiffuse(wpos, n, index);
		float4 lightcolSpec = CalcDirectPointLightSpecular(wpos, v, n, smoothness, index);
		colDiff.rgb += lightcolDiff.rgb * lightcolDiff.a;
		colSpec.rgb += lightcolSpec.rgb * lightcolSpec.a;
	}
	#endif

	PS_OUT_MRT2 Out;
	Out.Diffuse = float4(colDiff.rgb, 1);
	Out.Specular = float4(colSpec.rgb, 1);

	return Out;
}

//-----------------------------------------------------------------------------
//
PS_OUT_MRT2 PS_Export( VS_OUTPUT IN)
{
	float2 texCoord = IN.Tex.xy;

	float4 nd = tex2D(NormalDepthSampPoint, texCoord);
	float depth = (nd.w > 1.0) ? nd.w : (FarDepth * 2.0);
	float3 wpos = ReconstructWPos(texCoord, depth).xyz;

	float4 matparams = tex2D(MaterialSampPoint, texCoord);
	float f0 = matparams.x;
	float smoothness = matparams.y;
	float intensity = matparams.z;
	float sss = matparams.w;

	float3 L = -LightDirection;
	float3 V = normalize(CameraPosition - wpos);
	float3 N = normalize(nd.xyz);
	float ref = CalcReflectance(N, V, smoothness, f0);

	// 直接光
	float diffuse = CalcDiffuse(L, N, V, smoothness);
	float specular = CalcSpecular(L, N, V, smoothness, f0);
	// 間接光
	float4 colDiff = tex2D(BlurSamp0, texCoord);
	float4 colSpec = tex2D(BlurSamp1, texCoord);

	// 陰影・影
	float4 shadowInfo = tex2D(ShadowSamp, texCoord);
	float shadow = shadowInfo.x;
	float ao = shadowInfo.z;
	colDiff *= ao;
	colSpec *= (ao * ref * intensity);

	float3 diff3 = (diffuse * LightSpecular * shadow + colDiff.rgb) * (1.0 - f0);
	float3 spec3 = specular * LightSpecular * (shadow * intensity) + colSpec.rgb;

	// AL風飽和処理
	diff3 = OverExposure(diff3);
	spec3 = OverExposure(spec3);

	PS_OUT_MRT2 Out;
	Out.Diffuse = float4(diff3, sss);
	Out.Specular = float4(spec3, depth);	// .w に深度を格納。

	return Out;
}


//-----------------------------------------------------------------------------
//
#if defined(ENABLE_SPECULAR_RAYCAST)
float4 PS_Blur( float4 Tex: TEXCOORD0, uniform sampler2D smp, uniform bool isXBlur) : COLOR
{
	float2 offset = (isXBlur) ? float2(SampleStep.x, 0) : float2(0, SampleStep.y);

	float4 Color = tex2D( smp, Tex.xy );

#if !defined(TEST_DISABLE_BLUR)
	float4 nd0 = tex2D(NormalDepthSampPoint, Tex.xy);
	float depth = nd0.w;

	float weightSum = BlurWeight[0];
	Color *= weightSum;

	[unroll] for(int i = 1; i < 8; i ++) {
		float w = BlurWeight[i];
		float4 cp = tex2D(smp, Tex.xy + offset * i);
		float4 cn = tex2D(smp, Tex.xy - offset * i);
		float4 ndp = tex2D(NormalDepthSampPoint, Tex.xy + offset * i);
		float4 ndn = tex2D(NormalDepthSampPoint, Tex.xy - offset * i);
		float wp = CalcBlurWeight(ndp, nd0) * w;
		float wn = CalcBlurWeight(ndn, nd0) * w;
		Color += cp * wp + cn * wn;
		weightSum += wp + wn;
	}

	Color /= weightSum;
#endif

	return Color;
}
#endif

#define SssKernelSize	0.2 // ブラー半径
static float SssKernelSizeScale = abs(SssKernelSize * matP._11 * (0.5/8.0)) / matP._34;

// sss用のブラー
float4 PS_SSSBlurX( float4 Tex: TEXCOORD0) : COLOR
{
	float4 Color = tex2D( VxDiffuseSampClamp, Tex.xy );

#if !defined(TEST_DISABLE_BLUR)
	float4 Color0 = Color;
	float sss = Color.w;

	float4 nd0 = tex2D(NormalDepthSampPoint, Tex.xy);

	// 距離に応じてサンプリング距離を変える
	float depth = nd0.w;
	int2 iuv = floor(Tex.xy * ViewportSize);
	// float4 ppos = mul(float4(SssKernelSize, 0, depth, 1), matP);
	// float l = abs(ppos.x / ppos.w) * (0.5 / 8.0);
	float l = SssKernelSizeScale / max(depth, 0.1);

	float angle = GetJitterOffset(iuv) * PI;
	float2 offset0 = float2(cos(angle), sin(angle));
	float2 offset = offset0 * l * ViewportAspect;

	Color = float4(Color.rgb, 1) * BlurWeight[0];

	[unroll] for(int i = 1; i < 8; i += 2) {
		float w = BlurWeight[i];
		float4 cp = tex2D(VxDiffuseSampClamp, Tex.xy + offset * i);
		float4 cn = tex2D(VxDiffuseSampClamp, Tex.xy - offset * i);
		float4 ndp = tex2D(NormalDepthSampPoint, Tex.xy + offset * i);
		float4 ndn = tex2D(NormalDepthSampPoint, Tex.xy - offset * i);
		float wp = CalcBlurWeight(ndp, nd0) * w;
		float wn = CalcBlurWeight(ndn, nd0) * w;
		Color += float4(cp.rgb, 1) * wp + float4(cn.rgb, 1) * wn;
	}

	offset = offset0.yx * l * ViewportAspect;
	[unroll] for(int i = 2; i < 8; i += 2) {
		float w = BlurWeight[i];
		float4 cp = tex2D(VxDiffuseSampClamp, Tex.xy + offset * i);
		float4 cn = tex2D(VxDiffuseSampClamp, Tex.xy - offset * i);
		float4 ndp = tex2D(NormalDepthSampPoint, Tex.xy + offset * i);
		float4 ndn = tex2D(NormalDepthSampPoint, Tex.xy - offset * i);
		float wp = CalcBlurWeight(ndp, nd0) * w;
		float wn = CalcBlurWeight(ndn, nd0) * w;
		Color += float4(cp.rgb, 1) * wp + float4(cn.rgb, 1) * wn;
	}

	Color.rgb /= Color.a;
	Color.rgb = lerp(Color0.rgb, Color.rgb, sss * 0.8);
	Color.a = sss;
#endif

	return Color;
}

inline float4 SSSBlurYSub(float2 uv, float4 nd0, float weight)
{
	float4 c = tex2D(BlurSamp0Clamp, uv);
	float4 nd1 = tex2D(NormalDepthSampPoint, uv);
	return float4(c.rgb, 1) * CalcBlurWeight(nd1, nd0) * weight;
}

float4 PS_SSSBlurY( float4 Tex: TEXCOORD0) : COLOR
{
	float4 Color = tex2D(BlurSamp0Clamp, Tex.xy );

#if !defined(TEST_DISABLE_BLUR)
	float4 Color0 = Color;
	float sss = Color.w;
	clip(sss - 1/255.0);

	float4 nd0 = tex2D(NormalDepthSampPoint, Tex.xy);

	Color = float4(Color.rgb, 1);

	#define SSS_BLUR_SUB(ofsx, ofsy, w)	\
		SSSBlurYSub(Tex + SampleStep * float2(ofsx, ofsy), nd0, w)

	Color += SSS_BLUR_SUB(-1,-1, 0.25);
	Color += SSS_BLUR_SUB( 0,-1, 0.5);
	Color += SSS_BLUR_SUB( 1,-1, 0.25);
	Color += SSS_BLUR_SUB(-1, 0, 0.5);
	Color += SSS_BLUR_SUB( 1, 0, 0.5);
	Color += SSS_BLUR_SUB(-1, 1, 0.25);
	Color += SSS_BLUR_SUB( 0, 1, 0.5);
	Color += SSS_BLUR_SUB( 1, 1, 0.25);

	Color.rgb /= Color.a;
	Color.rgb = lerp(Color0.rgb, Color.rgb, sss * 0.8);
	Color.a = sss;
#endif

	return Color;
}


//-----------------------------------------------------------------------------
// テスト用にボクセルを表示する
#if defined(TEST_DISPLAY_VOXELS)
float4 PS_TestDisplay( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.Tex.xy;

#if 0
	//return tex2D(VoxelWorkSamp, texCoord);
	// return tex2D(VoxelAlbedoSamp, texCoord);

	float4 nd = tex2D(NormalDepthSamp, texCoord);
	float depth = (nd.w > 1.0) ? nd.w : (FarDepth * 2.0);
	float3 wpos = ReconstructWPos(IN.Tex.xy, depth).xyz;

	float4 col = 1;
	float3 diff3 = tex2D(VxDiffuseSamp, texCoord).rgb;
	float3 spec3 = tex2D(VxSpecularSamp, texCoord).rgb;
	col.rgb = diff3 + spec3;

	//float4 shadow = tex2D(ShadowSamp, texCoord);
	// return float4(shadow.xxx, 1);
	//float ao = shadow.z;
	//col.rgb *= ao;

	col.a = 1;
	return Gamma4(saturate(col));
#else

	// ボクセルの表示
	float4 nd = tex2D(NormalDepthSamp, texCoord);
	float depth = (nd.w > 1.0) ? nd.w : (FarDepth * 2.0);
	float3 wpos = ReconstructWPos(IN.Tex.xy, depth).xyz;

	float3 v = normalize(wpos - CameraPosition);

	// ボクセル圏外かチェック
	float3 t0 = ((GridCenterPosition - FarDepth * 0.5) - CameraPosition) / v;
	float3 t1 = ((GridCenterPosition + FarDepth * 0.5) - CameraPosition) / v;
	float3 mint = min(t0, t1);
	float3 maxt = max(t0, t1);

	float tbegin = max(max(mint.x, max(mint.y, mint.z)), 0);
	float tend = min(maxt.x, min(maxt.y, maxt.z));
	// 圏外?
	if (tend < tbegin) return float4(0,0,1,1);
	// ボクセル圏までジャンプ
	float3 pos = CameraPosition + tbegin * v;

	// 交差判定用の係数
	float3 invV = 1.0 / v;
	float3 offset1 = (sign(v) * GRID_SIZE_ * 0.5) * invV;
	float3 tnext0 = abs(GRID_SIZE_ * invV);
	float t2 = min(tnext0.x, min(tnext0.y, tnext0.z));

	#define LOOP_COUNT	128

	float4 col = 0;
	for(int i = 0; i < LOOP_COUNT; i++)
	{
		// 現在のチェック位置はどのグリッドに所属するか?
		float3 hitblock = GetAlignedVoxelPosition(pos);
		// グリッドの色と充填度を取得
		float4 col0 = GetPointVoxelColor(hitblock);

		float a0 = col0.a * max(1.0 - col.a, 0);
		col.rgb = (col.rgb * col.a + col0.rgb * a0) / max(col.a + a0, 1e-4);
		col.a = saturate(col.a + a0);

		// ジャンプ距離を求める
		float3 dif = (hitblock - pos.xyz) * invV;
		float3 tnear = offset1 + dif;		// 次のブロックまでの距離
		float3 t0 = (tnear.x < tnear.y) ? tnear.xyz : tnear.yxz;
		t0 = (t0.y < t0.z) ? t0.xyz : ((t0.x < t0.z) ? t0.xzy : t0.zxy);
		pos.xyz += v * ((t0.x + min(t0.y, t0.x + t2)) * 0.5);
	}

	col.a *= 0.75;

	return Gamma4(saturate(col));
#endif

}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////

technique VXGI <
	string Script = 

		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"

		//----------------------------------------------------------
		// 環境マップ
		"RenderDepthStencilTarget=EnvDepthBuffer;"
		"RenderColorTarget0=EnvMap2;			Pass=SynthEnvPass;"

		//----------------------------------------------------------
		// ボクセルの構築
		"RenderDepthStencilTarget=VoxelPackDepthBuffer;"
		"RenderColorTarget1=VoxelPackNormal2;"
		"RenderColorTarget0=VoxelPack2;			Pass=GatherVoxelPass;"

		"RenderDepthStencilTarget=VoxelDepthBuffer;"
		"RenderColorTarget1=VoxelNormalMap;"
		"RenderColorTarget0=VoxelAlbedoMap;		Pass=ConstructPass;"
		"RenderColorTarget1=;"

		// 光っている部分だけを集める
		"RenderDepthStencilTarget=VoxelPackDepthBuffer;"
		"RenderColorTarget0=VoxelPack2;			Pass=GatherEmissiveVoxelPass;"
		"RenderDepthStencilTarget=VoxelDepthBuffer;"
		"RenderColorTarget0=VoxelWorkMap;		Pass=ConstructEmissiveVoxelPass;"

		//----------------------------------------------------------
		// RSMによるボクセルの構築
		"RenderColorTarget0=VoxelMap2;"
		"Clear=Color;" // 不要な場所では速攻でリジェクトしたいので、クリアしておく。
		"Pass=InjectLightVoxelPass;"
		// mipmapの作成
		"RenderColorTarget0=VoxelMap3;			Pass=DownscalePass;"
		"RenderColorTarget0=VoxelMap4;			Pass=DownscalePass2;"

		//----------------------------------------------------------
		// ボクセル間の光の反射
		"RenderColorTarget0=BounceWorkMap;"
		"Clear=Color;" // 不要な場所では速攻でリジェクトしたいので、クリアしておく。
		"Pass=GenerateBouncePass;"
		"RenderColorTarget0=BounceMap;			Pass=GatherBouncePass;"		// Bounceの内容は次フレームでも利用する。
		"RenderColorTarget0=VoxelWorkMap;		Pass=SynthLightPass;"
		"RenderColorTarget0=VoxelMap2;			Pass=CopyPass;"

		// mipmapの作成
		"RenderColorTarget0=VoxelMap3;			Pass=DownscalePass;"
		"RenderColorTarget0=VoxelMap4;			Pass=DownscalePass2;"

		// 各ボクセルでライトプローブを作成
		"RenderColorTarget0=BounceWorkMap;		Pass=GenerateLightProbePass;"
		"RenderColorTarget0=VoxelSHMap;			Pass=GatherLightProbePass;"

		"RenderColorTarget0=BackupVoxelSHMap;	Pass=CopyLightProbePass;"

		//----------------------------------------------------------
		// SSAO + シャドウマップ
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=SSAOWorkMap;		Pass=SSAOPass;"
		"RenderColorTarget0=ShadowMap;			Pass=ShadowMapPass;"
		"RenderColorTarget0=BlurMap0;			Pass=ShadowBlurXPass;"
		"RenderColorTarget0=ShadowMap;			Pass=ShadowBlurYPass;"

		// スペキュラの計算
		#if defined(ENABLE_SPECULAR_RAYCAST)
		"RenderColorTarget0=BlurMap0;			Pass=RaycastSpecularPass;"
		"RenderColorTarget0=BlurMap1;			Pass=BlurXPass;"
		"RenderColorTarget0=VxSpecularMap;		Pass=BlurYPass;"
		#endif
		// 間接光の収集
		"RenderColorTarget0=BlurMap0;"
		"RenderColorTarget1=BlurMap1;			Pass=GatherIndirectLightPass;"

		// 出力用の情報を生成
		"RenderColorTarget0=VxDiffuseMap;"
		"RenderColorTarget1=VxSpecularMap;		Pass=ExportPass;"
		"RenderColorTarget1=;"

		// SSS
		"RenderColorTarget0=BlurMap0;			Pass=SSSBlurXPass;"
		"RenderColorTarget0=VxDiffuseMap;		Pass=SSSBlurYPass;"

		//----------------------------------------------------------
		// リバースリプロジェクション用の退避
		// マトリクスの退避
		"RenderDepthStencilTarget=MatrixDepthBuffer;"
		"RenderColorTarget0=MatrixBufferMap;	Pass=CopyMatrixPass;"

		//----------------------------------------------------------
		// Mainをレンダリング
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		//----------------------------------------------------------
		// 合成
		#if defined(TEST_DISPLAY_VOXELS)
		"Pass=TestDisplayPass;"
		#endif

		//----------------------------------------------------------
		// 後始末
//		"RenderColorTarget0=VoxelNormalMap; Clear=Color;"
//		"RenderColorTarget0=;"
	;
> {
	pass SynthEnvPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;	AlphaTestEnable = false;
		VertexShader = compile vs_3_0 VS_SynthEnv();
		PixelShader  = compile ps_3_0 PS_SynthEnv();
	}

	pass SSAOPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_SSAO();
	}
	pass ShadowMapPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Shadowmap();
	}
	pass ShadowBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_BlurShadow(ShadowSamp, true);
	}
	pass ShadowBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_BlurShadow(BlurSamp0, false);
	}

	pass GatherVoxelPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UnpackVoxel();
		PixelShader  = compile ps_3_0 PS_UnpackVoxel();
	}
	pass ConstructPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_ConstructVoxel();
	}

	pass GatherEmissiveVoxelPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UnpackVoxel();
		PixelShader  = compile ps_3_0 PS_UnpackEmissiveVoxel();
	}
	pass ConstructEmissiveVoxelPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_ConstructEmissiveVoxel();
	}
	pass InjectLightVoxelPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_InjectLightVoxel();
	}

	pass DownscalePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Downscale();
		PixelShader  = compile ps_3_0 PS_Downscale(VoxelSamp2Point);
	}
	pass DownscalePass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Downscale2();
		PixelShader  = compile ps_3_0 PS_Downscale(VoxelSamp3);
	}

	pass GenerateBouncePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_GenerateBounce();
		PixelShader  = compile ps_3_0 PS_GenerateBounce();
	}
	pass GatherBouncePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_GatherBounce();
	}

	pass SynthLightPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_SynthLight();
	}

	pass CopyPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Voxel();
		PixelShader  = compile ps_3_0 PS_CopyVoxel(VoxelWorkSamp);
	}

	pass GenerateLightProbePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_GenerateBounce();
		PixelShader  = compile ps_3_0 PS_GenerateLightProbe();
	}
	pass GatherLightProbePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_VoxelSH();
		PixelShader  = compile ps_3_0 PS_GatherLightProbe();
	}
	pass CopyLightProbePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_VoxelSH();
		PixelShader  = compile ps_3_0 PS_CopyVoxel(VoxelSHSamp);
	}

	pass CopyMatrixPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_CopyMatrix();
		PixelShader  = compile ps_3_0 PS_CopyMatrix();
	}

	#if defined(ENABLE_SPECULAR_RAYCAST)
	pass RaycastSpecularPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_RaycastSpecular();
	}
	pass BlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp0, true);
	}
	pass BlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(BlurSamp1, false);
	}
	#endif

	pass GatherIndirectLightPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_GatherIndirectLight();
	}

	pass SSSBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_SSSBlurX();
	}
	pass SSSBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_SSSBlurY();
	}

	pass ExportPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Export();
	}

	#if defined(TEST_DISPLAY_VOXELS)
	pass TestDisplayPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = TRUE;	AlphaTestEnable = TRUE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_TestDisplay();
	}
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////
