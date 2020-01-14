////////////////////////////////////////////////////////////////////////////////////////////////
// ボクセル化用のデータ出力。
//
// 頂点単位でボクセル化する (非推奨)
// 若干高速? 精度が悪い。大きなポリゴンをうまく変換できない。


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 設定ファイル
#include "../settings.fxsub"

/////////////////////////////////////////////////////////////////////////////////////////

float AcsSi : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si"; >;
static float GRID_SIZE_ = (AcsSi * 0.1 * GRID_SIZE);

#define		VOXEL_SIZE		(VOXEL_SIZE_SQRT * VOXEL_SIZE_SQRT)
static float FarDepth = (VOXEL_SIZE * GRID_SIZE_);

#define INV_GRID_SIZE	(1.0 / GRID_SIZE_)
#define INV_2D_VOXEL_SIZE	(1.0 / (VOXEL_SIZE * VOXEL_SIZE_SQRT))

#define		TEX_HEIGHT		(VOXEL_SIZE * VOXEL_SIZE_SQRT)

//-----------------------------------------------------------------------------

// 座法変換行列
float4x4 matW			: WORLD;
float2 ViewportSize : VIEWPORTPIXELSIZE;

float3 CenterPosition : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
static float3 GridCenterPosition = (floor(CenterPosition * INV_GRID_SIZE + VOXEL_SIZE) - VOXEL_SIZE) * GRID_SIZE_;
static float3 GridOffset = floor(GridCenterPosition * INV_GRID_SIZE + VOXEL_SIZE) % VOXEL_SIZE;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
static float3 AmbientColor  = MaterialAmbient + MaterialEmissive;
//static float4 DiffuseColor  = MaterialDiffuse;
static float4 DiffuseColor  = saturate( float4(AmbientColor.rgb, MaterialDiffuse.a));

// 材質モーフ対応
float4	TextureAddValue   : ADDINGTEXTURE;
float4	TextureMulValue   : MULTIPLYINGTEXTURE;

float3	LightSpecular	 	: SPECULAR  < string Object = "Light"; >;

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

static float3 LightColor = Degamma(saturate(LightSpecular)) * 2.5 / 1.5;

bool	use_texture;	//	テクスチャフラグ
bool	use_toon;		//	トゥーンフラグ
bool	parthf;			// パースペクティブフラグ
bool	transp;			// 半透明フラグ
bool	spadd;			// スフィアマップ加算合成フラグ
bool	opadd;

#define SKII1	1500
#define SKII2	8000
#define Toon	 3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);
//sampler DefSampler : register(s0);

shared texture2D VoxelPackNormal: RENDERCOLORTARGET;


////////////////////////////////////////////////////////////////////////////////////////////////
//

#define	PI	(3.14159265359)


////////////////////////////////////////////////////////////////////////////////////////////////
// 

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;
	float3 Normal	: TEXCOORD0;
	float2 Tex		: TEXCOORD1;
	float3 GridPos	: TEXCOORD3;
};

struct PS_OUT_MRT
{
	float4 Color	: COLOR0;
	float4 Normal	: COLOR1;
	float Depth		: DEPTH;
};

//-----------------------------------------------------------------------
// キャラはボクセルに比べて小さいので頂点単位で処理する

BufferShadow_OUTPUT DrawPoint_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, int index: _INDEX, 
	uniform bool useTexture)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	float3 vpos = floor((mul( Pos, matW ).xyz - GridCenterPosition + FarDepth * 0.5) * INV_GRID_SIZE - 0.5);

	int mode = index % 3;
	int index2 = index / 3;

	float3 coef = 0;
	if (mode == 0)
	{
		coef = float3(vpos.xy, vpos.z + GridOffset.z);
	}
	else if (mode == 1)
	{
		coef = float3(vpos.zy, vpos.x + GridOffset.x);
		coef.x = (VOXEL_SIZE - 1) - coef.x;
	}
	else
	{
		coef = float3(vpos.zx, vpos.y + GridOffset.y);
	}

	float w = coef.z;
	float wl = w % VOXEL_SIZE_SQRT;
	float wh0 = floor(w / VOXEL_SIZE_SQRT) % VOXEL_SIZE_SQRT;
	float wh = VOXEL_SIZE_SQRT - wh0; // - 1;
	// MEMO: indexに応じて意図的に奥行を位置をいじる?
	float u = coef.x * VOXEL_SIZE_SQRT + wl;
	float v = coef.y * VOXEL_SIZE_SQRT + wh;

	// 画面外?
	float isInRange = (clamp(vpos.x, 0, VOXEL_SIZE - 1) == vpos.x)
					* (clamp(vpos.y, 0, VOXEL_SIZE - 1) == vpos.y)
					* (clamp(vpos.z, 0, VOXEL_SIZE - 1) == vpos.z);
	// if (mode!=0) isInRange = 0;

	Out.Pos = float4(float2(u, v) * INV_2D_VOXEL_SIZE * 2 - 1, 1, isInRange);
	// 1つのテクスチャを3つに分割。3面図のそれぞれを描画する
	Out.Pos.y = (Out.Pos.y + (3 - mode * 2) * Out.Pos.w) * (1.0 / 4.0);

	// ボクセルグリッド決定用の情報
	Out.GridPos.x = (wh0 * VOXEL_SIZE_SQRT + wl) * 4 + mode;
	Out.GridPos.y = index2 % 64;
	Out.GridPos.z = floor(index2 / 64);

	Out.Normal = normalize( mul( Normal, (float3x3)matW ) );
	Out.Tex = Tex;

	return Out;
}

// ピクセルシェーダ
PS_OUT_MRT DrawPoint_PS(BufferShadow_OUTPUT IN, uniform bool useTexture)
{
	int gridDist = IN.GridPos.y;
	int hit8 = gridDist;
	int hit4 = (gridDist % 4 + (gridDist / 8) % 4);
	int hit2 = (gridDist % 2 + (gridDist / 8) % 2);
	// グリッド内での位置に応じて優先度をつける。
	float priority = (hit8 != 0) + (hit4 != 0) + (hit2 != 0);
	// 優先度が高いほど手前に表示する。
	float depth = (priority * 256.0 + (IN.GridPos.z % 256)) * (1.0 / (256*4));
	// 所属ボクセル識別用のid
	int patternNo = IN.GridPos.x;

	float4 Color = DiffuseColor;
	if ( useTexture ) {
		// テクスチャ適用
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		// 材質モーフ対応
		float4 MorphColor = TexColor * TextureMulValue + TextureAddValue;
		float MorphRate = TextureMulValue.a + TextureAddValue.a;
		TexColor.rgb = lerp(1, MorphColor, MorphRate).rgb;
		Color *= TexColor;
	}

	clip(Color.a - AlphaThreshold);

	float emissiveIntensity = 0;
	#if defined(FORCE_EMISSIVE)
		emissiveIntensity = rgb2gray(Color.rgb);
	#else
		emissiveIntensity = opadd ? rgb2gray(Color.rgb) : emissiveIntensity;
	#endif
	int attribute = floor(saturate(emissiveIntensity) * 127) * 2 + (opadd ? 0 : 1);

	Color.rgb = Degamma(Color.rgb);
	Color.a = attribute * (1.0 / 255.0);

	PS_OUT_MRT Out;
	Out.Color = Color;
	Out.Normal = float4(normalize(IN.Normal), patternNo);
	Out.Depth = 0;

	return Out;
}

#define	RENDER_MODE_SETTINGS	AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE; FillMode = Point;

#define OBJECT_TEC_POINT(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; \
	string Script = \
		"RenderColorTarget0=; " \
		"RenderColorTarget1=VoxelPackNormal;" \
		"Pass=DrawObject;" \
		"RenderColorTarget1=;" \
	; \
	> { \
		pass DrawObject { \
			RENDER_MODE_SETTINGS \
			VertexShader = compile vs_3_0 DrawPoint_VS(tex); \
			PixelShader  = compile ps_3_0 DrawPoint_PS(tex); \
		} \
	}

OBJECT_TEC_POINT(PointTec0, "object", use_texture)
OBJECT_TEC_POINT(PointTecBS0, "object_ss", use_texture)


///////////////////////////////////////////////////////////////////////////////////////////////
