// セルフシャドウ無視、陰影あり


// パラメータ宣言
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

// 座法変換行列
float4x4 matWVP	: WORLDVIEWPROJECTION;
float4x4 matWV	: WORLDVIEW;
float4x4 matW	: WORLD;

float4x4 matWVPLight : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection	: DIRECTION < string Object = "Light"; >;
float3   LightSpecular	 : SPECULAR  < string Object = "Light"; >;

float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

static float LightVolume = rgb2gray(LightSpecular);


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler DefSampler : register(s0);
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

bool	use_texture;		// テクスチャ使用

bool	 parthf;   // パースペクティブフラグ
#define SKII1	1500
#define SKII2	8000

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

float3   CameraPosition	: POSITION  < string Object = "Camera"; >;


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
	float4 Pos		: POSITION;    // 射影変換座標
	float4 ZCalcTex : TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;
	float3 Normal   : TEXCOORD2;	// 法線
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, matWVP );
	Out.Tex = Tex;

	// 頂点法線
	Out.Normal = normalize( mul( Normal, (float3x3)matW ) );

	// ライト視点によるワールドビュー射影変換
	Out.ZCalcTex = mul( Pos, matWVPLight );

	return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN, uniform bool bSahdow ) : COLOR
{
	float alpha = MaterialDiffuse.a;
	if (use_texture)
	{
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
	}

	float3 L = -LightDirection;
	float3 N = normalize(IN.Normal);
	float shadow = saturate(dot(N,L));

	return float4(shadow * LightVolume, 0,0, alpha);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false);
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true);
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}

///////////////////////////////////////////////////////////////////////////////////////////////
