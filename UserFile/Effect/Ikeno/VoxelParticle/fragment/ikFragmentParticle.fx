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
#include "ikFragmentSettings.fxsub"

////////////////////////////////////////////////////////////////////////////////////////////////

// 最大何個までボーンを登録するか
#define MaxWindNum		8

// テクスチャの幅
// MaxWindNum <= WIND_TEX_WIDTH である必要がある。
#define WIND_TEX_WIDTH	8

float3 WindPosition01 : CONTROLOBJECT < string name = "ikWindMaker01.x"; >;
float3 WindPosition02 : CONTROLOBJECT < string name = "ikWindMaker02.x"; >;
float3 WindPosition03 : CONTROLOBJECT < string name = "ikWindMaker03.x"; >;
float3 WindPosition04 : CONTROLOBJECT < string name = "ikWindMaker04.x"; >;
float3 WindPosition05 : CONTROLOBJECT < string name = "ikWindMaker05.x"; >;
float3 WindPosition06 : CONTROLOBJECT < string name = "ikWindMaker06.x"; >;
float3 WindPosition07 : CONTROLOBJECT < string name = "ikWindMaker07.x"; >;
float3 WindPosition08 : CONTROLOBJECT < string name = "ikWindMaker08.x"; >;

float WindScale01 : CONTROLOBJECT < string name = "ikWindMaker01.x"; >;
float WindScale02 : CONTROLOBJECT < string name = "ikWindMaker02.x"; >;
float WindScale03 : CONTROLOBJECT < string name = "ikWindMaker03.x"; >;
float WindScale04 : CONTROLOBJECT < string name = "ikWindMaker04.x"; >;
float WindScale05 : CONTROLOBJECT < string name = "ikWindMaker05.x"; >;
float WindScale06 : CONTROLOBJECT < string name = "ikWindMaker06.x"; >;
float WindScale07 : CONTROLOBJECT < string name = "ikWindMaker07.x"; >;
float WindScale08 : CONTROLOBJECT < string name = "ikWindMaker08.x"; >;

//inline float3 GetWindPos(float3 pos, float4x4 mat) { return mul(float4(pos,1), mat).xyz; }
#define GetWindPos(pos, mat) pos
inline float GetWindScale(float Si) { return 0.23 * 10.0 / max(Si, 0.001);}
	// exp(-1 * 0.23 * 10.0) = 0.1

static float4 WindPositionArray[] = {
	float4( GetWindPos(WindPosition01, WindMatrix01), GetWindScale( WindScale01)),
	float4( GetWindPos(WindPosition02, WindMatrix02), GetWindScale( WindScale02)),
	float4( GetWindPos(WindPosition03, WindMatrix03), GetWindScale( WindScale03)),
	float4( GetWindPos(WindPosition04, WindMatrix04), GetWindScale( WindScale04)),
	float4( GetWindPos(WindPosition05, WindMatrix05), GetWindScale( WindScale05)),
	float4( GetWindPos(WindPosition06, WindMatrix06), GetWindScale( WindScale06)),
	float4( GetWindPos(WindPosition07, WindMatrix07), GetWindScale( WindScale07)),
	float4( GetWindPos(WindPosition08, WindMatrix08), GetWindScale( WindScale08)),
};



////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ITERATION_NUM	8		// チェック用ループ回数
#define ALPHA_THRESHOLD	0.8
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
float3	LightPosition0	: POSITION < string Object = "Light"; >;
static float3 LightPosition = CameraPosition + LightPosition0 * 50.0;

float4x4 matVInvLight : VIEWINVERSE < string Object = "Light"; >;
float4x4 matVPLight : VIEWPROJECTION < string Object = "Light"; >;
float4x4 matVPInvLight : VIEWPROJECTIONINVERSE < string Object = "Light"; >;

#if MMD_LIGHTCOLOR == 1
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float3 LightColor = LightSpecular * 2.5 / 1.5;
#endif

bool	 parthf;   // パースペクティブフラグ
#define SKII1	1500
#define SKII2	8000

// 1フレーム当たりの粒子発生数
static float P_Count = ParticleOccur * (Dt / ParticleLife) * AcsSi*100;

static float ParticleSizeMax = max(ParticleSize.x, max(ParticleSize.y, ParticleSize.z)) * 10;


// 座標変換行列
float4x4 matW		: WORLD;
float4x4 matV		: VIEW;
float4x4 matVP		: VIEWPROJECTION;
float4x4 matVPInv	: VIEWPROJECTIONINVERSE;

float4x4 matVInv	: VIEWINVERSE;
static float3x3 BillboardMatrix = {
	normalize(matVInv[0].xyz),
	normalize(matVInv[1].xyz),
	normalize(matVInv[2].xyz),
};

static float3x3 LightBillboardMatrix = {
	normalize(matVInvLight[0].xyz),
	normalize(matVInvLight[1].xyz),
	normalize(matVInvLight[2].xyz),
};



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
	string ResourceName = "rand128.png";
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

#if (USE_PALLET > 0)
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
		"ik*.x = hide;"		// 自分以外の同類も排除
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
#define WIND_TEX_HEIGHT	1
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
		float2 coord = float2((i + 0.5f) / WIND_TEX_WIDTH, 0.5f/WIND_TEX_HEIGHT);
		float4 wpos = WindPositionArray[i];
		float3 wvel = tex2D(WindVelocityMap, coord).xyz;
		float len = max(length(pos - wpos.xyz), 0.001);
		result += exp(-len * wpos.w) * wvel;
	}

	return result * 100.0;
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
	float4 NormalX	: TEXCOORD1;
	float4 NormalY	: TEXCOORD2;
	float4 NormalZ	: TEXCOORD3;
	float4 WPos		: TEXCOORD4;
	float4 PPos		: TEXCOORD5;
	float4 Info		: TEXCOORD6;
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
	Out.Info.x = float(j);

	// テクスチャパターン
	int texIndex = Out.Info.x % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
	Out.Info.yz = float2( texIndex % TEX_PARTICLE_XNUM, texIndex / TEX_PARTICLE_XNUM)
		* float2(1.0 / TEX_PARTICLE_XNUM, 1.0 / TEX_PARTICLE_YNUM);

	// 粒子の座標
	float4 Pos0 = tex2Dlod(CoordWorkSmp, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;
	// 回転と平行移動成分
	float3x3 matWTmp = RoundMatrix(Index0, etime);
	Out.NormalX.xyz = matWTmp[0];
	Out.NormalY.xyz = matWTmp[1];
	Out.NormalZ.xyz = matWTmp[2];
	Out.WPos = Pos0;

	// 粒子の大きさ
	Pos.xy *= ParticleSizeMax;
	Pos.xyz = mul(Pos.xyz, BillboardMatrix);
	// 粒子のワールド座標
	Pos.xyz += Pos0.xyz;
	Pos.xyz *= step(0.001f, etime);
	Pos.w = 1.0f;

	Out.Pos = mul( Pos, matVP );
	Out.PPos = Out.Pos;

	// 粒子の乗算色
	float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
	// 床付近で消さない
	#if !defined(ENABLE_BOUNCE) || ENABLE_BOUNCE == 0
	alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
	#endif
	Out.Color = float4(1,1,1, alpha );

	return Out;
}


// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN, uniform bool useShadow ) : COLOR0
{
	float4 Color = IN.Color;
	clip(Color.a - AlphaThroughThreshold);

	// ワールド座標での視線
	float3 v = normalize(mul(IN.PPos, matVPInv).xyz - CameraPosition);

	float3x3 matRot = float3x3( IN.NormalX.xyz, IN.NormalY.xyz, IN.NormalZ.xyz);
	float3x3 matRotInv = transpose((float3x3)matRot);
	float4x4 matLocalInv = float4x4(
		matRotInv[0], 0,
		matRotInv[1], 0,
		matRotInv[2], 0,
		mul(-IN.WPos.xyz, matRotInv), 1);

	float3 localCameraPosition = mul(float4(CameraPosition,1), matLocalInv).xyz;
	float3 localViewDirection = mul(v, (float3x3)matLocalInv).xyz;

	// ヒットポイントを探す
	float3 tNear0 = ((ParticleSize * 0.5) - localCameraPosition) * (1.0/localViewDirection);
	float3 tFar0  = ((ParticleSize *-0.5) - localCameraPosition) * (1.0/localViewDirection);
	float3 tNear1 = min(tNear0, tFar0);
	float3 tFar1  = max(tNear0, tFar0);
	float tNear = max(tNear1.x, max(tNear1.y, tNear1.z));
	float tFar  = min(tFar1.x , min(tFar1.y , tFar1.z ));
	// キューブにヒットしない?
	clip((tFar > tNear) - 0.1);

	// キューブ内でテクスチャのある場所にヒットするか?
	float2 texOffsetSclae = float2(1.0 / TEX_PARTICLE_XNUM, 1.0 / TEX_PARTICLE_YNUM);
	float2 texOffset = IN.Info.yz;
	float3 hitposB = localCameraPosition + localViewDirection * tNear;
	float3 hitposE = localCameraPosition + localViewDirection * tFar;
	float2 TexB = saturate(hitposB.xy * (2.0 / ParticleSize.xy * 0.5) + 0.5);
	float2 TexE = saturate(hitposE.xy * (2.0 / ParticleSize.xy * 0.5) + 0.5);
	TexB = TexB * texOffsetSclae + texOffset;
	TexE = TexE * texOffsetSclae + texOffset;
	float2 vTex = (TexE - TexB) * (1.0 / ITERATION_NUM);
	float4 color = 0;
	int hitcount = -1;
	for(int i = 0; i < ITERATION_NUM; i++)
	{
		color = tex2D(ParticleTexSamp, i * vTex + TexB);
		if (color.a > ALPHA_THRESHOLD)
		{
			hitcount = i;
			break;
		}
	}
	// ヒットしなかった?
	clip(hitcount);

	color.a = 1;
	Color *= color;

	// ランダム色設定
	#if (USE_PALLET > 0)
	float4 randColor = tex2D(ColorPalletSmp, float2((IN.Info.x + 0.5f) / PALLET_TEX_SIZE, 0.5));
	Color.rgb *= randColor.rgb;
	#endif

	// 法線を調べる(適当)
	#if ENABLE_LIGHT > 0 || USE_SPHERE > 0
	float w0 = tex2D(ParticleTexSamp, TexB + hitcount * vTex + vTex.yx).a;
	float w1 = tex2D(ParticleTexSamp, TexB + hitcount * vTex - vTex.yx).a;
	float3 N = (hitcount == 0)
		? float3(0,0, localViewDirection.z >= 0.0 ? 1 : -1)
		: float3(-vTex + vTex.yx * (w1 - w0), 0);
	N = normalize(mul(N, matRot));
	#endif

	// 陰影計算
	float shadow = 1;
	#if ENABLE_LIGHT == 1
	float3 H = normalize( v + -LightDirection );
	float3 Specular = pow( max(0,dot( H, N )), SpecularPower ) * LightColor * SpecularColor;
	float light = max(dot(N, LightDirection), 0);
	if (useShadow)
	{
		float3 hitpos = hitposB + (hitposE - hitposB) * hitcount / ITERATION_NUM;
		float3 wpos = mul(hitpos, matRot) + IN.WPos.xyz;
		float4 ZCalcTex = mul(float4(wpos, 1), matVPLight);
		ZCalcTex /= ZCalcTex.w;
		float2 TransTexCoord = ZCalcTex.xy * float2(0.5, -0.5) + 0.5;
		if( all( saturate(TransTexCoord) == TransTexCoord ) ) {
			float a = (parthf) ? SKII2 * TransTexCoord.y : SKII1;
			float d = ZCalcTex.z;
			shadow = 1 - saturate(max(d - tex2D(DefSampler,TransTexCoord).r, 0.0) * a - 0.3);
			light = min(light, shadow);
			Specular *= shadow;
		}
	}

	Color.rgb *= max(light * LightColor * (1.0 - EmissivePower) + EmissivePower, 0);
	Color.rgb += Specular;
	#endif

	#if( USE_SPHERE==1 )
		float2 NormalWV = normalize(mul(reflect(N,v), (float3x3)matV)).xy;
		float2 SpTex = NormalWV.xy * float2(0.5,-0.5) + 0.5;
		Color.rgb += max(tex2D(ParticleSphereSamp, SpTex).rgb, 0) * (shadow * 0.5 + 0.5);
		#if( SPHERE_SATURATE==1 )
			Color = saturate( Color );
		#endif
	#endif

	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
//

VS_OUTPUT2 ZValuePlot_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepeatIndex;
	int j = round( Pos.z * 100.0f );
	int Index0 = i * TEX_HEIGHT + j;
	float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	Pos.z = 0.0f;
	Out.Info.x = float(j);

	// テクスチャパターン
	int texIndex = Out.Info.x % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
	Out.Info.yz = float2( texIndex % TEX_PARTICLE_XNUM, texIndex / TEX_PARTICLE_XNUM)
		* float2(1.0 / TEX_PARTICLE_XNUM, 1.0 / TEX_PARTICLE_YNUM);

	// 粒子の座標
	float4 Pos0 = tex2Dlod(CoordWorkSmp, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;
	// 回転と平行移動成分
	float3x3 matWTmp = RoundMatrix(Index0, etime);
	Out.NormalX.xyz = matWTmp[0];
	Out.NormalY.xyz = matWTmp[1];
	Out.NormalZ.xyz = matWTmp[2];
	Out.WPos = Pos0;

	// 粒子の大きさ
	Pos.xy *= ParticleSizeMax;
	Pos.xyz = mul(Pos.xyz, LightBillboardMatrix);
	// 粒子のワールド座標
	Pos.xyz += Pos0.xyz;
	Pos.xyz *= step(0.001f, etime);
	Pos.w = 1.0f;

	Out.Pos = mul( Pos, matVPLight );
	Out.PPos = Out.Pos;

	// 粒子の乗算色
	float alpha = step(0.001f, etime) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime) * AcsTr;
	// 床付近で消さない
	#if !defined(ENABLE_BOUNCE) || ENABLE_BOUNCE == 0
	alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
	#endif
	Out.Color = float4(1,1,1, alpha );

	return Out;
}

float4 ZValuePlot_PS( VS_OUTPUT2 IN) : COLOR0
{
	float4 Color = IN.Color;
	clip(Color.a - AlphaThroughThreshold);

	// ワールド座標での視線
	float3 v = normalize(mul(IN.PPos, matVPInvLight).xyz - LightPosition);

	float3x3 matRot = float3x3( IN.NormalX.xyz, IN.NormalY.xyz, IN.NormalZ.xyz);
	float3x3 matRotInv = transpose((float3x3)matRot);
	float4x4 matLocalInv = float4x4(
		matRotInv[0], 0,
		matRotInv[1], 0,
		matRotInv[2], 0,
		mul(-IN.WPos.xyz, matRotInv), 1);

	float3 localCameraPosition = mul(float4(LightPosition,1), matLocalInv).xyz;
	float3 localViewDirection = mul(v, (float3x3)matLocalInv).xyz;

	// ヒットポイントを探す
	float3 tNear0 = ((ParticleSize * 0.5) - localCameraPosition) * (1.0/localViewDirection);
	float3 tFar0  = ((ParticleSize *-0.5) - localCameraPosition) * (1.0/localViewDirection);
	float3 tNear1 = min(tNear0, tFar0);
	float3 tFar1  = max(tNear0, tFar0);
	float tNear = max(tNear1.x, max(tNear1.y, tNear1.z));
	float tFar  = min(tFar1.x , min(tFar1.y , tFar1.z ));
	// キューブにヒットしない?
	clip((tFar > tNear) - 0.1);

	// キューブ内でテクスチャのある場所にヒットするか?
	float2 texOffsetSclae = float2(1.0 / TEX_PARTICLE_XNUM, 1.0 / TEX_PARTICLE_YNUM);
	float2 texOffset = IN.Info.yz;
	float3 hitposB = localCameraPosition + localViewDirection * tNear;
	float3 hitposE = localCameraPosition + localViewDirection * tFar;
	float2 TexB = saturate(hitposB.xy * (2.0 / ParticleSize.xy * 0.5) + 0.5);
	float2 TexE = saturate(hitposE.xy * (2.0 / ParticleSize.xy * 0.5) + 0.5);
	TexB = TexB * texOffsetSclae + texOffset;
	TexE = TexE * texOffsetSclae + texOffset;
	float2 vTex = (TexE - TexB) * (1.0 / ITERATION_NUM);
	float4 color = 0;
	int hitcount = -1;
	for(int i = 0; i < ITERATION_NUM; i++)
	{
		color = tex2D(ParticleTexSamp, i * vTex + TexB);
		if (color.a > ALPHA_THRESHOLD)
		{
			hitcount = i;
			break;
		}
	}
	// ヒットしなかった?
	clip(hitcount);

	float3 hitpos = hitposB + (hitposE - hitposB) * hitcount / ITERATION_NUM;
	float3 wpos = mul(hitpos, matRot) + IN.WPos.xyz;
	float4 ppos = mul(float4(wpos,1), matVPLight);
	// float4 ppos = mul(IN.WPos , matVPLight);

	// R色成分にZ値を記録する
	return float4(ppos.z/ppos.w,0,0,1);
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
	float4 pos = GetWindPosition(floor(Tex.x * WIND_TEX_WIDTH));

	float3 oldPos = tex2D(WindPositionMap, Tex).xyz;

	// 一定速度以下は無視する
	float3 v = (pos.xyz - oldPos) / Dt;
	float len = length(v);
	if (!IsTimeToReset() && len > MinWindSpeed)
	{
		v = v * (min(len - MinWindSpeed, MaxWindSpeed) / len);
	} else {
		v = 0;
	}

	return float4(v, 1);
}

// 現在の位置を保存
float4 UpdateWindPosition_PS(float2 Tex: TEXCOORD0) : COLOR
{
	float3 pos = GetWindPosition(floor(Tex.x * WIND_TEX_WIDTH)).xyz;
	return float4(pos, 1);
}



///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
	string Script = 
		"RenderColorTarget0=WindVelocityRT;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=UpdateWindVelocity;"

		"RenderColorTarget0=WindPositionRT;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=UpdateWindPosition;"

		"RenderColorTarget0=CoordWorkTex;"
		"RenderColorTarget1=VelocityTexCopy;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=CopyPos;"

		"RenderColorTarget0=" COORD_TEX_NAME_STRING ";"
		"RenderColorTarget1=VelocityTex;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
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
		ZENABLE = TRUE; ZWRITEENABLE = TRUE;
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
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=UpdateWindPosition;"

		"RenderColorTarget0=CoordWorkTex;"
		"RenderColorTarget1=VelocityTexCopy;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=CopyPos;"

		"RenderColorTarget0=" COORD_TEX_NAME_STRING ";"
		"RenderColorTarget1=VelocityTex;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
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
		ZENABLE = TRUE; ZWRITEENABLE = TRUE;
		AlphaBlendEnable = TRUE;
		CullMode = NONE;
		VertexShader = compile vs_3_0 Particle_VS(true);
		PixelShader  = compile ps_3_0 Particle_PS(true);
	}
}


technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}

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

