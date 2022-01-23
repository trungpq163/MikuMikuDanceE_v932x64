////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MangaShader.fx ver0.0.6  モデルの漫画風描画を行います
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define TexFile1  "ScreenToon1.png"  // 濃いスクリーントーンテクスチャファイル名1
#define TexFile2  "ScreenToon2.png"  // 薄いスクリーントーンテクスチャファイル名2
float ToonLevel1 = 0.4;          // 黒とトーンの境値(0～1)
float ToonLevel2 = 0.8;          // トーンと白の境値(0～1)
float ToonScaling1 = 0.014;      // 濃いトーンのスケーリング
float ToonScaling2 = 0.012;      // 薄いトーンのスケーリング
float ToonScalingShadow = 0.012; // 地面影トーンのスケーリング
float EdgeThick = 1.0;           // 独自描画のエッジ太さ

float3 ToonColor1 = {0.0, 0.0, 0.0};  // 濃いスクリーントーンの色(RGB)
float3 ToonColor2 = {0.0, 0.0, 0.0};  // 薄いスクリーントーンの色(RGB)
float3 FillColor = {0.0, 0.0, 0.0};   // べた塗りの色(RGB)
float3 ShadowColor = {0.0, 0.0, 0.0}; // 地面影トーンの色(RGB)

#define UseDither  1   // 薄いトーンに対するディザ処理 0:しない,1;する


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldViewProjMatrix  : WORLDVIEWPROJECTION;
float4x4 WorldMatrix          : WORLD;
float4x4 ViewMatrix           : VIEW;
float4x4 ProjMatrix           : PROJECTION;
float4x4 ViewProjMatrix       : VIEWPROJECTION;

float3 LightDirection  : DIRECTION < string Object = "Light"; >;
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse  : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient  : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;
float4 EdgeColor        : EDGECOLOR;
static float4 DiffuseColor = MaterialDiffuse;
static float3 AmbientColor = saturate(MaterialAmbient + MaterialEmmisive);

// テクスチャ材質モーフ値
float4 TextureAddValue  : ADDINGTEXTURE;
float4 TextureMulValue  : MULTIPLYINGTEXTURE;
float4 SphereAddValue   : ADDINGSPHERETEXTURE;
float4 SphereMulValue   : MULTIPLYINGSPHERETEXTURE;

bool use_subtexture;    // サブテクスチャフラグ

bool spadd;    // スフィアマップ加算合成フラグ

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

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

// 濃いスクリーントーンテクスチャ(ミップマップも生成)
texture2D screen_tex1 <
    string ResourceName = TexFile1;
    int MipLevels = 0;
>;
sampler TexSampler1 = sampler_state {
    texture = <screen_tex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// 薄いスクリーントーンテクスチャ(ミップマップも生成)
texture2D screen_tex2 <
    string ResourceName = TexFile2;
    int MipLevels = 0;
>;
sampler TexSampler2 = sampler_state {
    texture = <screen_tex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

#if(UseDither==1)
// ディザパターンテクスチャ1
texture2D dither_tex1 <
    string ResourceName = "DitherPattern1.png";
    int MipLevels = 0;
>;
sampler DitherSmp1 = sampler_state {
    texture = <dither_tex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ2
texture2D dither_tex2 <
    string ResourceName = "DitherPattern2.png";
    int MipLevels = 0;
>;
sampler DitherSmp2 = sampler_state {
    texture = <dither_tex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ3
texture2D dither_tex3 <
    string ResourceName = "DitherPattern3.png";
    int MipLevels = 0;
>;
sampler DitherSmp3 = sampler_state {
    texture = <dither_tex3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ4
texture2D dither_tex4 <
    string ResourceName = "DitherPattern4.png";
    int MipLevels = 0;
>;
sampler DitherSmp4 = sampler_state {
    texture = <dither_tex4>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ5
texture2D dither_tex5 <
    string ResourceName = "DitherPattern5.png";
    int MipLevels = 0;
>;
sampler DitherSmp5 = sampler_state {
    texture = <dither_tex5>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ6
texture2D dither_tex6 <
    string ResourceName = "DitherPattern6.png";
    int MipLevels = 0;
>;
sampler DitherSmp6 = sampler_state {
    texture = <dither_tex6>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// ディザパターンテクスチャ7
texture2D dither_tex7 <
    string ResourceName = "DitherPattern7.png";
    int MipLevels = 0;
>;
sampler DitherSmp7 = sampler_state {
    texture = <dither_tex7>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// スクリーントーンの貼り付け

// 濃いスクリーントーン
float3 SetToonColor1(float4 VPos)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScaling1, VPos.y/ToonScaling1 );
    float3 Color = tex2D( TexSampler1, texCoord ).rgb;
    Color += ToonColor1;
    Color = saturate(Color);

    return Color;
}

// 薄いスクリーントーン
float3 SetToonColor2(float4 VPos, float lightNormal)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScaling2, VPos.y/ToonScaling2 );
    float4 Color = tex2D( TexSampler2, texCoord );

#if(UseDither==1)
    // ディザ処理の追加
    texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScaling2*0.5f, VPos.y/ToonScaling2*0.5f );
    if(lightNormal > 0.6f){
       Color += tex2D( DitherSmp1, texCoord );
    }else if(lightNormal > 0.55f){
       Color += tex2D( DitherSmp2, texCoord );
    }else if(lightNormal > 0.5f){
       Color += tex2D( DitherSmp3, texCoord );
    }else if(lightNormal > 0.45f){
       Color += tex2D( DitherSmp4, texCoord );
    }else if(lightNormal > 0.4f){
       Color += tex2D( DitherSmp5, texCoord );
    }else if(lightNormal > 0.35f){
       Color += tex2D( DitherSmp6, texCoord );
    }else if(lightNormal > 0.3f){
       Color += tex2D( DitherSmp7, texCoord );
    }
#endif

    Color.rgb += ToonColor2;
    Color = saturate(Color);

    return Color.rgb;
}

// 地面影トーン
float4 SetToonColor3(float4 VPos)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScalingShadow, VPos.y/ToonScalingShadow );
    float4 c = tex2D( TexSampler2, texCoord );
    float alpha = 1.0f - (c.r + c.g + c.b) * 0.33333f;

    return float4(ShadowColor, alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos    : POSITION;    // 射影変換座標
    float2 Tex    : TEXCOORD1;   // テクスチャ
    float3 Normal : TEXCOORD2;   // 法線
    float2 SpTex  : TEXCOORD3;   // スフィアマップテクスチャ座標
    float4 VPos   : TEXCOORD4;   // スクリーン座標取得用射影変換座標
    float4 Color  : COLOR0;      // ディフューズ色
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画(独自描画,エッジOFF材質・アクセサリにもエッジを付ける)

// 頂点シェーダ
VS_OUTPUT Edge_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // ワールド座標変換による頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // カメラとの距離
    float len = max( length( CameraPosition - Pos.xyz ), 5.0f );

    // 頂点を法線方向に押し出す
    Pos.xyz += Out.Normal * ( pow( len, 0.9f ) * EdgeThick * 0.003f * pow(2.4142f / ProjMatrix._22, 0.7f) );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // 半透明材質にエッジを付けないためにalpha値も求めておく
    Out.Color = DiffuseColor;

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Edge_PS(VS_OUTPUT IN, uniform bool useTexture) : COLOR0
{
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    // 半透明にはエッジを付けない
    float alpha = Color.a;
    alpha *= step( 0.98f, alpha );
    clip(alpha - 0.005f);

    // 輪郭色で塗りつぶし
    return float4(EdgeColor.rgb, alpha);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0, dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
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
            float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
            Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
            Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
        }
    }

    // スクリーン座標取得用
    Out.VPos = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfShadow) : COLOR0
{
    float4 Color = IN.Color;

    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        // テクスチャ材質モーフ数
        if ( useSelfShadow ) {
            TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
        }
        Color *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        // テクスチャ材質モーフ数
        if ( useSelfShadow ) {
            TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
        }
        if(spadd) Color.rgb += TexColor.rgb;
        else      Color.rgb *= TexColor.rgb;
        Color.a *= TexColor.a;
    }

    // モノクロに変換
    float v = (Color.r + Color.g + Color.b) * 0.3333f;
    Color.rgb = float3(v, v, v);

    // 明度でベタ,白,スクリーントーンに分ける
    if(v < ToonLevel1){
       Color.rgb = FillColor;
    }else if(v < ToonLevel2){
       // スクリーントーン色
       if( useToon ) {
           Color.rgb = float3(1.0f, 1.0f, 1.0f);
           float LightNormal = dot( IN.Normal, -LightDirection );
           if(saturate(LightNormal * 16 + 0.5) < 0.5f){
               Color.rgb = saturate( float3(0.8f, 0.8f, 0.8f) + ToonColor1 );
           }
       }
       Color.rgb *= SetToonColor1(IN.VPos);
    }else{
       // 白はトーンシェードで白,薄スクリーントーンに分ける
       Color.rgb = float3(1.0f, 1.0f, 1.0f);
       if( useToon ) {
           float LightNormal = dot( IN.Normal, -LightDirection );
#if(UseDither==1)
           // ディザ処理あり
           if(saturate(LightNormal + 0.45) < 0.7f){
               Color.rgb = SetToonColor2(IN.VPos, LightNormal+0.45);
           }
#else
           // ディザ処理なし
           if(saturate(LightNormal * 16 + 0.5) < 0.5f){
               Color.rgb = SetToonColor2(IN.VPos, 1.0f);
           }
#endif
       }
    }

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec01 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec02 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec03 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

technique MainTec04 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

technique MainTec05 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec06 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec07 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

technique MainTec08 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec09 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec10 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(false);
    }
}

technique MainTec11 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

technique MainTec12 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS(true);
    }
}

technique MainTec13 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true, true);
    }
}

technique MainTec14 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true, true);
    }
}

technique MainTec15 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true, true);
    }
}

technique MainTec16 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

struct VS_OUTPUT2 {
    float4 Pos   : POSITION;    // 射影変換座標
    float4 VPos  : TEXCOORD4;   // スクリーン座標取得用射影変換座標
};

// 頂点シェーダ
VS_OUTPUT2 Shadow_VS(float4 Pos : POSITION)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // スクリーン座標取得用
    Out.VPos = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 Shadow_PS(VS_OUTPUT2 IN) : COLOR
{
    float4 Color = SetToonColor3(IN.VPos);
    return Color;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////

