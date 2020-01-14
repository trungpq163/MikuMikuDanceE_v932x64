//ユーザ定義部分

// 環境光の強度
static float LightScale = 0.2;

//MMD標準のライト強度
static float MMDLight = 0.5;

//環境マップの解像度
#define WIDTH       32
#define HEIGHT      WIDTH

// 影の強さ
static float ShadowScale = 0.7;

// スペキュラの強度(0.1-2.0)
static float SpecularScale = 0.5;

// リムライトの強度
static float RimPow	= 4.0;
static float RimScale	= 0.2;

// 法線を利用するか?
#define USE_NORMALMAP

// ガンマ補正するか?
#define USE_GAMMA
const float gamma = 2.2;


/////////////////////////////////////////////////////////////////////////////////////////
// ■ ExcellentShadowシステム　ここから↓

//スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

//SSAOマップ取得
shared texture2D ExShadowSSAOMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "R16F";
>;

sampler2D ExShadowSSAOMapSamp = sampler_state {
    texture = <ExShadowSSAOMapOut>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

// スクリーンサイズ
float2 ES_ViewportSize : VIEWPORTPIXELSIZE;
static float2 ES_ViewportOffset = (float2(0.5,0.5)/ES_ViewportSize);

bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
bool Exist_ExShadowSSAO : CONTROLOBJECT < string name = "ExShadowSSAO.x"; >;
float ShadowRate : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Tr"; >;
float3   ES_CameraPos1      : POSITION  < string Object = "Camera"; >;
float es_size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; >;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;

static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43 );
static float CameraDistance1 = length(ES_CameraPos1 - es_move1); //カメラとシャドウ中心の距離

// ■ ExcellentShadowシステム　ここまで↑
/////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////
// 動的双放物面環境マップの宣言＆使用関数

#define ANTI_ALIAS  true
texture EnvMapF: OFFSCREENRENDERTARGET <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = ANTI_ALIAS;
    int Miplevels=1;
    string Format = "A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*=DPEnvMapF.fx;";
>;

sampler sampEnvMapF = sampler_state {
    texture = <EnvMapF>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture EnvMapB: OFFSCREENRENDERTARGET <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = ANTI_ALIAS;
    int Miplevels=1;
    string Format = "A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*=DPEnvMapB.fx;";
>;

sampler sampEnvMapB = sampler_state {
    texture = <EnvMapB>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// ボカした環境マップ
texture EnvMapFBlured: RenderColorTarget <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = ANTI_ALIAS;
    int Miplevels=1;
    string Format = "A16B16G16R16F";
>;

sampler sampEnvMapFBlured = sampler_state {
    texture = <EnvMapFBlured>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture EnvMapBBlured: RenderColorTarget <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = ANTI_ALIAS;
   int Miplevels=1;
     string Format = "A16B16G16R16F";
>;

sampler sampEnvMapBBlured = sampler_state {
    texture = <EnvMapBBlured>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



//法線マップ密度
float MapParam = 8;
#define ANISO_NUM 16

texture2D NormalMap <
    string ResourceName = "NormalMap.png";
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};


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
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * (LightAmbient*MMDLight) + MaterialEmmisive);
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



// 環境マップにボカしを掛ける
static const float4 BlurSamples[] = {
	//-------------
	float4( 0.0, 0.0, 1.0, 0.2734575),
	//-------------
	float4( 0.309017, 0.0, 0.95105654, 0.06501838),
	float4( -1.3507562E-8, 0.309017, 0.95105654, 0.06501838),
	float4( -0.309017, -2.7015124E-8, 0.95105654, 0.06501838),
	float4( 3.684991E-9, -0.309017, 0.95105654, 0.06501838),
	//-------------
	float4( 0.4156269, 0.4156269, 0.809017, 0.05530794),
	float4( -0.4156269, 0.4156269, 0.809017, 0.05530794),
	float4( -0.41562697, -0.41562688, 0.809017, 0.05530794),
	float4( 0.41562685, -0.415627, 0.809017, 0.05530794),
	//-------------
	float4( 0.7501075, 0.3030631, 0.5877853, 0.020091787),
	float4( 0.31610817, 0.74470407, 0.5877853, 0.020091787),
	float4( -0.30306312, 0.7501075, 0.5877853, 0.020091787),
	float4( -0.74470407, 0.31610814, 0.5877853, 0.020091787),
	float4( -0.75010747, -0.30306315, 0.5877853, 0.020091787),
	float4( -0.3161082, -0.74470407, 0.5877853, 0.020091787),
	float4( 0.30306292, -0.7501076, 0.5877853, 0.020091787),
	float4( 0.74470407, -0.31610808, 0.5877853, 0.020091787),
	//-------------
/*
	float4( 0.93358296, 0.18147014, 0.30901697, 0.0052814377),
	float4( 0.7930726, 0.52492326, 0.30901697, 0.0052814377),
	float4( 0.53182405, 0.78846157, 0.30901697, 0.0052814377),
	float4( 0.18961018, 0.9319638, 0.30901697, 0.0052814377),
	float4( -0.18147017, 0.93358296, 0.30901697, 0.0052814377),
	float4( -0.5249232, 0.7930726, 0.30901697, 0.0052814377),
	float4( -0.7884615, 0.5318242, 0.30901697, 0.0052814377),
	float4( -0.9319638, 0.18961014, 0.30901697, 0.0052814377),
	float4( -0.93358296, -0.1814701, 0.30901697, 0.0052814377),
	float4( -0.79307264, -0.52492315, 0.30901697, 0.0052814377),
	float4( -0.53182405, -0.7884616, 0.30901697, 0.0052814377),
	float4( -0.18961, -0.9319638, 0.30901697, 0.0052814377),
	float4( 0.18147004, -0.933583, 0.30901697, 0.0052814377),
	float4( 0.5249233, -0.7930725, 0.30901697, 0.0052814377),
	float4( 0.78846145, -0.5318243, 0.30901697, 0.0052814377),
	float4( 0.9319638, -0.18961029, 0.30901697, 0.0052814377),
*/
};


////////////////////////////////////////////////////////////////////////////////////////////////

float4 texDP(sampler2D sampFront, sampler2D sampBack, float3 vec) {
    vec = normalize(vec);
    bool front = (vec.z >= 0);
    if ( !front ) vec.xz = -vec.xz;
    
    float2 uv;
    uv = vec.xy / (1+vec.z);
    uv.y = -uv.y;
    uv = uv * 0.5 + 0.5;
    
    if ( front ) {
        return tex2D(sampFront, uv);
    } else {
        return tex2D(sampBack, uv);
    }
}

// ガンマ補正
#ifdef USE_GAMMA
inline float3 Degamma(float3 col) { return pow(col, gamma); }
inline float3 Gamma(float3 col) { return pow(col, 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(pow(col.rgb, gamma), col.a); }
inline float4 Gamma4(float4 col) { return float4(pow(col.rgb, 1.0/gamma), col.a); }
#else
inline float3 Degamma(float3 col) { return col; }
inline float3 Gamma(float3 col) { return col; }
inline float4 Degamma4(float4 col) { return col; }
inline float4 Gamma4(float4 col) { return col; }
#endif

float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

// 適当な減色処理
float3 darker(float3 x, float n)
{
	float v = rgb2gray(x);
	if (v <= 0.0) return x;
	float maxValue = max(x.x, max(x.y, x.z));
	float3 modify = pow(x / maxValue, 3.0-n*2);
	return modify * (v * n / rgb2gray(modify));
}


#define	PI	(3.14159265359)

// スペキュラパワーの強さを素材表面の滑らかさとみなす。
inline float CalcSmoothness(float specularPower)
{
	return log2(specularPower) * (SpecularScale / 16.0);
}

inline float3 CalcFresnel(float NV, float3 F0)
{
	return F0 + (1.0 - F0) * exp(-6.0 * NV);
}

//スペキュラの計算
float3 CalcSpecular(float3 L, float3 N, float3 V, float3 Col, float smoothness)
{
	float3 H = normalize(L + V);	// ハーフベクトル

	float a = pow(1 - smoothness * 0.7, 6);
	float a2 = a * a;
	float NV = dot(N, V);
	float NH = dot(N, H);
	float VH = dot(V, H);
	float NL = dot(N, L);

	// フレネル項
	float3 F = CalcFresnel(NV, smoothness * smoothness);

	// Trowbridge-Reitz(GGX) NDF
	float CosSq = (NH * NH) * (a2 - 1) + 1;
	float D = a2 / (PI * CosSq * CosSq);

	// 幾何学的減衰係数
	float G = min(1, min( (2*NH/VH) * NV, (2*NH/VH) * NL));

	return saturate(F * D * G / (4.0 * NL * NV));
}


////////////////////////////////////////////////////////////////////////////////////////////////

struct Blur_OUTPUT {
	float4 Pos      : POSITION;     // 射影変換座標
	float4 LocalV	: TEXCOORD0;
};

// MEMO: 本来はカメラから見える側だけをボカせばいい
Blur_OUTPUT Blur_VS(float4 Pos : POSITION, float2 Tex:TEXCOORD0, uniform float direction)
{
	Blur_OUTPUT Out = (Blur_OUTPUT)0;
	Out.Pos = Pos;
	Out.LocalV.xyz = Pos.xyz;
	Out.LocalV.w = direction;
	return Out;
}

float4 Blur_PS(Blur_OUTPUT IN) : COLOR
{
	float3 V0 = IN.LocalV.xyz;
	V0.z = max(0.25 - dot(V0.xy * 0.5, V0.xy * 0.5), 0);
	if (IN.LocalV.w < 0) V0.xz = -V0.xz;
/*
	return (V0.z > 0)
		? tex2D(sampEnvMapF, V0.xy * 0.5 + 0.5)
		: tex2D(sampEnvMapB, V0.xy * 0.5 + 0.5);
	//return texDP(sampEnvMapF, sampEnvMapB, V0);
*/
	float3 Vz = normalize(V0);
	float3 Vy = normalize(float3(-Vz.x * 0.1, 1 - Vz.y, Vz.y));
	float3 Vx = normalize(cross(Vy,Vz));
	float4x4 mat = 0;
	mat._11_12_13 = Vx;
	mat._21_22_23 = normalize(cross(Vz,Vx));
	mat._31_32_33 = Vz;
	mat._44 = 1;

	float4 Color = 0;
#if 1
//	for(int i = 0; i < 1+4+4+8+16; i++) {
	for(int i = 0; i < 1+4+4+8; i++) {
		float3 v = mul(BlurSamples[i].xyz, mat);
		float3 tmp = Degamma(texDP(sampEnvMapF, sampEnvMapB, v).rgb);
		Color.rgb += tmp * BlurSamples[i].w;
	}
#else
	Color.rgb = Degamma(texDP(sampEnvMapF, sampEnvMapB, mul(float3(0,0,1), mat)).rgb);
#endif
	Color.a = 1;
	return Color;

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
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_3_0 ColorRender_VS();
        PixelShader  = compile ps_3_0 ColorRender_PS();
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
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR0
{
	float3 V = normalize(IN.Eye);
	float3 N = normalize(IN.Normal);

    // ディフューズ色＋アンビエント色 計算
    float4 Color;
	float comp = max(0, dot( N, -LightDirection ) * ShadowScale + (1.0 - ShadowScale));
    Color.rgb = comp * (DiffuseColor.rgb + AmbientColor);
    Color.a = DiffuseColor.a;
    Color = saturate( Color );

    // スペキュラ色計算
    float3 HalfVector = normalize( V + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, N )), SpecularPower ) * SpecularColor;

    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Specular += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
        }
    }

	// スペキュラ適用
	Color.rgb += Specular;

	float4 DP = texDP(sampEnvMapF, sampEnvMapB, N);
	Color.rgb += DP * LightScale;

    return Color;
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
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float2 SpTex    : TEXCOORD3;	// スフィアマップテクスチャ座標
    float3 Eye		: TEXCOORD4;	// 視線

    // ■ ExcellentShadowシステム　ここから↓
    
    float4 ScreenTex : TEXCOORD5;   // スクリーン座標
    
    // ■ ExcellentShadowシステム　ここまで↑
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // Out.WPos = mul(Pos,WorldMatrix);
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );

    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    

    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    // ■ ExcellentShadowシステム　ここから↓
    
    //スクリーン座標取得
    Out.ScreenTex = Out.Pos;
    
    //超遠景におけるちらつき防止
    Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));
    
    // ■ ExcellentShadowシステム　ここまで↑
    /////////////////////////////////////////////////////////////////////////////////////////

    return Out;
}

float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}

float4 CalcNormal(float2 Tex,float3 Eye,float3 Normal, bool useTexture)
{
	#ifndef USE_NORMALMAP
		return float4(Normal,1);
	#endif
	float4 Norm = 1;

    float2 tex = Tex* MapParam;
	
	float4 NormalColor = tex2D( NormalMapSamp, tex)*2;	

	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;
	float3x3 tangentFrame = compute_tangent_frame(Normal, Eye, Tex);
	Norm.rgb = normalize(mul(NormalColor - 1.0f, tangentFrame));

	return Norm;
}


// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR
{
    float3 V = normalize(IN.Eye);
	float3 N = CalcNormal(IN.Tex,V,normalize(IN.Normal),useTexture).xyz;

    // ディフューズ色＋アンビエント色 計算
    float4 Color;
    Color.rgb = Degamma(AmbientColor);
    Color.a = DiffuseColor.a;

    // スペキュラ色計算
    float smoothness = CalcSmoothness(SpecularPower);
	float3 Specular = CalcSpecular(-LightDirection, N, V, 1, smoothness) * Degamma(SpecularColor);

    float4 ShadowColor = Color;
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = Degamma4(tex2D( ObjTexSampler, IN.Tex ));
        Color *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = Degamma4(tex2D(ObjSphareSampler,IN.SpTex));
        if(spadd) {
            Specular += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
        }
    }

    //DP適用
	float4 DP = texDP(sampEnvMapFBlured, sampEnvMapBBlured, N);
	// float4 DP = texDP(sampEnvMapF, sampEnvMapB, N);

	float comp = 1;

    /////////////////////////////////////////////////////////////////////////////////////////
    // ■ ExcellentShadowシステム　ここから↓
    if(Exist_ExcellentShadow){
        
        IN.ScreenTex.xyz /= IN.ScreenTex.w;
        float2 TransScreenTex;
        TransScreenTex.x = (1.0f + IN.ScreenTex.x) * 0.5f;
        TransScreenTex.y = (1.0f - IN.ScreenTex.y) * 0.5f;
        TransScreenTex += ES_ViewportOffset;
        float SadowMapVal = tex2D(ScreenShadowMapProcessedSamp, TransScreenTex).r;
        float SSAOMapVal = 0;
        if(Exist_ExShadowSSAO){
            SSAOMapVal = tex2D(ExShadowSSAOMapSamp , TransScreenTex).r; //陰度取得
        }

        DP.rgb = darker(DP.rgb, saturate(1.0 - SSAOMapVal));
		comp = SadowMapVal * ShadowScale + (1.0 - ShadowScale);
		comp *= saturate(1.0 - SSAOMapVal * 0.2);
    }else
    
    // ■ ExcellentShadowシステム　ここまで↑
    /////////////////////////////////////////////////////////////////////////////////////////
	{
		// テクスチャ座標に変換
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;

		if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
			// シャドウバッファ外
			;
		} else {
			float shadowVal = max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f);
			if(parthf) {
				// セルフシャドウ mode2
				comp=1-saturate(shadowVal*SKII2*TransTexCoord.y-0.3f);
			} else {
				// セルフシャドウ mode1
				comp=1-saturate(shadowVal*SKII1-0.3f);
			}

			comp = comp * ShadowScale + (1.0 - ShadowScale);
		}
	}

	comp = min(saturate(dot(N,-LightDirection)), comp);
	Specular *= comp;

	// リムライト
	comp += pow(1-saturate(max(0,dot( N, V ) )),RimPow) * RimScale;
	comp = saturate(comp);

	// 女優ライト
	float3 actressLightDirection = normalize(V + float3(0,V.z, 0));
	float actressLight = pow(saturate(dot(N, actressLightDirection)), 2) * 0.5;
	comp = comp + (1.0 - comp) * actressLight;

	Color.rgb = darker(Color.rgb, comp * ShadowScale + (1.0 - ShadowScale));

	Color.rgb += Specular;
	Color.rgb += darker(DP.rgb, LightScale);

	if( transp ) Color.a = 0.5f;

	Color.rgb = Gamma(Color.rgb);

	return Color;
}



float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

#define OBJECT_TEC0(name, sphere, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Basic_VS(tex, sphere); \
			PixelShader  = compile ps_3_0 Basic_PS(tex, sphere); \
		} \
	}

#define OBJECT_TEC(name, sphere, mmdpass, tex) \
	technique name < string MMDPass = mmdpass; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseSelfShadow = true;\
		string Script = \
			"RenderColorTarget0=EnvMapFBlured;" \
			"Pass=BlurFront;" \
			"RenderColorTarget0=EnvMapBBlured;" \
			"Pass=BlurBack;" \
\
			"RenderColorTarget=;" \
			"RenderDepthStencilTarget=;" \
			"Pass=DrawObject;" \
		; \
	> { \
		pass BlurFront < string Script = "Draw=Buffer;";> { \
			ALPHABLENDENABLE = FALSE; \
			ALPHATESTENABLE=FALSE; \
			ZENABLE = FALSE; \
			ZWRITEENABLE = FALSE; \
			VertexShader = compile vs_3_0 Blur_VS(1); \
			PixelShader  = compile ps_3_0 Blur_PS(); \
		} \
		pass BlurBack < string Script = "Draw=Buffer;";> { \
			ALPHABLENDENABLE = FALSE; \
			ALPHATESTENABLE=FALSE; \
			ZENABLE = FALSE; \
			ZWRITEENABLE = FALSE; \
			VertexShader = compile vs_3_0 Blur_VS(-1); \
			PixelShader  = compile ps_3_0 Blur_PS(); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BufferShadow_VS(tex, sphere); \
			PixelShader  = compile ps_3_0 BufferShadow_PS(tex, sphere); \
		} \
	}

OBJECT_TEC0(OBJTec0, false, "object", true)
OBJECT_TEC0(OBJTec1, true,  "object", true)
OBJECT_TEC0(OBJTec2, false, "object", false)
OBJECT_TEC0(OBJTec3, true,  "object", false)

OBJECT_TEC(BSTec0, false, "object_ss", true)
OBJECT_TEC(BSTec1, true,  "object_ss", true)
OBJECT_TEC(BSTec2, false, "object_ss", false)
OBJECT_TEC(BSTec3, true,  "object_ss", false)

///////////////////////////////////////////////////////////////////////////////////////////////
