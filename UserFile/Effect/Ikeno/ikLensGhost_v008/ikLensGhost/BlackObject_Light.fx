// パラメータ宣言

float FrameScale = 0.8;


// 座法変換行列
//float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float4	MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;

float4x4 WorldViewMatrix	: WORLDVIEW;
float4x4 ViewMatrix			: VIEW;
float4x4 ProjMatrix			: PROJECTION;
float3 LightDirection	: DIRECTION < string Object = "Light"; >;

/*
inline float3 GetTargetPosition()
{
	return -LightDirection * 32767;
}
static float LightDistance = distance(GetTargetPosition(), CameraPosition);
*/

float4x4 CalcViewProjMatrix(float4x4 v, float4x4 p)
{
	p._11_22 *= FrameScale;
	return mul(v, p);
}

float4x4 CreateWorldViewMatrix(float4x4 w, float4x4 v)
{
	float3 vz = normalize(-LightDirection);
	float3 vx = normalize(cross(v._12_22_32, vz));
	float3 vy = normalize(cross(vz, vx));

	float4x4 mat = float4x4(
		vx.x, vy.x, vz.x, 0,
		vx.y, vy.y, vz.y, 0,
		vx.z, vy.z, vz.z, 0,
		0,0,0, 1);
	mat[3].xyz = mul(-CameraPosition, (float3x3)mat);

	return mul(w, mat);
}

static float4x4 WorldViewProjMatrix = 
	CalcViewProjMatrix(CreateWorldViewMatrix(WorldMatrix, ViewMatrix), ProjMatrix);




// MMD本来のsamplerを上書きしないための記述です。削除不可。
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
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex 		  : TEXCOORD0;    // テクスチャ座標
//    float  Z 		  : TEXCOORD1;    // Z値
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    // Out.Z = length(CameraPosition - mul( Pos, WorldMatrix ));
    Out.Tex = Tex;

    return Out;
}

float4 Basic_PS( VS_OUTPUT IN, uniform bool useTexture ) : COLOR0
{
	float color = 1; // (IN.Z < LightDistance);
	float alpha = MaterialDiffuse.a;

	if ( useTexture ) {
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
	}

	return float4(color, 0,0, alpha);
}

#define OBJECT_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Basic_VS(); \
			PixelShader  = compile ps_3_0 Basic_PS(tex); \
		} \
	}


OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTec1, "object", true)
OBJECT_TEC(MainTecBS0, "object_ss", false)
OBJECT_TEC(MainTecBS1, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}

///////////////////////////////////////////////////////////////////////////////////////////////
