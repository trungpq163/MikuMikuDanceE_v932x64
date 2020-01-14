//-----------------------------------------------------------------------------
// ikLinearの存在を考慮したfull.fx
//-----------------------------------------------------------------------------

// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float	SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float3	MaterialToon		: TOONCOLOR;
float4	EdgeColor			: EDGECOLOR;
float4	GroundShadowColor	: GROUNDSHADOWCOLOR;
// ライト色
float3	LightDiffuse		: DIFFUSE	< string Object = "Light"; >;
float3	LightAmbient		: AMBIENT	< string Object = "Light"; >;
float3	LightSpecular		: SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmissive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool bLinearBegin : CONTROLOBJECT < string name = "ikLinearBegin.x"; >;
bool bLinearEnd : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;
static bool bOutputLinear = (bLinearEnd && !bLinearBegin);


// テクスチャ材質モーフ値
float4	TextureAddValue	: ADDINGTEXTURE;
float4	TextureMulValue	: MULTIPLYINGTEXTURE;
float4	SphereAddValue	: ADDINGSPHERETEXTURE;
float4	SphereMulValue	: MULTIPLYINGSPHERETEXTURE;

bool	use_texture;		// テクスチャフラグ
bool	use_spheremap;		// スフィアフラグ
bool	use_toon;			// トゥーンフラグ
bool	use_subtexture;		// サブテクスチャフラグ

bool	parthf;	// パースペクティブフラグ
bool	transp;	// 半透明フラグ
bool	spadd;	// スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	3


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};


// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);


// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }


//-----------------------------------------------------------------------------
// 輪郭描画

float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
	return mul( Pos, WorldViewProjMatrix );
}

float4 ColorRender_PS() : COLOR
{
	return EdgeColor;
}

technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}


//-----------------------------------------------------------------------------
// 影（非セルフシャドウ）描画

float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	return mul( Pos, WorldViewProjMatrix );
}

float4 Shadow_PS() : COLOR
{
	return GroundShadowColor;
}

technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_2_0 Shadow_VS();
		PixelShader  = compile ps_2_0 Shadow_PS();
	}
}


//-----------------------------------------------------------------------------
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD0;	// Zバッファテクスチャ
};

VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );
	Out.ShadowMapTex = Out.Pos;

	return Out;
}

float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 ZValuePlot_VS();
		PixelShader  = compile ps_2_0 ZValuePlot_PS();
	}
}


//-----------------------------------------------------------------------------
// オブジェクト描画

struct VS_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;		// スフィアマップテクスチャ座標
	float4 Color	: COLOR0;		// ディフューズ色
};


VS_OUTPUT Object_VS(
	float4 Pos : POSITION, float3 Normal : NORMAL, 
	float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, 
	uniform bool useTexture, uniform bool useSphereMap, 
	uniform bool useToon, uniform bool useSelfshadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfshadow)
	{
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	// ディフューズ色＋アンビエント色 計算
	Out.Color.rgb = AmbientColor;
	Out.Color.a = DiffuseColor.a;
//	Out.Color = saturate( Out.Color );

	Out.Tex = Tex;
	
	if ( useSphereMap ) {
		if ( use_subtexture ) {
			Out.SpTex = Tex2;
		} else {
			float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
			Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
			Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
		}
	}
	
	return Out;
}


float4 Object_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow) : COLOR
{
	float3 N = normalize(IN.Normal);
	float diffuse = dot(N,-LightDirection);

	float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
	float3 Specular = pow( saturate(dot( HalfVector, N )), SpecularPower ) * SpecularColor;

	float4 Color = IN.Color;

	if ( !useToon )
	{
		Color.rgb += saturate(diffuse) * DiffuseColor.rgb;
	}
	Color = saturate( Color );

	float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
	if ( useTexture ) {
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
		Color *= TexColor;
		ShadowColor *= TexColor;
	}

	if ( useSphereMap ) {
		float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
		TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a);
		if(spadd) {
			Color.rgb += TexColor.rgb;
			ShadowColor.rgb += TexColor.rgb;
		} else {
			Color.rgb *= TexColor.rgb;
			ShadowColor.rgb *= TexColor.rgb;
		}
		Color.a *= TexColor.a;
		ShadowColor.a *= TexColor.a;
	}

	Color.rgb += Specular;

	float comp = 1;
	if (useSelfshadow)
	{
		// テクスチャ座標に変換
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord = IN.ZCalcTex.xy * float2(0.5, - 0.5) + 0.5;
		if( all( saturate(TransTexCoord) == TransTexCoord ) )
		{
			float shadow = max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f);
			float k = (parthf) ? SKII2 * TransTexCoord.y : SKII1;
			comp = 1 - saturate(shadow * k - 0.3f);
		}
	}

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	float4 ans = lerp(ShadowColor, Color, comp);
//	if( transp ) ans.a = 0.5f;

	ans.rgb = bOutputLinear ? ans.rgb : Gamma(ans.rgb);

	return ans;
}


#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Object_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 Object_PS(tex, sphere, toon, selfshadow); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture, use_spheremap, use_toon, false)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, use_spheremap, use_toon, true)


//-----------------------------------------------------------------------------
