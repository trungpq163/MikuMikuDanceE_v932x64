// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);



///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画


// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 WPos        : TEXCOORD1;    // ワールド座標
    float3 Normal     : TEXCOORD2;   // 法線
};

// 頂点シェーダ
VS_OUTPUT NormalAndLen_VS(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.WPos = mul( Pos,WorldMatrix);
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    return Out;
}

// ピクセルシェーダ
float4 NormalAndLen_PS(VS_OUTPUT IN) : COLOR0
{
	float ypos = IN.WPos.y + 0xffff;
    return float4(IN.Normal,ypos);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {

}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 NormalAndLen_VS();
        PixelShader  = compile ps_3_0 NormalAndLen_PS();
    }
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 NormalAndLen_VS();
        PixelShader  = compile ps_3_0 NormalAndLen_PS();
    }
}
technique MainTec  < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 NormalAndLen_VS();
        PixelShader  = compile ps_3_0 NormalAndLen_PS();
    }
}



///////////////////////////////////////////////////////////////////////////////////////////////
