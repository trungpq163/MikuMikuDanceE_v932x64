////////////////////////////////////////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 法線マップファイル名
//#define NORMALMAP__FILENAME "brilliantTops2.png"
//#define NORMALMAP__FILENAME "circles.png"
//#define NORMALMAP__FILENAME "roundedSquares.png"
#define NORMALMAP__FILENAME "hexagons.png"
//#define NORMALMAP__FILENAME "PCCP.png"


// 反射する量。値が大きいほど明るくなる
float ReflectionIntensity = 1.0;

float NormalMapLoopNum = 48;			// 繰り返し回数。大きいほど模様が細かくなる
float NormalMapHeightScale = 1.0;		// 高さ補正。正で高くなる 0で平坦 (-4～4程度)

// 反射の鋭さ (0.7～0.98程度)
float Smoothness = 0.80;

// 屈折率 (1.3～2.5程度)
float IoR = 2.0;

// 光が当たらない部分の色を暗くするか? (0:明るい、1:暗い)
float TintRate = 0.5;

// 追加スフィアマップ
// 元々スフィアマップが無いモデル用。不要な場合は//でコメントアウトする。
//#define SPHERE_FILENAME "dummySphere.png"
// 追加スフィアマップの強さ
float SpehreIntensity = 0.5;

// 二次反射の色の強調を行う
// 暗い色でも二次反射が付く
#define ENABLE_COLOR_EMPHASIZE	1

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

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
float4   GroundShadowColor : GROUNDSHADOWCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4   TextureAddValue   : ADDINGTEXTURE;
float4   TextureMulValue   : MULTIPLYINGTEXTURE;
float4   SphereAddValue    : ADDINGSPHERETEXTURE;
float4   SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

bool	use_texture;		//	テクスチャフラグ
bool	use_spheremap;		//	スフィアフラグ
bool	use_toon;			//	トゥーンフラグ
bool	use_subtexture;    // サブテクスチャフラグ

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3


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

//////////////////////////////////////////////////////////////////////////////////////////////

static float F0 = saturate(pow((IoR - 1.0) / (IoR + 1.0), 2.0)) + 0.001;
static float Roughness0 = saturate((1 - Smoothness) * (1 - Smoothness)) * 0.98 + 0.01;
static float Roughness = Roughness0 * Roughness0;
static float WaveLengthRate = saturate(IoR - 1.0) / 40.0;


#if defined(SPHERE_FILENAME)
texture2D DummySphereMap <
    string ResourceName = SPHERE_FILENAME;
>;
sampler DummySphereMapSamp = sampler_state {
    texture = <DummySphereMap>;
	FILTER = LINEAR;
	AddressU  = CLAMP; AddressV  = CLAMP;
};
#endif

//メイン法線マップ
#define ANISO_NUM 16

texture2D NormalMap <
    string ResourceName = NORMALMAP__FILENAME;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMap>;
	FILTER = LINEAR;
	AddressU  = WRAP;
	AddressV  = WRAP;
};

#define	PI	(3.14159265359)

// 金属の場合、F0はrgb毎に異なる値を持つ
inline float CalcFresnel(float NV, float F0)
{
	return F0 + (1.0 - F0) * pow(1 - NV, 5);
}

//スペキュラの計算
inline float CalcSpecular(float3 L, float3 N, float3 V, float a)
{
	float3 H = normalize(L + V);

	float NH = saturate(dot(N, H));
	float NL = saturate(dot(N, L));
	float LH = saturate(dot(L, H));

	float CosSq = (NH * NH) * (a - 1) + 1;
	float D = a / (CosSq * CosSq);

	float k2 = a * a * 0.25;	// = (a * 0.5)^2
	float vis = (1.0/4.0) / (LH * LH * (1 - k2) + k2);
	return max(NL * D * vis, 0);
}


float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
	float3 vRx = ddx(View);
	float3 vRy = ddy(View);
	float2 duvdx = ddx(UV);
	float2 duvdy = ddy(UV);

	float3 Tangent = 0;//duvdx.x * vRx + duvdy.x * vRy;
	float3 Binormal = duvdx.y * vRx + duvdy.y * vRy;

	Tangent = normalize(cross(normalize(Binormal), Normal));
	Binormal = normalize(cross(Normal, Tangent));

	return float3x3(Tangent, Binormal, Normal);
}

float3 CalcNormal(float3 normal, float3x3 mat, float s)
{
	normal.xy *= s;
	return mul(normalize(normal.xyz), mat);
}


// それっぽい値を返す適当な屈折計算
inline float3 CustomRefract(float3 i, float3 n, float e)
{
	float ni = dot(n, i);
	float ni2 = 1 - ni * ni;
	float k1 = abs(1 - e * e * ni2) + 0.001;	// 本来は k > 0なら(0,0,0)を返す
	float3 v1 = (e * i - (e * ni + sqrt(k1)) * n);
	return v1 * sign(dot(v1,i));		// この処理も適当
}


inline float3 ColorEmphasize(float3 original)
{
#if defined(ENABLE_COLOR_EMPHASIZE) && ENABLE_COLOR_EMPHASIZE > 0
	float3 col = original + 0.01;
	float maxChannel = max(col.r, max(col.g, col.b));
	return pow(saturate(col / maxChannel), 4);
#else
	return original;
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 輪郭色で塗りつぶし
    return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // 地面影色で塗りつぶし
    return GroundShadowColor;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 ZCalcTex   : TEXCOORD0;   // Z値
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};


// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfshadow)
	{
		// ライト視点によるワールドビュー射影変換
	    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
		if ( use_subtexture ) {
			// PMXサブテクスチャ座標
			Out.SpTex = Tex2;
	    } else {
	        // スフィアマップテクスチャ座標
	        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	    }
    }
    
    return Out;
}


float4 Object_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow) : COLOR
{
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N0 = normalize(IN.Normal);

	//--------------------------------------------------------
	float3x3 tangentFrame = compute_tangent_frame(N0, V, IN.Tex);
	float3x3 invTangentFrame = transpose(tangentFrame);

	float2 uv = IN.Tex * NormalMapLoopNum;
	float4 NormalColor = tex2D( NormalMapSamp, uv);
	NormalColor.xyz = NormalColor.xyz * 2 - 1;
	// 簡易POM： NormalColor.zを高さとみなしてシフトする
	float shift = (1.0 - NormalColor.z) * 0.1 * NormalMapHeightScale;
	uv += mul(-V, invTangentFrame).xy * shift;
	NormalColor = tex2D( NormalMapSamp, uv) * 2 - 1;
	float3 N = CalcNormal(NormalColor.xyz, tangentFrame, NormalMapHeightScale);

	// 2次反射
	shift = NormalColor.z * 0.1 * NormalMapHeightScale;
	uv += mul(-V, invTangentFrame).xy * shift;
	NormalColor = tex2D( NormalMapSamp, uv);
	NormalColor.xyz = 1 - NormalColor.xyz * 2;
	float3 N2 = CalcNormal(NormalColor.xyz, tangentFrame, NormalMapHeightScale);
	// 3次反射
	uv += NormalColor.xy * 0.25 * NormalMapHeightScale;
	NormalColor = tex2D( NormalMapSamp, uv);
	NormalColor.xyz = NormalColor.xyz * 2 - 1;
	float3 N3 = CalcNormal(NormalColor.xyz, tangentFrame, NormalMapHeightScale);

	float F1 = CalcFresnel(abs(dot(N, V)), F0);
	float3 F2 = (1 - F1) * 0.5;

	float3 specular = CalcSpecular(L, N, V, Roughness) * F1 * ReflectionIntensity;
	float3 specular2 = CalcSpecular(L, N2, V, Roughness);
	float3 specular3 = CalcSpecular(L, N3, V, Roughness);
	specular2 = (specular2 + specular3) * F2 * ReflectionIntensity;

	float diffuse = max(0,dot(N, L)) * F1 + (max(0,dot(N2, L)) + max(0,dot(N3, L))) * F2;
	//--------------------------------------------------------

    float4 Color = IN.Color;
	if ( !useToon )
	{
        Color.rgb += max(0,diffuse) * DiffuseColor.rgb;
    }

    float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
    if ( useTexture ) {
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
	    TexColor.rgb = lerp(1, TexColor.rgb * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
        Color *= TexColor;
        ShadowColor *= TexColor;
    }

    if ( useSphereMap ) {
        float4 TexColor = tex2D(ObjSphareSampler, IN.SpTex);
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

	// 独自のスフィアマップを適用する
	#if defined(SPHERE_FILENAME)
	if (true)
	{
		float2 NormalWV = mul( N2, (float3x3)ViewMatrix );
		float2 SpTex = NormalWV.xy * float2(0.5, -0.5) + 0.5;
		float3 TexColor = tex2D(DummySphereMapSamp, SpTex).rgb * LightSpecular * SpehreIntensity;
		Color.rgb += TexColor;
		ShadowColor.rgb += TexColor;
	}
	#endif

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

	//--------------------------------------------------------
	float attenuation = lerp(1, 1.0 - F1, TintRate);

	Color.rgb *= attenuation;
	ShadowColor.rgb *= attenuation;

	// スペキュラ適用
	specular2 *= ColorEmphasize(Color.rgb);
	Color.rgb += specular + specular2;
	ShadowColor.rgb += specular2;
	//--------------------------------------------------------

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	float4 ans = lerp(ShadowColor, Color, comp);
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


///////////////////////////////////////////////////////////////////////////////////////////////
