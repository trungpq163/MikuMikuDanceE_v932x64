// PointLight1

// 照明ポイントの表示
static bool Draw = false;


//----
float ObjScaling : CONTROLOBJECT < string name = "PointLight1.x"; >;         // スケール
float4x4 ObjWorldMatrix : CONTROLOBJECT < string name = "PointLight1.x"; >;  // 

float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;

// 行列の回転量から色取得
float3 getRotCol(float4x4 rm)
{

    float4x4 m = rm / ObjScaling;
    return float3(degrees(-asin(m._32)),degrees(-atan2(-m._31, m._33)),degrees(-atan2(-m._12, m._22)));
}

// 色
static float3 LightColor = getRotCol(ObjWorldMatrix);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
float4 PL_VS(float4 Pos : POSITION, float3 Normal : NORMAL, uniform bool draw) : POSITION
{
    float4 p = float4(0,0,1,0);
    if(draw) {
        p = mul( Pos, WorldViewProjMatrix );
    }
    return p;
}

// ピクセルシェーダ
float4 PL_PS() : COLOR0
{
    return float4(LightColor, 1);
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec0 < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 PL_VS(Draw);
        PixelShader  = compile ps_3_0 PL_PS();
    }
}

technique MainTec0 < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 PL_VS(Draw);
        PixelShader  = compile ps_3_0 PL_PS();
    }
}



