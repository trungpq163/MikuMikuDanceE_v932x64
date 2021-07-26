////////////////////////////////////////////////////////////////////////////////////////////////
// 鏡面のモデルを黒く塗りつぶすエフェクト
////////////////////////////////////////////////////////////////////////////////////////////////
// アクセに組み込む場合はここを適宜変更してください．
float3 MirrorPos = float3( 0.0, 0.0, 0.0 );    // ローカル座標系における鏡面上の任意の座標(アクセ頂点座標の一点)
float3 MirrorNormal = float3( 0.0, 1.0, 0.0 ); // ローカル座標系における鏡面の法線ベクトル

///////////////////////////////////////////////////////////////////////////////////////////////
// 鏡面座標変換パラメータ
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >; // 鏡面アクセのワールド変換行列

// ワールド座標系における鏡像位置への変換
static float3 WldMirrorPos = mul( float4(MirrorPos, 1.0f), MirrorWorldMatrix ).xyz;
static float3 WldMirrorNormal = normalize( mul( MirrorNormal, (float3x3)MirrorWorldMatrix ) );

// 座標の鏡像変換
float4 TransMirrorPos( float4 Pos )
{
    Pos.xyz -= WldMirrorNormal * 2.0f * dot(WldMirrorNormal, Pos.xyz - WldMirrorPos);
    return Pos;
}

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 鏡面表裏判定(座標とカメラが両方鏡面の表側にある時だけ＋)
float IsFace( float4 Pos )
{
    return min( dot(Pos.xyz-WldMirrorPos, WldMirrorNormal),
                dot(CameraPosition-WldMirrorPos, WldMirrorNormal) );
}

///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;

float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

bool use_texture;  //テクスチャの有無

// オブジェクトのテクスチャ
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


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifndef MIKUMIKUMOVING
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
    };
    #define GETPOS (IN.Pos)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define GETPOS MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD1;   // テクスチャ
    float4 WPos  : TEXCOORD2;   // 鏡像元ワールド座標
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    float4 Pos = mul( GETPOS, WorldMatrix );
    Out.WPos = Pos; // ワールド座標

    // 鏡像位置への座標変換
    Pos = TransMirrorPos( Pos ); // 鏡像変換

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );
    Out.Pos.x = -Out.Pos.x; // ポリゴンが裏返らないように左右反転にして描画

    // テクスチャ座標
    Out.Tex = IN.Tex;

    return Out;
}

float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    // 鏡面の裏側にある部位は鏡像表示しない
    clip( IsFace( IN.WPos ) );

    float alpha = alpha1;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, IN.Tex ).a;

    return float4(0.0, 0.0, 0.0, alpha);
}

//セルフシャドウなし
technique Mask < string MMDPass = "object"; > {
    pass Single_Pass { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

//セルフシャドウあり
technique MaskSS < string MMDPass = "object_ss"; > {
    pass Single_Pass { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

