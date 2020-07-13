////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Clone.fx
//  作成: そぼろ
//  原作: 舞力介入P(full.fx)
//
////////////////////////////////////////////////////////////////////////////////////////////////

//サポート関数宣言(変更不可)
float4 rot_x(float4 pos, float deg);
float4 rot_y(float4 pos, float deg);
float4 rot_z(float4 pos, float deg);
float4x4 inverseDir(float4x4 mat);

//サポート変数定義
float Scale  : CONTROLOBJECT < string name = "(self)"; >;
float3 Offset : CONTROLOBJECT < string name = "(self)"; >;
float3 MasterPos : CONTROLOBJECT < string name = "(self)"; string item = "全ての親"; >;
float4x4 MasterWorldMat : CONTROLOBJECT < string name = "(self)"; string item = "全ての親"; >;
float Time1 : TIME <bool SyncInEditMode=true;>;
float Time2 : TIME <bool SyncInEditMode=false;>;

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//複製数
int CloneCount = 100;

//ループ変数（初期値は0固定）
int CloneIndex = 0;

// ミップマップ生成用テクスチャサイズ・0で無効
#define CLONE_MIPMAPTEX_SIZE  0 //512


////////////////////////////////////////////////////////////////////////////////////////////////
// 複製の位置をコントロールする関数・ここを改造して好みの配置にしてください。
// 不要な変化は削除可　行頭に「//」がある行はコメント文です。

// サポート関数
//   rot_x：X軸周りの回転
//   rot_y：Y軸周りの回転
//   rot_z：Z軸周りの回転

// ※ Z→X→Y の順に回転させるとMMDの回転方式と一致します。

// サポート変数
//   CloneIndex：複製番号
//   Scale：拡大率。アクセサリのデフォルトは10です。
//   Offset：元アクセサリが移動した位置。PMDでは常に0です。
//   MasterPos：「全ての親」ボーンの位置。存在しなければ0です。
//   Time1 : フレーム時間です。単位は秒です。
//   Time2 : フレーム時間です。単位は秒です。編集中も進み続けます。


float4 ClonePos(float4 Pos) 
{
    const float row_count = 16; //16列に配置
    float center = (int)(row_count / 2); //オリジナルと同じ位置に配置する番号
    float cindex = CloneIndex - center;
    
    float column = (int)(CloneIndex / row_count);    //行番号
    float row = ((CloneIndex % row_count) - center); //列番号
    
    float scatter = 4.2; //ばらつき係数
    
    //全ての親ボーンの位置を回転中心にする
    Pos.xyz = Pos.xyz - MasterPos;
    
    //回転
    //Pos = rot_z(Pos, 10);
    //Pos = rot_x(Pos, 45);
    Pos = rot_y(Pos, cindex * 30);
    
    //全ての親ボーンの位置を回転中心にする(さっき引いた分を戻す)
    Pos.xyz = Pos.xyz + MasterPos;
    
    //移動
    Pos.x += row * 15;
    Pos.z += column * 15;
    
    //ばらつきを付加
    Pos.x += (sin(cindex) + sin(cindex * 3)) * scatter;
    Pos.z += (sin(cindex * 3.2) + sin(cindex * 5)) * scatter;
    
    
    return Pos;
}

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと


// サポート関数定義

#define PI 3.14159
#define DEG_TO_RAD (PI / 180)

float4 rot_x(float4 pos, float deg){
    deg = DEG_TO_RAD * deg;
    float4x4 rot = {
        {1,         0,        0 , 0},
        {0,  cos(deg), sin(deg) , 0},
        {0, -sin(deg), cos(deg) , 0},
        {0,         0,        0 , 1},
    }; // X軸回転行列
    
    return mul(pos, rot);
}

float4 rot_y(float4 pos, float deg){
    deg = DEG_TO_RAD * deg;
    float4x4 rot = {
        {cos(deg), 0, -sin(deg), 0},
        {       0, 1,         0, 0},
        {sin(deg), 0,  cos(deg), 0},
        {       0, 0,         0, 1},
    }; // Y軸回転行列
    
    return mul(pos, rot);
}

float4 rot_z(float4 pos, float deg){
    deg = DEG_TO_RAD * deg;
    float4x4 rot = {
        { cos(deg), sin(deg), 0, 0},
        {-sin(deg), cos(deg), 0, 0},
        {        0,        0, 1, 0},
        {        0,        0, 0, 1},
    }; // Z軸回転行列
    
    return mul(pos, rot);
}


float4x4 inverseDir(float4x4 mat){
    return float4x4(
        mat._11, mat._21, mat._31, 0,
        mat._12, mat._22, mat._32, 0,
        mat._13, mat._23, mat._33, 0,
        0,0,0,1
    );
}

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

//外部インクルードされている場合は、これ以降の全てを無視する
#ifndef CLONE_PARAMINCLUDE

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
//ループ用スクリプト

#define LOOPSCR "LoopByCount=CloneCount;" \
                "LoopGetIndex=CloneIndex;" \
                "Pass=DrawObject;" \
                "LoopEnd=;"


#if CLONE_MIPMAPTEX_SIZE==0
    #define LOOPSCR_TEX LOOPSCR
    
#else
    
    #define LOOPSCR_TEX \
        "RenderColorTarget0=UseMipmapObjectTexture;" \
                "RenderDepthStencilTarget=DepthBuffer;" \
                    "ClearSetColor=ClearColor;" \
                    "ClearSetDepth=ClearDepth;" \
                    "Clear=Color;" \
                    "Clear=Depth;" \
                "Pass=CreateMipmap;" \
            "RenderColorTarget0=;" \
                "RenderDepthStencilTarget=;" \
                    "LoopByCount=CloneCount;" \
                    "LoopGetIndex=CloneIndex;" \
                    "Pass=DrawObject;" \
                    "LoopEnd=;"

#endif


////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "standard";
> = 0.8;

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
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool     spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;

#if CLONE_MIPMAPTEX_SIZE==0
    sampler ObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };
    
#else
    sampler DefObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };
    
    texture UseMipmapObjectTexture : RENDERCOLORTARGET <
        int Width = CLONE_MIPMAPTEX_SIZE;
        int Height = CLONE_MIPMAPTEX_SIZE;
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
        int Width = CLONE_MIPMAPTEX_SIZE;
        int Height = CLONE_MIPMAPTEX_SIZE;
        string Format = "D24S8";
    >;
    
    
    // オフセット
    static float2 ViewportOffset = (float2(0.5,0.5)/CLONE_MIPMAPTEX_SIZE);
    
#endif

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


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
// ミップマップ作成

#if CLONE_MIPMAPTEX_SIZE!=0
    
    struct VS_OUTPUT_MIPMAPCREATER {
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
    };

    VS_OUTPUT_MIPMAPCREATER VS_MipMapCreater( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
        VS_OUTPUT_MIPMAPCREATER Out;
        Out.Pos = Pos;
        Out.Tex = Tex.xy;
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
    
    float4 pos = Pos;
    
    // カメラ視点のワールドビュー射影変換
    return mul( ClonePos(pos), WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 黒で塗りつぶし
    return float4(0,0,0,1);
}

// 輪郭描画用テクニック
technique EdgeTec <
    string MMDPass = "edge";
    string Script = LOOPSCR;
> {
    pass DrawObject {
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
    float4 pos = Pos;
    
    // カメラ視点のワールドビュー射影変換
    return mul( ClonePos(pos), WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < 
    string MMDPass = "shadow";
    string Script = LOOPSCR;
> {
    pass DrawObject {
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
    float2 SpTex      : TEXCOORD4;     // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    float4 pos = Pos;
    float4 pos_norm = pos + float4(Normal, 0);
    
    //頂点および法線の移動
    pos = ClonePos(pos);
    pos_norm = ClonePos(pos_norm);
    Normal = normalize(pos_norm - pos).xyz;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( pos, WorldMatrix ).xyz;
    
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
        float3 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
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
    //float3 Specular = (float3)0;
    
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
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
    
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; 
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
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
    
    float4 pos = Pos;
    
    pos = ClonePos(pos);
    
    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( pos, LightWorldViewProjMatrix );

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
technique ZplotTec < string MMDPass = "zplot";
    string Script = LOOPSCR;
> {
    pass DrawObject {
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
    float2 SpTex    : TEXCOORD4;     // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
    
    float4 pos = Pos;
    float4 pos_norm = pos + float4(Normal, 0);
    
    //頂点および法線の移動
    pos = ClonePos(pos);
    pos_norm = ClonePos(pos_norm);
    Normal = normalize(pos_norm - pos).xyz;
    
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    // ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( pos, LightWorldViewProjMatrix );
    
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
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
    string Script = LOOPSCR_TEX;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
    #if CLONE_MIPMAPTEX_SIZE!=0
    pass CreateMipmap < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VS_MipMapCreater();
        PixelShader  = compile ps_2_0 PS_MipMapCreater();
    }
    #endif
}


///////////////////////////////////////////////////////////////////////////////////////////////


#endif //CLONE_PARAMINCLUDE





