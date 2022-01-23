////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PlanarShadow.fx ver0.0.3 MMDの地面影を任意の平面に投影できるようにします
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float3 PlanarPos = float3(0.0, 10.0, 0.0);    // 投影する平面上の任意の座標
float3 PlanarNormal = float3(0.0, 1.0, 0.0);  // 投影する平面の法線ベクトル


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 ViewProjMatrix  : VIEWPROJECTION;
float3   LightDirection  : DIRECTION < string Object = "Light"; >;

//  地面影色
float4 GroundShadowColor : GROUNDSHADOWCOLOR;


///////////////////////////////////////////////////////////////////////////////////////////////
// 任意平面の影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // 光源の仮位置(平行光源なので)
    float3 LightPos = Pos.xyz + LightDirection;

    // 任意平面に投影
    float a = dot(PlanarNormal, PlanarPos - LightPos);
    float b = dot(PlanarNormal, Pos.xyz - PlanarPos);
    float c = dot(PlanarNormal, Pos.xyz - LightPos);
    Pos = float4(Pos.xyz * a + LightPos * b, c);

    // ビュー射影変換
    return mul( Pos, ViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // 地面影色で塗りつぶし
    return GroundShadowColor;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
