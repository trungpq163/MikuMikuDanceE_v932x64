////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LineBillboard.fx ver0.0.1  ラインビルボードのサンプル
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float LocalLen = 2.0f;  // ローカル座標系でのボード辺の長さ
float Thick = 5.0f;     // ラインの太さ

// ボーン座標(ライン端点)
float3 Point1 : CONTROLOBJECT < string name = "LineBillboard.pmx"; string item = "Point1"; >;
float3 Point2 : CONTROLOBJECT < string name = "LineBillboard.pmx"; string item = "Point2"; >;

// 座標変換行列
float4x4 ViewProjMatrix  : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// ラインビルボード行列(ワールド変換行列になる)
static float3 xAxis = normalize( cross( Point2 - Point1, Point1 - CameraPosition ) );
static float3 yAxis = ( Point2 - Point1 ) / LocalLen;
static float3 zAxis = normalize( cross( xAxis, yAxis ) );
static float4x4 LineBillboardMatrix =  float4x4( xAxis * Thick,        0.0f,
                                                 yAxis,                0.0f,
                                                 zAxis,                0.0f,
                                                 (Point2+Point1)*0.5f, 1.0f );

// オブジェクトのテクスチャ
texture2D ObjectTexture <
    string ResourceName = "sample.png";
    int MipLevels = 0;
>;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    MaxAnisotropy = 16;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 射影変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Billboard_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // ボードローカル座標
    Pos = float4( LocalLen*(Tex.x - 0.5f), LocalLen*(0.5f - Tex.y), 0.0f, 1.0f );

    // ビルボード(ワールド座標変換)
    Pos = mul( Pos, LineBillboardMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Billboard_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    return tex2D( ObjTexSampler, Tex );
}

///////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec0 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Billboard_VS();
        PixelShader  = compile ps_2_0 Billboard_PS();
    }
}

technique MainTec1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Billboard_VS();
        PixelShader  = compile ps_2_0 Billboard_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
