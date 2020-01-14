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


////////////////////////////////////////////////////////////////////////////////////////////////

// 最大何個までボーンを登録するか
#define MaxWindNum		8

// テクスチャの幅
// MaxWindNum <= WIND_TEX_HEIGHT である必要がある。
#define WIND_TEX_HEIGHT	8

#define	DECL_WIND(_suffix, _name)	\
	float3 WindPosition##_suffix : CONTROLOBJECT < string name = _name; >;	\
	float WindScale##_suffix : CONTROLOBJECT < string name = _name; string item = "Si"; >;	\
	float WindPower##_suffix : CONTROLOBJECT < string name = _name; string item = "Tr"; >;	

DECL_WIND( _01, "ikWindMaker01.x")
DECL_WIND( _02, "ikWindMaker02.x")
DECL_WIND( _03, "ikWindMaker03.x")
DECL_WIND( _04, "ikWindMaker04.x")
DECL_WIND( _05, "ikWindMaker05.x")
DECL_WIND( _06, "ikWindMaker06.x")
DECL_WIND( _07, "ikWindMaker07.x")
DECL_WIND( _08, "ikWindMaker08.x")

inline float4 GetWindPos(float3 pos, float scale)
{
	return float4(pos, 0.23 * 10.0 / max(scale, 1e-4));
}

static float4 WindPositionArray[] = {
	GetWindPos(WindPosition_01, WindScale_01),
	GetWindPos(WindPosition_02, WindScale_02),
	GetWindPos(WindPosition_03, WindScale_03),
	GetWindPos(WindPosition_04, WindScale_04),
	GetWindPos(WindPosition_05, WindScale_05),
	GetWindPos(WindPosition_06, WindScale_06),
	GetWindPos(WindPosition_07, WindScale_07),
	GetWindPos(WindPosition_08, WindScale_08),
};

static float WindPowerArray[] = {
	WindPower_01,
	WindPower_02,
	WindPower_03,
	WindPower_04,
	WindPower_05,
	WindPower_06,
	WindPower_07,
	WindPower_08,
};


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
const float AlphaThroughThreshold = 0.5;

#define TEX_WIDTH	UNIT_COUNT  // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT	1024		// 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f	// π

#define STRGEN(x)	#x
#define	COORD_TEX_NAME_STRING		STRGEN(COORD_TEX_NAME)

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepeatCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepeatIndex;				// 複製モデルカウンタ

static float diffD = radians( clamp(90.0f - DiffusionAngle, -90.0f, 90.0f) );

// 時間設定
float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time1 : elapsed_time2, 0.0f, 0.1f);
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

// 1フレーム当たりの粒子発生数
static float P_Count = ParticleOccur * (Dt / ParticleLife) * AcsSi*100;


// 座標変換行列
float4x4 matW	: WORLD;
float4x4 matV	 : VIEW;
float4x4 matVP : VIEWPROJECTION;

#if USE_BILLBOARD == 1
float4x4 matVInv	: VIEWINVERSE;
static float3x3 BillboardMatrix = {
	normalize(matVInv[0].xyz),
	normalize(matVInv[1].xyz),
	normalize(matVInv[2].xyz),
};

float4x4 matLightVInv : VIEWINVERSE < string Object = "Light"; >;
static float3x3 LightBillboardMatrix = {
	normalize(matLightVInv[0].xyz),
	normalize(matLightVInv[1].xyz),
	normalize(matLightVInv[2].xyz),
};
#endif


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

// 粒子座標記録用
texture CoordWorkTex : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler CoordWorkSmp = sampler_state
{
	Texture = <CoordWorkTex>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
};

// 粒子座標記録用
shared texture COORD_TEX_NAME : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler CoordSmp = sampler_state
{
	Texture = <COORD_TEX_NAME>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
};

texture CoordDepthBuffer : RenderDepthStencilTarget <
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format = "D24S8";
>;

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler VelocitySmp = sampler_state
{
	Texture = <VelocityTex>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
};

texture VelocityTexCopy : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler VelocitySmpCopy = sampler_state
{
	Texture = <VelocityTexCopy>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
};


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
// 当たり判定
#if defined(ENABLE_BOUNCE) && ENABLE_BOUNCE > 0

#define AntiAliasMode		false
#define MipMapLevel			1
// 法線マップ
#if !defined(DRAW_NORMAL_MAP) || DRAW_NORMAL_MAP > 0
shared texture LPNormalMapRT: OFFSCREENRENDERTARGET <
	string Description = "render Normal and depth for ikParticle";
	float2 ViewPortRatio = {1, 1};
	string Format = "D3DFMT_A32B32G32R32F";		// RGBに法線。Aには深度情報
	int Miplevels = MipMapLevel;
	bool AntiAlias = AntiAliasMode;
	float4 ClearColor = { 0.0, 0.0, 0.0, 0.0};
	float ClearDepth = 1.0;
	string DefaultEffect = 
		"self = hide;"
		"ikParticle*.x = hide;"		// 自分以外の同類も排除
		"*.pmd = ikNormalMap.fx;"
		"*.pmx = ikNormalMap.fx;"
		"*.x = ikNormalMap.fx;"
		"* = hide;";
>;
#else
shared texture LPNormalMapRT: OFFSCREENRENDERTARGET;
#endif

sampler NormalMap = sampler_state {
	texture = <LPNormalMapRT>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
};

inline void GetND(float2 Tex, out float3 N, out float Depth)
{
	float4 ND = tex2D( NormalMap, Tex );
	N = normalize(ND.xyz);
	Depth = ND.w;
}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
#define WIND_TEX_WIDTH	1
#define WIND_TEX_FMT	"A32B32G32R32F"

texture WindPositionRT: RENDERCOLORTARGET
<
	int Width = WIND_TEX_WIDTH;
	int Height = WIND_TEX_HEIGHT;
	string Format = WIND_TEX_FMT;
>;

sampler WindPositionMap = sampler_state {
	texture = <WindPositionRT>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture WindVelocityRT: RENDERCOLORTARGET
<
	int Width = WIND_TEX_WIDTH;
	int Height = WIND_TEX_HEIGHT;
	string Format = WIND_TEX_FMT;
>;

sampler WindVelocityMap = sampler_state {
	texture = <WindVelocityRT>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////

// 風発生ポイントの位置
inline float4 GetWindPosition(int index)
{
	return (index < MaxWindNum) ? WindPositionArray[index] : float4(0,0,0,0);
}

// 風速の取得
inline float3 GetWindVelocity(float3 pos)
{
	float3 result = 0;

	for(int i = 0; i < MaxWindNum; i++) {
		float2 coord = float2(0.5 / WIND_TEX_WIDTH, (i + 0.5f) / WIND_TEX_HEIGHT);
		float4 wpos = WindPositionArray[i];
		float3 wvel = tex2D(WindVelocityMap, coord).xyz;
		result += exp(-length(pos - wpos.xyz) * wpos.w - 1e-4) * wvel;
	}

	return result * (50.0 * WindFactor);
}

inline bool IsTimeToReset()
{
	return (time < 0.001f);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float3 GetRand(float index)
{
	float u = floor(index + time);
	float v = fmod(u, RND_TEX_SIZE);
	u = floor(u / RND_TEX_SIZE);
	return tex2D(RandomSmp, float2(u,v) / RND_TEX_SIZE).xyz * 2.0 - 1.0;
}

float hash(float3 x)
{
	return cos(dot(x, float3(2.31,53.21,16.17))*124.123); 
}

float noise(float3 p)
{
	float3 pm = frac(p);
	float3 pd = p-pm;

	return lerp(hash(pd), hash(pd + 1.0), pm);
}

float3 PositionNoise(float3 pos)
{
	float scalex = (time * TurbulenceTimeScale + 0.136514);
	float scaley = (time * TurbulenceTimeScale + 1.216881);
	float scalez = (time * TurbulenceTimeScale + 2.556412);

	float x = noise(pos.xyz * float3(TurbulenceScale.xx, scalex));
	float y = noise(pos.yzx * float3(TurbulenceScale.xx, scaley));
	float z = noise(pos.zxy * float3(TurbulenceScale.xx, scalez));

	return float3(x,y,z);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 粒子の回転行列
float3x3 RoundMatrix(int index, float etime)
{
	float rotX = ParticleRotSpeed * (1.0f + 0.3f*sin(247*index)) * etime + (float)index * 147.0f;
	float rotY = ParticleRotSpeed * (1.0f + 0.3f*sin(368*index)) * etime + (float)index * 258.0f;
	float rotZ = ParticleRotSpeed * (1.0f + 0.3f*sin(122*index)) * etime + (float)index * 369.0f;

	float sinx, cosx;
	float siny, cosy;
	float sinz, cosz;
	sincos(rotX, sinx, cosx);
	sincos(rotY, siny, cosy);
	sincos(rotZ, sinz, cosz);

	float3x3 rMat = { cosz*cosy+sinx*siny*sinz, cosx*sinz, -siny*cosz+sinx*cosy*sinz,
					-cosy*sinz+sinx*siny*cosz, cosx*cosz,  siny*sinz+sinx*cosy*cosz,
					 cosx*siny,				-sinx,		cosx*cosy,				};
	return rMat;
}

// できるだけ正面を向く回転行列
float3x3 FacingRoundMatrix(int index, float etime, float4 Pos0)
{
	float3 v = normalize(CameraPosition - Pos0);
	float3x3 rMat = RoundMatrix(index, etime);

	float3 z = normalize(v * 0.5 + rMat[2]);
	float3 x = normalize(cross(rMat[1], z));
	float3 y = normalize(cross(z, x));

	float3x3 rMat2 = {x,y,z};
	return rMat2;
}

float3x3 RoundMatrixZ(int index, float etime)
{
	float rotZ = ParticleRotSpeed * (1.0f + 0.3f*sin(122*index)) * etime + (float)index * 369.0f;

	float sinz, cosz;
	sincos(rotZ, sinz, cosz);

	float3x3 rMat = { cosz*1+0*0*sinz, 1*sinz, -0*cosz+0*1*sinz,
					-1*sinz+0*0*cosz, 1*cosz,  0*sinz+0*1*cosz,
					 1*0,				-0,		1*1,				};

	return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
	return Out;
}

///////////////////////////////////////////////////////////////////////////////////////
struct PS_OUT_MRT
{
	float4 Pos		: COLOR0;
	float4 Vel		: COLOR1;
};

PS_OUT_MRT CopyPos_PS(float2 Tex: TEXCOORD0) : COLOR
{
	PS_OUT_MRT Out;
	Out.Pos = tex2D(CoordSmp, Tex);
	Out.Vel = tex2D(VelocitySmp, Tex);
	return Out;
}

// 粒子の発生・座標更新計算(xyz:座標,w:経過時間+1sec,wは更新時に1に初期化されるため+1sからスタート)
PS_OUT_MRT UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
	// 粒子の座標
	float4 Pos = tex2D(CoordSmp, Tex);

	// 粒子の速度
	float4 Vel = tex2D(VelocitySmp, Tex);

	int i = floor( Tex.x*TEX_WIDTH );
	int j = floor( Tex.y*TEX_HEIGHT );
	int p_index = j + i * TEX_HEIGHT;

	if(Pos.w < 1.001f){

		// 新たに粒子を発生させるかどうかの判定
		if(p_index < Vel.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
		if(p_index < Vel.w+P_Count){
		 Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生

	// 未発生粒子の中から新たに粒子を発生させる
		float3 WPos = GetRand(p_index);
		float3 WPos0 = matW._41_42_43;
		WPos *= ParticleInitPos * 0.1f;
		WPos = mul( float4(WPos,1), matW ).xyz;
		Pos.xyz = (WPos - WPos0) / AcsSi * 10.0f + WPos0;  // 発生初期座標

	// 発生したての粒子に初速度与える
		float3 rand = GetRand(p_index * 17 + RND_TEX_SIZE);
		float time1 = time + 100.0f;
		float ss, cs;
		sincos( lerp(diffD, PAI*0.5f, frac(rand.x*time1)), ss, cs );
		float st, ct;
		sincos( lerp(-PAI, PAI, frac(rand.y*time1)), st, ct );
		float3 vec  = float3( cs*ct, ss, cs*st );
		Vel.xyz = normalize( mul( vec, (float3x3)matW ) )
				* lerp(ParticleSpeedMin, ParticleSpeedMax, frac(rand.z*time1));

		}
	}else{
	// 発生粒子は疑似物理計算で座標を更新
		// 粒子の法線ベクトル
		float3 normal = mul( float3(0.0f,0.0f,1.0f), RoundMatrix(p_index, Pos.w) );

		// 抵抗係数の設定
		float v = length( Vel.xyz );
		float cosa = dot( normalize(Vel.xyz), normal );
		float coefResist = lerp(ResistFactor, 0.0f, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));
		float coefRotResist = lerp(0.2f, RotResistFactor, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));
		// 加速度計算(速度抵抗力+回転抵抗力+重力)
		float3 Accel = -Vel.xyz * coefResist - normal * v * cosa * coefRotResist + GravFactor;

		// 新しい座標に更新
		Pos.xyz += Dt * (Vel.xyz + Dt * Accel);

		// すでに発生している粒子は経過時間を進める
		Pos.w += Dt;
		Pos.w *= step(Pos.w-1.0f, ParticleLife); // 指定時間を超えると0

		Vel.xyz -= (Vel.xyz * (0.1 * Dt));
		Vel.xyz += GetWindVelocity(Pos.xyz) * (WindPowerScale * Dt);
		Vel.xyz += PositionNoise(Pos.xyz) * (Dt * TurbulenceFactor);
		Vel.xyz += GravFactor * Dt;

		#if defined(ENABLE_BOUNCE) && ENABLE_BOUNCE > 0
		// 簡単な交差判定
		float4 ppos = mul(float4(Pos.xyz,1), matVP );
		float dist = length(Pos.xyz - CameraPosition);
		float2 Tex2 = (1.0 + ppos.xy * float2(1, -1) / ppos.w) * 0.5;
		float3 N;
		float Depth;
		GetND(Tex2, N, Depth);
		float dotVN = dot(Vel.xyz, N);
		if (dotVN < 0.0 && Depth < dist && dist < Depth + IgnoreDpethOffset)
		{
			Vel.xyz = (Vel.xyz - N * (dotVN * (1 + BounceFactor))) * FrictionFactor;
		}

		// すこしだけ避ける
		const float reduce = 0.75;
		Tex2 = Tex2 * reduce + (-0.5 * reduce + 0.5); // 中央を見る
		GetND(Tex2, N, Depth);
		dotVN = dot(Vel.xyz, N);
		if (dotVN < 0.0)
		{
			float d = saturate(1.0 - abs(dist - Depth) * (1.0 / AvoidDistance));
			Vel.xyz -= N * (dotVN * d * d * AvoidFactor);
		}
		#endif
	}

	Vel.w += P_Count;
	if(Vel.w >= float(TEX_WIDTH*TEX_HEIGHT)) Vel.w -= float(TEX_WIDTH*TEX_HEIGHT);

	// 0フレーム再生で粒子初期化
	if(IsTimeToReset())
	{
		Pos = float4(matW._41_42_43, 0.0f);
		Vel = 0.0f;
	}

	PS_OUT_MRT Out;
	Out.Pos = Pos;
	Out.Vel = Vel;
	return Out;
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
	int Index0 = i * TEX_HEIGHT + j;
	float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	Pos.z = 0.0f;
	Out.TexIndex = float(j);

	// 粒子の座標
	float4 Pos0 = tex2Dlod(CoordWorkSmp, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;

	#if( USE_SPHERE==1 )
	// 粒子の法線ベクトル(頂点単位)
	float3 Normal = normalize(float3(0.0f, 0.0f, -0.2f) - Pos.xyz);
	#endif

	// 粒子の大きさ
	Pos.xy *= ParticleSize * 10.0f;

	#if USE_BILLBOARD == 0
	//float3x3 matWTmp = RoundMatrix(Index0, etime);
	float3x3 matWTmp = FacingRoundMatrix(Index0, etime, Pos0);
	#else
	float3x3 matWTmp = RoundMatrixZ(Index0, etime);
	#endif

	// 粒子の回転
	Pos.xyz = mul( Pos.xyz, matWTmp );
	#if USE_BILLBOARD != 0
	Pos.xyz = mul(Pos.xyz, BillboardMatrix);
	#endif

	// 粒子のワールド座標
	Pos.xyz += Pos0.xyz;
	Pos.xyz *= step(0.001f, etime);
	Pos.w = 1.0f;

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
	float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
	// 床付近で消さない
	#if !defined(ENABLE_BOUNCE) || ENABLE_BOUNCE == 0
	alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
	#endif
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
//

// 共通の頂点シェーダ
VS_OUTPUT CommonWind_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + float2(0.5f/WIND_TEX_WIDTH, 0.5f/WIND_TEX_HEIGHT);
	return Out;
}

// 現在の位置と、1フレ前の位置から速度を求める
float4 UpdateWindVelocity_PS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 pos = GetWindPosition(floor(Tex.y * WIND_TEX_HEIGHT));

	float3 oldPos = tex2D(WindPositionMap, Tex).xyz;

	// 一定速度以下は無視する
	float3 v = (pos.xyz - oldPos) / Dt;
	float len = length(v);
	if (!IsTimeToReset() && len > MinWindSpeed)
	{
		int i = (int)floor(Tex.y * WIND_TEX_HEIGHT);
		v = v * (min(len - MinWindSpeed, MaxWindSpeed) / len) * WindPowerArray[i];
	} else {
		v = 0;
	}

	return float4(v, 1);
}

// 現在の位置を保存
float4 UpdateWindPosition_PS(float2 Tex: TEXCOORD0) : COLOR
{
	float3 pos = GetWindPosition(floor(Tex.y * WIND_TEX_HEIGHT)).xyz;
	return float4(pos, 1);
}



///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD1;	// Zバッファテクスチャ

	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 Color	 : COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	int i = RepeatIndex;
	int j = round( Pos.z * 100.0f );
	int Index0 = i * TEX_HEIGHT + j;
	float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	Pos.z = 0.0f;

	// 粒子の座標
	float4 Pos0 = tex2Dlod(CoordWorkSmp, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;

	// 粒子の大きさ
	Pos.xy *= ParticleSize * 10.0f;

	// 粒子の回転
	Pos.xyz = mul( Pos.xyz, RoundMatrix(Index0, etime) );

	// 粒子のワールド座標
	Pos.xyz += Pos0.xyz;
	Pos.xyz *= step(0.001f, etime);
	Pos.w = 1.0f;

	// ライトの目線によるワールドビュー射影変換をする
	Out.Pos = mul( Pos, matVPLight );

	// テクスチャ座標を頂点に合わせる
	Out.ShadowMapTex = Out.Pos;

	// 粒子の乗算色
	float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
	#if !defined(ENABLE_BOUNCE) || ENABLE_BOUNCE == 0
	alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
	#endif
	Out.Color = float4( 1,1,1, alpha );

	// テクスチャ座標
	int texIndex = Index0 % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
	int tex_i = texIndex % TEX_PARTICLE_XNUM;
	int tex_j = texIndex / TEX_PARTICLE_XNUM;
	Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

	return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS(
		float4 ShadowMapTex	: TEXCOORD1,
		float2 Tex			: TEXCOORD0,
		float4 Color		: COLOR0
	) : COLOR
{
	float alpha = Color.a * tex2D( ParticleTexSamp, Tex ).a;
	clip(alpha - AlphaThroughThreshold);

	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec <
	string MMDPass = "zplot";
	string Script = 
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=ZValuePlot;"
			"LoopEnd=;";
>{
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ZValuePlot_VS();
		PixelShader  = compile ps_3_0 ZValuePlot_PS();
	}
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
	string Script = 
		"RenderColorTarget0=WindVelocityRT;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=UpdateWindVelocity;"

		"RenderColorTarget0=WindPositionRT;"
		"Pass=UpdateWindPosition;"

		"RenderColorTarget0=CoordWorkTex;"
		"RenderColorTarget1=VelocityTexCopy;"
		"Pass=CopyPos;"

		"RenderColorTarget0=" COORD_TEX_NAME_STRING ";"
		"RenderColorTarget1=VelocityTex;"
		"Pass=UpdatePos;"
		"RenderColorTarget1=;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=DrawObject;"
			"LoopEnd=;";
>{
	pass UpdateWindVelocity < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 CommonWind_VS();
		PixelShader  = compile ps_3_0 UpdateWindVelocity_PS();
	}

	pass UpdateWindPosition < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 CommonWind_VS();
		PixelShader  = compile ps_3_0 UpdateWindPosition_PS();
	}

	pass CopyPos < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 CopyPos_PS();
	}

	pass UpdatePos < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 UpdatePos_PS();
	}

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
		"RenderColorTarget0=WindVelocityRT;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=UpdateWindVelocity;"

		"RenderColorTarget0=WindPositionRT;"
		"Pass=UpdateWindPosition;"

		"RenderColorTarget0=CoordWorkTex;"
		"RenderColorTarget1=VelocityTexCopy;"
		"Pass=CopyPos;"

		"RenderColorTarget0=" COORD_TEX_NAME_STRING ";"
		"RenderColorTarget1=VelocityTex;"
		"Pass=UpdatePos;"
		"RenderColorTarget1=;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=DrawObject;"
			"LoopEnd=;";
>{
	pass UpdateWindVelocity < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 CommonWind_VS();
		PixelShader  = compile ps_3_0 UpdateWindVelocity_PS();
	}

	pass UpdateWindPosition < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 CommonWind_VS();
		PixelShader  = compile ps_3_0 UpdateWindPosition_PS();
	}

	pass CopyPos < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 CopyPos_PS();
	}

	pass UpdatePos < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 UpdatePos_PS();
	}

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

