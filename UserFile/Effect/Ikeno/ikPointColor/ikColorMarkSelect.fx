
#include "ikPointColorSettings.fxsub"

// 合う色がなかったときに選ばれるパレット番号
const int DefaultMark = 0;

// 指定パレットと許容できる色の範囲
const float DistanceLatitude = 64 / 256.0;



///////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 matWVP	: WORLDVIEWPROJECTION;
float4x4 matWV	: WORLDVIEW;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


shared texture2D PalletTex;
sampler PalletTexSamp = sampler_state {
	texture = <PalletTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
	float4 Pos        : POSITION;    // 射影変換座標
	float2 Tex	  : TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL,float2 Tex: TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = mul( Pos, matWVP );
	Out.Tex = Tex;
	return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	// α値が閾値以下の箇所は描画しない
	float4 col = tex2D( ObjTexSampler, IN.Tex );
	float alpha = col.a;
	clip(alpha - AlphaThroughThreshold);

	// 近い色を探す
	int index = DefaultMark;
	float dist = DistanceLatitude;
	const float ph = PALLET_HEIGHT * PALLET_SLOT;
	for(int i = 0; i < PALLET_HEIGHT; i++) {
		float3 pal = tex2D( PalletTexSamp, float2(1, (i + 0.5) / ph)).rgb;
		float tmpDist = dot(abs(col.rgb - pal), 1);
		if (tmpDist < dist)
		{
			dist = tmpDist;
			index = i;
		}
	}

	return float4((index  + 0.5) / PALLET_HEIGHT, 0,0,1);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}

///////////////////////////////////////////////////////////////////////////////////////////////
