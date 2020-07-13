////////////////////////////////////////////////////////////////////////////////////////////////
//
//  hair_full.fx
//  Tda式ミク用の髪シェーダー
//
////////////////////////////////////////////////////////////////////////////////////////////////


// スペキュラの強さ (0.0～1.5程度)
const float HairSpecularScale = 1.0;

// タンジェントマップファイル
#define TANGENTMAP_FILENAME		"flowmap.png"

// ハイライトの入り方をズラす。未使用の場合、行頭に//をいれてコメントアウトする。
#define NOISEMAP_FILENAME		"hairnoisemap.png"
// ハイライトの強度をズラす。未使用の場合、行頭に//をいれてコメントアウトする。
#define HAIRMASK_FILENAME		"hairmask.png"

// マテリアルのスペキュラカラーを上書きする
// 上書きしない場合は、行頭に//を入れる。
#define	OverrideMaterialSpecular	float3(1.0, 1.0, 1.0)

// マテリアルのスペキュラピークの強さを上書きする
// 上書きしない場合は、行頭に//を入れる。
#define	OverrideSpecularPower	32


// 髪の毛の中に入った光が、髪の毛に吸収される率。数値が高いほど吸収される。
// これでセカンドスペキュラの色が決定される
//const float3 AttenuationColor = float3(0.1, 0.7, 0.99); // 赤が残る (黒髪)
//const float3 AttenuationColor = float3(0.01, 0.3, 0.5); // 赤が残る (金髪)
const float3 AttenuationColor = float3(2.0, 0.6, 0.05);	// 青が強く残る

// スフィアマップを併用するか? (0:しない、1:する)
#define ENABLE_SphereMap		0

// デバッグ用に生え際の方向を表示する。
// 毛先が真っ直ぐ下に向かっているなら、毛先は上(Y方向)なので緑になる。
//#define DEBUG_DISP_TANGENT

//#define DEBUG_SPECULAR_ONLY

// 従法線書き出しテクスチャのスケール
#define BinormalTexScale	1.0



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
#if defined(OverrideMaterialSpecular)
float3   MaterialSpecular = OverrideMaterialSpecular;
#else
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
#endif

#if defined(OverrideSpecularPower)
float	SpecularPower = OverrideSpecularPower;
#else
float	SpecularPower	 : SPECULARPOWER < string Object = "Geometry"; >;
#endif
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

float2 ViewportSize : VIEWPORTPIXELSIZE;

////////////////////////////////////////////////////////////////////////////////////////////////

shared texture2D BinormalTex : RenderColorTarget
<
	float2 ViewPortRatio = {BinormalTexScale,BinormalTexScale};
	bool AntiAlias = false;
	int Miplevels = 1;
	string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler BinormalSampler = sampler_state {
	texture = <BinormalTex>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D BinormalWorkTex : RenderColorTarget
<
	float2 ViewPortRatio = {BinormalTexScale,BinormalTexScale};
	bool AntiAlias = false;
	int Miplevels = 1;
	string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler BinormalWorkSampler = sampler_state {
	texture = <BinormalWorkTex>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {BinormalTexScale,BinormalTexScale};
	string Format = "D24S8";
>;

// タンジェントマップ
texture2D TangentMap <
    string ResourceName = TANGENTMAP_FILENAME;
>;
sampler TangentMapSamp = sampler_state {
    texture = <TangentMap>;
	FILTER = LINEAR;
};


#if defined(NOISEMAP_FILENAME)
texture2D NoiseMap <
    string ResourceName = NOISEMAP_FILENAME;
>;
sampler NoiseMapSamp = sampler_state {
    texture = <NoiseMap>;
	FILTER = LINEAR;
};
#endif

#if defined(HAIRMASK_FILENAME)
texture2D HairMaskMap <
    string ResourceName = HAIRMASK_FILENAME;
>;
sampler HairMaskSamp = sampler_state {
    texture = <HairMaskMap>;
	FILTER = LINEAR;
};
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
//

#define	PI	(3.14159265359)
#define DEG2RAD(d)	((d) * PI / 180.0)

// ぼかし処理の重み係数：
//	ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//	(WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
static const float BlurWeight[] = {
	0.0920246,
	0.0902024,
	0.0849494,
	0.0768654,
	0.0668236,
	0.0558158,
	0.0447932,
	0.0345379,
};

// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float3 CalcBinormal(float3 Pos, float3 N, float2 uv)
{
	float3 dpdy = ddy(Pos);
	float3 vRx = normalize(cross(dpdy, N));
	float3 vRy = cross(N, vRx);
	float2 duvdx = ddx(uv);
	float2 duvdy = ddy(uv);
	float3 Tangent = duvdx.x * vRx + duvdy.x * vRy;
	float3 Binormal = duvdx.y * vRx + duvdy.y * vRy;

	float2 tex = tex2Dlod(TangentMapSamp, float4(uv,0,0)).xy * 2.0 - 1.0;
	Tangent = normalize(Binormal * -tex.y + Tangent * tex.x);
	Binormal = cross(Tangent, N);
	return normalize(Binormal);
}

// Kajiya-Kayモデル
float KajiyaKayDiff(float3 T, float3 V, float3 L)
{
	// return sin( acos(dot(T,L)) );
	float TL = dot(T, L);
	return sqrt(1 - TL * TL);
}

float KajiyaKaySepc(float3 T, float3 V, float3 L, float specPower)
{
//	return pow( cos( abs( acos(dot(T, L)) - acos(dot(-T,V)) ) ), specPower);
	float TL = dot(T, L);
	float TV = dot(-T, V);
	float TLy = sqrt(1 - TL * TL);
	float TVy = sqrt(1 - TV * TV);
	return pow( abs(-TV * TL - TVy * TLy), specPower);
}

inline float gaussian(float beta, float theta)
{
	float beta2 = 2.0 * beta * beta;
	float theta2 = theta * theta;
	return exp(-theta2 * (1.0 / beta2)) / sqrt(PI * beta2);
}

// Marschnerのサブセット。TTを考慮しない。
float3 SimpleHairSepc(float3 T, float3 V, float3 L, float specPower)
{
	float TL = dot(T, L);
	float thetaI = asin(TL);
	float thetaR = asin(dot(T, V));
	float thetaH = (thetaR + thetaI) * 0.5;
	float thetaD = (thetaR - thetaI) * 0.5;
	float cosThetaD2 = pow(cos(thetaD), 2) * 0.5;

	float alphaR = DEG2RAD(3);		// キューティクルの傾き
	float betaR = DEG2RAD(8);		// 表面の粗さ。
	float alphaTRT = -1.5 * alphaR;
	float betaTRT = 2.0 * betaR;

	float M_R = (gaussian(betaR, thetaH - alphaR));
	// M1(TT)は省略。
	float M_TRT = (gaussian(betaTRT, thetaH - alphaTRT));

	// 適当な色の減衰
	float3 N_TRT = exp(-((1.0 - TL * TL) + 0.1) * 4.0 * (AttenuationColor + 0.1));

	return (M_R + M_TRT * N_TRT) * cosThetaD2;
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
// 従法線の生成。

struct Binormal_OUTPUT {
	float4 Pos		: POSITION;	 // 射影変換座標
	float4 WPos		: TEXCOORD0;
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
};

Binormal_OUTPUT Binormal_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	Binormal_OUTPUT Out = (Binormal_OUTPUT)0;

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.WPos = mul( Pos, WorldMatrix );
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	Out.Tex = Tex;

	return Out;
}

float4 Binormal_PS(Binormal_OUTPUT IN) : COLOR
{
	// 抜きテクスチャ対応
	float4 TexColor = tex2D( ObjTexSampler, IN.Tex);
	clip(TexColor.a - 2.0/255.0);

	float depth = distance(CameraPosition, IN.WPos.xyz);
	float3 N = normalize(IN.Normal);
	float3 Binormal = CalcBinormal(IN.WPos, N, IN.Tex);

	return float4(Binormal, depth * 0.5);
}


///////////////////////////////////////////////////////////////////////////////////////////////
// ブラー

struct VS_OUTPUT_BLUR {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT_BLUR Blur_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_OUTPUT_BLUR Out = (VS_OUTPUT_BLUR)0; 

	Out.Pos = Pos;
	Out.Tex = Tex + (0.5 / (ViewportSize * BinormalTexScale));

	return Out;
}

inline float DepthDistance(float4 c1, float4 c2)
{
	float depth1 = c1.w;
	float depth2 = c2.w;
	depth1 = (depth1 > 0.0) ? depth1 : depth2; // 中心が圏外?
	float w = max(dot(c1.xyz, c2.xyz), 0);
	return (depth2 == 0.0) ? 0 : exp(-abs(depth1 - depth2) - 1e-6) * w;
}

float4 Blur_PS( float2 Tex: TEXCOORD0, uniform bool isXBlur, uniform sampler smp) : COLOR
{
	float2 SampStep = 1.0 / (ViewportSize * BinormalTexScale);
	// sampler smp = (isXBlur) ? BinormalSampler : BinormalWorkSampler;
	float2 offset = (isXBlur) ? float2(SampStep.x, 0) : float2(0, SampStep.y);

	float4 Color0 = tex2D( smp, Tex);
	float4 Color = Color0;
	Color.rgb *= BlurWeight[0];

	[unroll]
	for(int i = 1; i < 8; i ++) {
		float w = BlurWeight[i];
		float4 cp = tex2D( smp, Tex + offset * i);
		float wp = w * DepthDistance(Color0, cp);
		float4 cn = tex2D( smp, Tex - offset * i);
		float wn = w * DepthDistance(Color0, cn);
		Color.rgb += (cp.rgb * wp + cn.rgb * wn);
	}

	Color.rgb = Color.rgb / max(length(Color.rgb), 0.01);
	return Color;
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
	float4 PPos			: TEXCOORD5;
    float4 Color      : COLOR0;      // ディフューズ色
};


// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.PPos = Out.Pos;
    
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
	float3 L = -LightDirection;
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);

	float diffuse = dot(N,L);

    // スペキュラ色計算
#if 0
    float3 HalfVector = normalize( V + L );
    float3 Specular = pow( max(0,dot( HalfVector, N )), SpecularPower ) * SpecularColor;
#else

	float2 uv = (IN.PPos.xy / IN.PPos.w) * float2(0.5, -0.5) + 0.5;
	float3 Binormal = normalize(tex2D(BinormalSampler, uv.xy).xyz);
	float3 Tangent = normalize(cross(N, Binormal));

	#if defined(NOISEMAP_FILENAME)
	float n = tex2D(NoiseMapSamp, IN.Tex.xy).x;
	Tangent = normalize(Tangent + N * (n * 2.0 - 1.0) * 0.25);
	#endif

	#if defined(DEBUG_DISP_TANGENT)
	//デバッグ用に根元方向のベクトルを表示する
	float3 c0 = -Tangent * 0.5 + 0.5;
	float3 c1 = tex2D( ObjTexSampler, IN.Tex.xy ).rgb;
	return float4(lerp(c0, c1, 0.25), 1);
	#endif

	// float3 s = KajiyaKaySepc(Tangent, V, L, SpecularPower);
	// diffuse = min(KajiyaKayDiff(Tangent, V, L), saturate(dot(N,L)));
	float3 s = SimpleHairSepc(Tangent, V, L, SpecularPower);
	diffuse = saturate(diffuse);

	float3 Specular = s * min(diffuse * 4.0, 1) * Degamma(SpecularColor) * HairSpecularScale;

	#if defined(HAIRMASK_FILENAME)
	Specular = saturate(Specular * Degamma(tex2D(HairMaskSamp, IN.Tex.xy).rgb));
	#endif

	#if defined(DEBUG_SPECULAR_ONLY)
	return float4(Gamma(Specular), 1);
	#endif
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

		Specular *= comp;
	}

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	float4 ans = lerp(ShadowColor, Color, comp);

    // スペキュラ適用
    // Color.rgb += Specular;
    ans.rgb = Gamma(Degamma(ans.rgb) + Specular);

//	if( transp ) ans.a = 0.5f;
	return ans;
}



///////////////////////////////////////////////////////////////////////////////////////////////

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
technique name < \
	string MMDPass = mmdpass; \
	string Script = \
		"RenderColorTarget0=BinormalTex;" \
		"RenderDepthStencilTarget=DepthBuffer;" \
		"ClearSetColor=ClearColor;" \
		"ClearSetDepth=ClearDepth;" \
		"Clear=Color; Clear=Depth;" \
		"Pass=DrawBinormal;" \
		"RenderColorTarget0=BinormalWorkTex;	Pass=BlurX;" \
		"RenderColorTarget0=BinormalTex;		Pass=BlurY;" \
	\
		"RenderColorTarget0=;" \
		"RenderDepthStencilTarget=;" \
		"Pass=DrawObject;" \
; \
> { \
	pass DrawBinormal { \
		AlphaBlendEnable = false; AlphaTestEnable = false; \
		VertexShader = compile vs_3_0 Binormal_VS(); \
		PixelShader  = compile ps_3_0 Binormal_PS(); \
	} \
	pass BlurX < string Script= "Draw=Buffer;"; > { \
		AlphaBlendEnable = false; AlphaTestEnable = false; \
		ZEnable = false; ZWriteEnable = false; \
		VertexShader = compile vs_3_0 Blur_VS(); \
		PixelShader  = compile ps_3_0 Blur_PS(true, BinormalSampler); \
	} \
	pass BlurY < string Script= "Draw=Buffer;"; > { \
		AlphaBlendEnable = false; AlphaTestEnable = false; \
		ZEnable = false; ZWriteEnable = false; \
		VertexShader = compile vs_3_0 Blur_VS(); \
		PixelShader  = compile ps_3_0 Blur_PS(false, BinormalWorkSampler); \
	} \
	pass DrawObject { \
		VertexShader = compile vs_3_0 Object_VS(tex, sphere, toon, selfshadow); \
		PixelShader  = compile ps_3_0 Object_PS(tex, sphere, toon, selfshadow); \
	} \
}


#if defined(ENABLE_SphereMap) && ENABLE_SphereMap > 0
OBJECT_TEC(MainTec0, "object", use_texture, use_spheremap, use_toon, false)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, use_spheremap, use_toon, true)
#else
OBJECT_TEC(MainTec0, "object", use_texture, false, use_toon, false)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, false, use_toon, true)
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
