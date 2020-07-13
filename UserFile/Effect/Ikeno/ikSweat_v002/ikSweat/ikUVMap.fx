////////////////////////////////////////////////////////////////////////////////////////////////
// スクリーン座標でのUVを出力する。
//	UVにギャップがあるせいで、移動できない場合、このマップを参考に移動先を決める。
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 一定以上の半透明は不透明とみなす。
const float AlphaThreshold = 0.75;
const float Smoothness = 0.40;			// 0.3～0.5程度(低いと鈍りすぎる。高いとピーキーすぎる)

//シャドウマップサイズ
#define SHADOWMAP_SIZE 1024
//#define SHADOWMAP_SIZE 4096



// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler DefSampler : register(s0);
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3





#define	PI	(3.14159265359)

inline float CalcFresnel(float NV, float F0)
{
	return F0 + (1.0 - F0) * exp(-6.0 * NV);
}

//スペキュラの計算
float CalcSpecular(float3 L, float3 N, float3 V, float smoothness)
{
	float3 H = normalize(L + V);
	// return pow( max(0,dot( H, N )), SpecularPower );

	float a = pow(1 - smoothness * 0.7, 6);
	float a2 = a * a;
	float NV = dot(N, V);
	float NH = dot(N, H);
	float VH = dot(V, H);
	float NL = dot(N, L);

	// フレネル項
	float F = CalcFresnel(NV, smoothness * smoothness);

	// Trowbridge-Reitz(GGX) NDF
	float CosSq = (NH * NH) * (a2 - 1) + 1;
	float D = a2 / (PI * CosSq * CosSq);

	// 幾何学的減衰係数
	float G = min(1, min( (2*NH/VH) * NV, (2*NH/VH) * NL));

	return saturate(F * D * G / (4.0 * NL * NV));
}



inline float GetShadowDepth(float2 TransTexCoord)
{
	return tex2D(DefSampler,TransTexCoord).r;
}

inline float CalcDepth(float2 TexCoord, float depth, float k)
{
	float depthDiff = max(depth - GetShadowDepth(TexCoord), 0);
	return saturate(depthDiff * k - 0.3);
}

inline float2 ToRectangular(float r, int idx)
{
	return float2(sin(idx*PI/180.0/24.0), cos(idx*PI/180.0/24.0)) * r;
}

float2 CalcShadow(float2 TexCoord, float depth)
{
	float comp = 1;

	if( any( saturate(TexCoord) != TexCoord ) ) {
		;	// シャドウバッファ外
	} else {
		float sum = 0;
		float k = (parthf) ? SKII2 * TexCoord.y : SKII1;

		float U = 0.5 / SHADOWMAP_SIZE;
		float U2 = U*2;
		int ang = 0;
		int angStep = 4;
		for(int i = 0; i < 6;i++)
		{
			sum += CalcDepth(TexCoord+ToRectangular(U,ang), depth, k);
			ang += angStep;
		}

		float ang2 = 0;
		float angStep2 = 2;
		for(int i = 0; i < 12;i++)
		{
			sum += CalcDepth(TexCoord+ToRectangular(U2,ang2), depth, k);
			ang2 += angStep2;
		}

		sum += CalcDepth(TexCoord, depth, k);
		sum = saturate(sum / (1+6+12));
		comp = 1 - sum;
	}

	return comp;
}



///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;

	float4 ZCalcTex	: TEXCOORD1;
	float3 Normal	: TEXCOORD2;
	float3 Eye		: TEXCOORD3;
	float Depth		: TEXCOORD4;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSelfShadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Tex = Tex;

	Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );

	Out.Depth = Out.Pos.z;

	return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSelfShadow) : COLOR0
{
	if ( useTexture ) {
		// テクスチャ適用
		float4 Color = 1;
		Color.a *= tex2D( ObjTexSampler, IN.Tex ).a;
		clip(Color.a - AlphaThreshold);
	}


	// スペキュラ色計算
	float3 N = normalize(IN.Normal);
	float specular = CalcSpecular(-LightDirection, N, normalize(IN.Eye), Smoothness);

	// シャドウマップ
	float diffuse = 1;
	if (useSelfShadow)
	{
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;

		diffuse = CalcShadow(TransTexCoord, IN.ZCalcTex.z);
		specular *= diffuse; // シャドウでマスクされる。
	}

	// デフューズ
	diffuse = min(saturate(dot(N,-LightDirection)), diffuse);

	return float4(IN.Tex.xy, diffuse + specular, IN.Depth);
}


#define OBJECT_TEC(name, mmdpass, tex, shadow) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSelfShadow = shadow;>\
	{ \
		pass DrawObject { \
			AlphaBlendEnable = FALSE; \
			AlphaTestEnable = FALSE; \
			VertexShader = compile vs_3_0 Basic_VS(tex, shadow); \
			PixelShader  = compile ps_3_0 Basic_PS(tex, shadow); \
		} \
	}


OBJECT_TEC(MainTec0, "object", true, false)
OBJECT_TEC(MainTec4, "object", false, false)

OBJECT_TEC(BSTec0, "object_ss", true, true)
OBJECT_TEC(BSTec4, "object_ss", false, true)


technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
