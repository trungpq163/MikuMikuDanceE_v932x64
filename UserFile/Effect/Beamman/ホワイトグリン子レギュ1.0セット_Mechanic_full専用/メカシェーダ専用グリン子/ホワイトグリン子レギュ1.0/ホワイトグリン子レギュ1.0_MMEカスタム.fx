//メカっぽいシェーダ
//ビームマンP

//フィルライト色
float3 FillLight = float3(100,75,50)/255.0;
//バックライト色
float3 BackLight = float3(100,92,82)/255.0;
//空色
float3 SkyColor = float3(0.9f, 0.9f, 1.0f);
//地面色
float3 GroundColor = float3(0.1f, 0.05f, 0.0f);
//明るさ補正値
float LightParam = 1;
//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//自己発色抑制値
float EmmisiveParam = 0.5;

//ここから触らない
#define DefSubset "8-13,15-19"


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

static float3 AmbientColor_Def  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

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
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    // テクスチャ適用
    float2 tex = abs(frac(IN.Tex)*0.5);
    
	float4 Color;
	float3 normal;
	if ( useTexture ) {
		float3 Eye = normalize(CameraPosition.xyz - IN.WorldPos.xyz);
		tex = tex - Eye.xy * tex2D( ObjTexSampler, tex+float2(0.5,0.5)) * 0.002;
        tex = clamp(tex,0,0.4995);
		float4 NormalColor = tex2D( ObjTexSampler, tex+float2(0,0.5));	
		NormalColor = NormalColor.rbga;
		NormalColor.a = 1;
		float3x3 tangentFrame = compute_tangent_frame(IN.Normal, Eye, IN.Tex);
		normal = normalize(mul(2.0f * NormalColor - 1.0f, tangentFrame));

	    // ディフューズ色＋アンビエント色 計算

	    Color.rgb = AmbientColor;
	    Color.rgb += max(0,dot( normal, -LightDirection )) * DiffuseColor.rgb;
	    
	    Color.a = DiffuseColor.a;
	    Color = saturate( Color );
	    
	}else{
	    Color.rgb = AmbientColor;
	    Color.rgb += max(0,dot( IN.Normal, -LightDirection )) * DiffuseColor.rgb;
	    Color.a = 1;
	    normal = IN.Normal;		
	}
	//normal = IN.Normal;	
				
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(normal) )), SpecularPower ) * 1;
    
    float4 ShadowColor = Color*0.8;//float4(Color, Color.a);  // 影の色
    ShadowColor.a = 1;
    
    if ( useTexture ) {
        float4 TexColor = tex2D( ObjTexSampler, tex );
        float4 TexColor2 = tex2D( ObjTexSampler, tex+float2(0.5,0) );

		TexColor = lerp(TexColor,TexColor2,1);
		
        Color *= TexColor;
        ShadowColor *= TexColor;
        
    }
    
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular*0.5;
	return Color;
}
// オブジェクト描画用テクニック
// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS_NOTEX  < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
}
technique MainTecBS  < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
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
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

#define SHADOWMAP_SIZE 1024
#define SHADOW_COLOR 0.1
float SoftShadow( sampler samp, float2 Tex, float d)
{
	float Shadow = 4.0f;
	float U = 1.0f / SHADOWMAP_SIZE;
	float V = 1.0f / SHADOWMAP_SIZE;
	U = 0;
	V = 0;
	float Adjust = 0.0;
	float2 uv = Tex + float2( 0.0f, -V);
	if( tex2D( samp, uv ).x + Adjust <= d){ Shadow -= SHADOW_COLOR;}
	uv = Tex + float2( -U, 0.0f);
	if( tex2D( samp, uv ).x + Adjust <= d){ Shadow -= SHADOW_COLOR;}
	uv.x += U + U;
	if( tex2D( samp, uv ).x + Adjust <= d){ Shadow -= SHADOW_COLOR;}
	uv = Tex + float2( 0.0f, V);
	if( tex2D( samp, uv ).x + Adjust <= d){ Shadow -= SHADOW_COLOR;}
	
	return Shadow / 4.0f;
}



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
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	Out.WorldPos = Pos;
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
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}
// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_Def_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor_Def;
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


// ピクセルシェーダ
float4 BufferShadow_Mec_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // テクスチャ適用
    float2 tex = abs(frac(IN.Tex)*0.5);
	float4 Color;
	float3 normal;
	float4 TexColor = 1;
	if ( useTexture ) {
		float2 BaseTex = tex;
		float3 Eye = normalize(CameraPosition.xyz - IN.WorldPos.xyz);
		tex = tex - Eye.xy * tex2D( ObjTexSampler, tex+float2(0.5,0.5)).r * 0.0001;
        tex = clamp(tex,0,0.4995);
		float4 NormalColor = tex2D( ObjTexSampler, tex+float2(0,0.5))*2;	
		NormalColor = NormalColor.rgba;
		NormalColor.a = 1;
		float3x3 tangentFrame = compute_tangent_frame(IN.Normal, Eye, IN.Tex);
		normal = normalize(mul(NormalColor - 1.0f, tangentFrame));
		//normal = NormalColor;
	    // ディフューズ色＋アンビエント色 計算


	    Color.a = DiffuseColor.a;
	    Color = saturate( Color );
			    
		TexColor = tex2D( ObjTexSampler, BaseTex );
	}else{
	    Color.rgb = AmbientColor;
	    Color.rgb += max(0,dot( IN.Normal, -LightDirection )) * DiffuseColor.rgb;
	    Color.a = 1;
	    normal = IN.Normal;		
	}
	float3 N = normal;	//法線
	float3 V = normalize(IN.Eye);	//視線ベクトル
    float amount = (dot( normal, float3(0,1,0) )+1) * 0.5;
    float3 HalfSphereL = lerp( GroundColor, SkyColor, amount ) * 0.1;
	Color.rgb = max(0,dot( normal, -LightDirection )) * AmbientColor + MaterialEmmisive * EmmisiveParam;
	Color.rgb += max(0,dot( normal, normalize(-LightDirection+float3(0,0,-1)) )) * FillLight*0.25;
	Color.rgb += max(0,dot( normal, normalize(-V) + float3(0,-0.5,0) )) * BackLight*2;
	Color.rgb += HalfSphereL;
	Color *= TexColor;

	// スペキュラ色計算
    float3 Specular = CalcSpecular(normalize(-LightDirection),N,V,AmbientColor) * 1
    +				CalcSpecular(normalize(-LightDirection+mul(WorldMatrix,float3(0.5,1,-0.5))),N,V,FillLight*0.5)*1
    +				CalcSpecular(normalize(mul(WorldMatrix,float3(-0.5,0.5,10))),N,V,BackLight*1);
	Specular = saturate(pow(Specular,2));
	
    float anti_sp = tex2D( ObjTexSampler, tex+float2(0.5,0.0)).r * LightParam;
    Specular *= anti_sp;
    //return float4(Specular,1);

    float4 ShadowColor = Color*0.8;//float4(Color, Color.a);  // 影の色
    ShadowColor *= TexColor;
    //float4 ShadowColor = float4(float3(0,0,0), Color.a);  // 影の
    ShadowColor.a = Color.a;

    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.5;
    ShadowColor.rgb = Color.rgb*0.5;
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
        float comp = 0;
		float U = SoftShadowParam / SHADOWMAP_SIZE;
		float V = SoftShadowParam / SHADOWMAP_SIZE;
        if(parthf) {
            // セルフシャドウ mode2
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII1-0.3f);
        }
        comp = 1-saturate(comp/9);
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
// ピクセルシェーダ
float4 BufferShadow_Def_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor_Def, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
            ShadowColor.rgb *= TexColor.rgb;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
        float comp = 0;
		float U = SoftShadowParam / SHADOWMAP_SIZE;
		float V = SoftShadowParam / SHADOWMAP_SIZE;
        if(parthf) {
            // セルフシャドウ mode2
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII1-0.3f);
        }
        comp = 1-saturate(comp/9);
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
        
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}



// オブジェクト描画用テクニック（PMDモデル用）
//肌用

technique MainTecDefBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;  string Subset=DefSubset;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Def_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Def_PS(false, false, true);
    }
}

technique MainTecDefBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;  string Subset=DefSubset;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Def_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Def_PS(true, false, true);
    }
}

technique MainTecDefBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;  string Subset=DefSubset;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Def_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Def_PS(false, true, true);
    }
}

technique MainTecDefBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;  string Subset=DefSubset;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_Def_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Def_PS(true, true, true);
    }
}

//メカ部分用
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_Mec_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
