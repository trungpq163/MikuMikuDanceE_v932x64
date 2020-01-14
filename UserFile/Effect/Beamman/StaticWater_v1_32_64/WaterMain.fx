//水面メイン部分　改変しないほうが身のため！


// ■ ExcellentShadowシステム　ここから↓

float X_SHADOWPOWER = 1.0;   //アクセサリ影濃さ
float PMD_SHADOWPOWER = 0.2; //モデル影濃さ


//スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

//SSAOマップ取得
shared texture2D ExShadowSSAOMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "R16F";
>;

sampler2D ExShadowSSAOMapSamp = sampler_state {
    texture = <ExShadowSSAOMapOut>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

// スクリーンサイズ
float2 ES_ViewportSize : VIEWPORTPIXELSIZE;
static float2 ES_ViewportOffset = (float2(0.5,0.5)/ES_ViewportSize);

bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
bool Exist_ExShadowSSAO : CONTROLOBJECT < string name = "ExShadowSSAO.x"; >;
float ShadowRate : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Tr"; >;
float3   ES_CameraPos1      : POSITION  < string Object = "Camera"; >;
float es_size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; >;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;

static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43 );
static float CameraDistance1 = length(ES_CameraPos1 - es_move1); //カメラとシャドウ中心の距離

// ■ ExcellentShadowシステム　ここまで↑

bool use_WLC : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx";>;
float m_fR : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "フォグ赤"; >;
float m_fG : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "フォグ緑"; >;
float m_fB : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "フォグ青"; >;
float m_lR : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "ライト赤"; >;
float m_lG : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "ライト緑"; >;
float m_lB : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "ライト青"; >;

float m_Fog : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "深度フォグ"; >;
float m_Mirror : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "鏡面強さ"; >;

float m_UpDown : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "上下幅"; >;
float m_Strength : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx"; string item = "水面荒さ"; >;
float3 WLC_Pos : CONTROLOBJECT < string name = "StaticWaterLightController_v5.pmx";string item = "位置調整用";>;

// パースペクティブフラグ
bool     parthf;
//時間
float time : TIME <bool SyncInEditMode=true;>;
// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 InvWorldMatrix              : INVWORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;

#define SKII1    1500
#define SKII2    8000

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5f, 0.5f)/ViewportSize);

#define BUF_AA true

#define MIRROR_SIZE 512

#define BUF_FORMAT "D3DFMT_A16B16G16R16F"

#define WAVE_TEXSIZE 1024

#define HITTEX_SIZE 1024


//波の種テクスチャ
texture HeightTex_Zero
<
   string ResourceName = "height.png";
>;
sampler HeightSampler_Zero = sampler_state
{
	Texture = <HeightTex_Zero>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
//波の計算用テクスチャ
texture ChoppyTex
<
   string ResourceName = "choppy.png";
>;
sampler ChoppySamp = sampler_state
{
	Texture = <ChoppyTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
//マスクテクスチャ
texture MaskTex
<
   string ResourceName = "\mask.png";
>;
sampler MaskSamp = sampler_state
{
	Texture = <MaskTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

//高さ情報を保存するテクスチャー
texture HeightTex1 : RenderColorTarget
<
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
   string Format="D3DFMT_R16F";
>;
sampler HeightSampler1 = sampler_state
{
	Texture = <HeightTex1>;
    Filter = POINT;
    AddressU = Wrap;
    AddressV = Wrap;
};
sampler HeightSampler1_Linear = sampler_state
{
	Texture = <HeightTex1>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
texture HeightTex2 : RenderColorTarget
<
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
   string Format="D3DFMT_R16F";
>;
sampler HeightSampler2 = sampler_state
{
	Texture = <HeightTex2>;
    Filter = POINT;
    AddressU = Wrap;
    AddressV = Wrap;
};
//速度情報を保存するテクスチャー
texture VelocityTex1 : RenderColorTarget
<
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
   string Format= BUF_FORMAT;
>;
sampler VelocitySampler1 = sampler_state
{
	Texture = <VelocityTex1>;
    Filter = POINT;
    AddressU = Wrap;
    AddressV = Wrap;
};
texture VelocityTex2 : RenderColorTarget
<
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
   string Format= BUF_FORMAT;
>;
sampler VelocitySampler2 = sampler_state
{
	Texture = <VelocityTex2>;
    Filter = POINT;
    AddressU = Wrap;
    AddressV = Wrap;
};
//法線情報を保存するテクスチャー
shared texture NormalTex : RenderColorTarget
<
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
   string Format= BUF_FORMAT;
>;
sampler NormalSampler = sampler_state
{
	Texture = <NormalTex>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

//波用深度バッファ
texture Wave_DepthBuffer : RenderDepthStencilTarget <
   int Width=WAVE_TEXSIZE;
   int Height=WAVE_TEXSIZE;
    string Format = "D24S8";
>;

//当たり判定用RT
texture HitRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    int Width = HITTEX_SIZE;
    int Height = HITTEX_SIZE;
    string Format = "D3DFMT_R16F" ;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "WaterLightController.pmd = hide;"
        "*=../sub/HitObject.fx;";
>;
sampler HitView = sampler_state {
    texture = <HitRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV = WRAP;
};

//水面下、画像用RT
texture2D UnderObjectsRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = BUF_FORMAT;
    bool AntiAlias = BUF_AA;
    
    string DefaultEffect = 
        "self = hide;"
        "*=../sub/UnderObject.fx;";
>;
sampler UnderView = sampler_state {
    texture = <UnderObjectsRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//水面下、深度用RT
texture2D UnderDepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    
    string Format = "D3DFMT_R16F" ;
    float4 ClearColor = { 65535, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = BUF_AA;
    
    string DefaultEffect = 
        "self = hide;"
        "*=../sub/Depth.fx;";
>;
sampler UnderDepthView = sampler_state {
    texture = <UnderDepthRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面下、法線用RT
texture2D UnderNormalRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = BUF_AA;
    
    string DefaultEffect = 
        "self = hide;"
        "*=../sub/Normal.fx;";
>;
sampler UnderNormalView = sampler_state {
    texture = <UnderNormalRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面下、座標用RT
texture2D UnderPosRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = BUF_FORMAT;
    bool AntiAlias = BUF_AA;
    
    string DefaultEffect = 
        "self = hide;"
        "*=../sub/Pos.fx;";
>;
sampler UnderPosView = sampler_state {
    texture = <UnderPosRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//鏡面用RT
texture2D MirrorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Water5.fx";
    int Width = MIRROR_SIZE;
    int Height = MIRROR_SIZE;
    string Format = BUF_FORMAT;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = BUF_AA;
    string DefaultEffect = 
        "self = hide;"
        "*=../sub/MirrorObject.fx;";
>;
sampler MirrorView = sampler_state {
    texture = <MirrorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面深度保存用(最終座標）
texture2D WaterDepth : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F" ;
>;
sampler2D WaterDepthSamp = sampler_state {
    texture = <WaterDepth>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D ScnDepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


//垂直ガウス読み込み
#include "..\sub\V_Gaussian.fx"
//水面ぼかし読み込み
#include "..\sub\Height_Gaussian.fx"

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
	float4 Pos      : POSITION;     // 射影変換座標
	float4 ZCalcTex : TEXCOORD0;    // Z値
	float2 Tex      : TEXCOORD1;    // テクスチャ
	float3 WPos     : TEXCOORD2;    // ワールド座標
	float4 LastPos  : TEXCOORD3;
	float4 DefPos	: TEXCOORD4;
    float4 ScreenTex : TEXCOORD5;   // スクリーン座標
	float4 Color    : COLOR0;       // ディフューズ色
};
// 逆行列計算。
float4x4 InverseMatrix(float4x4 mat) {
    float scaling = length(mat._11_12_13);
    float scaling_inv = 1.0 / (scaling * scaling);

    float3x3 mat3x3_inv = transpose((float3x3)mat) * scaling_inv;
    return float4x4( mat3x3_inv[0], 0, 
                     mat3x3_inv[1], 0, 
                     mat3x3_inv[2], 0, 
                     -mul(mat._41_42_43, mat3x3_inv), 1 );
}

// 頂点シェーダ
BufferShadow_OUTPUT Main_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	if(use_WLC)
	{
		WaveHeight *= (1-m_UpDown);
	}
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
   	Out.DefPos = Pos;
	float2 temp = Tex + UVScroll * time;
	float Height = tex2Dlod(HeightSampler1,float4(temp * WaveSplitLevel,0,0)).r;
	Height += tex2Dlod(HeightSampler1,float4(temp * WaveSplitLevel * 0.5,0,0)).r;
	Height /= 2;
	Height *= 0.25;
	
	float WatH = Height * (WaveHeight/2);
	//WatH -= WaveHeight*0.1;
	Pos.y += WatH;
	
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.WPos = mul(Pos,WorldMatrix).xyz;
    
    Out.Pos = mul(Pos,WorldMatrix);
    //Out.Pos = mul(Out.Pos,InverseMatrix(WorldMatrix));
    Out.Pos = mul(Out.Pos,ViewProjMatrix);
    
    Out.LastPos = Out.Pos;
	Out.Tex = Tex + 0.5/WAVE_TEXSIZE;
	
    //スクリーン座標取得
    Out.ScreenTex = Out.Pos;
    
    //超遠景におけるちらつき防止
    //Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));
	
    return Out;
}
// ピクセルシェーダ
float4 Main_PS(BufferShadow_OUTPUT IN,uniform bool shadow) : COLOR
{

	if(use_WLC)
	{
		LightAmbient.rgb = float3(m_lR,m_lG,m_lB)*2;
		WaterColor.rgb = float3(m_fR,m_fG,m_fB);
		DepthFog += m_Fog*0.1;
		DepthFog_min = DepthFog * 20.0;
		reflectParam += m_Mirror;
		WLC_Pos.y -= 0.01;
		LightDirection = normalize(-WLC_Pos);
		WaveStrength *= 1+m_Strength*3;
	}
	
	
	float2 temp = IN.Tex + UVScroll * time;
	
	/*
	float4 NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel)*0.25;
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.5)*0.25;
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.1)*0.25;
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.05)*0.125;
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.0001)*0.125;
	//NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.0001);
	*/
	float4 NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	

	float3 Normal = normalize(float3(0,1,0) + NormalColor.rgb * WaveStrength);

	float2 UVSeed = Normal.xz;
	float3 SpecNormal = normalize(Normal * float3(1,0.1,1));
	Normal = mul(float4(Normal,1),WorldMatrix).xyz;
	SpecNormal = mul(float4(SpecNormal,1),WorldMatrix).xyz;
	
	float3 Eye = IN.WPos - CameraPosition;
	float4 Color = 1;
	//フレネル反射率計算
    float A = refractiveRatio;
    float B = dot(-normalize(Eye), Normal);
    float C = sqrt(1.0f - A*A * (1-B*B));
    float Rs = (A*B-C) * (A*B-C) / ((A*B+C) * (A*B+C));
    float Rp = (A*C-B) * (A*C-B) / ((A*C+B) * (A*C+B));
    float alpha = (Rs + Rp) / 2;
 	//水面下用UV座標
    float2 UnderUV = float2((IN.LastPos.x/IN.LastPos.w + 1)*0.5,(-IN.LastPos.y/IN.LastPos.w + 1)*0.5)+ViewportOffset;
    
	//水面下深度
	float3  UnderDepth;
	UnderDepth.r = tex2D(UnderDepthView,UnderUV + UVSeed*0.2*Chromatic.r).r;
	UnderDepth.g = tex2D(UnderDepthView,UnderUV + UVSeed*0.2*Chromatic.g).r;
	UnderDepth.b = tex2D(UnderDepthView,UnderUV + UVSeed*0.2*Chromatic.b).r;
	
    //水面下画像
    float4 UnderColor = tex2D(UnderView,UnderUV + UVSeed*0.1);
	
	UnderColor.r = tex2D(UnderView,UnderUV + UVSeed*0.1*Chromatic.r).r;
	UnderColor.g = tex2D(UnderView,UnderUV + UVSeed*0.1*Chromatic.g).g;
	UnderColor.b = tex2D(UnderView,UnderUV + UVSeed*0.1*Chromatic.b).b;
	
	float realDep = tex2D(UnderDepthView,UnderUV).r;
	float3 NowDep = UnderDepth;
	if(NowDep.r - length(Eye) < 0)
	{
		UnderDepth = realDep;
		UnderColor.r = tex2D(UnderView,UnderUV).r;
		
	}
	if(NowDep.g - length(Eye) < 0)
	{
		UnderDepth = realDep;
		UnderColor.g = tex2D(UnderView,UnderUV).g;
		
	}
	if(NowDep.b - length(Eye) < 0)
	{
		UnderDepth = realDep;
		UnderColor.b = tex2D(UnderView,UnderUV).b;
	}
	
	float dep = (UnderDepth - length(Eye)).r*0.005;
	
    //鏡面用UV座標
    float2 MirrorUV = float2( 1.0f - ( IN.LastPos.x/IN.LastPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.LastPos.y/IN.LastPos.w + 1.0f ) * 0.5f ) + ViewportOffset;
	float4 mirror_test = tex2D(MirrorBufView,MirrorUV + UVSeed*0.1);

	//鏡面画像
	float4 MirrorColor = tex2D(MirrorBufView,MirrorUV + UVSeed*0.1*mirror_test.a);
	float DepthLen = saturate(DepthFog_min + (UnderDepth - length(Eye))*DepthFog);
	
	WaterColor *= (LightAmbient+0.666);
	
	MirrorColor.rgb = lerp(MirrorColor.rgb,WaterColor,DepthLen*0.5);

	UnderColor.rgb = lerp(UnderColor.rgb,WaterColor,DepthLen);

	Color.rgb = lerp(MirrorColor.rgb,UnderColor.rgb,saturate(alpha)*reflectParam);
	// スペキュラ色計算
    float3 HalfVector = normalize( normalize(Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(SpecNormal) )), SpecularPower ) * SpecularColor;
	
	//火線処理
	float3 c = 1;
	float4 UnderNormal = tex2D(UnderNormalView,UnderUV + UVSeed*0.1);
	UnderNormal.xyz = UnderNormal.xyz * 2.0 - 1.0;
	float3 UnderPos = tex2D(UnderPosView,UnderUV + UVSeed*0.1).xyz*0.1;
	WorldMatrix[3].xyz *= 0.1;
	float4x4 InvWorld = InverseMatrix(WorldMatrix);
	
	UnderPos = mul(float4(UnderPos,1),InvWorld).xyz;

	UnderNormal.y *= -1;
	UnderPos *= 10;
	
	UnderPos.z *= -1;
	UnderPos.xz += 0.5;
	
	//UnderPos.xz = IN.Tex.xy;
	//return float4(UnderPos.xz,0,1);
	
	Chromatic = 1+float3(0,0.005,0.01)*dep;

	UnderPos.xz += normalize(Normal.xz) * 0.0001 * length(length(Eye) - UnderDepth);

	temp = UnderPos.xz * saturate(1-UnderPos.y) * Chromatic.r + UVScroll * time;
	NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.5);
	NormalColor /= 2;
	
	NormalColor.rgb = normalize(float3(0,1,0) + NormalColor.rgb * WaveStrength);
	c.r = length(NormalColor.rb)*5;
	
	temp = UnderPos.xz * saturate(1-UnderPos.y) * Chromatic.g + UVScroll * time;
	NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.5);
	NormalColor /= 2;
	
	NormalColor.rgb = normalize(float3(0,1,0) + NormalColor.rgb * WaveStrength);
	c.g = length(NormalColor.rb)*5;
	
	temp = UnderPos.xz * saturate(1-UnderPos.y) * Chromatic.b + UVScroll * time;
	NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	NormalColor += tex2D( NormalSampler, temp * WaveSplitLevel*0.5 );
	NormalColor /= 2;
	
	NormalColor.rgb = normalize(float3(0,1,0) + NormalColor.rgb * WaveStrength);
	c.b = length(NormalColor.rb)*5;

	
	c *= UnderNormal.a * (1-saturate((UnderDepth - length(Eye))*CausticsPow)) * (1-alpha) * 2 * CausticsScale;
	c = saturate(c);
	c = pow(c,2);
	

	
	//return float4(c,1);
	Color.rgb += c;
	Color.rgb += Specular;
	
	Color.rgb *= 1+pow(dot(normalize(Normal*float3(1,0.5,1)),-LightDirection),8)*(LightAmbient+0.666);
	Color.a *= tex2D(MaskSamp,IN.Tex);
	

	
	if(shadow)
    {
    	float4 ShadowColor = Color * float4(ShadowPow,ShadowPow,ShadowPow,1);

	
    	//高さ情報分持ちあげる
    	//temp.y *= -1;
		float Height = tex2Dlod(HeightSampler1,float4(temp * WaveSplitLevel,0,0)).r;
		Height += tex2Dlod(HeightSampler1,float4(temp * WaveSplitLevel * 0.5,0,0)).r;
		Height /= 2;

    	IN.DefPos.y += Height*ShadowHeight*0.1;
    	IN.ScreenTex.y += NormalColor.xy*ShadowHeight*200;
	    float4 ZCalcTex = mul( IN.DefPos, LightWorldViewProjMatrix );
	    
		// テクスチャ座標に変換
		ZCalcTex /= ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - ZCalcTex.y)*0.5f;

		if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
		    // シャドウバッファ外
		    return Color;
		} else {
		    float comp = 0;
		    if(parthf) {
		        // セルフシャドウ mode2
		        comp = saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		    } else {
		        // セルフシャドウ mode1
		        comp = saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
		    }
			
		    float4 ans = lerp(Color,ShadowColor,comp);
		    return ans;
		}
    }

	return Color;
}
//水面の深度保存
float4 Depth_PS(BufferShadow_OUTPUT IN) : COLOR
{
	float3 Eye = IN.WPos - CameraPosition;
	return float4(length(Eye),0,0,1);
}

//波計算

struct PS_IN_BUFFER
{
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
struct PS_OUT
{
	float4 Height		: COLOR0;
	float4 Velocity		: COLOR1;
};

float4 TextureOffsetTbl[4] = {
	float4(-1.0f,  0.0f, 0.0f, 0.0f) / WAVE_TEXSIZE,
	float4(+1.0f,  0.0f, 0.0f, 0.0f) / WAVE_TEXSIZE,
	float4( 0.0f, -1.0f, 0.0f, 0.0f) / WAVE_TEXSIZE,
	float4( 0.0f, +1.0f, 0.0f, 0.0f) / WAVE_TEXSIZE,
};

//入力された値をそのまま吐く
PS_IN_BUFFER VS_Standard( float4 Pos: POSITION, float2 Tex: TEXCOORD )
{
   PS_IN_BUFFER Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5/WAVE_TEXSIZE, 0.5/WAVE_TEXSIZE);
   return Out;
}

float WaveFunc(float t,float2 IN)
{
	t *= 10;
	float ret = sin(t*IN.x) + cos(-t*IN.y);

	return ret;
}

//--高さマップ計算
PS_OUT PS_Height1( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	float Height;
	float Velocity;
	

	Out.Height   = tex2D( HeightSampler_Zero, In.Tex );
	Out.Height	+= tex2D( HeightSampler_Zero, In.Tex+0.25+0.05*sin(WaveSpeed*time+64) );
	Out.Height	+= tex2D( HeightSampler_Zero, In.Tex-0.45-0.05*cos(WaveSpeed*time+32+0.31415)*float2(-1,1) );
	
	Out.Height /= 3;
	Out.Height = Out.Height * 2.0 - 1.0;
	
	Out.Velocity = 0;
	
	
	/*
	if(time == 0)
	{
		Out.Height   = tex2D( HeightSampler_Zero, In.Tex ) * 2.0 - 1.0;
		Out.Velocity   = 0;
	}else{
		Height   = tex2D( HeightSampler2, In.Tex );
		Velocity = tex2D( VelocitySampler2, In.Tex );

		float4 HeightTbl = {
			tex2D( HeightSampler2, In.Tex + TextureOffsetTbl[0] ).r,
			tex2D( HeightSampler2, In.Tex + TextureOffsetTbl[1] ).r,
			tex2D( HeightSampler2, In.Tex + TextureOffsetTbl[2] ).r,
			tex2D( HeightSampler2, In.Tex + TextureOffsetTbl[3] ).r,
		};

		Out.Velocity = Velocity + ((dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) )) * WaveSpeed);
		Out.Height = Height + Out.Velocity;
		
		In.Tex.y = 1-In.Tex.y;
		
		//Out.Height = max(-1,min(1,Out.Height));
		//Out.Velocity = max(-1,min(1,Out.Velocity));
		
	}
	*/
	Out.Velocity.a = 1;
	Out.Height.a = 1;
	return Out;
}
//高さマップコピー
PS_OUT PS_Height2( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	
	Out.Height = tex2D( HeightSampler1, In.Tex );
	Out.Velocity = tex2D( VelocitySampler1, In.Tex );
	return Out;
}
//法線作成
struct CPU_TO_VS
{
	float4 Pos		: POSITION;
};
struct VS_TO_PS
{
	float4 Pos		: POSITION;
	float2 Tex[4]		: TEXCOORD;
};
VS_TO_PS VS_Normal( CPU_TO_VS In )
{
	VS_TO_PS Out;

	// 位置そのまま
	Out.Pos = In.Pos;

	float2 Tex = (In.Pos.xy+1)*0.5;

	// テクスチャ座標は中心からの４点
	float2 fInvSize = float2( 1.0, 1.0 ) / (float)WAVE_TEXSIZE;

	Out.Tex[0] = Tex + float2( 0.0, -fInvSize.y );		// 上
	Out.Tex[1] = Tex + float2( 0.0, +fInvSize.y );		// 下
	Out.Tex[2] = Tex + float2( -fInvSize.x, 0.0 );		// 左
	Out.Tex[3] = Tex + float2( +fInvSize.x, 0.0 );		// 右

	return Out;
}
float4 PS_Normal( VS_TO_PS In ) : COLOR
{
	float HeightHx = (tex2D( HeightSampler1, In.Tex[3] ) - tex2D( HeightSampler1, In.Tex[2] )) * 3.0;
	float HeightHy = (tex2D( HeightSampler1, In.Tex[0] ) - tex2D( HeightSampler1, In.Tex[1] )) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	float3 Out = (normalize( cross( AxisU, AxisV ) ) ) + 0.5;
	
	Out.rb = Out.rb * 2.0 - 1.0;
	Out.g = 0;
	return float4( Out, 1 );
}

float4 PS_MirrorTest( PS_IN_BUFFER In ) : COLOR
{
	return 0;
}
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

technique WaterTec < string MMDPass = "object"; 
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		
    	//メイン波計算
	    "RenderDepthStencilTarget=Wave_DepthBuffer;"
        "RenderColorTarget0=HeightTex1;"
        "RenderColorTarget1=VelocityTex1;"
	    "Pass=height1;"

        "RenderColorTarget0=NormalTex;"
        "RenderColorTarget1=;"
		"Pass=normal;"
		
		//水面の深度を保存
        "RenderColorTarget0=WaterDepth;"
	    "RenderDepthStencilTarget=ScnDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=MainDepth;"
		
        "RenderColorTarget0=ScnBuf;"
	    "RenderDepthStencilTarget=MirrorDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=MirrorBuf;"
	    "RenderDepthStencilTarget=MirrorDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_Y;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPass;"
	    "Pass=MirrorTest;"
    ;
>
{
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass MirrorTest < string Script= "Draw=Buffer;"; > {

        VertexShader = compile vs_2_0 VS_Standard();
        PixelShader  = compile ps_2_0 PS_MirrorTest();
    }
    
    //メイン波用
	//高さ情報計算
	pass height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_Height1();
	}
	//高さ情報コピーして保存
	pass height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_Height2();
	}
	//法線マップ作製
	pass normal < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Normal();
	    PixelShader = compile ps_2_0 PS_Normal();
	}
    pass MainDepth {
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 Depth_PS();
    }
    pass MainPass {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 Main_PS(false);
    }
}
technique WaterTec_SS  < string MMDPass = "object_ss"; 
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		
    	//メイン波計算
	    "RenderDepthStencilTarget=Wave_DepthBuffer;"
        "RenderColorTarget0=HeightTex1;"
        "RenderColorTarget1=VelocityTex1;"
	    "Pass=height1;"

        "RenderColorTarget0=NormalTex;"
        "RenderColorTarget1=;"
		"Pass=normal;"
		
		//水面の深度を保存
        "RenderColorTarget0=WaterDepth;"
	    "RenderDepthStencilTarget=ScnDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=MainDepth;"
		
        "RenderColorTarget0=ScnBuf;"
	    "RenderDepthStencilTarget=MirrorDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=MirrorBuf;"
	    "RenderDepthStencilTarget=MirrorDepthBuffer;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_Y;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPass;"
	    "Pass=MirrorTest;"
    ;
>
{
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass MirrorTest < string Script= "Draw=Buffer;"; > {

        VertexShader = compile vs_2_0 VS_Standard();
        PixelShader  = compile ps_2_0 PS_MirrorTest();
    }
    
    //メイン波用
	//高さ情報計算
	pass height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_Height1();
	}
	//高さ情報コピーして保存
	pass height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_Height2();
	}
	//法線マップ作製
	pass normal < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Normal();
	    PixelShader = compile ps_2_0 PS_Normal();
	}
    
    pass MainDepth {
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 Depth_PS();
    }
    pass MainPass {
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 Main_PS(true);
    }
}