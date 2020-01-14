
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
// AbsoluteShadowシステム　ここから↓

float X_SHADOWPOWER = 1.0;
float PMD_SHADOWPOWER = 0.0;

#include "AbsoluteShadowShaderSystem.fx"

// AbsoluteShadowシステム　ここまで↑
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////



//異方性フィルタリングスイッチ
#define FILTER_ENABLE  1
#define MIPTEXSIZE 1024

float3 CoverColor1 = float3(1, 1, 1);


bool FogFlag : CONTROLOBJECT < string name = "SnowCoverFog.x"; >;

float FogSize1 : CONTROLOBJECT < string name = "SnowCoverFog.x"; string item = "Si"; >;
static float FogSize = FogSize1 * 0.1;


// 距離フォグ(カメラからの距離でフォグをかける)
static float4 FogColor = float4(0.75f, 0.75f, 0.77f, 1.0f);    // 霧の色(RGBA)
static float FogStart = 100.0f * FogSize, FogDistance = 2000.0f * FogSize;    // 霧のかかる距離、範囲
static float FogEnd = FogStart + FogDistance;
static float2 FogCoord = float2(FogEnd / (FogEnd - FogStart), -1 / (FogEnd - FogStart)); // 係数を計算
static float FogMax = 1.0;


// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
//float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

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


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;

#if FILTER_ENABLE==0
    //標準のサンプラーをそのまま使用
    sampler ObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };
    
#else
    //異方性フィルタリング可能なテクスチャにコピーし、
    //それをサンプリングするようサンプラーを置き換え
    
    sampler DefObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };

    texture UseMipmapObjectTexture : RENDERCOLORTARGET <
        int Width = MIPTEXSIZE;
        int Height = MIPTEXSIZE;
        int MipLevels = 0;
        string Format = "A8R8G8B8" ;
    >;
    sampler ObjTexSampler = sampler_state {
        texture = <UseMipmapObjectTexture>;
        MINFILTER = ANISOTROPIC;
        MAGFILTER = ANISOTROPIC;
        MIPFILTER = LINEAR;
        MAXANISOTROPY = 16;
    };

    texture2D DepthBuffer : RenderDepthStencilTarget <
        int Width = MIPTEXSIZE;
        int Height = MIPTEXSIZE;
        string Format = "D24S8";
    >;
    
    static float2 ViewportOffset = (float2(0.5,0.5)/MIPTEXSIZE);
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // ミップマップ作成
    
    struct VS_OUTPUT_MIPMAPCREATER {
        float4 Pos : POSITION;
        float2 Tex : TEXCOORD0;
    };
    VS_OUTPUT_MIPMAPCREATER VS_MipMapCreater( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
        VS_OUTPUT_MIPMAPCREATER Out;
        Out.Pos = Pos;
        Out.Tex = Tex;
        Out.Tex += ViewportOffset;
        return Out;
    }
    
    float4  PS_MipMapCreater(float2 Tex: TEXCOORD0) : COLOR0
    {
        return tex2D(DefObjTexSampler,Tex);
    }
    
#endif


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
    float Fog        : COLOR1;
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
    
    
    // フォグ係数計算
    Out.Fog = saturate(FogCoord.x + Out.Pos.w * FogCoord.y);
    Out.Fog = clamp(Out.Fog, 1 - FogMax, 1);
    
    Out.Fog = FogFlag ? Out.Fog : 1;
    
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
        if(spadd) Color += tex2D(ObjSphareSampler,IN.SpTex);
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    
    
    // Snow Color
    float CoverNormal = dot( IN.Normal, float3(0,1,0)); //法線とY軸ベクトルの内積
    float CoverAlpha = saturate(CoverNormal * 1.5 + 0.1) * 0.92; //合成度を決定
    float3 CoverColor2 = lerp(saturate(LightSpecular + LightAmbient), CoverColor1, 0.6); //光源の影響
    Color.rgb = lerp(Color.rgb, CoverColor2, CoverAlpha); //色合成
    Specular *= (1 - CoverAlpha); //雪のある部分はスペキュラ無効に
    
    
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    }
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    
    // フォグ合成
    float4 FogColorL = FogColor;
    FogColorL.rgb *= saturate(LightSpecular + LightAmbient);
    Color.rgb = lerp(FogColorL.rgb, Color.rgb, IN.Fog);
    
    
    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    
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
    float4 Color    : COLOR0;       // ディフューズ色
    float Fog        : COLOR1;
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
    
    
    // フォグ係数計算
    Out.Fog = saturate(FogCoord.x + Out.Pos.w * FogCoord.y);
    Out.Fog = clamp(Out.Fog, 1 - FogMax, 1);
    
    Out.Fog = FogFlag ? Out.Fog : 1;
    
    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
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
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    
    
    // Snow Color
    float CoverNormal = dot( IN.Normal, float3(0,1,0)); //法線とY軸ベクトルの内積
    float CoverAlpha = saturate(CoverNormal * 1.5 + 0.1) * 0.92; //合成度を決定
    float3 CoverColor2 = lerp(saturate(LightSpecular + LightAmbient), CoverColor1, 0.6); //光源の影響
    Color.rgb = lerp(Color.rgb, CoverColor2, CoverAlpha); //色合成
    ShadowColor.rgb = lerp(ShadowColor.rgb, CoverColor2 * 0.4, CoverAlpha); //色合成
    Specular *= (1 - CoverAlpha); //雪のある部分はスペキュラ無効に
    
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    /////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////
    // AbsoluteShadowシステム　ここから↓
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord = 0.5 + IN.ZCalcTex * float2(0.5, -0.5);
    
    float comp = saturate(dot(IN.Normal,-LightDirVec)*Toon);
    
    if(!any( saturate(TransTexCoord) != TransTexCoord ) ) { 
        // シャドウバッファ内
        
        ////VSM法の実装
        float2 depth = GetZBufSample(TransTexCoord);
        depth.y += 0.00002;
        float sigma2 = depth.y - depth.x * depth.x;
        float comp2 = sigma2 / (sigma2 + IN.ZCalcTex.z - depth.x);
        comp2 = saturate(comp2) + (comp2 < 0);
        
        comp = min(comp, comp2);
    }
    
    if ( useToon ) {
        // トゥーン適用
        ShadowColor.rgb *= MaterialToon;
        ShadowColor.rgb *= (1 - (1 - ShadowRate) * PMD_SHADOWPOWER);
    }else{
        ShadowColor.rgb *= (1 - (1 - ShadowRate) * X_SHADOWPOWER);
    }
    
    Color = lerp(ShadowColor, Color, comp);
    
    // AbsoluteShadowシステム　ここまで↑
    /////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////
    
    // フォグ合成
    float4 FogColorL = FogColor;
    FogColorL.rgb *= saturate(LightSpecular + LightAmbient);
    Color.rgb = lerp(FogColorL.rgb, Color.rgb, IN.Fog);
    
    
    return Color;
}



///////////////////////////////////////////////////////////////////////////////////////////////
//テクニックリスト

#if FILTER_ENABLE==0
// テクニックのリスト

// オブジェクト描画用テクニック（アクセサリ用）
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
// オブジェクト描画（セルフシャドウON）
// セルフシャドウOFF時と同じ描画を行う

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

#else
// テクニックのリスト・異方性フィルタリング使用時


// レンダリングターゲットのクリア値
float4 TexClearColor = {0,0,0,0};
float TexClearDepth  = 1.0;


// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）
// セルフシャドウOFF時と同じ描画を行う

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; 
    string Script= 
        "RenderColorTarget0=UseMipmapObjectTexture;"
            "RenderDepthStencilTarget=DepthBuffer;"
                "ClearSetColor=TexClearColor; ClearSetDepth=TexClearDepth;"
                "Clear=Color; Clear=Depth;"
            "Pass=CreateMipmap;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        ;
 > {
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
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

#endif

///////////////////////////////////////////////////////////////////////////////////////////////
