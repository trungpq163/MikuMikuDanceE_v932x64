////////////////////////////////////////////////////////////////////////////////////////////////
//
//  full.fx ver2.0 をskydome専用に改造したもの
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;
    float2 Tex        : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Tex = Tex;
    return Out;
}

float4 Object_PS(VS_OUTPUT IN) : COLOR
{
    return tex2D( ObjTexSampler, IN.Tex);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Object_VS(); \
			PixelShader  = compile ps_3_0 Object_PS(); \
		} \
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTec1, "object_ss")

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}



///////////////////////////////////////////////////////////////////////////////////////////////
