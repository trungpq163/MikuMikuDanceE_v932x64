
// モデルテクスチャのアルファを見て抜くかどうか。
// コレ以下の半透明度なら透明扱い
const float AlphaThreshold = 0.3;
#define USE_TEXTURE_ALPHA

// float FrameScale = 1.0;

////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 座法変換行列
float4x4 matW		: WORLD;
float4x4 matV		: VIEW;
float4x4 matP		: PROJECTION;
float4x4 matWV		: WORLDVIEW;
float4x4 matWVP		: WORLDVIEWPROJECTION;
/*
float4x4 CalcWVP(float4x4 wv, float4x4 p)
{
	p._11_22 *= FrameScale;
	return mul(wv, p);
}
static float4x4 matWVP = CalcWVP(matWV, matP);
*/

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT
{
	float4 Pos		: POSITION;
	float3 Normal	: TEXCOORD0;
	float2 Tex		: TEXCOORD1;
	// float4 WPos		: TEXCOORD2;
	float4 VPos		: TEXCOORD3;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex: TEXCOORD0, uniform bool useTexture)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, matWVP );
	Out.Normal = mul(Normal,(float3x3)matW);
	Out.Tex = Tex;

	// Out.WPos = mul( Pos, matW );
	Out.VPos = mul(Pos, matWV);

	return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN, uniform bool useTexture) : COLOR
{
	float alpha = MaterialDiffuse.a;
	#ifdef USE_TEXTURE_ALPHA
	if ( useTexture ) {
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
	}
	#endif

	clip(alpha - AlphaThreshold);

	const float3 N = normalize(IN.Normal);
	return float4(N, length(IN.VPos.xyz));
}

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; \
	> { \
		pass DrawObject { \
			AlphaTestEnable = FALSE; \
			AlphaBlendEnable = FALSE; \
			VertexShader = compile vs_3_0 Basic_VS(tex); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTec1, "object", true)
OBJECT_TEC(MainTecBS0, "object_ss", false)
OBJECT_TEC(MainTecBS1, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
