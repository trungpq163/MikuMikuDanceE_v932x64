////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Hologram_Mask1.fx  マスク画像作成，適用モデルをを白に
//  ( Hologram.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

float3 BoneCenter : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;
float3 AcsOffset : CONTROLOBJECT < string name = "(self)"; >;

// 座標変換行列
float4x4 WorldMatrix      : WORLD;
float4x4 ProjMatrix       : PROJECTION;
float4x4 ViewProjMatrix   : VIEWPROJECTION;

float3 CameraPosition   : POSITION  < string Object = "Camera"; >;
static float PmdEyeLength = max( length( CameraPosition - BoneCenter ), 10.0f ) * pow(2.4142f / ProjMatrix._22, 0.7f);;
static float AcsEyeLength = max( length( CameraPosition - AcsOffset ), 10.0f ) * pow(2.4142f / ProjMatrix._22, 0.7f);;


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos  : POSITION;    // 射影変換座標
    float4 VPos : TEXCOORD1;   // ワールド変換座標
};

// 頂点シェーダ
VS_OUTPUT VS_Mask(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
    Out.VPos = Pos;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    return Out;
}

//ピクセルシェーダ
float4 PS_PmdMask(VS_OUTPUT IN) : COLOR
{
    float height = IN.VPos.y/IN.VPos.w;
    return float4(1.0f, height, min(PmdEyeLength, 40.0f), 1.0f);
}

float4 PS_AcsMask(VS_OUTPUT IN) : COLOR
{
    float height = IN.VPos.y/IN.VPos.w;
    return float4(1.0f, height, min(AcsEyeLength, 40.0f), 1.0f);
}

//////////////////////////////////////////////////////////////////////////////////
// テクニック

technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_PmdMask();
    }
}

//セルフシャドウなし
technique Mask0 < string MMDPass = "object"; bool UseToon = false; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_AcsMask();
    }
}

technique Mask1 < string MMDPass = "object"; bool UseToon = true; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_PmdMask();
    }
}

//セルフシャドウあり
technique MaskSS0 < string MMDPass = "object_ss"; bool UseToon = false; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_AcsMask();
    }
}

technique MaskSS1 < string MMDPass = "object_ss"; bool UseToon = true; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_PmdMask();
    }
}

//描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }

