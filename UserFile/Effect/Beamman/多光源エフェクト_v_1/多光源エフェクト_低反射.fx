//メイン色バイアス
float3 BaseBias = float3(1,1,1);
//影色バイアス
float3 ShadowBias = float3(1,1,1);

//スペキュラ強度補正
float SP_Power = 1.0;

//スペキュラ光度補正
float SP_Scale = 1.0;

//スペキュラ光補正
float3 SP_Add = float3(0.1,0.1,0.1);

//リムライト強度
float RimPow	= 4.0;
//リムライトベース色
float3 RimLight = 1*float3(255,255,255)/255.0;
//ライトスケール
float LightScale = 1.0;

//メインライト係数
float MainLightParam = 0.7;
//サブライト係数
float SubLightParam = 0.5;

//メインハーフランバート係数
float MainHLamb = 0.25;
//サブハーフランバート係数
float SubHLamb = 0.5;
//シャドウリミット
float ShadowLimitLength = 0;
//ソフトシャドウパラメータ
float SoftShadowParam = 8;
#define SHADOWMAP_SIZE 4096

/////////////////////////////////////////////////////////////////////////////////////////

float X_SHADOWPOWER = 1.0;   //アクセサリ影濃さ
float PMD_SHADOWPOWER = 0.2; //モデル影濃さ


//スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R32F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// スクリーンサイズ
float2 ES_ViewportSize : VIEWPORTPIXELSIZE;
static float2 ES_ViewportOffset = (float2(0.5,0.5)/ES_ViewportSize);

bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;

float ShadowRate : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Tr"; >;


float3   ES_CameraPos1      : POSITION  < string Object = "Camera"; >;

float es_size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; >;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43 );

//カメラとシャドウ中心の距離
static float CameraDistance1 = length(ES_CameraPos1 - es_move1);


////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ベース：full.fx ver1.4
//  作成: 舞力介入P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
float4x4 LightWorldMatrix : WORLD < string Object = "Light"; >;

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
#define Toon     3

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

float3 LightPos[16] = {
	float3(0.53812504, 0.18565957, -0.43192),
	float3(0.13790712, 0.24864247, 0.44301823),
	float3(0.33715037, 0.56794053, -0.005789503),
	float3(-0.6999805, -0.04511441, -0.0019965635),
	float3(0.06896307, -0.15983082, -0.85477847),
	float3(0.056099437, 0.006954967, -0.1843352),
	float3(-0.014653638, 0.14027752, 0.0762037),
	float3(0.010019933, -0.1924225, -0.034443386),
	float3(-0.35775623, -0.5301969, -0.43581226),
	float3(-0.3169221, 0.106360726, 0.015860917),
	float3(0.010350345, -0.58698344, 0.0046293875),
	float3(-0.08972908, -0.49408212, 0.3287904),
	float3(0.7119986, -0.0154690035, -0.09183723),
	float3(-0.053382345, 0.059675813, -0.5411899),
	float3(0.035267662, -0.063188605, 0.54602677),
	float3(-0.47761092, 0.2847911, -0.0271716)
};


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
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
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
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * AmbientColor;
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
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
	
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color.rgb *= tex2D(ObjSphareSampler,IN.SpTex).rgb;
    }
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    }
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
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
	float4 ScreenTex : TEXCOORD5;   // スクリーン座標
    float4 Color    : COLOR0;       // ディフューズ色
};
// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
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
   
    float3 Add = 0;
    Out.Color.rgb = max(0,dot( Out.Normal, -LightDirection ) * MainHLamb + (1-MainHLamb)) * AmbientColor * MainLightParam;
    
    for(int i=0;i<16;i++)
    {
	    Add += max(0,dot( Out.Normal, normalize(mul(LightPos[i],LightWorldMatrix)))*SubHLamb + (1-SubHLamb))*AmbientColor*SubLightParam;
    }
    
    Out.Color.rgb += (Add/(16*LightScale))*1.0;
    //Out.Color.rgb = pow(Out.Color.rgb*1.5,1.5);
    Out.Color.a = smoothstep(0,0.9,DiffuseColor.a);
    //Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    //スクリーン座標取得
    Out.ScreenTex = Out.Pos;
    
    //超遠景におけるちらつき防止
    Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.05));
    
    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // スペキュラ色計算
	float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
	float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower+SP_Power ) * (SpecularColor+SP_Add) * SP_Scale * MainLightParam;
 
    for(int i=0;i<16;i++)
    {
    	HalfVector = normalize( normalize(IN.Eye) + -normalize(LightPos[i]) );
    	Specular += 0.16*pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower+SP_Power ) * (SpecularColor+SP_Add) * SP_Scale * SubLightParam;
    }
    float4 Color = IN.Color;
    float4 ShadowColor = IN.Color;  // 影の色
    
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
    
    //簡易リムライト
    float3 Rim = pow(1-saturate(max(0,dot( IN.Normal, normalize(IN.Eye) ) )),RimPow)* RimLight * pow(Color.rgb,2);
    
    Color.rgb += Rim;
    ShadowColor.rgb += Rim;
    
    // スペキュラ適用
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.5;
    
    Color.rgb *= BaseBias;
    ShadowColor.rgb *= ShadowBias;
    
    Color.a = saturate(Color.a);
    ShadowColor.a = saturate(ShadowColor.a);
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if(Exist_ExcellentShadow){
        
        IN.ScreenTex.xyz /= IN.ScreenTex.w;
        float2 TransScreenTex;
        TransScreenTex.x = (1.0f + IN.ScreenTex.x) * 0.5f;
        TransScreenTex.y = (1.0f - IN.ScreenTex.y) * 0.5f;
        float4 SadowMapVal = tex2D(ScreenShadowMapProcessedSamp, TransScreenTex + ES_ViewportOffset).r;
        
        ShadowColor.rgb *= (1 - (1 - ShadowRate) * X_SHADOWPOWER);
        
        Color = lerp(ShadowColor, Color, SadowMapVal);
        
        return Color;
        
    } else if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
        float zcal = max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f);
        zcal = smoothstep(0,ShadowLimitLength,zcal);
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
        
        float4 ans = lerp(ShadowColor, Color, comp);
        ans.a = 1;
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
