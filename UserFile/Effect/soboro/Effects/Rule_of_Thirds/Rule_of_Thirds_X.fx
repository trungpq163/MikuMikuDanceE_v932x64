

float3 LineColor = float3(0.3, 0.3, 0.3);

////////////////////////////////////////////////////////////////////////////////////////////////

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

//アルファ値取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//フレーム時間とシステム時間が一致したら再生中とみなす
float elapsed_time1 : ELAPSEDTIME<bool SyncInEditMode=true;>;
float elapsed_time2 : ELAPSEDTIME<bool SyncInEditMode=false;>;
static bool IsPlaying = (abs(elapsed_time1 - elapsed_time2) < 0.01) && (scaling > 0.5);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
};

// 頂点シェーダ
VS_OUTPUT2 Line_VS(float4 Pos : POSITION, float3 Normal : NORMAL, uniform bool hidden)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;
    
    Out.Pos = Pos;
    Out.Pos.z = 0;
    
    return Out;
}

// ピクセルシェーダ
float4 Line_PS( VS_OUTPUT2 IN ) : COLOR0
{
    return float4(LineColor, alpha1 * (1 - IsPlaying));
}

///////////////////////////////////////////////////////////////////////////////////////////////
// その他のオブジェクトをマスク描画

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        FillMode = WIREFRAME;
        VertexShader = compile vs_2_0 Line_VS(false);
        PixelShader  = compile ps_2_0 Line_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        FillMode = WIREFRAME;
        VertexShader = compile vs_2_0 Line_VS(false);
        PixelShader  = compile ps_2_0 Line_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTech < string MMDPass = "shadow";  > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
