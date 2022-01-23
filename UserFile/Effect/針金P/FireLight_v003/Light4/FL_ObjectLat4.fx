////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FL_ObjectLat.fx : FireLightオブジェクト描画(Lat式モデル専用)
//  ( FireLight.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
//(FireLight.fxと同名パラメータは同じ値に設定してください)

// ライトID番号
#define  LightID  4   // 1～4以外で新たに光源を増やす場合はファイル名変更とこの値を5,6,7･･と変えていく

// Lat式モデルのフェイス材質番号リスト
#define LatFaceNo  "7,17,19,22,24"  // ←Lat式ミクVer2.31_Normal.pmdの例, モデルによって書き換える必要あり

// セルフシャドウの有無
#define Use_SelfShadow  1  // 0:なし, 1:有り

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024   // 512, 1024, 2048, 4096 のどれかで選択


#define FLG_EXCEPTION  0  // MMDでモデル描画が正常にされない場合はここを1にする


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////
// パラメータセット

#define  OwnerDataTex(n)  FireLight_OwnerDataTex##n   // データバッファのテクスチャ名

shared texture OwnerDataTex(LightID) : RENDERCOLORTARGET;
sampler OwnerDataSmp = sampler_state
{
   Texture = <OwnerDataTex(LightID)>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
static float4 OwnerDat0 = tex2Dlod(OwnerDataSmp, float4(0.125f, 0.5f, 0, 0 ));
static float4 OwnerDat1 = tex2Dlod(OwnerDataSmp, float4(0.375f, 0.5f, 0, 0 ));
static float4 OwnerDat2 = tex2Dlod(OwnerDataSmp, float4(0.625f, 0.5f, 0, 0 ));
/* ↓これで読みたいけどエラーになる
float4 OwnerData[4] : TEXTUREVALUE <
   string TextureName = "OwnerDataTex";
>;
*/

// 光源の位置
float3 LightPos : CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;
static float3 LightPosition = LightPos + OwnerDat0.xyz;

// 光源の明るさ
float AcsSi : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si";  >;
static float LightPower = 0.1f * AcsSi * OwnerDat0.w;

// ソフトシャドウのぼかし強度
static float ShadowBulrPower = OwnerDat1.x;  // 0.5～5.0程度で調整

// セルフ影の濃度
static float ShadowDensity = OwnerDat1.y;  // 0.0～1.0で調整

// 光源の距離に対する減衰量係数(0.03～30.0程度)
static float Attenuation = OwnerDat1.z;

// 光源よる散乱光の強さ(0.0～1.0程度)
static float AmbientPower = OwnerDat1.w;

// ライト色
static float3 LightColor = OwnerDat2.rgb; // ライトの色

// 顔ボーン座標
float4x4 BoneFaceMatrix : CONTROLOBJECT < string name = "(self)"; string item = "頭"; >;
static float3 LatFacePos = BoneFaceMatrix._41_42_43;
static float3 LatFaceDirec = -normalize( BoneFaceMatrix._31_32_33 );


////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウマップ関連の処理

#if Use_SelfShadow==1

// Zプロット範囲
#define Z_NEAR  1.0     // 最近値
#define Z_FAR   1000.0  // 最遠値

// シャドウマップバッファサイズ
#if ShadowMapSize==512
    #define SMAPSIZE_WIDTH   512
    #define SMAPSIZE_HEIGHT  1024
#endif
#if ShadowMapSize==1024
    #define SMAPSIZE_WIDTH   1024
    #define SMAPSIZE_HEIGHT  2048
#endif
#if ShadowMapSize==2048
    #define SMAPSIZE_WIDTH   2048
    #define SMAPSIZE_HEIGHT  4096
#endif
#if ShadowMapSize==4096
    #define SMAPSIZE_WIDTH   4096
    #define SMAPSIZE_HEIGHT  8192
#endif

#if LightID > 1
    #define  ShadowMap(n)  FL_ShadowMap##n  // シャドウマップ(前面)テクスチャ名
#else
    #define  ShadowMap(n)  FL_ShadowMap   // シャドウマップ(前面)テクスチャ名
#endif

// 独自シャドウマップサンプラー
shared texture ShadowMap(LightID) : OFFSCREENRENDERTARGET;
sampler ShadowMapSamp = sampler_state {
    texture = <ShadowMap(LightID)>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


#if UseSoftShadow==1
// シャドウマップのサンプリング間隔
static float2 SMapSampStep = float2(ShadowBulrPower/1024.0f, ShadowBulrPower/2048.0f);

// シャドウマップの周辺サンプリング1
float4 GetZPlotSampleBase1(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv));
    return (Color / 6.0f);
}

// シャドウマップの周辺サンプリング2
float4 GetZPlotSampleBase2(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv));
    return (Color / 6.0f);
}
#endif

#define MSC   0.98  // マップ縮小率

// 双放物面シャドウマップよりZプロット読み取り
float2 GetZPlotDP(float3 Vec)
{
    bool flagFront = (Vec.z >= 0) ? true : false;

    if ( !flagFront ) Vec.yz = -Vec.yz;
    float2 Tex = Vec.xy * MSC / (1.0f + Vec.z);
    Tex.y = -Tex.y;
    Tex = (Tex + 1.0f) * 0.5f;
    Tex.y = flagFront ? 0.5f*Tex.y : 0.5f*(Tex.y+1.0f) + 1.0f/SMAPSIZE_HEIGHT;

    #if UseSoftShadow==1
    float4 Color;
    Color  = GetZPlotSampleBase1(Tex, 1.0f) * 0.508f;
    Color += GetZPlotSampleBase2(Tex, 2.0f) * 0.254f;
    Color += GetZPlotSampleBase1(Tex, 3.0f) * 0.127f;
    Color += GetZPlotSampleBase2(Tex, 4.0f) * 0.063f;
    Color += GetZPlotSampleBase1(Tex, 5.0f) * 0.032f;
    Color += GetZPlotSampleBase2(Tex, 6.0f) * 0.016f;
    #else
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex,0,0));
    #endif

    return Color.xy;
}

#endif


#ifndef MIKUMIKUMOVING
////////////////////////////////////////////////////////////////////////////////////////////////
//  以下MikuMikuEfect仕様コード
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse  : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient  : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower    : SPECULARPOWER < string Object = "Geometry"; >;
float3 MaterialToon     : TOONCOLOR;
float4 EdgeColor        : EDGECOLOR;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightColor, 1.0f);
static float3 AmbientColor  = MaterialEmmisive * LightColor * AmbientPower;
static float3 SpecularColor = MaterialSpecular * LightColor;

// テクスチャ材質モーフ値
#if(FLG_EXCEPTION == 0)
float4 TextureAddValue : ADDINGTEXTURE;
float4 TextureMulValue : MULTIPLYINGTEXTURE;
float4 SphereAddValue  : ADDINGSPHERETEXTURE;
float4 SphereMulValue  : MULTIPLYINGSPHERETEXTURE;
#else
float4 TextureAddValue = float4(0,0,0,0);
float4 TextureMulValue = float4(1,1,1,1);
float4 SphereAddValue  = float4(0,0,0,0);
float4 SphereMulValue  = float4(1,1,1,1);
#endif

bool use_subtexture;    // サブテクスチャフラグ
bool spadd;    // スフィアマップ加算合成フラグ

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


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 VS_Edge(float4 Pos : POSITION) : POSITION
{
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 PS_Edge() : COLOR
{
    // 黒で塗りつぶし
    return float4(0, 0, 0, EdgeColor.a);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 VS_Edge();
        PixelShader  = compile ps_2_0 PS_Edge();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos       : POSITION;    // 射影変換座標
    float4 WPos      : TEXCOORD1;   // ワールド座標
    float2 Tex       : TEXCOORD2;   // テクスチャ
    float3 Normal    : TEXCOORD3;   // 法線
    float3 Eye       : TEXCOORD4;   // カメラとの相対位置
    float2 SpTex     : TEXCOORD5;   // スフィアマップテクスチャ座標
};

// 頂点シェーダ
VS_OUTPUT VS_Object(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1,
                    uniform bool useTexture, uniform bool useSphereMap, uniform bool isLatFace)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // ワールド座標
    Out.WPos = mul( Pos, WorldMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;

    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // テクスチャ座標
    Out.Tex = Tex;

    if ( useSphereMap ) {
        if ( use_subtexture ) {
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
float4 PS_Object(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool isLatFace, uniform bool useSelfShadow) : COLOR0
{
    // ライト方向
    float3 LightDirection;
    if( isLatFace ){
        LightDirection = normalize(LatFacePos - LightPosition);
    }else{
        LightDirection = normalize(IN.WPos.xyz - LightPosition);
    }

    // ピクセル法線
    float3 Normal = normalize( IN.Normal );
    if( isLatFace ){
        Normal = LatFaceDirec;
    }else{
        Normal = normalize( IN.Normal );
    }

    // ディフューズ色＋アンビエント色 計算
    float4 Color = float4(AmbientColor, DiffuseColor.a);
    float4 ShadowColor = Color;  // 影の色
    if( isLatFace ){
        Color.rgb += lerp(0.03f, 0.7f, max(0.0f, dot(LatFaceDirec, -LightDirection))) * DiffuseColor.rgb;
        ShadowColor = Color;
    }else{
        Color.rgb += max(0.0f, dot(Normal, -LightDirection)) * DiffuseColor.rgb;
    }
    Color = saturate( Color );
    ShadowColor = saturate( ShadowColor );

    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        if( useSelfShadow ) {
            // テクスチャ材質モーフ数
            TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
        }
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if( useSelfShadow ) {
            // スフィアテクスチャ材質モーフ数
            TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
        }
        if(spadd){ Color.rgb += TexColor.rgb; ShadowColor.rgb += TexColor.rgb; }
        else     { Color.rgb *= TexColor.rgb; ShadowColor.rgb *= TexColor.rgb; }
        Color.a *= TexColor.a;
        ShadowColor.a *= TexColor.a;
    }

    // トゥーン適用
    float LightNormal = dot( Normal, -LightDirection );
    #if(FLG_EXCEPTION == 0)
    Color.rgb *= tex2D( ObjToonSampler, float2(0.0f, 0.5f - LightNormal * 0.5f) ).rgb;
    #else
    Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    #endif
    ShadowColor.rgb *= MaterialToon;

    // スペキュラ適用
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0, dot( HalfVector, Normal )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.3f;

    // ライト強度
    if( isLatFace ){
        float LtPower = LightPower / max( pow(length(LatFacePos - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }else{
        float LtPower = LightPower / max( pow(length(IN.WPos.xyz - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }

#if Use_SelfShadow==1

    // Z値
    float L = length(IN.WPos.xyz - LightPosition);
    float z = ( Z_FAR / L ) * ( L - Z_NEAR ) / ( Z_FAR - Z_NEAR );

    // シャドウマップZプロット
    float2 zplot = GetZPlotDP( LightDirection );

    #if UseSoftShadow==1
    // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
    float variance = max( zplot.y - zplot.x * zplot.x, 0.002f );
    float Comp = variance / (variance + max(z - zplot.x, 0.0f));
    #else
    // 影部判定(ソフトシャドウ無し)
    float Comp = 1.0 - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
    #endif

    // 影の合成
    ShadowColor = lerp(Color, ShadowColor, ShadowDensity);
    Color = lerp(ShadowColor, Color, Comp);

#endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウOFF）
technique MainTec0 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, true);
        PixelShader  = compile ps_3_0 PS_Object(false, false, true, false);
    }
}

technique MainTec1 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, true);
        PixelShader  = compile ps_3_0 PS_Object(true, false, true, false);
    }
}

technique MainTec2 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, true);
        PixelShader  = compile ps_3_0 PS_Object(false, true, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, true);
        PixelShader  = compile ps_3_0 PS_Object(true, true, true, false);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウOFF）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, false);
        PixelShader  = compile ps_3_0 PS_Object(false, false, false, false);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, false);
        PixelShader  = compile ps_3_0 PS_Object(true, false, false, false);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, false);
        PixelShader  = compile ps_3_0 PS_Object(false, true, false, false);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, false);
        PixelShader  = compile ps_3_0 PS_Object(true, true, false, false);
    }
}

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウON）
technique MainTecSS0 < string MMDPass = "object_ss"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, true);
        PixelShader  = compile ps_3_0 PS_Object(false, false, true, true);
    }
}

technique MainTecSS1 < string MMDPass = "object_ss"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, true);
        PixelShader  = compile ps_3_0 PS_Object(true, false, true, true);
    }
}

technique MainTecSS2 < string MMDPass = "object_ss"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, true);
        PixelShader  = compile ps_3_0 PS_Object(false, true, true, true);
    }
}

technique MainTecSS3 < string MMDPass = "object_ss"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, true);
        PixelShader  = compile ps_3_0 PS_Object(true, true, true, true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウON）
technique MainTecSS4 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, false);
        PixelShader  = compile ps_3_0 PS_Object(false, false, false, true);
    }
}

technique MainTecSS5 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, false);
        PixelShader  = compile ps_3_0 PS_Object(true, false, false, true);
    }
}

technique MainTecSS6 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, false);
        PixelShader  = compile ps_3_0 PS_Object(false, true, false, true);
    }
}

technique MainTecSS7 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, false);
        PixelShader  = compile ps_3_0 PS_Object(true, true, false, true);
    }
}


#else
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
//  以下MikuMikuMoving仕様コード
///////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;

//材質モーフ関連
float4 AddingTexture    : ADDINGTEXTURE;       // 材質モーフ加算Texture値
float4 AddingSphere     : ADDINGSPHERE;        // 材質モーフ加算SphereTexture値
float4 MultiplyTexture  : MULTIPLYINGTEXTURE;  // 材質モーフ乗算Texture値
float4 MultiplySphere   : MULTIPLYINGSPHERE;   // 材質モーフ乗算SphereTexture値

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse    : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient    : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive   : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular   : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower      : SPECULARPOWER < string Object = "Geometry"; >;
float4 MaterialToon       : TOONCOLOR;
float4 EdgeColor          : EDGECOLOR;
float  EdgeWidth          : EDGEWIDTH;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightColor, 1.0f);
static float3 AmbientColor  = MaterialEmmisive * LightColor * AmbientPower;
static float3 SpecularColor = MaterialSpecular * LightColor;

bool spadd;                // スフィアマップ加算合成フラグ
bool usetoontexturemap;    // Toonテクスチャフラグ

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


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos     : POSITION;     // 射影変換座標
    float4 WPos    : TEXCOORD0;    // ワールド座標
    float2 Tex     : TEXCOORD2;    // テクスチャ
    float4 SubTex  : TEXCOORD3;    // サブテクスチャ/スフィアマップテクスチャ座標
    float3 Normal  : TEXCOORD4;    // 法線
    float3 Eye     : TEXCOORD5;    // カメラとの相対位置
};

//==============================================
// 頂点シェーダ
// MikuMikuMoving独自の頂点シェーダ入力(MMM_SKINNING_INPUT)
//==============================================
VS_OUTPUT VS_Object(MMM_SKINNING_INPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool isLatFace)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    //================================================================================
    //MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。座標と法線を取得する。
    //================================================================================
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

    // ワールド座標
    Out.WPos = mul( SkinOut.Position, WorldMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( SkinOut.Position, WorldMatrix ).xyz;

    // 頂点法線
    Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

    // 頂点座標
    if (MMM_IsDinamicProjection)
    {
        float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, length(Out.Eye)));
        Out.Pos = mul( SkinOut.Position, wvpmat );
    }
    else
    {
        Out.Pos = mul( SkinOut.Position, WorldViewProjMatrix );
    }

    // テクスチャ座標
    Out.Tex = IN.Tex;
    Out.SubTex.xy = IN.AddUV1.xy;

    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
        Out.SubTex.z = NormalWV.x * 0.5f + 0.5f;
        Out.SubTex.w = NormalWV.y * -0.5f + 0.5f;
    }

    return Out;
}


// ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool isLatFace) : COLOR0
{
    // ライト方向
    float3 LightDirection;
    if( isLatFace ){
        LightDirection = normalize(LatFacePos - LightPosition);
    }else{
        LightDirection = normalize(IN.WPos.xyz - LightPosition);
    }

    // ピクセル法線
    float3 Normal = normalize( IN.Normal );
    if( isLatFace ){
        Normal = LatFaceDirec;
    }else{
        Normal = normalize( IN.Normal );
    }

    // ディフューズ色＋アンビエント色 計算
    float4 Color = float4(AmbientColor, DiffuseColor.a);
    float4 ShadowColor = Color;  // 影の色
    if( isLatFace ){
        Color.rgb += lerp(0.03f, 1.6f, max(0.0f, dot(LatFaceDirec, -LightDirection))) * DiffuseColor.rgb;
        ShadowColor = Color;
    }else{
        Color.rgb += max(0.0f, dot(Normal, -LightDirection)) * DiffuseColor.rgb;
    }
    Color = saturate( Color );
    ShadowColor = saturate( ShadowColor );

    float4 texColor = float4(1,1,1,1);
    float  texAlpha = MultiplyTexture.a + AddingTexture.a;

    // テクスチャ適用
    if (useTexture) {
        texColor = tex2D(ObjTexSampler, IN.Tex);
        texColor.rgb = (texColor.rgb * MultiplyTexture.rgb + AddingTexture.rgb) * texAlpha + (1.0 - texAlpha);
    }
    Color.rgb *= texColor.rgb;
    ShadowColor.rgb *= texColor.rgb;

    // スフィアマップ適用
    if ( useSphereMap ) {
        // スフィアマップ適用
        float3 texSphare = tex2D(ObjSphareSampler,IN.SubTex.zw).rgb * MultiplySphere.rgb + AddingSphere.rgb;
        if(spadd){ Color.rgb += texSphare; ShadowColor.rgb += texSphare; }
        else     { Color.rgb *= texSphare; ShadowColor.rgb *= texSphare; }
    }
    // アルファ適用
    Color.a *= texColor.a;
    ShadowColor.a *= texColor.a;

    // セルフシャドウなしのトゥーン適用
    if ( usetoontexturemap ) {
        //================================================================================
        // MikuMikuMovingデフォルトのトゥーン色を取得する(MMM_GetToonColor)
        //================================================================================
        float3 color = MMM_GetToonColor(MaterialToon, Normal, LightDirection, LightDirection, LightDirection);
        Color.rgb *= color;
        ShadowColor.rgb *= MaterialToon.rgb;
    }

    // スペキュラ適用
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0, dot( HalfVector, Normal )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.3f;

    // ライト強度
    if( isLatFace ){
        float LtPower = LightPower / max( pow(length(LatFacePos - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }else{
        float LtPower = LightPower / max( pow(length(IN.WPos.xyz - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }

#if Use_SelfShadow==1

    // Z値
    float L = length(IN.WPos.xyz - LightPosition);
    float z = ( Z_FAR / L ) * ( L - Z_NEAR ) / ( Z_FAR - Z_NEAR );

    // シャドウマップZプロット
    float2 zplot = GetZPlotDP( LightDirection );

    #if UseSoftShadow==1
    // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
    float variance = max( zplot.y - zplot.x * zplot.x, 0.002f );
    float Comp = variance / (variance + max(z - zplot.x, 0.0f));
    #else
    // 影部判定(ソフトシャドウ無し)
    float Comp = 1.0 - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
    #endif

    // 影の合成
    ShadowColor = lerp(Color, ShadowColor, ShadowDensity);
    Color = lerp(ShadowColor, Color, Comp);

#endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウOFF）
technique MainTec0 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, true);
        PixelShader  = compile ps_3_0 PS_Object(false, false, true);
    }
}

technique MainTec1 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, true);
        PixelShader  = compile ps_3_0 PS_Object(true, false, true);
    }
}

technique MainTec2 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, true);
        PixelShader  = compile ps_3_0 PS_Object(false, true, true);
    }
}

technique MainTec3 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, true);
        PixelShader  = compile ps_3_0 PS_Object(true, true, true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウOFF）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, false);
        PixelShader  = compile ps_3_0 PS_Object(false, false, false);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, false);
        PixelShader  = compile ps_3_0 PS_Object(true, false, false);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, false);
        PixelShader  = compile ps_3_0 PS_Object(false, true, false);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, false);
        PixelShader  = compile ps_3_0 PS_Object(true, true, false);
    }
}

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウON）
technique MainTecSS0 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, true);
        PixelShader  = compile ps_3_0 PS_Object(false, false, true);
    }
}

technique MainTecSS1 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, true);
        PixelShader  = compile ps_3_0 PS_Object(true, false, true);
    }
}

technique MainTecSS2 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = false; bool UseSphereMap = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, true);
        PixelShader  = compile ps_3_0 PS_Object(false, true, true);
    }
}

technique MainTecSS3 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseTexture = true; bool UseSphereMap = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, true);
        PixelShader  = compile ps_3_0 PS_Object(true, true, true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウON）
technique MainTecSS4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, false, false);
        PixelShader  = compile ps_3_0 PS_Object(false, false, false);
    }
}

technique MainTecSS5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, false, false);
        PixelShader  = compile ps_3_0 PS_Object(true, false, false);
    }
}

technique MainTecSS6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false, true, false);
        PixelShader  = compile ps_3_0 PS_Object(false, true, false);
    }
}

technique MainTecSS7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true, true, false);
        PixelShader  = compile ps_3_0 PS_Object(true, true, false);
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 VS_Edge(MMM_SKINNING_INPUT IN) : POSITION
{
    //================================================================================
    //MikuMikuMoving独自のスキニング関数(MMM_SkinnedPosition)。座標を取得する。
    //================================================================================
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

    // ワールド座標
    float4 Pos = mul(SkinOut.Position, WorldMatrix);

    // 法線方向
    float3 Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

    // 頂点座標
    if (MMM_IsDinamicProjection)
    {
        float dist = length(CameraPosition - Pos.xyz);
        float4x4 vpmat = mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, dist));

        Pos += float4(Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(Pos.xyz, CameraPosition) * MMM_GetDynamicFovEdgeRate(dist);
        Pos = mul( Pos, vpmat );
    }
    else
    {
        Pos += float4(Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(Pos.xyz, CameraPosition);
        Pos = mul( Pos, ViewProjMatrix );
    }

    return Pos;
}

//==============================================
// ピクセルシェーダ
//==============================================
float4 PS_Edge() : COLOR
{
    // 黒で塗りつぶし
    return float4(0, 0, 0, EdgeColor.a);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 VS_Edge();
        PixelShader  = compile ps_2_0 PS_Edge();
    }
}


#endif
///////////////////////////////////////////////////////////////////////////////////////////////
//地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }

