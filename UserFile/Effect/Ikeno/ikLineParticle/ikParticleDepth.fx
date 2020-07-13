////////////////////////////////////////////////////////////////////////////////////////////////
//
// ikParticleDepth.fx
//		ikボケ用にLineParticleの情報を出力する
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 設定ファイル
#include "ikParticleSettings.fxsub"

// 座標を共有する時の名前
#define	COORD_TEX_NAME		LineParticleCoordTex

// これ以下の透明度を無視する。
const float AlphaThroughThreshold = 0.3;


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// なにもない描画しない場合の背景までの距離
#define FAR_DEPTH		1000

#define POS_TEX_WIDTH	(TAIL_DIV * UNIT_COUNT)
#define TEX_HEIGHT		PARTICLE_NUM	// 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

int RepertCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepertIndex;               // 複製モデルカウンタ


// 座標変換行列
float4x4 matW    : WORLD;
float4x4 matV     : VIEW;
float4x4 matVP : VIEWPROJECTION;

float4x4 matVInv	: VIEWINVERSE;
static float3x3 BillboardMatrix = {
	normalize(matVInv[0].xyz),
	normalize(matVInv[1].xyz),
	normalize(matVInv[2].xyz),
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

    texture2D ParticleTex <
        string ResourceName = TEX_FileName;
        int MipLevels = 1;
    >;
    sampler ParticleTexSamp = sampler_state {
        texture = <ParticleTex>;
        MinFilter = LINEAR;
        MagFilter = LINEAR;
        MipFilter = NONE;
        AddressU  = CLAMP;
        AddressV  = CLAMP;
    };

// 粒子座標記録用
shared texture COORD_TEX_NAME : RENDERCOLORTARGET;
sampler PosSmpCopy = sampler_state
{
	Texture = <COORD_TEX_NAME>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
};


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
	float4 Pos		: POSITION;	// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 VPos		: TEXCOORD1;
	float4 Color	: COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, int index: _INDEX)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepertIndex;
	int j = index / (TAIL_DIV * 2);
	int k = index % (TAIL_DIV * 2);
	int l = k / 2;
	int Index0 = i * TEX_HEIGHT + j;

	float2 texCoord = float2((i*TAIL_DIV+l+0.5f)/POS_TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	float4 Pos0 = tex2Dlod(PosSmpCopy, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;

	Pos.x *= ParticleSize * 10.0f;
	Pos.yzw = float3(0, 0, 1);
	Pos.xyz = mul(Pos.xyz, BillboardMatrix) * step(0.001f, etime) + Pos0.xyz;
	Out.Pos = mul(Pos, matVP);
	Out.VPos = mul(Pos, matV);

	float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime);
	Out.Color = BASE_COLOR;
	Out.Color.a *= alpha;

	// テクスチャ座標
	int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
	int tex_i = texIndex % TEX_PARTICLE_XNUM;
	int tex_j = texIndex / TEX_PARTICLE_XNUM;
	Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

	return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
	float alpha = IN.Color.a * tex2D( ParticleTexSamp, IN.Tex ).a;
/*
	#if defined(USE_PALLET) && USE_PALLET > 0
	alpha *= tex2D(ColorPalletSmp, float2((IN.TexIndex+0.5f) / PALLET_TEX_SIZE, 0.5)).a;
	#endif
*/

    // 粒子の色
	clip(alpha - AlphaThroughThreshold);

	float distance = length(IN.VPos.xyz);
	return float4(distance / FAR_DEPTH, 0, 0, 1);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepertCount;"
            "LoopGetIndex=RepertIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;";
>{
    pass DrawObject {
        ZENABLE = TRUE;
        ZWRITEENABLE = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}
