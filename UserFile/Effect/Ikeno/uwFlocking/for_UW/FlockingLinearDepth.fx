// カメラからの距離を格納する
// 仮想光源との陰影計算の結果も格納する。

// 半透明を無視する閾値
const float ShadowAlphaThreshold = 0.6;

///////////////////////////////////////////////////////////////////////////////////////////////

#include "FlockingUWCoomons.fxsub"

// 座法変換行列
float4x4 matVP	: VIEWPROJECTION;
float4x4 matV	: VIEW;
float4x4 WorldMatrix              : WORLD;

float4   MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;
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
// 

struct VS_OUTPUT
{
    float4 Pos       : POSITION;    // 射影変換座標
    float4 Tex       : TEXCOORD1;   // テクスチャ
    float3 Normal    : TEXCOORD2;   // 法線
    float3 VPos      : TEXCOORD3;   // ビュー座標
    float4 Color     : COLOR0;      // ディフューズ色
};


float4 GetWorldPosition(float4 pos, inout VS_OUTPUT Out)
{
	Out.Pos = mul( pos, matVP );
	Out.VPos = mul( pos, matV).xyz;
	return pos;
}


// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN, uniform bool useTexture) : COLOR
{
	float alpha = MaterialDiffuse.a;
	if (useTexture) alpha *= tex2D( ObjTexSampler, IN.Tex.xy ).a;
	clip(alpha - ShadowAlphaThreshold);

	float distance = length(IN.VPos);

	// float3 L = normalize(LightPosition - IN.WPos);
	float3 L = -WaveLightDirection;
	float NL = saturate(dot(IN.Normal, L));
	// 距離に応じて減衰
	// NL *= saturate(100.0 / distance);

	return float4(distance / FAR_Z, NL, 0, 1);
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
