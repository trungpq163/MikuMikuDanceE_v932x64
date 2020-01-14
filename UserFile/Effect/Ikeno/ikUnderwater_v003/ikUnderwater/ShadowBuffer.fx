////////////////////////////////////////////////////////////////////////////////////////////////
//
// 仮想光源からモデルまでの距離を計測する。
// (各ピクセルで)もっとも手前にあるモデルより後にあるモデルには光が当たらない。
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

const float ShadowAlphaThreshold = 0.6;

///////////////////////////////////////////////////////////////////////////////////////////////

#include "Settings.fxsub"
#include "Commons.fxsub"

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
	float4 Pos : POSITION;			  // 射影変換座標
	float2 Tex : TEXCOORD0;
	float4 ShadowMapTex : TEXCOORD1;	// Zバッファテクスチャ
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matWaveWVP );
	Out.ShadowMapTex = Out.Pos;
	Out.Tex = Tex;
	return Out;
}

float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
	float alpha = MaterialDiffuse.a;
	if(useTexture) alpha *= tex2D(ObjTexSampler, IN.Tex).a;
	clip(alpha - ShadowAlphaThreshold);

	float depth = IN.ShadowMapTex.z / IN.ShadowMapTex.w;
	return float4(depth, 0, 0, 1);
}

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; \
	> { \
		pass DrawObject { \
			ALPHABLENDENABLE = false; \
			CullMode = NONE; \
			VertexShader = compile vs_3_0 Basic_VS(); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTec1, "object", true)

OBJECT_TEC(MainTecBS0, "object_ss", false)
OBJECT_TEC(MainTecBS1, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
