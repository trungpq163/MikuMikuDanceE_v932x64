////////////////////////////////////////////////////////////////////////////////////////////////
//
//  EdgeOnly.fx ver0.0.2  線画エフェクト(エッジと暗い色のみを表示します)
//  作成: 針金P( 舞力介入P氏のbasic.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float DrawRate = 0.18;   // 描画閾値(0でエッジのみ,数値を上げると明度の低い順から描画されていきます)


// 解らない人はここから下はいじらないでね

// 座法変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;

float3 LightDirection    : DIRECTION < string Object = "Light"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float4 EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse    : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient    : AMBIENT   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;

bool use_texture;  //テクスチャの有無

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT
{
    float4 Pos    : POSITION;    // 射影変換座標
    float2 Tex    : TEXCOORD1;   // テクスチャ
    float3 Normal : TEXCOORD2;   // 法線
    float3 Eye    : TEXCOORD3;   // カメラとの相対位置
    float4 Color  : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = saturate( max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb + AmbientColor );
    Out.Color.a = DiffuseColor.a;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = IN.Color;
    
    // テクスチャ適用
    if ( use_texture ) Color *= tex2D( ObjTexSampler, IN.Tex );
    
    // 明度を求める
    float brightness = (Color.r + Color.g + Color.b)*0.33333333;
    // 明度の高いところは透過
    if(brightness >= DrawRate) Color.a = 0.003;  // 0にするとZバッファがセットされない(多分)
    
    return Color;
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }

