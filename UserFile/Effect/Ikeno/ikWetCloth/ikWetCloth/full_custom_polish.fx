////////////////////////////////////////////////////////////////////////////////////////////////
//
//  full.fx を改造したもの。
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define IGNORE_LIGHT		1


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
float3   MaterialEmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
float4   GroundShadowColor : GROUNDSHADOWCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
#if defined(IGNORE_LIGHT) && IGNORE_LIGHT > 0
static float4 DiffuseColor  = MaterialDiffuse  * float4(1,1,1, 1);
static float3 AmbientColor  = MaterialAmbient  * float4(1,1,1, 1) + MaterialEmisive;
static float3 SpecularColor = MaterialSpecular * float4(1,1,1, 1);
#else
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;
#endif

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

////////////////////////////////////////////////////////////////////////////////////////////////
// 

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}


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
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
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
	float3 N = normalize(IN.Normal);

	#if defined(IGNORE_LIGHT) && IGNORE_LIGHT > 0
	float diffuse = 1;
	#else
	float diffuse = dot(N,-LightDirection);
	float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
	float3 Specular = pow( max(0,dot( HalfVector, N )), SpecularPower ) * SpecularColor;
	#endif

    float4 Color = IN.Color;
	if ( !useToon )
	{
        Color.rgb += max(0,diffuse) * DiffuseColor.rgb;
    }

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
 
	#if defined(IGNORE_LIGHT) && IGNORE_LIGHT > 0
	#else
	// スペキュラ適用
	Color.rgb += Specular;
	#endif

	float comp = 1;

	#if defined(IGNORE_LIGHT) && IGNORE_LIGHT > 0
	#else
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
	#endif

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	float4 ans = lerp(ShadowColor, Color, comp);
//	if( transp ) ans.a = 0.5f;
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
