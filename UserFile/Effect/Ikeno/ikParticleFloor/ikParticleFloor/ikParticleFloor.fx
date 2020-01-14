////////////////////////////////////////////////////////////////////////////////////////////////
//
// ikFloorParticle.fx 床に散乱しているパーティクル
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 設定ファイル
#include "ikParticleSettings.fxsub"

// 0:円形に並べる、1:均等に並べる
#define ENABLE_FLAT_PATTERN		0

// アクセの中心からパーティクルを配置しない半径
// キャラがいるので、中心部にはパーティクルが落ちにくいという想定。
// 円形配置時のみ有効
#define AvoidanceRadius		(5.0)

// 強制的にパーティクル数を変更する。0の場合、元パーティクルと同じ数
// 最大でx1024個のパーティクルが出る。
#define FORCE_UNIT_COUNT		2

// 不透明度。0:透明～1:不透明。
#define ParticleAlpha	(1.0)


////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
const float AlphaThroughThreshold = 0.5;

// パーティクル数を増やす場合の設定
#if defined(FORCE_UNIT_COUNT) && FORCE_UNIT_COUNT > 0
#undef	UNIT_COUNT
#define	UNIT_COUNT	FORCE_UNIT_COUNT
#endif

#define PAI 3.14159265f	// π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float3 AcsPosition : CONTROLOBJECT < string name = "(self)"; >;

int RepeatCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepeatIndex;				// 複製モデルカウンタ

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float4x4 matVPLight : VIEWPROJECTION < string Object = "Light"; >;

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

// 座標変換行列
float4x4 matW	: WORLD;
float4x4 matV	 : VIEW;
float4x4 matVP : VIEWPROJECTION;


// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

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

	#if(USE_SPHERE == 1)
	texture2D ParticleSphere <
		string ResourceName = SPHERE_FileName;
		int MipLevels = 1;
	>;
	sampler ParticleSphereSamp = sampler_state {
		texture = <ParticleSphere>;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = NONE;
		AddressU  = CLAMP;
		AddressV  = CLAMP;
	};
	#endif


// 乱数生成用
texture2D RandomTex <
	string ResourceName = "../Commons/rand128.png";
>;
sampler RandomSmp = sampler_state{
	texture = <RandomTex>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU  = WRAP;
	AddressV = WRAP;
};

#define RND_TEX_SIZE 128

#if defined(PALLET_FileName) && USE_PALLET > 0
texture2D ColorPallet <
	string ResourceName = PALLET_FileName;
>;
sampler ColorPalletSmp = sampler_state{
	texture = <ColorPallet>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU  = WRAP;
	AddressV = WRAP;
};
#endif




////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float3 GetRand(float index)
{
	float u = floor(index);
	float v = fmod(u, RND_TEX_SIZE);
	u = floor(u / RND_TEX_SIZE);
	float3 pos = tex2Dlod(RandomSmp, float4(float2(u,v) / RND_TEX_SIZE, 0,0)).xyz;

	float ang = (pos.y + index / 251.0) * 3.141592 * 2.0;

#if defined(ENABLE_FLAT_PATTERN) && ENABLE_FLAT_PATTERN > 0
	// 均等に配置
	pos.xz += float3(cos(ang), 0, sin(ang)) * (1.0 / 256.0);
	pos.y = 0;
	pos.xz = (pos.xz * 2.0 - 1.0) * ParticleInitPos * AcsSi * 0.1;

#else
	// 円形に配置
	float l = pos.x * (ParticleInitPos + 0.5) * AcsSi * 0.1 + AvoidanceRadius;
	l -= pos.z * pos.z * AvoidanceRadius * 0.25; // 少し内側にも入り込む
	pos = float3(cos(ang), 0, sin(ang)) * l;

#endif
	return pos + AcsPosition + float3(0, 0.1, 0);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 粒子の回転行列
float3x3 RoundMatrix(int index, float etime)
{
//	float rotX = ParticleRotSpeed * (1.0f + 0.3f*sin(247*index)) * etime + (float)index * 147.0f;
	float rotY = ParticleRotSpeed * (1.0f + 0.3f*sin(368*index)) * etime + (float)index * 258.0f;
//	float rotZ = ParticleRotSpeed * (1.0f + 0.3f*sin(122*index)) * etime + (float)index * 369.0f;

	float sinx = 1, cosx = 0;
	float siny, cosy;
	float sinz = 0, cosz = 1;

	sincos(rotY, siny, cosy);

	float3x3 rMat = { cosz*cosy+sinx*siny*sinz, cosx*sinz, -siny*cosz+sinx*cosy*sinz,
					-cosy*sinz+sinx*siny*cosz, cosx*cosz,  siny*sinz+sinx*cosy*cosz,
					 cosx*siny,				-sinx,		cosx*cosy,				};
	return rMat;
}

///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
	float4 Pos		: POSITION;	// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float  TexIndex	: TEXCOORD1;	// テクスチャ粒子インデクス
	float4 ZCalcTex	: TEXCOORD2;	// Z値
	float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
	float4 Color	: COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool useShadow)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepeatIndex;
	int j = round( Pos.z * 100.0f );
	int Index0 = i * 1024 + j;
	Pos.z = 0.0f;
	Out.TexIndex = float(j);

	// 粒子の座標
	// Index0から一意に決める
	float4 Pos0 = float4(GetRand(Index0), 1);

	#if( USE_SPHERE==1 )
	// 粒子の法線ベクトル(頂点単位)
	float3 Normal = normalize(float3(0.0f, 0.0f, -0.2f) - Pos.xyz);
	#endif

	// 粒子の大きさ
	Pos.xy *= ParticleSize * 10.0f;

	float3x3 matWTmp = RoundMatrix(Index0, 0);

	// 粒子の回転
	Pos.xyz = mul( Pos.xyz, matWTmp );

	// 粒子のワールド座標
	Pos.xyz += Pos0.xyz;
	Pos.w = 1.0f;

	bool isVisible = (Index0 <= AcsTr * UNIT_COUNT * 1024);
	Pos.xyz *= isVisible;

	// カメラ視点のビュー射影変換
	Out.Pos = mul( Pos, matVP );
	if (useShadow) Out.ZCalcTex = mul( Pos, matVPLight );

	// ライトの計算
	#if ENABLE_LIGHT == 1
	float3 N = normalize(matWTmp[2]);
	float dotNL = dot(-LightDirection, N);
	float dotNV = dot(normalize(CameraPosition - Pos.xyz), N);
	dotNL = dotNL * sign(dotNV);
	float diffuse = lerp(max(dotNL,0) + max(-dotNL,0) * Translucency, 1, Translucency);
	#else
	float diffuse = 1;
	#endif

	// 粒子の乗算色
	float alpha = isVisible * ParticleAlpha;
	Out.Color = float4(saturate(LightColor * diffuse + EmissivePower), alpha );

	// テクスチャ座標
	int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
	int tex_i = texIndex % TEX_PARTICLE_XNUM;
	int tex_j = texIndex / TEX_PARTICLE_XNUM;
	Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

	#if( USE_SPHERE==1 )
		// スフィアマップテクスチャ座標
		Normal = mul( Normal, matWTmp );
		float2 NormalWV = mul( Normal, (float3x3)matV ).xy;
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	#endif

	return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN, uniform bool useShadow ) : COLOR0
{
	// 粒子の色
	float4 Color = IN.Color * tex2D( ParticleTexSamp, IN.Tex );
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

	#if defined(PALLET_FileName) && USE_PALLET > 0
	// ランダム色設定
	float4 randColor = tex2D(ColorPalletSmp, float2((IN.TexIndex+0.5f) / PALLET_TEX_SIZE, 0.5));
	Color.rgb *= randColor.rgb;
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



///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
	string Script = 
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=DrawObject;"
			"LoopEnd=;";
>{
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
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=DrawObject;"
			"LoopEnd=;";
>{
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
