// 

// パラメータ
#define	LightDistance	500
#define	LightZMax		1000
#define	LightRange		20

float AlphaThroughThreshold = 0.1;


/////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
//float4x4 matWVP	: WORLDVIEWPROJECTION;
//float4x4 matWV	: WORLDVIEW;
float4x4 matW	: WORLD;

float3 CameraPosition : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float AcsSi  : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si"; >;

float4x4 CreateLightViewMatrix(float3 foward)
{
	const float3 up = float3(0,0,1);
	float3 right = cross(up, foward);

	float3x3 mat;
	mat[2].xyz = foward;
	mat[0].xyz = right;
	mat[1].xyz = normalize(cross(foward, right));
	float3x3 matRot = transpose((float3x3)mat);

	float3 pos = floor(CameraPosition) - foward * LightDistance;

	return float4x4(
		matRot[0], 0,
		matRot[1], 0,
		matRot[2], 0,
		mul(-pos, matRot), 1);
}

static float CameraRange = 1.0 / (LightRange * AcsSi * 0.1);
static float4x4 matP = {
	CameraRange,	0,	0,	0,
	0,	CameraRange,	0,	0,
	0,	0,	1.0 / LightZMax,	0,
	0,	0,	0,	1
};

static float4x4 matV = CreateLightViewMatrix(float3(0,-1,0));
static float4x4 matWVP = mul(matW, mul(matV, matP));


bool opadd;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

float3	LightDirection	: DIRECTION < string Object = "Light"; >;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmisive;

bool	use_toon;
bool	use_texture;		//	テクスチャフラグ

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
	float4 Pos		: POSITION;    // 射影変換座標
	float2 Tex		: TEXCOORD0;
	float4 WPos		: TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL,float2 Tex: TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matWVP );
	Out.Pos.w = opadd ? 0 : Out.Pos.w;

	Out.WPos = mul(Pos, matW);

	Out.Tex = Tex;
	return Out;
}


// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	// α値が閾値以下の箇所は描画しない
	float4 albedo = saturate(float4(AmbientColor, DiffuseColor.a));
	if (use_texture)
	{
		albedo *= tex2D( ObjTexSampler, IN.Tex );
	}

	float alpha = albedo.w;
	clip(alpha - AlphaThroughThreshold);

	return float4(IN.WPos.xyz, 1);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; >
{
    pass DrawObject
    {
		AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
       VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}

technique MainTecBS  < string MMDPass = "object_ss"; >
{
    pass DrawObject {
		AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}

///////////////////////////////////////////////////////////////////////////////////////////////
