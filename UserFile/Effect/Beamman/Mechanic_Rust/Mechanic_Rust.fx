//メカっぽいシェーダ ver2.0
//ビームマンP

//ソフトシャドウフラグ
//　//#define～　と、//をつけると無効に
//#define USE_SOFTSHADOW

//ﾍﾞﾍﾞﾙ使用フラグ
//　//#define～　と、//をつけると無効に
#define USE_BEVEL

//特殊ｽﾍﾟｷｭﾗ使用フラグ
//　//#define～　と、//をつけると無効に
#define EXSpecular

//フルテクスチャフラグ
//　//#define～　と、//をつけると有効に
//テクスチャ改造が必要です。詳しくは同梱の「フルテクスチャについて.txt」を参照の事
#define USE_FULLMODE

//フィルライト色
float3 FillLight = float3(194,150,104)/255.0;
//バックライト色
float3 BackLight = float3(82,92,100)/255.0*0.5;
//空色
float3 SkyColor = float3(0.9f, 0.9f, 1.0f)*0.1;
//地面色
float3 GroundColor = float3(0.1f, 0.05f, 0.0f)*0.1;
//各種マップ密度
float MapParam = 4;
//自己発色抑制値
float EmmisiveParam = 0;
//ベベルの広さ
float BevelParam = 1;
//ベベル強さ
float BevelPow = 1;

//スペキュラ倍率
float SpecularPow = 1;

//ハーフランバート係数 0でランバート準拠 1でハーフランバート準拠
float HalfLambParam = 0;

//シャドウマップサイズ
#define SHADOWMAP_SIZE 1024
//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (BevelParam/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ベース
//  full.fx ver1.3
//  作成: 舞力介入P
//
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
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient * LightAmbient);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

//自己の法線を保存するテクスチャ
texture NormalTex : RenderColorTarget
<
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler NormalSampler = sampler_state {
    texture = <NormalTex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
#define ANISO_NUM 16
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};
// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
texture2D SabiMap <
    string ResourceName = "sabi.jpg";
>;
sampler SabiMapSamp = sampler_state {
    texture = <SabiMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};
texture2D SpMap <
    string ResourceName = "SpMap.png";
>;
sampler SpMapSamp = sampler_state {
    texture = <SpMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};
texture2D HeightMap <
    string ResourceName = "HeightMap.png";
>;
sampler HeightMapSamp = sampler_state {
    texture = <HeightMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
};
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

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

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
    float4 WorldPos      : TEXCOORD5;     // ワールド空間座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.WorldPos = Pos;
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
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
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
	return IN.Color;
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION,float2 Tex : TEXCOORD0 )
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
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 WorldPos      : TEXCOORD5;     // ワールド空間座標
    float4 Color    : COLOR0;       // ディフューズ色
    float4 LocalPos		: TEXCOORD6;
    float4 LastPos	: TEXCOORD7;
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_Mec_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	Out.LocalPos = Pos;
	Out.WorldPos = mul( Pos, WorldMatrix );
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    Out.LastPos = Out.Pos;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
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
	float4 Norm = 1;
	
	#ifdef USE_FULLMODE
		float2 full_tex = abs(frac(Tex)*0.5);
	#endif
    float2 tex = Tex* MapParam;
	float4 Color;
	float3 normal;
	float height = 0;
	
	height = tex2D( HeightMapSamp, Tex * MapParam).r;
	float4 NormalColor = tex2D( NormalMapSamp, tex)*2;	
	
	#ifdef USE_FULLMODE
	if ( useTexture ) {
		height = tex2D( ObjTexSampler, full_tex+float2(0.5,0.5)).r;
		NormalColor *= tex2D( ObjTexSampler, full_tex+float2(0,0.5))*2;
	}
	#endif
	
	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;
	float3x3 tangentFrame = compute_tangent_frame(Normal, Eye, Tex);
	Norm.rgb = normalize(mul(NormalColor - 1.0f, tangentFrame));

	return Norm;
}

// 法線出力シェーダ
float4 Normal_PS(VS_OUTPUT IN,uniform bool useTexture) : COLOR0
{
	return CalcNormal(IN.Tex,normalize(IN.Eye),normalize(IN.Normal),useTexture);
}


//べックマン分布計算関数
inline float CalcBeckman(float m, float cosbeta)
{
	return (
		exp(-(1-(cosbeta*cosbeta))/(m*m*cosbeta*cosbeta))
		/(4*m*m*cosbeta*cosbeta*cosbeta*cosbeta)
		);
}

//フレネル計算関数
inline float CalcFresnel(float n, float c)
{
	float g = sqrt(n*n + c*c - 1);
	float T1 = ((g-c)*(g-c))/((g+c)*(g+c));
	float T2 = 1 + ( (c*(g+c)-1)*(c*(g+c)-1) )/( (c*(g-c)+1)*(c*(g-c)+1) );
	return 0.5 * T1 * T2;
}

//スペキュラ計算関数
inline float3 CalcSpecular(float3 L,float3 N,float3 V,float3 Col)
{
	float3 H = normalize(L + V);	//ハーフベクトル

	#ifndef EXSpecular
	float3 Specular = pow( max(0,dot( H, normalize(N) )), (SpecularPower)) * (Col);
    return Specular;
	#endif
	
	//計算に使う角度
	float NV = dot(N, V);
	float NH = dot(N, H);
	float VH = dot(V, H);
	float NL = dot(N, L);

	//Beckmann分布関数
	float D = CalcBeckman(0.35f, NH);

	//幾何減衰率
	float G = min(1, min(2*NH*NV/VH, 2*NH*NL/VH));

	//フレネル項
	float F = CalcFresnel(20.0f, dot(L, H));
	
	return max(0, F*D*G/NV)*1 * Col;
}

float2 test[]=
{
	{1,0},	{0,1},
	{-1,0},	{0,-1},
	{1,-1},	{-1,1},
	{1,1},	{-1,-1},
};


// ピクセルシェーダ
float4 BufferShadow_Mec_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{

	#ifdef USE_FULLMODE
		float2 full_tex = abs(frac(IN.Tex)*0.5);
	#endif
	
	float2 ScrTex;
    ScrTex.x = (IN.LastPos.x / IN.LastPos.w)*0.5+0.5;
	ScrTex.y = (-IN.LastPos.y / IN.LastPos.w)*0.5+0.5;
	
	IN.Normal = CalcNormal(IN.Tex,normalize(IN.Eye),normalize(IN.Normal),useTexture).rgb;
	IN.Normal = normalize(IN.Normal);
	
	#ifdef USE_BEVEL
		float3 BaseNormal = IN.Normal;
		IN.Normal = (tex2D(NormalSampler,ScrTex).rgb);
		
		//9点サンプリング
		for(int i=0;i<8;i++)
		{
			IN.Normal += tex2D(NormalSampler,ScrTex+test[i]*SampStep).rgb;
		}
		IN.Normal = lerp(BaseNormal,normalize(IN.Normal),BevelPow);
	#endif
	
    float3 normal = IN.Normal;
	float3 Eye = normalize(IN.Eye);
	float height = tex2D( HeightMapSamp, IN.Tex * MapParam).r;
	float2 tex = IN.Tex * MapParam - Eye.xy * height*0.005;
    
    //return float4(normal,1);
    
    float4 Color = 1;
    Color.a = IN.Color.a;

	float half_mul = lerp(1,0.5,HalfLambParam);
	float half_add = lerp(0,0.5,HalfLambParam);
	Color.rgb = max(0,dot( normal, -LightDirection )*half_mul+half_add) * AmbientColor * LightAmbient * 2;
	Color.rgb += max(0,dot( normal, normalize(normalize(-Eye) ) )*half_mul+half_add) * BackLight*2* LightAmbient * 2;
	Color.rgb += max(0,dot( normal, normalize(Eye) )*half_mul+half_add) * FillLight*0.25* LightAmbient * 2;
	
	float3 N = normal;	//法線
	float3 V = normalize(IN.Eye);	//視線ベクトル
    float amount = (dot( normal, float3(0,1,0) )+1) * 0.5;
    float3 HalfSphereL = lerp( GroundColor, SkyColor, amount );
    Color.rgb += HalfSphereL;
    
    Color.rgb += (1-saturate(max(0,dot( normal, normalize(Eye)*2 ) )))*BackLight * LightAmbient;
	//return Color;
	// スペキュラ色計算
    float3 Specular = 
    				CalcSpecular(normalize(-LightDirection),N,V,AmbientColor)  * LightAmbient
    +				CalcSpecular(normalize(-LightDirection+mul(WorldMatrix,float3(0.5,1,-0.5))),N,V,FillLight*0.5) * LightAmbient
    +				CalcSpecular(normalize(mul(WorldMatrix,float3(-0.5,0.5,10))),N,V,BackLight*1) * LightAmbient
    ;
    				 
    float anti_sp = tex2D( SpMapSamp, tex).r;
    #ifdef USE_FULLMODE
    	anti_sp *= tex2D( ObjTexSampler, full_tex+float2(0.5,0.0)).r;
    #endif
    Specular *= anti_sp*SpecularPow;
    //テスト出力
    //return float4(Specular,1);

    float4 ShadowColor = Color*0.8;//float4(Color, Color.a);  // 影の色
    //float4 ShadowColor = float4(float3(0,0,0), Color.a);  // 影の
    ShadowColor.a = Color.a;
    Color.rgb = saturate(Color.rgb+MaterialEmmisive*EmmisiveParam);
    ShadowColor.rgb = saturate(ShadowColor.rgb+MaterialEmmisive*EmmisiveParam);
	
    if ( useTexture ) {
    	//テクスチャ適用
		#ifdef USE_FULLMODE
        	float4 TexColor = tex2D( ObjTexSampler, full_tex );
		#else
	        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );	
	    #endif
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    
	Color = lerp(Color,tex2D(SabiMapSamp,IN.Tex),1-height);
	ShadowColor = lerp(ShadowColor,tex2D(SabiMapSamp,IN.Tex),1-height);
	
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor;
            ShadowColor.rgb += TexColor;
        } else {
            Color.rgb *= TexColor;
            ShadowColor.rgb *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.5;
    ShadowColor.rgb = Color.rgb*0.5;
    
        
    //高さマップによる色補正
    Color.rgb *= saturate(height+0.5);
    ShadowColor.rgb *= saturate(height+0.5);
		 
    float4 WP = IN.LocalPos;
    WP.xyz += normal*height*0;
    
    //Zテクスチャ作り直し
    IN.ZCalcTex = mul( WP, LightWorldViewProjMatrix );
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
    	float zcol = tex2D(DefSampler,TransTexCoord).r;
        float comp = 0;
		float U = SoftShadowParam / SHADOWMAP_SIZE;
		float V = SoftShadowParam / SHADOWMAP_SIZE;
		#ifndef USE_SOFTSHADOW
	        if(parthf) {
	            // セルフシャドウ mode2
	            float Skill = SKII2*TransTexCoord.y;
	            comp=1-saturate(max(IN.ZCalcTex.z-zcol , 0.0f)*Skill-0.3f);
	        } else {
	            // セルフシャドウ mode1
	            float Skill = SKII1-0.3f;
	            comp=1-saturate(max(IN.ZCalcTex.z-zcol , 0.0f)*Skill-0.3f);
	        }
		#else
	        if(parthf) {
	            // セルフシャドウ mode2
	            float Skill = SKII2*TransTexCoord.y-0.3f;
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*Skill-0.3f);
	        } else {
	            // セルフシャドウ mode1
	            float Skill = SKII1-0.3f;
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*Skill-0.3f);
		        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*Skill-0.3f);
	        }
	        comp = 1-saturate(comp/9);
	    #endif
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
       
        
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss";bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif
	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, false, false);
    }
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif
		
	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; 
    string Script = 
    	#ifdef USE_BEVEL
	        "RenderColorTarget0=NormalTex;"
		    "RenderDepthStencilTarget=DepthBuffer;"
			"ClearSetColor=ClearColor;"
			"ClearSetDepth=ClearDepth;"
			"Clear=Color;"
			"Clear=Depth;"
	        "Pass=DrawNormal;"
		#endif

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawNormal {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Normal_PS(true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Mec_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, true, true);
    }
}



///////////////////////////////////////////////////////////////////////////////////////////////
