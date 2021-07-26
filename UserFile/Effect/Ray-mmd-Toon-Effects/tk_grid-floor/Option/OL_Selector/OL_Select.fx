////////////////////////////////////////////////////////////////////////////////////////////////
//
// Material Selector for ObjectLuminous.fx
//    発光させるオブジェクトを、元の素材の色及び発光色で描画します
//    ｢MMEffect｣→｢エフェクト割当｣のAL_EmitterRTタブから、
//       下の発光させる材質番号を指定してモデルに適用する
//       あるいは、サブセット展開して指定する材質に適用します
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 発光させる材質番号
#define TargetSubset "0-1000"

//発光色 (RGBA各要素 0.0～1.0)
float3 Emittion_Color
<
   string UIName = "Emittion Color1";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 1.0;
> = float3( 0.0, 0.0, 0.0 );

//ゲイン
float Gain
<
   string UIName = "Gain";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0; float UIMax = 5.0;
> = float( 1.0 );


// 解らない人はここから下はいじらないでね
///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;

//カメラ位置
float3 CameraPosition   : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;

bool use_texture;    //テクスチャの有無
bool use_spheremap;  //テクスチャの有無
bool spadd;    // スフィアマップ加算合成フラグ


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

// オブジェクトのスフィアマップテクスチャ。
texture ObjectSphereMap : MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state
{
    texture = <ObjectSphereMap>;
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
        float3 Normal : NORMAL;
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

struct VS_OUTPUT {
    float4 Pos   : POSITION;
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float2 SpTex : TEXCOORD1;   // スフィアマップテクスチャ座標
    float4 VPos  : TEXCOORD2;
    float4 Color : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT VS_Selected(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    float4 Pos = mul( GETPOS, WorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color = MaterialDiffuse;
    Out.Color.rgb += MaterialEmmisive / 2;
    Out.Color.rgb *= 0.5;

    // テクスチャ座標
    Out.Tex = IN.Tex;

    // スフィアマップテクスチャ座標
    float3 Normal = normalize( mul( IN.Normal, (float3x3)WorldMatrix ) );
    float2 NormalWV = mul( Normal, (float3x3)ViewMatrix ).xy;
    Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
    Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;

    return Out;
}

//ピクセルシェーダ
float4 PS_Selected(VS_OUTPUT IN) : COLOR
{
    float4 Color = IN.Color;
    if ( use_texture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( use_spheremap ) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color.rgb *= tex2D(ObjSphareSampler,IN.SpTex).rgb;
    }
    Color.rgb += Emittion_Color;
    Color.rgb *= (Gain * Color.a);

    return Color;
}

float4 PS_Black(float2 Tex : TEXCOORD1) : COLOR
{
    float alpha = MaterialDiffuse.a;
    if ( use_texture ) alpha *= tex2D( ObjTexSampler, Tex ).a;
    return float4(0.0, 0.0, 0.0, alpha);
}


////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

//セルフシャドウなし
technique Tec1 < string MMDPass = "object"; string Subset = TargetSubset; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Selected();
        PixelShader  = compile ps_2_0 PS_Selected();
    }
}

technique Mask < string MMDPass = "object"; >
{
    pass Single_Pass {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_Selected();
        PixelShader  = compile ps_2_0 PS_Black();
    }
}

//セルフシャドウあり
technique Tec1SS < string MMDPass = "object_ss"; string Subset = TargetSubset; >
{
    pass Single_Pass {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Selected();
        PixelShader  = compile ps_2_0 PS_Selected();
    }
}

technique MaskSS < string MMDPass = "object_ss"; >
{
    pass Single_Pass {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_Selected();
        PixelShader  = compile ps_2_0 PS_Black();
    }
}

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

