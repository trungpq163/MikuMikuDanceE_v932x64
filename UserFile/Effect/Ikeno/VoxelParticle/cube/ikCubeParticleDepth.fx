////////////////////////////////////////////////////////////////////////////////////////////////
//
// ikボケ用
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 設定ファイル
#include "ikCubeParticleSettings.fxsub"

const float AlphaThroughThreshold = 0.5;

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// なにもない描画しない場合の背景までの距離
#define FAR_DEPTH		1000

#define TEX_WIDTH     UNIT_COUNT  // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT    1024        // 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int RepeatCount = UNIT_COUNT;  // シェーダ内描画反復回数
int RepeatIndex;               // 複製モデルカウンタ

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

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;


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
sampler CoordSmp : register(s3) = sampler_state
{
   Texture = <COORD_TEX_NAME>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};


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
                     cosx*siny,               -sinx,       cosx*cosy,               };

   return rMat;
}


// 法線から参照するuv値を求める。
float2 CalcUV(float3 N, float3 Pos)
{
	float2 Tex;

#if TEX_PARTICLE_XNUM == 6
	// 6面
	if (abs(N.x) > max(abs(N.y), abs(N.z)))
	{
		Tex = (N.x >= 0) ? float2(Pos.z + 4, Pos.y) : float2(-Pos.z + 0, Pos.y);
	}
	else if (abs(N.y) > abs(N.z))
	{
		Tex = (N.y >= 0) ? float2( Pos.x + 8, Pos.z) : float2(-Pos.x + 10, Pos.z);
	}
	else
	{
		Tex = (N.z >= 0) ? float2(-Pos.x + 2, Pos.y) : float2( Pos.x + 6, Pos.y);
	}

	Tex = Tex.xy * float2(0.5/6.0, 0.5) + float2(0.5/6.0, 0.5);
#else
	// 1面のみ
	if (abs(N.x) > max(abs(N.y), abs(N.z)))
	{
		Tex = (N.x >= 0) ? float2(Pos.z, Pos.y) : float2(-Pos.z + 0, Pos.y);
	}
	else if (abs(N.y) > abs(N.z))
	{
		Tex = (N.y >= 0) ? float2( Pos.x, Pos.z) : float2(-Pos.x, Pos.z);
	}
	else
	{
		Tex = (N.z >= 0) ? float2(-Pos.x, Pos.y) : float2( Pos.x, Pos.y);
	}

	Tex = frac(Tex.xy * float2(0.5, 0.5) + float2(0.5, 0.5));
#endif

	return Tex;
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos       : POSITION;    // 射影変換座標
	float4 NormalX	: TEXCOORD1;
	float4 NormalY	: TEXCOORD2;
	float4 NormalZ	: TEXCOORD3;
	float4 WPos		: TEXCOORD4;
	float4 PPos		: TEXCOORD5;
	float4 Info		: TEXCOORD6;
	float4 Color	: COLOR0;		// 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out=(VS_OUTPUT2)0;

	int i = RepeatIndex;
	int j = round( Pos.z * 100.0f );
	int Index0 = i * TEX_HEIGHT + j;
	float2 texCoord = float2((i+0.5f)/TEX_WIDTH, (j+0.5f)/TEX_HEIGHT);
	Pos.z = 0.0f;
	Out.Info.x = float(j);

	// 粒子の座標
	float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 0));

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
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
	float4 Color = IN.Color;

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
	// ヒットしない
	// if (tFar < tNear) return float4(1,0,1,1);
	clip((tFar > tNear) - 0.1);

	// 法線を調べる
	float3 hitpos = localCameraPosition + localViewDirection * tNear;
/*
	float3 N = normalize(abs(hitpos));
	N = normalize(step(max(N.x, max(N.y, N.z)).xxx - 0.05, N) * sign(localViewDirection));
	float2 Tex = CalcUV(N, hitpos * (2.0 / ParticleSize));
	N = mul(N, matRot);

	Color *= tex2D(ParticleTexSamp, Tex);
	clip(Color.a - AlphaThroughThreshold);
*/
	float3 wpos = mul(hitpos, matRot) + IN.WPos.xyz;
	float dist = length(mul(float4(wpos,1), matV).xyz);
	return float4(dist / FAR_DEPTH, 0, 0, 1);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepeatCount;"
            "LoopGetIndex=RepeatIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;";
>{
    pass DrawObject {
        ZENABLE = TRUE; ZWRITEENABLE = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}

technique MainTec2 < string MMDPass = "object_ss";
   string Script = 
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "LoopByCount=RepeatCount;"
            "LoopGetIndex=RepeatIndex;"
                "Pass=DrawObject;"
            "LoopEnd=;";
>{
    pass DrawObject {
        ZENABLE = TRUE; ZWRITEENABLE = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}

