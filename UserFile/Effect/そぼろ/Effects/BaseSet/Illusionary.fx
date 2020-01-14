
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//モデルの色を指定します
float3 DrawColor = float3( 0, 0.5, 1 );

////////////////////////////////////////////////////////////////////////////////////////////////


// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    
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
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    
    // スフィアマップテクスチャ座標
    float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
    Out.SpTex.x = NormalWV.x * 1.5;
    Out.SpTex.y = NormalWV.y * 1.5;
    
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    
    float4 Color = float4(0,0,0,1);
    
    float p = 1 - dot(normalize(IN.Eye), IN.Normal);
    p *= saturate(1 - saturate(p - 1) / 0.3);
    //p = p * p;
    
    Color.rgb = p * DrawColor;
    
    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可

technique MainTec1 < string MMDPass = "object"; > {
    pass DrawObject {
        CullMode=NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
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

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        CullMode=NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
