////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 抜きテクスチャを無視するα値の上限
// const float AlphaThroughThreshold = 0.2;

////////////////////////////////////////////////////////////////////////////////////////////////

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 ProjMatrix				  : PROJECTION;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
float4x4 matWV	: WORLDVIEW;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
// 材質モーフ対応
float4	TextureAddValue   : ADDINGTEXTURE;
float4	TextureMulValue   : MULTIPLYINGTEXTURE;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


inline float4 GetTextureColor(float2 uv)
{
	float4 TexColor = tex2D( ObjTexSampler, uv);
	TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
	return TexColor;
}


///////////////////////////////////////////////////////////////////////////////////////////////

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float4 PPos		: TEXCOORD2;	// Position
	float3 Normal	: TEXCOORD3;
};


////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0
	, uniform bool useTexture)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	Out.Pos = mul(Pos,WorldViewProjMatrix);
	Out.PPos = Out.Pos;

	Out.Tex = Tex;
	Out.Normal = mul(Normal, (float3x3)matWV).xyz;

	return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture) : COLOR
{
	// α値が閾値以下の箇所は描画しない
	float alpha = MaterialDiffuse.a;
	if ( useTexture ) {
		alpha *= GetTextureColor( IN.Tex ).a;
	}

	// clip(alpha - AlphaThroughThreshold);

	float3 N = normalize(IN.Normal);
	float nz = abs(N.z);
	nz = 1.0 - (1.0 - nz) * (1.0 - nz);

	// 遠いほどデフュージョンの影響力を弱くする？
#if 0
	float w = 100.0 / IN.PPos.z;

	nz = (1.0 - nz) * saturate(w);

	return float4(1.0 - nz, 0, 0, alpha);
#else
	return float4(nz, 0, 0, alpha);
#endif
}



// オブジェクト描画用テクニック
#define BASICSHADOW_TEC(name, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BufferShadow_VS(tex); \
			PixelShader  = compile ps_3_0 BufferShadow_PS(tex); \
		} \
	}

BASICSHADOW_TEC(BTec0, "object", false)
BASICSHADOW_TEC(BTec1, "object", true)

BASICSHADOW_TEC(BSTec0, "object_ss", false)
BASICSHADOW_TEC(BSTec1, "object_ss", true)

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
