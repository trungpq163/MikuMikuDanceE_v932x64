//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
// パラメータ宣言

#define USE_VIEWPORT_SIZE		0
// 0:スクリーンサイズを指定。
// 1:スクリーンサイズ=画面サイズ

// USE_VIEWPORT_SIZE = 0の場合の、スクリーンのサイズ
float2 ScreenSize = float2(320, 180);

// ドットサイズ
// 現在のテクスチャ(matrix.png)は4x4ドットで1pixel分になっている。
float DotScale = 4.0;


//-----------------------------------------------------------------------------

bool bLinearBegin : CONTROLOBJECT < string name = "ikLinearBegin.x"; >;
bool bLinearEnd : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;
static bool bOutputLinear = (bLinearEnd && !bLinearBegin);

float2 ViewportSize : VIEWPORTPIXELSIZE;

#if USE_VIEWPORT_SIZE == 0
#define	SCREEN_SIZE		(ScreenSize * DotScale)
#else
#define	SCREEN_SIZE		(ViewportSize * DotScale)
#endif

// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
// ライト色
float3	LightDiffuse		: DIFFUSE	< string Object = "Light"; >;
float3	LightAmbient		: AMBIENT	< string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmissive;

// テクスチャ材質モーフ値
float4	TextureAddValue	: ADDINGTEXTURE;
float4	TextureMulValue	: MULTIPLYINGTEXTURE;
float4	SphereAddValue	: ADDINGSPHERETEXTURE;
float4	SphereMulValue	: MULTIPLYINGSPHERETEXTURE;

bool	use_texture;		// テクスチャフラグ


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = POINT;	MAGFILTER = POINT;	MIPFILTER = POINT;
	ADDRESSU  = CLAMP;	ADDRESSV  = CLAMP;
};

texture MatrixTex < string ResourceName = "matrix.png"; >;
sampler MatrixSamp = sampler_state {
	Texture = <MatrixTex>;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
float2 MatrixTextureSize = float2(128, 128);

// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;

float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float4 Degamma(float4 col) { col.rgb = Degamma(col.rgb); return col; }
float4 Gamma(float4 col) { col.rgb = Gamma(col.rgb); return col; }


//-----------------------------------------------------------------------------
// オブジェクト描画

struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 Color	: COLOR0;		// ディフューズ色
};

VS_OUTPUT Object_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool useTexture)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Color.rgb = AmbientColor + DiffuseColor.rgb;
	Out.Color.a = DiffuseColor.a;
	Out.Color = Degamma4(saturate( Out.Color));

	Out.Tex = Tex;

	return Out;
}


float4 Object_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR
{
	float4 Color = IN.Color;

	if ( useTexture ) {
		float2 uv = (floor(IN.Tex * SCREEN_SIZE) + 0.5) / (SCREEN_SIZE);
		float4 TexColor = tex2D( ObjTexSampler, uv );

		float3 tint = tex2D(MatrixSamp, IN.Tex * SCREEN_SIZE / MatrixTextureSize).rgb;
		TexColor.rgb *= tint;

		TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
		Color *= Degamma4(TexColor);
	}

	Color.rgb = bOutputLinear ? Color.rgb : Gamma(Color.rgb);

	return Color;
}


#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Object_VS(tex); \
			PixelShader  = compile ps_3_0 Object_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

//-----------------------------------------------------------------------------
