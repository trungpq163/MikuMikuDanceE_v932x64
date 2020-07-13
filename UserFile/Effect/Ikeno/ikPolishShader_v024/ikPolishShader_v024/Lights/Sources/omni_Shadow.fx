//-----------------------------------------------------------------------------/
// ポイントライト・スフィアライト用のシャドウマップ
//-----------------------------------------------------------------------------

#define CTRL_NAME	"(OffscreenOwner)"
#define _DECLARE_PARAM(_t,_var,_item, _ctrl)	\
	_t _var : CONTROLOBJECT < string name = _ctrl; string item = _item;>;
#define DECLARE_PARAM(_t,_var,_item) _DECLARE_PARAM(_t, _var, _item, CTRL_NAME)

#include "../../ikPolishShader.fxsub"
#include "../../Sources/constants.fxsub"

#include "omni_common.fxsub"


float4x4 matPOrig		: PROJECTION;
float4 MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;
bool opadd;		// 加算合成フラグ
bool use_texture;

float4x4 CalcWorldViewMat(float3 vz, float3 vy, float3 pos)
{
	float3 vx = normalize(cross(vy, vz));
	vy = normalize(cross(vz, vx));
	float4x4 matV = float4x4(
		float4(vx.x, vy.x, vz.x, 0),
		float4(vx.y, vy.y, vz.y, 0),
		float4(vx.z, vy.z, vz.z, 0),
		float4(
			-dot(vx, pos),
			-dot(vy, pos),
			-dot(vz, pos),
			1
		));

	return mul(matW, matV);
}

float4x4 CalcProjMat(float4x4 mat)
{
//	mat._11 = mat._22 = 1 / tan(acos(1/3));	// 1.2828
	mat._11 = mat._22 = 1 / 2.8;
	return mat;
}

float3 Vec0 = normalize(float3( 1, 1, 1));
float3 Vec1 = normalize(float3(-1, 1,-1));
float3 Vec2 = normalize(float3( 1,-1,-1));
float3 Vec3 = normalize(float3(-1,-1, 1));

float2 offsets[] = {
	float2(-1, 1) / 2.0,
	float2( 1, 1) / 2.0,
	float2(-1,-1) / 2.0,
	float2( 1,-1) / 2.0
};

static float4x4 matP = CalcProjMat(matPOrig);

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

//-----------------------------------------------------------------------------

struct VS_OUTPUT {
	float4 Pos : POSITION;			  // 射影変換座標
	float3 Tex : TEXCOORD0;
	float4 ShadowMapTex : TEXCOORD1;	// Zバッファテクスチャ
	float4 WPos : TEXCOORD2;
//	float3 Normal : TEXCOORD3;
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,
	uniform float2 offset, uniform float3 v0, uniform float3 v1)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	float4x4 matWV = CalcWorldViewMat(v0, v1, LightPosition);

	Out.Pos = mul(mul(Pos, matWV), matP);
	float w = Out.Pos.w;
	Out.Pos.w *= (opadd ? 0 : 1); // 加算半透明なら無視する
	Out.Pos.xy = (Out.Pos.xy / w * 0.5 + offset) * w;

//	Out.Normal = mul(Normal, (float3x3)matW);

	Out.ShadowMapTex = Out.Pos;
	Out.Tex.xy = Tex;
	Out.WPos = mul(Pos, matW);

	return Out;
}

float4 Basic_PS(VS_OUTPUT IN, uniform float2 offset, uniform bool useTexture) : COLOR0
{
	float3 ppos = IN.ShadowMapTex.xyz / IN.ShadowMapTex.w;
	float2 clipUV = ppos.xyz * offset;
	clip( clipUV.x);
	clip( clipUV.y);
/*
	// 不要な場所は描画しない(この処理自体が不要?)
	float x = abs(frac(ppos.x + 1.0) * 2.0 - 1.0);
	float y = frac(ppos.y + 1.0);
	if (x - 0.2 > y) discard;	// 100/512程度
*/

	float alpha = MaterialDiffuse.a;
	if (useTexture) alpha *= tex2D(ObjTexSampler, IN.Tex).a;
	clip(alpha - AlphaThreshold);

	float3 v = LightPosition - IN.WPos.xyz;
	float depth = length(v);
	// clip(depth - PROJ_NEAR);
	depth = depth / PROJ_FAR;

// VSMが必要な場合、4面体→8面体への変換時に計算を行う
//	return float4(depth, depth * depth, 0, 1);
	return float4(depth, 0, 0, 1);
}


#define	BLENDMODE	ALPHABLENDENABLE = false; CullMode = NONE;

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; >\
	{ \
		pass DrawObject1 { BLENDMODE \
			VertexShader = compile vs_3_0 Basic_VS(offsets[0], Vec0, Vec1); \
			PixelShader  = compile ps_3_0 Basic_PS(float2(-1, 1), tex); \
		} \
		pass DrawObject2 { BLENDMODE \
			VertexShader = compile vs_3_0 Basic_VS(offsets[1], Vec1, Vec2); \
			PixelShader  = compile ps_3_0 Basic_PS(float2( 1, 1), tex); \
		} \
		pass DrawObject3 { BLENDMODE \
			VertexShader = compile vs_3_0 Basic_VS(offsets[2], Vec2, Vec3); \
			PixelShader  = compile ps_3_0 Basic_PS(float2(-1,-1), tex); \
		} \
		pass DrawObject4 { BLENDMODE \
			VertexShader = compile vs_3_0 Basic_VS(offsets[3], Vec3, Vec0); \
			PixelShader  = compile ps_3_0 Basic_PS(float2( 1,-1), tex); \
		} \
	}

//technique MainTec0 < string MMDPass = "object"; > { }
OBJECT_TEC(MainTec0, "object", use_texture)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture)

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

//-----------------------------------------------------------------------------
