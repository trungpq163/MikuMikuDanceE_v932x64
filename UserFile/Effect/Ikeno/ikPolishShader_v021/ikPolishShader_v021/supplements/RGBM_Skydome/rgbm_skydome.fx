////////////////////////////////////////////////////////////////////////////////////////////////
//
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define RGBM_SCALE_FACTOR	6


// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);
sampler DefSampler : register(s0);

////////////////////////////////////////////////////////////////////////////////////////////////
//

// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;
	float2 Tex		: TEXCOORD1;
};

BufferShadow_OUTPUT DrawObject_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Tex = Tex;
	return Out;
}

float4 DrawObject_PS(BufferShadow_OUTPUT IN) : COLOR
{
	float4 Color = tex2D( ObjTexSampler, IN.Tex );
	Color.rgb = Color.rgb * Color.a * RGBM_SCALE_FACTOR;
	Color.a = 1;
	Color = Gamma4(Color);
	return Color;
}

#define OBJECT_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 DrawObject_VS(); \
			PixelShader  = compile ps_3_0 DrawObject_PS(); \
		} \
	}


OBJECT_TEC(MainTec, "object")
OBJECT_TEC(MainTecBS, "object_ss")

///////////////////////////////////////////////////////////////////////////////////////////////
