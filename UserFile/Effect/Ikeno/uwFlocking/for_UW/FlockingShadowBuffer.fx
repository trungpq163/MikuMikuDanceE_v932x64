////////////////////////////////////////////////////////////////////////////////////////////////
//
// 仮想光源からモデルまでの距離を計測する。
// (各ピクセルで)もっとも手前にあるモデルより後にあるモデルには光が当たらない。
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


const float ShadowAlphaThreshold = 0.6;

///////////////////////////////////////////////////////////////////////////////////////////////

#include "FlockingUWCoomons.fxsub"

float4x4 WorldMatrix              : WORLD;

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



struct VS_OUTPUT
{
    float4 Pos       : POSITION;    // 射影変換座標
    float4 Tex       : TEXCOORD1;   // テクスチャ
    float3 Normal    : TEXCOORD2;   // 法線
    float4 ShadowMapTex	: TEXCOORD3;   // ビュー座標
    float4 Color     : COLOR0;      // ディフューズ色
};


float4 GetWorldPosition(float4 pos, inout VS_OUTPUT Out)
{
	Out.Pos = mul( pos, matWaveVP );
	Out.ShadowMapTex = Out.Pos;

	return pos;
}


float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
	float alpha = MaterialDiffuse.a;
	if(useTexture) alpha *= tex2D(ObjTexSampler, IN.Tex.xy).a;
	clip(alpha - ShadowAlphaThreshold);

	float depth = IN.ShadowMapTex.z / IN.ShadowMapTex.w;
	return float4(depth, 0, 0, 1);
}


#define ENABLE_COLOR 0
#include "FlockingBody.fxsub"

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < \
		string MMDPass = mmdpass; \
		bool UseTexture = tex; \
		string Script = LOOPSCRIPT_OBJECT; \
	> { \
		pass Basic { \
			VertexShader = compile vs_3_0 Basic_VS(tex, false, false); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTec1, "object", true)

OBJECT_TEC(MainTecBS0, "object_ss", false)
OBJECT_TEC(MainTecBS1, "object_ss", true)



///////////////////////////////////////////////////////////////////////////////////////////////
