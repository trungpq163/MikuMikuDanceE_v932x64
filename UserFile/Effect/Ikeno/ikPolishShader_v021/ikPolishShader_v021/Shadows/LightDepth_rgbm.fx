////////////////////////////////////////////////////////////////////////////////////////////////
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////

#include "../ikPolishShader.fxsub"

// 各シャドウマップの間の境界の幅
#define BorderOffset	(1.0 / SHADOW_TEX_SIZE)

float4x4 matInvV		: VIEWINVERSE;
float4x4 matInvP		: PROJECTIONINVERSE;

float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float3	CameraDirection	: DIRECTION  < string Object = "Camera"; >;

#include "shadow_common.fxsub"

////////////////////////////////////////////////////////////////////////////////////////////////
// 

float4x4 matW			: WORLD;
static float4x4 matLightWVP = mul(mul(matW, matLightVs), matLightPs);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
bool opadd;		// 加算合成フラグ

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU  = WRAP; ADDRESSV  = WRAP;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// 

struct DrawObject_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float4 Tex		: TEXCOORD0;	// テクスチャ
	float4 PPos		: TEXCOORD1;
};

DrawObject_OUTPUT DrawObject_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0,
	uniform float4 args)
{
	float4 frustumInfo = CreateFrustumFromProjection();
	float4 lightParamWork = CreateLightProjParameter(frustumInfo, args.x, args.y);

	float4 ppos = mul( Pos, matLightWVP );
	ppos.xy = ppos.xy * lightParamWork.xy + lightParamWork.zw;
	ppos.xy = ppos.xy * 0.5 + (args.zw * 0.5f);
	ppos.z = max(ppos.z, LightZMin / LightZMax);	// depth clamping
	ppos.w *= (opadd ? 0 : 1); // 加算半透明なら無視する

	DrawObject_OUTPUT Out;
	Out.PPos = Out.Pos = ppos;
	Out.Tex = float4(Tex, args.zw);

	return Out;
}

float4 DrawObject_PS(DrawObject_OUTPUT IN, uniform bool useTexture) : COLOR
{
	float2 clipUV = (IN.PPos.xy / IN.PPos.w - BorderOffset) * IN.Tex.zw;
	clip( clipUV.x);
	clip( clipUV.y);
/*
	float alpha = MaterialDiffuse.a;
	if ( useTexture ) alpha *= tex2D( ObjTexSampler, IN.Tex.xy ).a;
	clip(alpha - CasterAlphaThreshold);
*/
	return float4(IN.PPos.z, 0, 0, 1);
}


#if defined(ENABLE_DOUBLE_SIDE_SHADOW) && ENABLE_DOUBLE_SIDE_SHADOW > 0
#define	SetCullMode		CullMode = NONE;
#else
#define	SetCullMode
#endif

#define ARGS(x,y, u,v)	float4(SplitPositions[x], SplitPositions[y], u,v)

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; \
	> { \
		pass DrawObject0 { \
			SetCullMode \
			AlphaBlendEnable = FALSE;	AlphaTestEnable = TRUE; \
			VertexShader = compile vs_3_0 DrawObject_VS( ARGS(0, 1, -1, 1)); \
			PixelShader  = compile ps_3_0 DrawObject_PS( tex); \
		} \
		pass DrawObject1 { \
			SetCullMode \
			AlphaBlendEnable = FALSE;	AlphaTestEnable = TRUE; \
			VertexShader = compile vs_3_0 DrawObject_VS( ARGS(1, 2,  1, 1)); \
			PixelShader  = compile ps_3_0 DrawObject_PS( tex); \
		} \
		pass DrawObject2 { \
			SetCullMode \
			AlphaBlendEnable = FALSE;	AlphaTestEnable = TRUE; \
			VertexShader = compile vs_3_0 DrawObject_VS( ARGS(2, 3,-1,-1)); \
			PixelShader  = compile ps_3_0 DrawObject_PS( tex); \
		} \
		pass DrawObject3 { \
			SetCullMode \
			AlphaBlendEnable = FALSE;	AlphaTestEnable = TRUE; \
			VertexShader = compile vs_3_0 DrawObject_VS( ARGS(3, 4, 1,-1)); \
			PixelShader  = compile ps_3_0 DrawObject_PS(tex); \
		} \
	}


technique DepthTec0 < string MMDPass = "object"; >{}

bool use_texture;
OBJECT_TEC(DepthTecBS2, "object_ss", use_texture)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
