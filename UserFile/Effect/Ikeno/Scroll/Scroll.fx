////////////////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 陰影計算を有効にする
// #define ENABLE_DIFFUSE

// ハイライトを有効にする
// #define ENABLE_SPECULAR
float	SpecularPower = 32;
float	SpecularScale = 0.5;

// 加算モード：動画を加算合成する。
// 背面処理が有効な場合、背面の上に加算されるので注意。
// 加算で明るくなり過ぎるときは逆に、背面に暗い色(0,0,0,0.5)などを指定すると、白飛びが軽減される。
//#define ENABLE_ADDITION_MODE

// 動画の下に置く画像を指定
// この画像の透明部分には動画が適用されません。
//#define BASE_TEXTURE_NAME		"grad.png"

// パターンタイプのベース画像。通常のBASEと併用可能、
// #define BASEPATTERN_TEXTURE_NAME	"Pattern/dot.png"
// パターンの繰り返しサイズ。値が大きいほど小さく表示されます。
const float2 BASEPATTERN_LOOP_SIZE = float2(50, 50);


// 動画に上乗せする画像を指定：画像のαに応じて動画を隠します。
// フレームなどの追加用。
// #define COVER_TEXTURE_NAME		"back.jpg"

// 背面処理：優先度は、テクスチャ > 色 > 両面表示 > 透明(どれも指定しない場合)
// 背面に指定テクスチャを貼る
#define BACKFACE_TEXTURE_NAME		"back.jpg"
// 背面を指定の色で塗る
#define BACKFACE_COLOR		float4(0,0,0.5,0.75)
// 裏にも動画を表示する
#define ENABLE_DOUBLE_FACE


// コントローラの名称
#define CONTROLLER_NAME		"ScrollController.pmx"

// 奥行き情報の書き込みをしない
// 加算モードで優先順位の競合が起こったときに改善される可能性がある。
//#define DISABLE_ZWRITE

// 動画のサイズ：
// 4分割時に隣接する動画が含まれないようにするために設定。
// 端が気にならないなら設定しなくてよい。
float2 MovieSize = float2(854,480);
// 動画の端を無視するピクセル数
float MoveMargin = 2;

////////////////////////////////////////////////////////////////////////////////////////////////


// 座法変換行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 WorldMatrix			: WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection	: DIRECTION < string Object = "Light"; >;
float3   CameraPosition	: POSITION  < string Object = "Camera"; >;

// ライト色
float3   LightDiffuse		: DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient		: AMBIENT   < string Object = "Light"; >;
float3   LightSpecular	 : SPECULAR  < string Object = "Light"; >;
static float3 SpecularColor = LightSpecular;
static float4 DiffuseColor  = float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(LightAmbient);

bool	 parthf;   // パースペクティブフラグ
bool	 transp;   // 半透明フラグ
bool	 spadd;	// スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	 3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


#if defined(BACKFACE_TEXTURE_NAME)
texture2D BackfaceTex <
	string ResourceName = BACKFACE_TEXTURE_NAME;
>;
sampler BackfaceSamp = sampler_state{
	texture = <BackfaceTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

#if defined(BASE_TEXTURE_NAME)
texture2D BaseTex <
	string ResourceName = BASE_TEXTURE_NAME;
>;
sampler BaseSamp = sampler_state{
	texture = <BaseTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

#if defined(BASEPATTERN_TEXTURE_NAME)
texture2D BasePatternTex <
	string ResourceName = BASEPATTERN_TEXTURE_NAME;
>;
sampler BasePatternSamp = sampler_state{
	texture = <BasePatternTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = WRAP;
	AddressV = WRAP;
};
#endif

#if defined(COVER_TEXTURE_NAME)
texture2D CoverTex <
	string ResourceName = COVER_TEXTURE_NAME;
>;
sampler CoverSamp = sampler_state{
	texture = <CoverTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif




////////////////////////////////////////////////////////////////////////////////////////////////
//

#define	PI	(3.14159265359)

float CalcDiffuse(float3 L, float3 N, float3 V)
{
	return saturate(dot(N,L));
}

float CalcSpecular(float3 L, float3 N, float3 V, float smoothness)
{
	float3 H = normalize(L + V);	// ハーフベクトル
	float3 Specular = max(0,dot( H, N ));
	float3 result = pow(Specular, smoothness);
	return result; // *= (2.0 + smoothness) / (2.0 * PI);
}



////////////////////////////////////////////////////////////////////////////////////////////////
bool isExistController : CONTROLOBJECT < string name = CONTROLLER_NAME; >;

float mAllScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "全体拡大"; >;
float mAllScaleDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "全体縮小"; >;
float mHScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "横拡大"; >;
float mHScaleDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "横縮小"; >;
float mVScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "縦拡大"; >;
float mVScaleDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "縦縮小"; >;
float mLScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "左拡大"; >;
float mRScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "右拡大"; >;
float mTScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "上拡大"; >;
float mBScaleUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "下拡大"; >;

float mHRollUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "横回転+"; >;
float mHRollDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "横回転-"; >;
float mVRollUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "縦回転+"; >;
float mVRollDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "縦回転-"; >;

float mXOffsetUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Xオフセット+"; >;
float mXOffsetDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Xオフセット-"; >;
float mYOffsetUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Yオフセット+"; >;
float mYOffsetDown : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Yオフセット-"; >;

float mMovieRange : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "動画範囲"; >;
float mPatternFade : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "パターンフェード"; >;

//---

float AllScaleValue(float u, float d)
{
	float t = u - d;
	return (t >= 0.0) ? lerp(1, 4.0, t) : lerp(1.0, 0.1, -t);
}
float ScaleValue(float u, float d)
{
	float t = u - d;
	return (t >= 0.0) ? lerp(1, 2.0, t) : lerp(1.0, 0.1, -t);
}

float SetHScale()
{
	if (isExistController)
	{
		return AllScaleValue(mAllScaleUp, mAllScaleDown) * ScaleValue(mHScaleUp, mHScaleDown);
	} else {
		return 1;
	}
}

float SetVScale()
{
	if (isExistController)
	{
		return AllScaleValue(mAllScaleUp, mAllScaleDown) * ScaleValue(mVScaleUp, mVScaleDown);
	} else {
		return 1;
	}
}


float2 GetTexCoord(float2 inTexCoord)
{
	float2 result = inTexCoord;

	if (isExistController)
	{
		int mode = (int)floor(mMovieRange * 5.0 + 0.5/5.0);
		if (mode == 0) result = inTexCoord;
		else
		{
			float2 halfSize = (MovieSize - MoveMargin * 2.0) / MovieSize * 0.5;
			float2 offset = (MoveMargin + 0.5) / MovieSize * 0.5;
			result = inTexCoord * halfSize;
			if (mode == 1) ; // 左上
			else if (mode == 2) result += float2(0.5, 0); // 右上
			else if (mode == 3) result += float2(0, 0.5); // 左下
			else result += float2(0.5, 0.5); // 右下
			result += offset;
		}
	}

	return result;
}

//---

static float kWx = SetHScale(); // 横方向の拡大率 (暫定拡大率は0.1～2.0)
static float kWz = SetVScale(); // 縦方向の拡大率
static float kSvx = (mTScaleUp - mBScaleUp) * 0.999;
static float kSvz = (mRScaleUp - mLScaleUp) * 0.999;
static float kRotX = mVRollUp - mVRollDown;
static float kRotZ = mHRollUp - mHRollDown;
	// ひねりも欲しい?

// 原点
static float kOffsetX = mXOffsetUp - mXOffsetDown;
static float kOffsetZ = mYOffsetUp - mYOffsetDown;


////////////////////////////////////////////////////////////////////////////////////////////////
//
void CalcRawPosMat(float4 Pos0, out float4 oPos, out float4x4 oMat)
{
	float e = 0.001;

	float sx = (1 + Pos0.z * sign(kSvx) * abs(kSvx)) * kWx;
	float sy = 0;
	float sz = (1 + Pos0.x * sign(kSvz) * abs(kSvz)) * kWz;
	float3 pos = Pos0.xyz * float3(sx,sy,sz);

	// 適当なゆがみ計算。行列で綺麗に書けそうな気もするが…。
	float angX = Pos0.x * PI * abs(kRotX) * 0.5;
	float angZ = Pos0.z * PI * abs(kRotZ) * 0.5;

	float rx = sx / PI;
	float s = sx * (2.0 / PI) * sin(angX);
	float lx = lerp(pos.x, s, abs(kRotX));
	pos.x = lx * cos(angX);
	pos.y = lx * sin(angX) * sign(kRotX) - rx;

	float rz = sz / PI;
	float t = sz * (2.0 / PI) * sin(angZ);
	float lz = lerp(pos.z, t, abs(kRotZ));
	pos.z = lz * cos(angZ);
	pos.y += lz * sin(angZ) * sign(kRotZ) - rz;

	angX = Pos0.x * PI * kRotX;
	angZ = Pos0.z * PI * kRotZ;

	// 適当な傾きの計算
	float rateX = abs(kRotX) / (abs(kRotX) + abs(kRotZ) + e);
	float rateZ = abs(kRotZ) / (abs(kRotX) + abs(kRotZ) + e);
	float nx = sin(angX) * rateX;
	float nz = sin(angZ) * rateZ;
	float ny = sign(cos(angX) * rateX + cos(angZ) * rateZ + e);
	ny *= sqrt(1 - (nx*nx + nz*nz));

	float bnx = cos(angX);
	float bny =-sin(angX);
	float bnz = 0;

	float3 normal = normalize(float3(nx,ny,nz));
	float3 binormal = normalize(float3(bnx,bny,bnz));
	float3 tangent = normalize(cross(binormal,normal));
	binormal = normalize(cross(normal,tangent));

	oPos = float4(pos.xyz, Pos0.w);

	oMat[0] = float4(binormal,0);
	oMat[1] = float4(normal,0);
	oMat[2] = float4(tangent,0);
	oMat[3] = float4(0,0,0,1);
	oMat[3].xyz = -mul(float4(pos.xyz, 1), oMat).xyz;
}

float4x4 CalcMat()
{
	float4 offsetPos;
	float4x4 offsetMat;
	CalcRawPosMat(float4(kOffsetX,0,-kOffsetZ,1), offsetPos, offsetMat);
	return offsetMat;
}

static float4x4 WorldMat = CalcMat();

void CalcPosNormal(float4 Pos0, out float4 oPos, out float3 oNormal)
{
	float4x4 mat;
	CalcRawPosMat(Pos0, oPos, mat);

	oPos = mul(oPos, WorldMat);
	oNormal = mul(mat._12_22_32, (float3x3)(WorldMat));
}

float4 CalcPos(float4 Pos0)
{
	float4x4 mat;
	float4 oPos;
	CalcRawPosMat(Pos0, oPos, mat);
	oPos = mul(oPos, WorldMat);
	return oPos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
/*
// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
	// カメラ視点のワールドビュー射影変換
	Pos = CalcPos(Pos);
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
	// 輪郭色で塗りつぶし
	return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;

		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}
*/
technique EdgeTec < string MMDPass = "edge"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	// カメラ視点のワールドビュー射影変換
	Pos = CalcPos(Pos);
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
	// アンビエント色で塗りつぶし
	return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_2_0 Shadow_VS();
		PixelShader  = compile ps_2_0 Shadow_PS();
	}
}



///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD0;	// Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	// ライトの目線によるワールドビュー射影変換をする
	Pos = CalcPos(Pos);
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );

	// テクスチャ座標を頂点に合わせる
	Out.ShadowMapTex = Out.Pos;

	return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0, float2 Tex : TEXCOORD1 ) : COLOR
{
	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 ZValuePlot_VS();
		PixelShader  = compile ps_2_0 ZValuePlot_PS();
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;	 // 射影変換座標
	float4 ZCalcTex : TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal   : TEXCOORD2;	// 法線
	float3 WPos		: TEXCOORD3;
};

// 頂点シェーダ
BufferShadow_OUTPUT DrawObject_VS(float4 Pos : POSITION, // , float3 Normal : NORMAL, 
	float2 Tex : TEXCOORD0,
	uniform bool useTexture, uniform bool useSphereMap, 
	uniform bool useToon, uniform bool useSelfShadow)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	float3 Normal;
	CalcPosNormal(Pos, Pos, Normal);

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.WPos = mul( Pos, WorldMatrix );
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfShadow)
	{
		// ライト視点によるワールドビュー射影変換
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	// テクスチャ座標
	Out.Tex = Tex;

	return Out;
}


// 裏側
#if defined(BACKFACE_TEXTURE_NAME) || defined(BACKFACE_COLOR)
float4 DrawBack_PS(BufferShadow_OUTPUT IN,
	uniform bool useTexture, uniform bool useSphereMap, 
	uniform bool useToon, uniform bool useSelfShadow) : COLOR
{
	float4 Color = float4(1,1,1, DiffuseColor.a);
	float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色

	#if defined(ENABLE_SPECULAR) || defined(ENABLE_DIFFUSE)
	float3 L = -LightDirection;
	float3 V = normalize(CameraPosition - IN.WPos);
	float3 N = normalize(IN.Normal);
	#endif

	#ifdef ENABLE_SPECULAR
	float specular = CalcSpecular(L, N, V, SpecularPower) * SpecularScale;
	#else
	float specular = 0;
	#endif

	#ifdef ENABLE_DIFFUSE
	float diffuse = CalcDiffuse(L, N, V);
	Color.rgb = AmbientColor + DiffuseColor.rgb;
	#else
	float diffuse = 1;
	#endif

	#if defined(BACKFACE_TEXTURE_NAME)
	float4 BackColor = tex2D(BackfaceSamp, IN.Tex);
	#else
	float4 BackColor = BACKFACE_COLOR;
	#endif
	Color *= BackColor;
	ShadowColor *= BackColor;

	float comp = 1;

	#ifdef ENABLE_DIFFUSE
	if (useSelfShadow)
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
			float z = tex2D(DefSampler,TransTexCoord).r;
			comp = 1 - saturate(max(d - z, 0.0f)*a-0.3f);
		}

		specular *= comp;
	}

	comp = saturate(min(comp, diffuse));
	#endif

	#ifdef ENABLE_SPECULAR
	Color.rgb += specular * (SpecularColor);
	#endif

	Color.rgb = lerp(ShadowColor.rgb, Color.rgb, comp);

	#if defined(ENABLE_ADDITION_MODE)
	Color.rgb *= Color.a;
	#endif

	return Color;
}
#endif

// ピクセルシェーダ
float4 DrawObject_PS(BufferShadow_OUTPUT IN,
	uniform bool useTexture, uniform bool useSphereMap, 
	uniform bool useToon, uniform bool useSelfShadow) : COLOR
{
	float4 Color = float4(1,1,1, DiffuseColor.a);

	#if defined(ENABLE_SPECULAR) || defined(ENABLE_DIFFUSE)
	float3 L = -LightDirection;
	float3 V = normalize(CameraPosition - IN.WPos);
	float3 N = normalize(IN.Normal);
	#endif

	#ifdef ENABLE_SPECULAR
	float specular = CalcSpecular(L, N, V, SpecularPower) * SpecularScale;
	#else
	float specular = 0;
	#endif

	#ifdef ENABLE_DIFFUSE
	float diffuse = CalcDiffuse(L, N, V);
	Color.rgb = AmbientColor + DiffuseColor.rgb;
	#else
	float diffuse = 1;
	#endif

	float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色

	#if defined(BASE_TEXTURE_NAME)
	float4 BaseColor = tex2D(BaseSamp, IN.Tex);
	Color *= BaseColor;
	ShadowColor *= BaseColor;
	#endif
	#if defined(BASEPATTERN_TEXTURE_NAME)
	float4 BasePatternColor = tex2D(BasePatternSamp, IN.Tex * BASEPATTERN_LOOP_SIZE);
	BasePatternColor.rgb = lerp(BasePatternColor.rgb, 1, mPatternFade); // αは維持
	Color *= BasePatternColor;
	ShadowColor *= BasePatternColor;
	#endif

	// 動画
	float4 TexColor = tex2D( ObjTexSampler, GetTexCoord(IN.Tex));
	Color *= TexColor;
	ShadowColor *= TexColor;

	#if defined(COVER_TEXTURE_NAME)
	float4 CoverColor = tex2D(CoverSamp, IN.Tex);
	Color.rgb = lerp(Color, CoverColor, CoverColor.a).rgb;
	ShadowColor.rgb = lerp(ShadowColor, CoverColor, CoverColor.a).rgb;
	#endif

	float comp = 1;

	#ifdef ENABLE_DIFFUSE
	if (useSelfShadow)
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
			float z = tex2D(DefSampler,TransTexCoord).r;
			comp = 1 - saturate(max(d - z, 0.0f)*a-0.3f);
		}

		specular *= comp;
	}

	comp = saturate(min(comp, diffuse));
	#endif

	#ifdef ENABLE_SPECULAR
	// スペキュラ適用
	Color.rgb += specular * (SpecularColor);
	#endif

	Color.rgb = lerp(ShadowColor.rgb, Color.rgb, comp);

	#if defined(ENABLE_ADDITION_MODE)
	Color.rgb *= Color.a;
	#endif

	return Color;
}


// 合成モード
#if defined(ENABLE_ADDITION_MODE)
#define ARPHA_MODE	\
        SRCBLEND=ONE;\
        DESTBLEND=ONE;
#else
#define ARPHA_MODE	
#endif

// 背面処理
#if defined(BACKFACE_TEXTURE_NAME) || defined(BACKFACE_COLOR)
#define BACKFACE_PASS(tex, sphere, toon, selfshadow)	\
		pass DrawBack { \
			cullmode = none; \
			VertexShader = compile vs_3_0 DrawObject_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 DrawBack_PS(tex, sphere, toon, selfshadow); \
		}
#define CULLING_MODE
#else
#define BACKFACE_PASS(tex, sphere, toon, selfshadow)
#if defined(ENABLE_DOUBLE_FACE)
#define CULLING_MODE		CullMode = none;
#else
#define CULLING_MODE
#endif
#endif

#if defined(DISABLE_ZWRITE)
#define ZWRITE_MODE				ZWriteEnable = false;
#else
#define ZWRITE_MODE
#endif

#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
	> { \
		BACKFACE_PASS(tex, sphere, toon, selfshadow) \
		pass DrawObject { \
			CULLING_MODE \
			ARPHA_MODE \
			ZWRITE_MODE \
			VertexShader = compile vs_3_0 DrawObject_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 DrawObject_PS(tex, sphere, toon, selfshadow); \
		} \
	}

OBJECT_TEC(MainTec0, "object", true, false, false, false)
OBJECT_TEC(MainTecBS7, "object_ss", true, false, false, true)



///////////////////////////////////////////////////////////////////////////////////////////////

