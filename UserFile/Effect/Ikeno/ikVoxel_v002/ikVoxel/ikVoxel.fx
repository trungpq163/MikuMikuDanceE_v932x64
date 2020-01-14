////////////////////////////////////////////////////////////////////////////////////////////////
//
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// ブロックのサイズ。0.1～1.0程度。
float VoxelGridSize = 0.5;

// テクスチャの解像度を下げる。8～32程度。
// 8でテクスチャを8分割する。小さいほど粗くなる。
float VoxelTextureGridSize = 16;

// 無視する透明度の閾値
float VoxelAlphaThreshold = 0.05;

// ブロックを描画するとき半透明を考慮する?
// 0:不透明で描画、1:半透明度を利用する。
#define VOXEL_ENBALE_ALPHA_BLOCK	1

// ブロックのフチを丸めるか? 0.0～0.1程度 大きいほどエッジ部分が強調される
// ※ 0にしても計算誤差でエッジが見える場合があります。
float VoxelBevelOffset = 0.05;

// チェック回数。4～16程度。多いほど遠くまで検索するが、重くなる。
#define VOXEL_ITERATION_NUMBER	6

// 外部からブロックサイズをコントロールするアクセサリ名
#define VOXEL_CONTROLLER_NAME	"ikiVoxelSize.x"

// ブロック表面にテクスチャを追加する場合のテクスチャ名。
// コメントアウト(行頭に"//"をつける)すると無効になる。
#define VOXEL_TEXTURE	"grid.png"

// 付き抜けチェックをする? 0:しない、1:チェックする。
// 1にすることで床が抜けるのを回避できる。代わりに見た目がおかしくなる。
#define VOXEL_ENABLE_FALLOFF		0


////////////////////////////////////////////////////////////////////////////////////////////////

// 座法変換行列
float4x4 matWVP			: WORLDVIEWPROJECTION;
float4x4 matWV			: WORLDVIEW;
float4x4 matVP			: VIEWPROJECTION;
float4x4 matW			: WORLD;
float4x4 matV			: VIEW;
float4x4 matP			: PROJECTION;

float4x4 matLightVP		: VIEWPROJECTION < string Object = "Light"; >;
float3   LightDirection	: DIRECTION < string Object = "Light"; >;

float3   CameraPosition	: POSITION  < string Object = "Camera"; >;
float3   CameraDirection : DIRECTION  < string Object = "Camera"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float	SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float3	MaterialToon		: TOONCOLOR;
float4	GroundShadowColor	: GROUNDSHADOWCOLOR;

// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;

// 材質モーフ対応
float4	TextureAddValue   : ADDINGTEXTURE;
float4	TextureMulValue   : MULTIPLYINGTEXTURE;
float4	SphereAddValue    : ADDINGSPHERETEXTURE;
float4	SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

static float4 DiffuseColor  = MaterialDiffuse * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient * LightAmbient + MaterialEmissive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

float2 ViewportSize : VIEWPORTPIXELSIZE;

bool	use_texture;
bool	use_spheremap;
bool	use_toon;
bool	parthf;		// パースペクティブフラグ
bool	spadd;		// スフィアマップ加算合成フラグ
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

#define VOXEL_ENABLE_OUPUT_COLOR
#include "vox_commons.fxsub"



////////////////////////////////////////////////////////////////////////////////////////////////
//

// ディフューズの計算
inline float CalcDiffuse(float3 L, float3 N)
{
	return saturate(dot(N,L));
}

// スペキュラの計算
inline float CalcSpecular(float3 L, float3 N, float3 V)
{
	float3 H = normalize(L + V);
	return pow( max(0,dot( H, N )), SpecularPower );
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

technique EdgeTec < string MMDPass = "edge"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	// matW →補正→ matVPだとおかしくなるので適当に処理
	// アクセサリは10倍されているので、VoxelGridSizeも1/10する必要があるが特になにもしていない
	Pos.xyz = AlignPosition(Pos.xyz);
	return mul( Pos, matWVP );
}

float4 Shadow_PS() : COLOR
{
	return GroundShadowColor;
}

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

VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	Pos = mul( Pos, matW );
	Pos.xyz = AlignPosition(Pos.xyz);
	Out.Pos = mul( Pos, matLightVP );
	Out.ShadowMapTex = Out.Pos;
	return Out;
}

float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0, float2 Tex : TEXCOORD1 ) : COLOR
{
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

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

struct BufferShadow_OUTPUT
{
	float4 Pos		: POSITION;	 // 射影変換座標
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal   : TEXCOORD2;	// 法線
	float4 Distance	: TEXCOORD3;
	float4 WPos		: TEXCOORD4;	// Z値
};

///////////////////////////////////////////////////////////////////////////////////////////////
// ブロック単位で色を塗るための情報を出力する
BufferShadow_OUTPUT DrawInfo_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	Out.Pos = mul( Pos, matWVP );
	Out.Distance = mul( Pos, matWV );
	Out.Tex = Tex;
	return Out;
}

float4 DrawInfo_PS(BufferShadow_OUTPUT IN) : COLOR
{
	float4 Color = float4(1,1,1, DiffuseColor.a);
	if ( use_texture ) {
		// テクスチャ適用
		float4 TexColor = tex2D( ObjTexSampler, AlignTexture(IN.Tex) );
		if (use_toon)
		{	// 材質モーフ対応
			float4 MorphColor = TexColor * TextureMulValue + TextureAddValue;
			float MorphRate = TextureMulValue.a + TextureAddValue.a;
			TexColor.rgb = lerp(1, MorphColor.rgb, MorphRate);
		}

		Color *= TexColor;
	}

	clip(Color.w - VoxelAlphaThreshold);
	Color.a = IN.Distance.z;

	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// ブロックにヒットするか調べながら描画する

BufferShadow_OUTPUT DrawObject_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,
	uniform bool bExpand)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	Out.WPos = mul( Pos, matW );
	Out.Normal = normalize( mul( Normal, (float3x3)matW ) );

	if (bExpand)
	{
		// 法線方向に拡大
		float3 vNormal = normalize(Out.Normal - dot(Out.Normal, CameraDirection));
		Out.WPos.xyz += vNormal * VoxelScaledGridSize;
	}

	Out.Pos = mul( Out.WPos, matVP );

	Out.Distance.x = mul(Out.WPos, matV).z;
	Out.Distance.yz = mul(float4(0,VoxelScaledGridSize,Out.Distance.x,1), matP).yw;
	Out.Distance.y *= ViewportSize.y * 0.5 / 2.0;

	Out.Tex = Tex;

	return Out;
}


// ピクセルシェーダ
float4 DrawObject_PS(BufferShadow_OUTPUT IN, uniform bool useSelfShadow) : COLOR
{
	#if defined(VOXEL_ENBALE_ALPHA_BLOCK) && VOXEL_ENBALE_ALPHA_BLOCK > 0
	// 透明なら破棄
	float alpha = DiffuseColor.a;
	if ( use_texture ) alpha *= tex2D( ObjTexSampler, AlignTexture(IN.Tex)).a;
	clip(alpha - VoxelAlphaThreshold);
	#endif

	float3 V = AdjustVector(normalize(CameraPosition - IN.WPos.xyz));
	float3 N = IN.Normal;

	//-----------------------------------------------------------
	// どのブロックにヒットするか探す
	float3 hitblock = 0;
	float4 albedo = Raytrace(IN.WPos, -V, hitblock);

	clip(albedo.w - 1e-3); // ヒットしなかった

	float3 hitpos = CalcPositionAndNormal(hitblock, N, V, IN.Distance.z / IN.Distance.y);

	#if defined(VOXEL_TEXTURE)
	float2 griduv = CalcUV(N, hitpos * (1.0 / VoxelScaledGridSize));
	float3 gridPattern = tex2D( VoxelPatternSmp, griduv).rgb;
	albedo.rgb *= gridPattern;
	#endif

/*
return float4(frac((hitpos+10)*0.5),1);
return float4(frac((hitblock+10)*0.5),1);
*/

	// 正しい深度を出力すると、計算誤差から余計にzファイトが生じる
	// float4 hitPPos = mul(float4(hitpos,1), matVP);
	// float depth = hitPPos.z / hitPPos.w;

	//-----------------------------------------------------------
	// 光源計算
	float3 L = -LightDirection;
	float diffuse = CalcDiffuse(L, N);
	if (use_toon) diffuse = saturate(diffuse * Toon);
	float3 specular = CalcSpecular(L, N, V) * SpecularColor;

	float4 Color = float4(AmbientColor.rgb, 1);
	if ( !use_toon ) Color.rgb += DiffuseColor.rgb;
	float3 ShadowColor = saturate(AmbientColor);
	Color.rgb = Color.rgb * albedo.rgb + specular;
	ShadowColor = ShadowColor * albedo.rgb + specular;

	// シャドウマップ
	float comp = 1;
	if (useSelfShadow)
	{
		// テクスチャ座標に変換
		float4 ZCalcTex = mul( float4(hitpos,1), matLightVP );
		ZCalcTex /= ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - ZCalcTex.y)*0.5f;
		if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
			// シャドウバッファ外
			;
		} else {
			float a = (parthf) ? SKII2*TransTexCoord.y : SKII1;
			float d = ZCalcTex.z;
			comp = 1 - saturate(max(d - tex2D(DefSampler,TransTexCoord).r , 0.0f)*a-0.3f);
		}
	}

	comp = min(diffuse, comp);

	if ( use_spheremap ) {
		// スフィアマップ適用
		// Nそのままだと同一方向の面全てが同じ色になるので適当に補正
		float2 NormalWV = normalize(mul( reflect(N,V), (float3x3)matV)).xy;
		float2 SpTex = NormalWV * float2(0.5,-0.5) + 0.5;

		float3 TexColor = tex2D(ObjSphareSampler,SpTex).rgb;
		if (useSelfShadow && use_toon)
		{	// 材質モーフ対応
			float3 MorphColor = TexColor * SphereMulValue.rgb + SphereAddValue.rgb;
			float MorphRate = saturate(SphereMulValue.a + SphereAddValue.a);
			TexColor.rgb = lerp(spadd?0:1, MorphColor, MorphRate);
		}

		if(spadd) {
			Color.rgb += TexColor;
			ShadowColor.rgb += TexColor;
		} else {
			Color.rgb *= TexColor;
			ShadowColor.rgb *= TexColor;
		}
	}

	if ( use_toon ) ShadowColor.rgb *= MaterialToon;
	Color.rgb = lerp(ShadowColor, Color.rgb, comp);

	#if defined(VOXEL_ENBALE_ALPHA_BLOCK) && VOXEL_ENBALE_ALPHA_BLOCK > 0
	Color.a = alpha;
	#else
	Color.a = 1;
	#endif

	return Color;
}

#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; bool UseSelfShadow = selfshadow;\
	string Script = \
		"RenderColorTarget0=VoxelInfoTex; RenderDepthStencilTarget=VoxelDepthBuffer;" \
		"ClearSetColor=VoxelClearColor; ClearSetDepth=VoxelClearDepth; Clear=Color; Clear=Depth;" \
		"Pass=DrawInfo;" \
		"RenderColorTarget0=; RenderDepthStencilTarget=;" \
		"Pass=DrawFalloff; Pass=DrawObject;" \
; \
	> { \
		pass DrawInfo { \
			AlphaBlendEnable = false; AlphaTestEnable = false; \
			VertexShader = compile vs_3_0 DrawInfo_VS(); \
			PixelShader  = compile ps_3_0 DrawInfo_PS(); \
		} \
		pass DrawFalloff { /* 拡大すると穴が開くことがあるので念のために */ \
			VertexShader = compile vs_3_0 DrawObject_VS(false); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
		pass DrawObject { \
			CullMode = none; \
			VertexShader = compile vs_3_0 DrawObject_VS(true); \
			PixelShader  = compile ps_3_0 DrawObject_PS(selfshadow); \
		} \
	}

OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTecBS0, "object_ss", true)

////////////////////////////////////////////////////////////////////////////////////////////////
