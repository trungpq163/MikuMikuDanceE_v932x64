////////////////////////////////////////////////////////////////////////////////////////////////
//
// ikParticle.fx オブジェクトの動きに影響を受けるパーティクルエフェクト
//
// ベース：
//  CannonParticle.fx ver0.0.4 打ち出し式パーティクルエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////


// 設定ファイル
#include "ikParticleSettings.fxsub"

// 本体
#include "../Commons/Sources/_body.fxsub"


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

float4x4 matV	: VIEW;
float4x4 matVP	: VIEWPROJECTION;
float4x4 matVPLight : VIEWPROJECTION < string Object = "Light"; >;

float3	CameraPosition    : POSITION  < string Object = "Camera"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;

#if MMD_LIGHTCOLOR == 1
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float3 LightColor = LightSpecular * 2.5 / 1.5;
#else
float3 LightSpecular = float3(1, 1, 1);
float3 LightColor = float3(1, 1, 1);
#endif

bool	 parthf;   // パースペクティブフラグ
#define SKII1	1500
#define SKII2	8000

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);


struct VS_OUTPUT2
{
	float4 Pos		: POSITION;	// 射影変換座標
	float4 Tex		: TEXCOORD0;	// テクスチャ
	float4 ZCalcTex	: TEXCOORD2;	// Z値
	float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
	float4 Color	: COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool useShadow)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	POSITION_INFO posInfo = CalcPosition(Pos, Tex);
	float4 WPos = posInfo.WPos;

	Out.Pos = mul( WPos, matVP );
	if (useShadow) Out.ZCalcTex = mul( WPos, matVPLight );

	// ライトの計算
	#if ENABLE_LIGHT == 1
	float3 N = posInfo.Normal;
	float dotNL = dot(-LightDirection, N);
	float dotNV = dot(normalize(CameraPosition - Pos.xyz), N);
	dotNL = dotNL * sign(dotNV);
	float diffuse = lerp(max(dotNL,0) + max(-dotNL,0) * Translucency, 1, Translucency);
	#else
	float diffuse = 1;
	#endif

	Out.Color = posInfo.Color * float4(diffuse.xxx, 1);
	Out.Tex = posInfo.Tex;
	Out.SpTex = posInfo.SpTex;

	return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN, uniform bool useShadow ) : COLOR0
{
	// 粒子の色
	float4 Color = CalcColor(IN.Color, IN.Tex);

	#if( TEX_ZBuffWrite==1 )
		clip(Color.a - AlphaThroughThreshold);
	#endif

	#if ENABLE_LIGHT == 1
	if (useShadow)
	{
		// テクスチャ座標に変換
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
		if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
			// シャドウバッファ外
			;
		} else {
			float a = (parthf) ? SKII2*TransTexCoord.y : SKII1;
			float d = IN.ZCalcTex.z;
			float light = 1 - saturate(max(d - tex2D(DefSampler,TransTexCoord).r , 0.0f)*a-0.3f);
			light = saturate(light + EmissivePower);
			Color.rgb = min(Color.rgb, light);
		}
	}
	#endif

	#if( USE_SPHERE==1 )
		// スフィアマップ適用
		Color.rgb += max(tex2D(ParticleSphereSamp, IN.SpTex).rgb * LightSpecular, 0);
		#if( SPHERE_SATURATE==1 )
			Color = saturate( Color );
		#endif
	#endif

	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos		: POSITION;				// 射影変換座標
	float4 Tex		: TEXCOORD0;	// テクスチャ
	float4 ShadowMapTex : TEXCOORD1;	// Zバッファテクスチャ
	float4 Color	 : COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	POSITION_INFO posInfo = CalcPosition(Pos, Tex);
	float4 WPos = posInfo.WPos;

	Out.Pos = mul( WPos, matVPLight );
	Out.ShadowMapTex = Out.Pos;

	Out.Color = posInfo.Color;
	Out.Tex = posInfo.Tex;

	return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS(
		float4 ShadowMapTex	: TEXCOORD1,
		float4 Tex			: TEXCOORD0,
		float4 Color		: COLOR0
	) : COLOR
{
	float alpha = CalcColor(Color, Tex).a;
	clip(alpha - AlphaThroughThreshold);

	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec <
	string MMDPass = "zplot";
	string Script = PARTICLE_LOOPSCRIPT_OBJECT;
>{
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ZValuePlot_VS();
		PixelShader  = compile ps_3_0 ZValuePlot_PS();
	}
}


technique MainTec1 < string MMDPass = "object";
	string Script = 
		PARTICLE_UPDATE_POSITION
		PARTICLE_LOOPSCRIPT_OBJECT;
>{
	UPDATE_PASS_STATES

	pass DrawObject {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		AlphaBlendEnable = TRUE;
		CullMode = NONE;
		VertexShader = compile vs_3_0 Particle_VS(false);
		PixelShader  = compile ps_3_0 Particle_PS(false);
	}
}

technique MainTec2 < string MMDPass = "object_ss";
	string Script = 
		PARTICLE_UPDATE_POSITION
		PARTICLE_LOOPSCRIPT_OBJECT;
>{
	UPDATE_PASS_STATES

	pass DrawObject {
		ZENABLE = TRUE;
		#if TEX_ZBuffWrite==0
		ZWRITEENABLE = FALSE;
		#endif
		AlphaBlendEnable = TRUE;
		CullMode = NONE;
		VertexShader = compile vs_3_0 Particle_VS(true);
		PixelShader  = compile ps_3_0 Particle_PS(true);
	}
}

