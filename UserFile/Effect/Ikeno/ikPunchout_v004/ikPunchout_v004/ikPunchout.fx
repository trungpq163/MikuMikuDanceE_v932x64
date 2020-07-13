////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////

// マスクの回転速度。0で停止。1でデフォルト。
#define ROTATION_SPEED	1.0

// マスクの数 (MAX_X * MAX_Y < 256にする)
#define MAX_X	16
#define MAX_Y	9

// 編集中はエフェクトを止めるかどうか。0:止めない。1:止める。
#define	TimeSync	0

#define RANDOM_SEED		1234

////////////////////////////////////////////////////////////////////////////////////////////////

// 強制的に表示するためのアンカー数
#define MAX_ANCHOR_COUNT	8

#define DEF_ANCHOR(_varname, _objname)	\
	float3 _varname##Pos : CONTROLOBJECT < string name = _objname; >; \
	float _varname##Scale  : CONTROLOBJECT < string name = _objname; string item = "Si"; >

DEF_ANCHOR( Anchor01, "MaskAnchor01.x");
DEF_ANCHOR( Anchor02, "MaskAnchor02.x");
DEF_ANCHOR( Anchor03, "MaskAnchor03.x");
DEF_ANCHOR( Anchor04, "MaskAnchor04.x");
DEF_ANCHOR( Anchor05, "MaskAnchor05.x");
DEF_ANCHOR( Anchor06, "MaskAnchor06.x");
DEF_ANCHOR( Anchor07, "MaskAnchor07.x");
DEF_ANCHOR( Anchor08, "MaskAnchor08.x");

static float4 AnchorArray[] = {
	float4( Anchor01Pos, Anchor01Scale),
	float4( Anchor02Pos, Anchor02Scale),
	float4( Anchor03Pos, Anchor03Scale),
	float4( Anchor04Pos, Anchor04Scale),
	float4( Anchor05Pos, Anchor05Scale),
	float4( Anchor06Pos, Anchor06Scale),
	float4( Anchor07Pos, Anchor07Scale),
	float4( Anchor08Pos, Anchor08Scale),
};


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define STRGEN(x)	#x
#define	COORD_TEX_NAME_STRING		STRGEN(COORD_TEX_NAME)

float3 AcsPos : CONTROLOBJECT < string name = "(self)"; >;
float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

static float3 MaskColor = saturate(AcsPos/256.0);

float4x4 matVP : VIEWPROJECTION;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

static float2 ToDFSpace = (ViewportAspect >= 1.0) ? float2(1, ViewportSize.x / ViewportSize.y) : float2(ViewportSize.y / ViewportSize.x, 1);
static float2 ToInvDFSpace = 1.0 / ToDFSpace;

static float RadiusScale = max(ViewportSize.x / MAX_X, ViewportSize.y / MAX_Y) / ViewportSize.x;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time2 : time1;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "postprocess";
> = 0.8;

texture MaskMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for punchout";
	float4 ClearColor = { 0.0, 0, 0, 1 };
	float2 ViewportRatio = {0.5, 0.5};
	float ClearDepth = 1.0;
	string Format = "R16F";
	bool AntiAlias = false;
	int MipLevels = 1;
	string DefaultEffect = 
		"self = hide;"
		"* = object.fx";
>;

sampler MaskSamp = sampler_state {
	texture = <MaskMapRT>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
sampler MaskSampClamp = sampler_state {
	texture = <MaskMapRT>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

texture2D PunchedMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = {1,1};
	string Format="R16F";
>;
sampler2D PunchedSamp = sampler_state {
	texture = <PunchedMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};


texture2D DistanceFieldMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	int Width=256;
	int Height=256;
	string Format="G16R16F";
>;
sampler2D DistanceFieldSamp = sampler_state {
	texture = <DistanceFieldMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
sampler2D DistanceFieldSampClamp = sampler_state {
	texture = <DistanceFieldMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
texture2D DistanceFieldMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	int Width=256;
	int Height=256;
	string Format="G16R16F";
>;
sampler2D DistanceFieldSamp1 = sampler_state {
	texture = <DistanceFieldMap1>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};

texture2D DistanceFieldDepth : RENDERDEPTHSTENCILTARGET <
	int Width=256;
	int Height=256;
	string Format = "D24S8";
>;


inline float AspectDistance(float2 uv0, float2 uv1)
{
	// float2 d = (uv0 - uv1) * ToInvDFSpace; return dot(d, d);
	return distance(uv0 * ToInvDFSpace, uv1 * ToInvDFSpace);
}


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};

struct VS_OUTPUT2
{
	float4 Pos		: POSITION;	// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 Color	: COLOR0;		// 粒子の乗算色
};


///////////////////////////////////////////////////////////////////////////////////////
// 
VS_OUTPUT DistanceField_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + 0.5 / 256.0;
	return Out;
}

float4 ResizeDistanceField_PS( VS_OUTPUT IN ) : COLOR0
{
	float2 tex = IN.Tex;
	float2 s = float2(0, 0.5 / 256.0);

	float v0 = tex2D( MaskSamp, tex + s.xx ).x;
	float v1 = tex2D( MaskSamp, tex + s.xy ).x;
	float v2 = tex2D( MaskSamp, tex + s.yx ).x;
	float v3 = tex2D( MaskSamp, tex + s.yy ).x;

	float w = v0 + v1 + v2 + v3;
	float2 uv = (w >= 0.25) ? tex : float2(64, 64);

	return float4(uv, 0, 1);
}


float4 JumpingFlood_PS( VS_OUTPUT IN, uniform float l, uniform sampler2D smp) : COLOR0
{
	float s = l / 256.0;
	float2 tex = IN.Tex;

	float2 tmp;
	float3 n;

	tmp = tex2D( smp, tex).xy;
	float3 uv = float3(tmp.xy, AspectDistance(tmp, tex));

	#define	CMP_DIST(offset)	\
		tmp = tex2D( smp, tex + offset).xy;	\
		n = float3(tmp, AspectDistance(tmp, tex)); \
		n += (tmp.x + tmp.y < 0.5/256.0 ? 1000 : 0); \
		uv = (uv.z < n.z) ? uv : n;

	CMP_DIST( float2(-s,-s));
	CMP_DIST( float2(-s, 0));
	CMP_DIST( float2(-s, s));
	CMP_DIST( float2( 0,-s));
	CMP_DIST( float2( 0, s));
	CMP_DIST( float2( s,-s));
	CMP_DIST( float2( s, 0));
	CMP_DIST( float2( s, s));
		// 24タップにしてパス数を半分にする?

	return float4(uv.xy, 0, 1);
}



///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

inline float3 GetCenterPosition(int index)
{
	float4 h = float4(1275.231, 4461.7, 7182.423, 727.1) * index;
	float4 hash = frac(sin(h + RANDOM_SEED)*43758.543123);

	int y = floor(index * 1.0 / MAX_X);
	int x = index - y * MAX_X;
	float2 offset = hash.xy;
	float2 scale = 1.0 / float2(MAX_X, MAX_Y) * 2.0;

	float2 uv = (float2(x,y) + offset + 0.25) * scale - 1.0;

	// 半径
	float r = 0.5 + hash.w;
	// 回転速度
	float rotSpeed = (hash.z * 2.0 - 1.0);
	rotSpeed += (rotSpeed < 0.0) ? -0.5 : 0.5;
	rotSpeed *= time * ROTATION_SPEED;

	uv += float2(cos(rotSpeed), sin(rotSpeed)) * (2.0 - r) * RadiusScale;

	return float3(uv, r);
}

inline float GetMaskDistance(float2 uv)
{
	uv = uv * 0.5 + 0.5;

	float2 tex = uv.xy;
	float l = AspectDistance(tex2Dlod( DistanceFieldSampClamp, float4(tex,0,0)).xy, tex);
	l *= (tex2Dlod( MaskSampClamp, float4(tex,0,0)).x < 0.9);
	l *= ToDFSpace.x;
	l = max(l - 1.0 / 256.0, 0); // 誤差を考慮してマージンを追加

	return l * 2.0; // プロジェクションスペースは0～1でなく、-1～1なので2倍する。
}


VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT2 Out = (VS_OUTPUT2)0;

	int j = round( Pos.z * 100.0f );
	Pos.z = 0.0f;
	Pos.xy *= 10.0;	// * 事前に10倍しておく?

	float3 uv = GetCenterPosition(j);

	// サイズを決定
	float s = RadiusScale * 1.5 * (AcsSi * 0.1) * uv.z;
	s = min(s, GetMaskDistance(uv.xy));

	Pos.xy = Pos.xy * s * float2(1, ViewportAspect) + uv.xy;
	Pos.y *= -1;
	Pos.w = (j < MAX_X * MAX_Y) * (s * ViewportSize.x > 3.0);

	Out.Pos = Pos;
	Out.Tex = Tex;

	return Out;
}



VS_OUTPUT2 Anchor_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT2 Out = (VS_OUTPUT2)0;

	int j = round( Pos.z * 100.0f );
	int i = min(j, MAX_ANCHOR_COUNT - 1);

//	float4 AnchorInfo = AnchorArray[i]; // 32bit版だと i = 0以外うけつけない?
	float4 AnchorInfo = (i == 0) ? AnchorArray[0] : AnchorArray[1];
	if (i == 2) AnchorInfo = AnchorArray[2];
	if (i == 3) AnchorInfo = AnchorArray[3];
	if (i == 4) AnchorInfo = AnchorArray[4];
	if (i == 5) AnchorInfo = AnchorArray[5];
	if (i == 6) AnchorInfo = AnchorArray[6];
	if (i == 7) AnchorInfo = AnchorArray[7];

	Pos.z = 0.0f;
	Pos.xy *= 10.0;

	float4 ppos = mul(float4(AnchorInfo.xyz, 1), matVP);
	float3 uv = float3(ppos.xy / ppos.w, 4.0);
	uv.y *= -1;

	float s = RadiusScale * 1.5 * (AcsSi * 0.1) * uv.z * (AnchorInfo.w * 0.1);
	s = min(s, GetMaskDistance(uv.xy));

	Pos.xy = Pos.xy * s * float2(1, ViewportAspect) + uv;
	Pos.y *= -1;
	Pos.w = (j < MAX_ANCHOR_COUNT) * (s * ViewportSize.x > 3.0) * (AnchorInfo.w > 0.1) * (ppos.z > 0.0);

	Out.Pos = Pos;
	Out.Tex = Tex;

	return Out;
}

float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
	float r = length(IN.Tex * 2.0 - 1.0);

	// アンチエイリアス
	float margin = 50;
	float alpha = 1 - saturate(r * margin - margin);

	return float4(1,0,0, alpha);
}


///////////////////////////////////////////////////////////////////////////////////////
// 
VS_OUTPUT DrawBuffer_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

float4 DrawBuffer_PS( VS_OUTPUT IN ) : COLOR0
{
#if 0 // TEST
	if (tex2D( MaskSampClamp, IN.Tex).x > 0.9) return float4(0,0,1,1);
	float2 tex = IN.Tex;
	float l = AspectDistance(tex2D( DistanceFieldSampClamp, tex).xy, tex);
	l *= ToDFSpace.x;
	if (l < 16.0 / ViewportSize.x) return float4(0,1,1,1);
#endif

	float maskRate = 1.0 - tex2D( PunchedSamp, IN.Tex).r;
	maskRate = lerp(0, maskRate, AcsTr);
	return float4(MaskColor, maskRate);
}


///////////////////////////////////////////////////////////////////////////////////////
// 

technique MainTec1 <
	string Script = 

		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderDepthStencilTarget=DistanceFieldDepth;"
		"Clear=Depth;"
		"RenderColorTarget0=DistanceFieldMap;	Pass=ResizeDistanceField;"

		"RenderColorTarget0=DistanceFieldMap1;	Pass=JumpingFlood1;"
		"RenderColorTarget0=DistanceFieldMap;	Pass=JumpingFlood2;"
		"RenderColorTarget0=DistanceFieldMap1;	Pass=JumpingFlood3;"
		"RenderColorTarget0=DistanceFieldMap;	Pass=JumpingFlood4;"
		"RenderColorTarget0=DistanceFieldMap1;	Pass=JumpingFlood5;"
		"RenderColorTarget0=DistanceFieldMap;	Pass=JumpingFlood6;"
		"RenderColorTarget0=DistanceFieldMap1;	Pass=JumpingFlood7;"
		"RenderColorTarget0=DistanceFieldMap;	Pass=JumpingFlood8;"

		"RenderColorTarget0=PunchedMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawObject;"
		"Pass=DrawAnchor;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=DrawBuffer;"
;
>{
	// DistanceField用にバッファサイズを正方形にする
	pass ResizeDistanceField < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 ResizeDistanceField_PS();
	}
	// JumpingFloodでDistanceFieldの計算を行う
	pass JumpingFlood1 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(128, DistanceFieldSamp);
	}
	pass JumpingFlood2 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(64, DistanceFieldSamp1);
	}
	pass JumpingFlood3 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(32, DistanceFieldSamp);
	}
	pass JumpingFlood4 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(16, DistanceFieldSamp1);
	}
	pass JumpingFlood5 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(8, DistanceFieldSamp);
	}
	pass JumpingFlood6 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(4, DistanceFieldSamp1);
	}
	pass JumpingFlood7 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(2, DistanceFieldSamp);
	}
	pass JumpingFlood8 < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DistanceField_VS();
		PixelShader  = compile ps_3_0 JumpingFlood_PS(1, DistanceFieldSamp1);
	}

	// マスクを描画する
	pass DrawObject < string Script= "Draw=Geometry;"; > {
		ZENABLE = FALSE;	ZWRITEENABLE = FALSE;
		CULLMODE = NONE;
		ALPHABLENDENABLE = TRUE;
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader  = compile ps_3_0 Particle_PS();
	}

	pass DrawAnchor < string Script= "Draw=Geometry;"; > {
		ZENABLE = FALSE;	ZWRITEENABLE = FALSE;
		CULLMODE = NONE;
		ALPHABLENDENABLE = TRUE;
		VertexShader = compile vs_3_0 Anchor_VS();
		PixelShader  = compile ps_3_0 Particle_PS();
	}

	// マスクに従って塗りつぶす
	pass DrawBuffer < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 DrawBuffer_VS();
		PixelShader  = compile ps_3_0 DrawBuffer_PS();
	}
}
