//-----------------------------------------------------------------------------
// ゴッドレイ用のマスク作成

float FrameScale = 0.8;

float4x4 matWV			: WORLDVIEW;
float4x4 matP			: PROJECTION;
float4	MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;

float4x4 CalcViewProjMatrix(float4x4 wv, float4x4 p)
{
	p._11_22 *= FrameScale;
	return mul(wv, p);
}
static float4x4 matWVP = CalcViewProjMatrix(matWV, matP);

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

bool	use_texture;		// テクスチャ使用

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};

struct VS_OUTPUT
{
	float4 Pos		: POSITION;
	float2 Tex 		: TEXCOORD0;
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matWVP );
	Out.Tex = Tex;
	return Out;
}

float4 Basic_PS( VS_OUTPUT IN, uniform bool useTexture ) : COLOR0
{
	float alpha = MaterialDiffuse.a;
	if ( useTexture ) alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
	return float4(0, 0,0, alpha);
}

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Basic_VS(); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
