////////////////////////////////////////////////////////////////////////////////////////////////
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 設定ファイル
#include "ikParticleSettings.fxsub"


// 当たり判定に使用する法線マップを作成するか?
// 1つのシェーダーが作成すれば、あとのシェーダーはそれを流用できる。
#define DRAW_NORMAL_MAP		1

// 座標を共有する時の名前
// 複数のパーティクルエフェクトを使う場合、名前が重複しないようにする必要がある。
// 逆に、他のポストエフェクトがこのパーティクルを参照する場合は、同じ名前を指定する。
#define	COORD_TEX_NAME		LineParticleCoordTex


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define TEX_WIDTH		UNIT_COUNT		// 座標情報テクスチャピクセル幅
#define TEX_HEIGHT		PARTICLE_NUM	// 配置・乱数情報テクスチャピクセル高さ
#define POS_TEX_WIDTH	(TAIL_DIV * UNIT_COUNT)

#define STRGEN(x)	#x
#define	COORD_TEX_NAME_STRING		STRGEN(COORD_TEX_NAME)

#define PAI 3.14159265f

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

int RepeatCount = UNIT_COUNT;		// シェーダ内描画反復回数
int RepeatIndex;					// 複製モデルカウンタ

static float diffD = radians( clamp(90.0f - DiffusionAngle, -90.0f, 90.0f) );

// 時間設定
float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time1 : time2;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time1 : elapsed_time2, 0.0f, 0.1f);
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// 1フレーム当たりの粒子発生数
static float P_Count = ParticleOccur * (Dt / ParticleLife) * AcsSi * 100;

// 座標変換行列
float4x4 matW	: WORLD;
float4x4 matV	: VIEW;
float4x4 matVP : VIEWPROJECTION;
float4x4 matWInv	: WORLDINVERSE;

float4x4 ViewInverseMatrix	: VIEWINVERSE;
static float3x3 BillboardMatrix = {
	normalize(ViewInverseMatrix[0].xyz),
	normalize(ViewInverseMatrix[1].xyz),
	normalize(ViewInverseMatrix[2].xyz),
};

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
texture CoordTex : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler CoordSmp = sampler_state
{
	Texture = <CoordTex>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
};

// 粒子座標記録用
texture CoordTexCopy : RENDERCOLORTARGET
<
	int Width=TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler CoordSmpCopy = sampler_state
{
	Texture = <CoordTexCopy>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
};

texture CoordDepthBuffer : RenderDepthStencilTarget <
	int Width=POS_TEX_WIDTH;
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
	Filter = NONE;
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
	Filter = NONE;
};


texture PosTex : RENDERCOLORTARGET
<
	int Width=POS_TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler PosSmp = sampler_state
{
	Texture = <PosTex>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
};

shared texture COORD_TEX_NAME : RENDERCOLORTARGET
<
	int Width=POS_TEX_WIDTH;
	int Height=TEX_HEIGHT;
	string Format="A32B32G32R32F";
>;
sampler PosSmpCopy = sampler_state
{
	Texture = <COORD_TEX_NAME>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
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

#if defined(USE_PALLET) && USE_PALLET > 0
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
//

#define AntiAliasMode		false
#define MipMapLevel			1

// 法線マップ
#if DRAW_NORMAL_MAP > 0
shared texture LPNormalMapRT: OFFSCREENRENDERTARGET <
	string Description = "render Normal and depth for ikLineParticle";
	float2 ViewPortRatio = {1, 1};
	string Format = "D3DFMT_A32B32G32R32F";		// RGBに法線。Aには深度情報
	int Miplevels = MipMapLevel;
	bool AntiAlias = AntiAliasMode;
	float4 ClearColor = { 0.0, 0.0, 0.0, 0.0};
	float ClearDepth = 1.0;
	string DefaultEffect = 
		"self = hide;"
		"ikLineParticle*.x = hide;"		// 自分以外の同類も排除
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

////////////////////////////////////////////////////////////////////////////////////////////////

inline bool IsTimeToReset()
{
	return (time < 0.001f);
}

float3 GetRand(float index)
{
	float u = floor(index + time);
	float v = fmod(u, RND_TEX_SIZE);
	u = floor(u / RND_TEX_SIZE);
	return tex2D(RandomSmp, float2(u,v) / RND_TEX_SIZE).xyz * 2.0 - 1.0;
}


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
	float2 Tex2 : TEXCOORD1;
};

struct PS_OUT_MRT
{
	float4 Pos		: COLOR0;
	float4 Vel		: COLOR1;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
	Out.Tex2 = Tex;
	return Out;
}

///////////////////////////////////////////////////////////////////////////////////////

PS_OUT_MRT CopyPos_PS(float2 Tex: TEXCOORD0) : COLOR
{
	PS_OUT_MRT Out;
	Out.Pos = tex2D(CoordSmp, Tex);
	Out.Vel = tex2D(VelocitySmp, Tex);
	return Out;
}

float4 CopyPos_PS1(float2 Tex: TEXCOORD1) : COLOR
{
	float x = round(Tex.x * POS_TEX_WIDTH);
	float ix = floor(x / TAIL_DIV);
	float jx = x % TAIL_DIV;

	float4 ret = tex2D(CoordSmp, float2((ix + 0.5) / TEX_WIDTH, Tex.y + 0.5f/TEX_HEIGHT));
	if (!IsTimeToReset() && jx >= 1.0)
	{
		if (ret.w != 1.0011)
		{
			ret = tex2D(PosSmpCopy, Tex + float2(-0.5f/POS_TEX_WIDTH, 0.5f/TEX_HEIGHT));
		} else {
			ret.w = 0;
		}
	}

	return ret;
}

float4 CopyPos_PS2(float2 Tex: TEXCOORD1) : COLOR
{
	return tex2D(PosSmp, Tex + float2(0.5f/POS_TEX_WIDTH, 0.5f/TEX_HEIGHT));
}


///////////////////////////////////////////////////////////////////////////////////////
// 座標の更新
PS_OUT_MRT UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 Pos = tex2D(CoordSmpCopy, Tex);
	float4 Vel = tex2D(VelocitySmp, Tex);

	int i = floor( Tex.x*TEX_WIDTH );
	int j = floor( Tex.y*TEX_HEIGHT );
	int p_index = j + i * TEX_HEIGHT;

	if(Pos.w < 1.001f){
		if(p_index < Vel.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
		if(p_index < Vel.w + P_Count)
		{
			Pos = float4(matW._41_42_43, 1.0011);  // 発生初期座標

			// 発生したての粒子に初速度与える
			float3 rand = GetRand(p_index * 17 + RND_TEX_SIZE);
			float time1 = time + 100.0f;
			float ss, cs;
			sincos( lerp(diffD, PAI*0.5f, frac(rand.x*time1)), ss, cs );
			float st, ct;
			sincos( lerp(-PAI, PAI, frac(rand.y*time1)), st, ct );
			float3 vec = float3( cs*ct, ss, cs*st );
			Vel.xyz = normalize( mul( vec, (float3x3)matW ) )
					* lerp(ParticleSpeedMin, ParticleSpeedMax, frac(rand.z*time1));
		}
	}else{
		// 新しい座標に更新
		float3 v = Dt * (Vel.xyz) / BOUNCE_CHECK_DIV;

		// 簡単な交差判定
		for(int i = 0; i < BOUNCE_CHECK_DIV; i++)
		{
			Pos.xyz += v;
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
				v = Dt * (Vel.xyz) / BOUNCE_CHECK_DIV;
			}
		}

		// すでに発生している粒子は経過時間を進める
		Pos.w += Dt;
		Pos.w *= step(Pos.w - 1.0f, ParticleLife); // 指定時間を超えると0

		// 粒子の速度計算
		Vel.xyz -= Vel.xyz * (0.1 * Dt);
		Vel.xyz += GravFactor * Dt;
	}

	// 次発生粒子の起点
	Vel.w += P_Count;
	if (Vel.w >= float(TEX_WIDTH*TEX_HEIGHT)) Vel.w -= float(TEX_WIDTH*TEX_HEIGHT);

	if (IsTimeToReset())
	{
		Pos = float4(matW._41_42_43, 0.0f);
		Vel = 0.0;
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
	float4 Color	: COLOR0;		// 粒子の乗算色
};

VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, int index: _INDEX)
{
	VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepeatIndex;
	int j = index / (TAIL_DIV * 2);
	int k = index % (TAIL_DIV * 2);
	int l = k / 2;
	int Index0 = i * TEX_HEIGHT + j;
	Out.TexIndex = float(j);

	float2 texCoord = float2((i*TAIL_DIV+l+0.5f)/POS_TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	float4 Pos0 = tex2Dlod(PosSmpCopy, float4(texCoord, 0, 0));

	// 経過時間
	float etime = Pos0.w - 1.0f;

	Pos.x *= ParticleSize * 10.0f;
	Pos.yzw = float3(0, 0, 1);
	Pos.xyz = mul(Pos.xyz, BillboardMatrix) * step(0.001f, etime) + Pos0.xyz;
	Out.Pos = mul(Pos, matVP);

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

float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
	float4 Color = IN.Color;
	Color *= tex2D( ParticleTexSamp, IN.Tex );

	#if defined(USE_PALLET) && USE_PALLET > 0
	float4 randColor = tex2D(ColorPalletSmp, float2((IN.TexIndex+0.5f) / PALLET_TEX_SIZE, 0.5));
	Color *= randColor;
	#endif

	#if( TEX_ZBuffWrite==1 )
		clip(Color.a - 0.3);
	#endif

	return Color;
}



///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
	string Script = 
		"RenderColorTarget0=CoordTexCopy;"
		"RenderColorTarget1=VelocityTexCopy;"
		"RenderDepthStencilTarget=CoordDepthBuffer;"
		"Pass=CopyPos;"

		"RenderColorTarget0=CoordTex;"
		"RenderColorTarget1=VelocityTex;"
		"Pass=UpdatePos;"
		"RenderColorTarget1=;"

		"RenderColorTarget0=PosTex;"
		"Pass=CopyPos1;"
		"RenderColorTarget0=" COORD_TEX_NAME_STRING ";"
		"Pass=CopyPos2;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
			"LoopByCount=RepeatCount;"
			"LoopGetIndex=RepeatIndex;"
				"Pass=DrawObject;"
			"LoopEnd=;";
>{
	pass CopyPos < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 CopyPos_PS();
	}

	pass CopyPos1 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 CopyPos_PS1();
	}

	pass CopyPos2 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		ALPHATESTENABLE = FALSE;
		VertexShader = compile vs_3_0 Common_VS();
		PixelShader  = compile ps_3_0 CopyPos_PS2();
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
		SRCBLEND = SRCALPHA;
		#if defined(ADD_MODE) && ADD_MODE > 0
			DESTBLEND = ONE;
		#else
			DESTBLEND = INVSRCALPHA;
		#endif
		CullMode = NONE;
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader  = compile ps_3_0 Particle_PS();
	}
}

technique ZplotTec < string MMDPass = "zplot"; > {}
