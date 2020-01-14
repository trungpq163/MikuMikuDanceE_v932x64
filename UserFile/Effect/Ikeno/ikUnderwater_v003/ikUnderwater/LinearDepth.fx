// カメラからの距離を格納する
// 仮想光源との陰影計算の結果も格納する。

#include "Settings.fxsub"
#include "Commons.fxsub"

// 半透明を無視する閾値
const float ShadowAlphaThreshold = 0.6;


///////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 matWVP	: WORLDVIEWPROJECTION;
float4x4 matWV	: WORLDVIEW;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

bool	use_texture;		// テクスチャ使用

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

float4   MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
	float4 Pos		: POSITION;    // 射影変換座標
	float3 VPos		: TEXCOORD0;
	float2 Tex		: TEXCOORD1;
	float3 Normal	: TEXCOORD2;
	float4 WPos		: TEXCOORD3;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL,float2 Tex: TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matWVP );
	Out.WPos = Out.Pos;
	Out.VPos = mul( Pos, matWV).xyz;
	Out.Tex = Tex;
	Out.Normal = Normal;
	return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	float alpha = MaterialDiffuse.a;
	if (use_texture) alpha *= tex2D( ObjTexSampler, IN.Tex ).a;
	clip(alpha - ShadowAlphaThreshold);

	float distance = length(IN.VPos);

	float3 L = normalize(WaveLightPosition - IN.WPos.xyz);
	// float3 L = -WaveLightDirection;
	float NL = saturate(dot(IN.Normal, L));
	// 距離に応じて減衰
	// NL *= saturate(100.0 / distance);

	return float4(distance / FAR_Z, NL, 0, 1);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}

///////////////////////////////////////////////////////////////////////////////////////////////
