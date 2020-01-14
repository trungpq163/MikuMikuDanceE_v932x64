////////////////////////////////////////////////////////////////////////////////////////////////
// ikDepthBright.fx
// ikボケ.fxのために、線形の深度情報と(フェイクの)明るさ情報を出力する。
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 抜きテクスチャを無視するα値の上限
const float AlphaThroughThreshold = 0.2;

// 明るい部分を強調するか? (0:しない、1:する)
#define EMPHASIS_BRIGHTNESS		1

//シャドウマップサイズ
//#define SHADOWMAP_SIZE 1024
#define SHADOWMAP_SIZE 4096

// なにもない描画しない場合の、背景までの距離
// これを弄る場合、ikボケ.fxの同じ値も変更する必要がある。
#define FAR_DEPTH		1000

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
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);


///////////////////////////////////////////////////////////////////////////////////////////////

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float4 VPos		: TEXCOORD2;	// Position

#if defined(EMPHASIS_BRIGHTNESS) && EMPHASIS_BRIGHTNESS > 0
	float3 Normal	: TEXCOORD3;	// 法線
	float3 Eye		: TEXCOORD4;	// カメラとの相対位置
	float4 SpTex	: TEXCOORD5;	// スフィアマップテクスチャ座標
#endif
};


///////////////////////////////////////////////////////////////////////////////////////////////
// デフューズの計算
float CalcDiffuse(float3 L, float3 N, float3 V)
{
	const float NL = dot(N,L);
	return saturate(NL);
}

//スペキュラの計算
float CalcSpecular(float3 L, float3 N, float3 V, float2 coef)
{
	float3 H = normalize(L + V);
	float Specular = saturate(dot( H, N ));
	return pow(Specular, coef.y) * coef.x;
}

// 適当なグレースケール化
float gray(float3 color)
{
	return (color.r + color.g + color.b) / 3.0;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 

float GetShadowDepth(float2 TransTexCoord)
{
	return tex2D(DefSampler,TransTexCoord).r;
}

//-----------------------------------------------------------------------
// 光源が遮蔽されているかどうか調べる
// @return	0:完全に遮蔽されている。1:遮蔽されていない。
float CalcShadowRate(float2 TransTexCoord, float depth)
{
	float comp = 1;
	if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
		;	// シャドウバッファ外
	} else {
		float sum = 0;
		float k = (parthf) ? SKII2 * TransTexCoord.y : SKII1;

		float depthTest = max(depth - GetShadowDepth(TransTexCoord), 0);
		comp = 1 - saturate(depthTest * k - 0.3);
	}

	return comp;
}




////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useSelfshadpw)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	Out.Pos = mul(Pos,WorldViewProjMatrix);
	Out.VPos = mul(Pos,matWV);

	Out.Tex = Tex;

#if defined(EMPHASIS_BRIGHTNESS) && EMPHASIS_BRIGHTNESS > 0
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfshadpw)
	{
		Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);
	}

	if ( useSphereMap ) {
		float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}

	float smoothness = log2(SpecularPower) / 16.0;
	Out.SpTex.z = smoothness;
	Out.SpTex.w = SpecularPower;
#endif

	return Out;
}


// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useSelfshadpw) : COLOR
{
	// α値が閾値以下の箇所は描画しない
	if ( useTexture ) {
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex ).a;
		float alpha = TexColor.a;
		clip(alpha - AlphaThroughThreshold);
	}

	float distance = length(IN.VPos);

#if defined(EMPHASIS_BRIGHTNESS) && EMPHASIS_BRIGHTNESS > 0
	const float3 N = normalize(IN.Normal);
	const float3 V = normalize(IN.Eye);
	const float3 L = normalize(-LightDirection);

	float bright = CalcDiffuse(L, N, V);

	if (useSelfshadpw)
	{
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord = float2(1.0f + IN.ZCalcTex.x, 1.0f - IN.ZCalcTex.y) * 0.5;
		float shadow = CalcShadowRate(TransTexCoord, IN.ZCalcTex.z);
		bright = bright * shadow;
	}

	float Specular = CalcSpecular(L, N, V, IN.SpTex.zw);
	if ( useSphereMap && spadd) {
		float4 TexColor = tex2D(ObjSphareSampler, IN.SpTex.xy);
		Specular = saturate(Specular + gray(TexColor.rgb));
	}

	bright = (bright * Specular);
#else
	float bright = 0;
#endif

	return float4(distance / FAR_DEPTH, bright, 0, 1);
}



// オブジェクト描画用テクニック
#define BASICSHADOW_TEC(name, mmdpass, sphere, tex, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BufferShadow_VS(tex, sphere, selfshadow); \
			PixelShader  = compile ps_3_0 BufferShadow_PS(tex, sphere, selfshadow); \
		} \
	}

BASICSHADOW_TEC(BTec0, "object", false, false, false)
BASICSHADOW_TEC(BTec1, "object", true,  false, false)
BASICSHADOW_TEC(BTec2, "object", false, true, false)
BASICSHADOW_TEC(BTec3, "object", true,  true, false)

BASICSHADOW_TEC(BSTec0, "object_ss", false, false, true)
BASICSHADOW_TEC(BSTec1, "object_ss", true,  false, true)
BASICSHADOW_TEC(BSTec2, "object_ss", false, true, true)
BASICSHADOW_TEC(BSTec3, "object_ss", true,  true, true)

///////////////////////////////////////////////////////////////////////////////////////////////
