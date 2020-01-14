//-----------------------------------------------------------------------------
// 方向有りライト用のシャドウマップ
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// パラメータ宣言

#define CTRL_NAME	"(OffscreenOwner)"
#define _DECLARE_PARAM(_t,_var,_item, _ctrl)	\
	_t _var : CONTROLOBJECT < string name = _ctrl; string item = _item;>;
#define DECLARE_PARAM(_t,_var,_item) _DECLARE_PARAM(_t, _var, _item, CTRL_NAME)

#include "../../ikPolishShader.fxsub"
#include "../../Sources/constants.fxsub"
#include "directional_common.fxsub"

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
bool opadd;		// 加算合成フラグ
bool use_texture;

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

//-----------------------------------------------------------------------------

struct VS_OUTPUT {
	float4 Pos : POSITION;			  // 射影変換座標
	float2 Tex : TEXCOORD0;
	float4 ShadowMapTex : TEXCOORD1;	// Zバッファテクスチャ
//	float4 WPos : TEXCOORD2;	// Zバッファテクスチャ
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matLightWVP );
	Out.ShadowMapTex = Out.Pos;

	Out.Pos.w *= (opadd ? 0 : 1); // 加算半透明なら無視する

	Out.Tex.xy = Tex;
	// Out.WPos = mul( Pos, matW );

	return Out;
}

float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
	float alpha = MaterialDiffuse.a;
	if(useTexture) alpha *= tex2D(ObjTexSampler, IN.Tex).a;
	clip(alpha - AlphaThreshold);

//	float depth = distance(IN.WPos, LightPosition) / PROJ_FAR;
	float depth = IN.ShadowMapTex.w / PROJ_FAR;

	return float4(depth, 0, 0, 1);
}

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; \
	> { \
		pass DrawObject { \
			ALPHABLENDENABLE = false; \
			VertexShader = compile vs_3_0 Basic_VS(); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture)

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

//-----------------------------------------------------------------------------
