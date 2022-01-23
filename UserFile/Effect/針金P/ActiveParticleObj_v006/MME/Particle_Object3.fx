////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Particle_Object.fx  オブジェクトが移動している時だけ複製モデルを粒子にして放出
//   (ActiveParticleObj.fxと一緒に使用,複製モデルに適用する)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int RepertCount = 1000;  // モデル複製数(最大4096まで)

#define SHADOW_ON  0        // 非セルフシャドウ地面影描画 0:しない,1:する

#define EDGE_ON_MAT   "0-"      // エッジを描画する材質番号
float EdgeThickness = 1.0;  // エッジの太さ

// 粒子オブジェクトID番号
#define  ObjectNo  3   // 0～3以外で新たに粒子オブジェクトを増やす場合はファイル名変更とこの値を4,5,6･･と変えていく


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

#define LOOPSCRIPT_OBJECT       "LoopByCount=RepertCount; LoopGetIndex=RepertIndex; Pass=DrawObject; LoopEnd=;"
#define LOOPSCRIPT_OBJECT_EDGE  "LoopByCount=RepertCount; LoopGetIndex=RepertIndex; Pass=DrawObject; Pass=DrawEdge; LoopEnd=;"
#define LOOPSCRIPT_EDGE         "LoopByCount=RepertCount; LoopGetIndex=RepertIndex; Pass=DrawEdge; LoopEnd=;"
#define LOOPSCRIPT_SHADOW       "LoopByCount=RepertCount; LoopGetIndex=RepertIndex; Pass=DrawShadow; LoopEnd=;"
#define LOOPSCRIPT_ZPLOT        "LoopByCount=RepertCount; LoopGetIndex=RepertIndex; Pass=ZValuePlot; LoopEnd=;"

#define  WorldMatrixTexName(n)  ActiveParticle_WorldMatrixTex##n   // ワールド座標記録用テクスチャ名

int RepertIndex;  // 複製モデルカウンタ

#define TEX_WIDTH_W   16  // 粒子ワールド座標テクスチャピクセル幅
#define TEX_HEIGHT  1024  // 粒子ワールド座標テクスチャピクセル高さ

// 座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;
float4x4 LightViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;

float3 LightDirection    : DIRECTION < string Object = "Light"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3 MaterialToon      : TOONCOLOR;
float4 EdgeColor         : EDGECOLOR;
float4 GroundShadowColor : GROUNDSHADOWCOLOR;
// ライト色
float3 LightDiffuse      : DIFFUSE  < string Object = "Light"; >;
float3 LightAmbient      : AMBIENT  < string Object = "Light"; >;
float3 LightSpecular     : SPECULAR < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4 TextureAddValue : ADDINGTEXTURE;
float4 TextureMulValue : MULTIPLYINGTEXTURE;
float4 SphereAddValue  : ADDINGSPHERETEXTURE;
float4 SphereMulValue  : MULTIPLYINGSPHERETEXTURE;

bool parthf;   // パースペクティブフラグ
bool transp;   // 半透明フラグ
bool spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

bool use_subtexture;    // サブテクスチャフラグ

// オブジェクトのテクスチャ
texture ObjectTexture : MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap : MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// トゥーンマップのテクスチャ
texture ObjectToonTexture: MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state {
    texture = <ObjectToonTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};

// 粒子のワールド変換行列が記録されているテクスチャ
shared texture WorldMatrixTexName(ObjectNo) : RenderColorTarget;
sampler ActiveParticle_SmpWldMat : register(s3) = sampler_state
{
    Texture = <WorldMatrixTexName(ObjectNo)>;
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MAGFILTER = NONE;
    MINFILTER = NONE;
    MIPFILTER = NONE;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの配置変換行列(配置後のワールド変換行列)
float4x4 SetTransMatrix(out float alpha)
{
    int i = (RepertIndex / TEX_HEIGHT) * 4;
    int j = RepertIndex % TEX_HEIGHT;
    float y = (j+0.5f)/TEX_HEIGHT;

    // モデルの配置変換行列
    float4x4 TrMat = float4x4( tex2Dlod(ActiveParticle_SmpWldMat, float4((i+0.5f)/TEX_WIDTH_W, y, 0, 0)), 
                               tex2Dlod(ActiveParticle_SmpWldMat, float4((i+1.5f)/TEX_WIDTH_W, y, 0, 0)), 
                               tex2Dlod(ActiveParticle_SmpWldMat, float4((i+2.5f)/TEX_WIDTH_W, y, 0, 0)), 
                               tex2Dlod(ActiveParticle_SmpWldMat, float4((i+3.5f)/TEX_WIDTH_W, y, 0, 0)) );

    alpha = TrMat._44;
    TrMat._44 = 1.0f;

    return TrMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

struct VS_OUTPUT2 {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Edge_VS(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // ワールド座標変換による頂点法線
    Normal = mul( Normal, (float3x3)WorldMatrix );

    // 複製モデルの配置座標変換
    float alpha;
    float4x4 TransMatrix = SetTransMatrix(alpha);
    Pos = mul( Pos, TransMatrix );

    // 配置座標変換による頂点法線
    Normal = normalize( mul( Normal, (float3x3)TransMatrix ) );

    // カメラとの距離
    float len = max( length( CameraPosition - Pos ), 5.0f );

    // 頂点を法線方向に押し出す
    if(ProjMatrix._44 < 0.5f){
        // パースペクティブon
        Pos.xyz += Normal * ( EdgeThickness * pow( len, 0.9f ) * 0.0015f * pow(2.4142f / ProjMatrix._22, 0.7f) );
    }else{
        // パースペクティブoff
        Pos.xyz += Normal * ( EdgeThickness * 0.0025f / ProjMatrix._11 );
    }

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // モデルのalpha値
    Out.Color = float4(1.0f, 1.0f, 1.0f, alpha);

    return Out;
}

// ピクセルシェーダ
float4 Edge_PS(VS_OUTPUT2 IN) : COLOR
{
    clip(IN.Color.a-0.001f);

    // 輪郭色で塗りつぶし
    return (EdgeColor*IN.Color);
}

// オブジェクト描画テクニックで EdgeColor を取得するためのダミー処理
// 頂点シェーダ
float4 DummyEdge_VS(float4 Pos : POSITION) : POSITION 
{
    return float4(0,0,0,0);
}
// ピクセルシェーダ
float4 DummyEdge_PS() : COLOR
{
    return float4(0,0,0,0);
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 DummyEdge_VS();
        PixelShader  = compile ps_2_0 DummyEdge_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 非セルフシャドウ地面影描画

#if(SHADOW_ON==1)
// 頂点シェーダ
VS_OUTPUT2 Shadow_VS(float4 Pos : POSITION)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

    // 複製モデルの配置座標変換
    float alpha;
    float4x4 TransMatrix = SetTransMatrix(alpha);
    Pos =  mul( Pos, TransMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // モデルのalpha値
    Out.Color = float4(1.0f, 1.0f, 1.0f, alpha);

    return Out;
}

// ピクセルシェーダ
float4 Shadow_PS(VS_OUTPUT2 IN) : COLOR
{
    clip(IN.Color.a-0.001f);

    // 地面影色で塗りつぶし
    return (GroundShadowColor*IN.Color);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; string Script = LOOPSCRIPT_SHADOW; >
{
    pass DrawShadow {
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}

#else
technique ShadowTec < string MMDPass = "shadow"; >{ }
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos     : POSITION;    // 射影変換座標
    float2 Tex     : TEXCOORD1;   // テクスチャ
    float3 Normal  : TEXCOORD2;   // 法線
    float3 Eye     : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex   : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 Color   : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // ワールド座標変換による頂点法線
    Normal = mul( Normal, (float3x3)WorldMatrix );

    // 複製モデルの配置座標変換
    float alpha;
    float4x4 TransMatrix = SetTransMatrix(alpha);
    Pos = mul( Pos, TransMatrix );

    // 配置座標変換による頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)TransMatrix ) );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - Pos.xyz;

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a * alpha;
    Out.Color = saturate( Out.Color );

    // テクスチャ座標
    Out.Tex = Tex;

    if ( useSphereMap ) {
        if( use_subtexture ) {
            // PMXサブテクスチャ座標
            Out.SpTex = Tex2;
        } else {
            // スフィアマップテクスチャ座標
            float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
            Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
            Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
        }
    }

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    clip(IN.Color.a-0.001f);

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
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) Color.rgb += TexColor.rgb;
        else      Color.rgb *= TexColor.rgb;
        Color.a *= TexColor.a;
    }

    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color *= tex2D( ObjToonSampler, float2(0.0f, 0.5f-LightNormal*0.5f) );
    }

    // スペキュラ適用
    Color.rgb += Specular;

    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用,エッジ有り）
technique MainTec4 < string MMDPass = "object";  string Subset = EDGE_ON_MAT;
                     bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTec5 < string MMDPass = "object"; string Subset = EDGE_ON_MAT;
                     bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTec6 < string MMDPass = "object"; string Subset = EDGE_ON_MAT;
                     bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTec7 < string MMDPass = "object"; string Subset = EDGE_ON_MAT;
                     bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

// オブジェクト描画用テクニック（PMDモデル用,エッジ無し）
technique MainTec8 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
}

technique MainTec9 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
                     string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
}

technique MainTec10 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
                      string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
}

technique MainTec11 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
                      string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos          : POSITION;    // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;   // Zバッファテクスチャ
    float4 Color        : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // 複製モデルの配置座標変換
    float alpha;
    float4x4 TransMatrix = SetTransMatrix(alpha);
    Pos = mul( Pos, TransMatrix );

    // ライトの目線によるビュー射影変換
    Out.Pos = mul( Pos, LightViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    // モデルのalpha値
    Out.Color = float4(1.0f, 1.0f, 1.0f, alpha);

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( VS_ZValuePlot_OUTPUT IN ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(IN.ShadowMapTex.z/IN.ShadowMapTex.w, 0, 0, IN.Color.a);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; string Script = LOOPSCRIPT_ZPLOT; >
{
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
    float2 SpTex    : TEXCOORD4;    // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // ワールド座標変換による頂点法線
    Normal = mul( Normal, (float3x3)WorldMatrix );

    // 複製モデルの配置座標変換
    float alpha;
    float4x4 TransMatrix = SetTransMatrix(alpha);
    Pos = mul( Pos, TransMatrix );

    // 配置座標変換による頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)TransMatrix ) );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - Pos.xyz;

    // ライト視点によるビュー射影変換
    Out.ZCalcTex = mul( Pos, LightViewProjMatrix );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0, dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a * alpha;
    Out.Color = saturate( Out.Color );

    // テクスチャ座標
    Out.Tex = Tex;

    if ( useSphereMap ) {
        if( use_subtexture ) {
            // PMXサブテクスチャ座標
            Out.SpTex = Tex2;
        } else {
            // スフィアマップテクスチャ座標
            float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
            Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
            Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
        }
    }

    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    clip(IN.Color.a-0.001f);

    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;
    float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        // テクスチャ材質モーフ数
        TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        // スフィアテクスチャ材質モーフ数
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
    // スペキュラ適用
    Color.rgb += Specular;

    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;

    if( any( saturate(TransTexCoord) - TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
        float comp;
        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
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

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用,エッジ有り）
technique MainTecBS4  < string MMDPass = "object_ss"; string Subset = EDGE_ON_MAT;
                        bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; string Subset = EDGE_ON_MAT;
                        bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; string Subset = EDGE_ON_MAT;
                        bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; string Subset = EDGE_ON_MAT;
                        bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT_EDGE; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_3_0 Edge_VS();
        PixelShader  = compile ps_3_0 Edge_PS();
    }
}

// オブジェクト描画用テクニック（PMDモデル用,エッジ無し）
technique MainTecBS8  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS9  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS10  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS11  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
                        string Script = LOOPSCRIPT_OBJECT; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
