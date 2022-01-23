////////////////////////////////////////////////////////////////////////////////////////////////
//
//  BSB_Object.fx モデルの形状に合わせて炎を出すエフェクト(モデルセレクタ)
//  ( BoardSelfBurning.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換パラメータ
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;
float4x4 WorldViewMatrix     : WORLDVIEW;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

float4x4 BoardWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >; // ボードのワールド変換行列
static float3 PlanarPos = mul( BoardWorldMatrix[3], ViewMatrix ).xyz;  // 投影する平面上の原点座標
static float3 PlanarNormal = float3(0.0, 0.0, -1.0);                   // 投影する平面の法線ベクトル
static float scaling = length(BoardWorldMatrix._11_12_13)*0.1f;
static float aspect = ProjMatrix._22 /  ProjMatrix._11;  // メイン画面のアスペクト比(ProjMatrixはOffscreenのサイズに関係なくメイン画面のが取得される)

// ボードのZ軸回転行列
static float4 WPos = float4(BoardWorldMatrix._41_42_43, 1);
static float4 pos0 = mul( WPos, ViewProjMatrix);
static float4 posY = mul( float4(WPos.x, WPos.y+1, WPos.z, 1), ViewProjMatrix);
static float2 rotVec0 = posY.xy/posY.w - pos0.xy/pos0.w;
static float2 rotVec = normalize( float2(rotVec0.x*aspect, rotVec0.y) );
static float2x2 RotMatrix = float2x2( rotVec.y, rotVec.x,
                                     -rotVec.x, rotVec.y );

// モデル形状のはみ出し度
float AcsRz: CONTROLOBJECT < string Name = "(OffscreenOwner)"; string item = "Rz"; >;
static float sourceFatness = max(0.8f + degrees(AcsRz), -0.2f);

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// ボード面への描画

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    // ワールドビュー射影座標変換(z,wだけこのまま用いる)
    float4 Pos0 = mul( Pos, WorldViewProjMatrix );

    // ワールドビュー座標変換
    Pos = mul( Pos, WorldViewMatrix );
    Normal = normalize( mul( Normal, (float3x3)WorldViewMatrix ) );

    // 法線方向に少し押し出す
    Pos.xyz += Normal * sourceFatness;

    // ボード面に投影
    if(ProjMatrix._44 < 0.5f){
        float a = dot(PlanarNormal, PlanarPos);
        float b = dot(PlanarNormal, Pos.xyz);
        Pos.xyz *= a/b;
    }

    // 射影変換もどき
    Pos.xyz -= PlanarPos;
    Pos.xy = mul( Pos.xy, RotMatrix );
    Pos.x /= 30.0f * scaling; // アクセが-30～30なので
    Pos.y -= 10.0f * scaling;
    Pos.y /= 30.0f * scaling; // アクセが-20～40なので
    Pos.xy *= Pos0.w;
    Pos.zw = Pos0.zw;

    Out.Pos = Pos;
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Object_PS(float2 Tex : TEXCOORD0, uniform bool useTexture) : COLOR
{
    // ボード面がカメラの裏側にあるときは描画しない
    clip(PlanarPos.z - 2.0f);

    float alpha = MaterialDiffuse.a;

    if ( useTexture ) {
        // テクスチャ透過値適用
        alpha *= tex2D( ObjTexSampler, Tex ).a;
    }

    clip(alpha - 0.005f);

    return float4(alpha, alpha, alpha, 1);
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique Tec1 < string MMDPass = "object"; bool UseTexture = false; > {
    pass DrawShadow {
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader  = compile ps_2_0 Object_PS(false);
    }
}

technique Tec2 < string MMDPass = "object"; bool UseTexture = true; > {
    pass DrawShadow {
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader  = compile ps_2_0 Object_PS(true);
    }
}

technique TecSS1 < string MMDPass = "object_ss"; bool UseTexture = false; > {
    pass DrawShadow {
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader  = compile ps_2_0 Object_PS(false);
    }
}

technique TecSS2 < string MMDPass = "object_ss"; bool UseTexture = true; > {
    pass DrawShadow {
        DestBlend = ONE;
        SrcBlend = ONE;
        VertexShader = compile vs_2_0 Object_VS();
        PixelShader  = compile ps_2_0 Object_PS(true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

// エッジは描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
// 地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは描画しない
technique ZplotTec < string MMDPass = "zplot"; > { }

