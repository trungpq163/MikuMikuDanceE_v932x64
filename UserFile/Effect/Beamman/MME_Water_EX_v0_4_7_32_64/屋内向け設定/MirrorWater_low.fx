//--潮の満ち引き用
//水面上下幅
float WaveUpDownLen = 0;
//水面上下速度
float WaveUpDownSpd = 1;

//水面の分割数（細かさ制御用）
int WaveSplitLevel = 2;

//なみうち際のα用係数
float WaveEndPow = 0;

//なみうち際、波の頂点に発生する泡の強さ
float BubblePow = 0;

//生成用の波の強さ
float WavePow = 10;

//鏡面反射の強さ
float MirrorPow = 0.6;

//ライトスペキュラの強さ
float SpeculerPow = 0.8;

//反射光の強さ
float BrightPow = 0;

//水の色（乗算）
float3 WaterColor = float3(1,1,1);

//水の色（加算）
float3 WaterColorAdd = float3(0,0,0);

//RGBそれぞれの色収差の比率(全部1で完全な誤差無し）
float3 Chromatic = float3(1,1.5,2.0);

//波の減衰力
float DownPow = 0.91;

//テクスチャスクロール速度
float2 UVScroll = float2(0,0);

//波の高さ最大値(実際の高さはアクセサリのSi値×これ）
float WaveHeight = 0;
float WaveSpeed = 0.05;

//フレネル反射用の係数 水の透明度…的な。
//０で完全に不透明-0.2以下は非推奨
float refractiveRatio = 0.2;

//影の凹凸強さ
float ShadowHeight = 0.015;

//影の濃さ
float ShadowPow = 0.5;

//計算用テクスチャサイズ 数値が大きいほど細かい波を出力する
//0～
//基本的に128,256,512,1024を推奨 それ以外は非常に不安定な動きになります
//また、変更後は波のパラメータが壊れるので、一度再生ボタンを押すと直ります。
//#define TEX_SIZE 512
#define TEX_SIZE 256
//#define MIRROR_SIZE 512
#define MIRROR_SIZE 1024
#define HITTEX_SIZE 512

//距離フォグ最遠距離
float FogLen = 65535;

//バッファテクスチャのアンチエイリアス設定
#define BUFFER_AA true

//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//シャドウマップサイズ
//通常：1024 CTRL+Gで解像度を上げた場合 4096
#define SHADOWMAP_SIZE 1024

//マスクテクスチャ指定
texture TexMask
<
   string ResourceName = "no_mask.png";
>;

//--よくわからない人はここから触らない--//

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
bool     parthf;   // パースペクティブフラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

//コントローラの値読み込み
bool use_light : CONTROLOBJECT < string name = "WaterLightController.pmd";>;
float3 LightPos : CONTROLOBJECT < string name = "WaterLightController.pmd";string item = "位置調整用";>;
float morph_r : CONTROLOBJECT < string name = "WaterLightController.pmd"; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = "WaterLightController.pmd"; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = "WaterLightController.pmd"; string item = "青"; >;


#define MAX_ANISOTROPY 16

float4x4 WorldMatrix    : WORLD;
float4x4 wvpmat : WORLDVIEWPROJECTION;
float4x4 wvmat          : WORLDVIEW;

float4   CameraPos     : POSITION   < string Object = "Camera"; >;
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float4   LightAmbient     : AMBIENT   < string Object = "Light"; >;
float4   LightDifuse     : DIFUSE   < string Object = "Light"; >;
float4   LightSpecular     : SPECULAR   < string Object = "Light"; >;

#define TEX_WIDTH TEX_SIZE
#define TEX_HEIGHT TEX_SIZE

//==================================================================================================
// テクスチャーサンプラー
//==================================================================================================

texture HitRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWater.fx";
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
        "*=HitObject.fx;";
>;

shared texture2D NoWaterTex : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWater.fx";
    int Width = 512;
    int Height = 512;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = BUFFER_AA;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "* = ZFog.fx;";
>;
shared texture2D NoWaterNormalTex : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWater.fx";
    int Width = 512;
    int Height = 512;
    float4 ClearColor = { 0, 0, 0, 0 };
    string Format = "D3DFMT_A32B32G32R32F" ;
    float ClearDepth = 1.0;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "* = GetNormal.fx;";
>;

sampler NoWaterView = sampler_state {
    texture = <NoWaterTex>;
    Filter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler NoWaterNormalView = sampler_state {
    texture = <NoWaterNormalTex>;
    MinFilter = LINEAR;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV = WRAP;
};
sampler HitView = sampler_state {
    texture = <HitRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV = WRAP;
};

sampler TexMaskView = sampler_state {
    texture = <TexMask>;
    Filter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

texture2D MirrorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWater.fx";
    int Width = MIRROR_SIZE;
    int Height = MIRROR_SIZE;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "*=MirrorObject.fx;";
>;

sampler MirrorView = sampler_state {
    texture = <MirrorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D HDRMirrorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWater.fx";
    int Width = MIRROR_SIZE;
    int Height = MIRROR_SIZE;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "Mirror*.x = hide;"
        "*=MirrorObject_Black.fx;";
>;

sampler HDRMirrorView = sampler_state {
    texture = <HDRMirrorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ハイトマップ初期値初期値
//--メイン波用
texture HeightTex_Zero
<
   string ResourceName = "Height.png";
>;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
//高さ情報を保存するテクスチャー
texture HeightTex1 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="R32F";
>;
//速度情報を保存するテクスチャー
texture VelocityTex1 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
//高さ情報を保存するテクスチャー
texture HeightTex2 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="R32F";
>;
//速度情報を保存するテクスチャー
texture VelocityTex2 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
//法線情報を保存するテクスチャー
shared texture NormalTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
//HDR情報を保存するテクスチャ
shared texture HDROutTex : RenderColorTarget
<
   int Width=1024;
   int Height=1024;
>;
sampler HDROutSamp = sampler_state
{
	Texture = <HDROutTex>;
	Filter = LINEAR;
};
//--波紋用
//高さ情報を保存するテクスチャー
texture RippleHeightTex1 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="R32F";
>;
//高さ情報を保存するテクスチャー
texture RippleHeightTex2 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="R32F";
>;
//速度情報を保存するテクスチャー
texture RippleVelocityTex1 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="A32B32G32R32F";
>;
texture RippleVelocityTex2 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="A32B32G32R32F";
>;
shared texture RippleNormalTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="A32B32G32R32F";
>;

//---サンプラー
sampler HeightSampler_Zero = sampler_state
{
	// 利用するテクスチャ
	Texture = <HeightTex_Zero>;
    Filter = NONE;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler HeightSampler1 = sampler_state
{
	// 利用するテクスチャ
	Texture = <HeightTex1>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler VelocitySampler1 = sampler_state
{
	// 利用するテクスチャ
	Texture = <VelocityTex1>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler HeightSampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <HeightTex2>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler VelocitySampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <VelocityTex2>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
//--波紋用
sampler RippleHeightSampler1 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex1>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleHeightSampler1_Linear = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex1>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleVelocitySampler1 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleVelocityTex1>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleHeightSampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex2>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleVelocitySampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleVelocityTex2>;
    Filter = POINT;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};

sampler NormalSampler = sampler_state
{
	// 利用するテクスチャ
	Texture = <NormalTex>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleNormalSampler = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleNormalTex>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
//なみうち際 泡用テクスチャ
texture BubbleTex
<
   string ResourceName = "bubble.png";
>;
sampler BubbleSampler = sampler_state
{
	// 利用するテクスチャ
	Texture = <BubbleTex>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};

//==================================================================================================
// 頂点フォーマット
//==================================================================================================
struct VS_IN
{
	float4 Pos : POSITION;
};

struct VS_OUTPUT
{
   float4 Pos      : POSITION;  //頂点座標
   float2 Tex      : TEXCOORD0; //テクセル座標
   float3 Normal      : TEXCOORD1; //法線ベクトル
   float3 WorldPos : TEXCOORD2;
   float4 LastPos : TEXCOORD3;
   float4 DefPos	: TEXCOORD4;
};
float time_0_X : Time;
//==================================================================================================
// 頂点シェーダー
//==================================================================================================
VS_OUTPUT VS_SeaMain( float3 Pos      : POSITION,   //頂点座標
              float3 normal   : NORMAL,     //法線ベクトル
              float2 Tex      : TEXCOORD0   //テクセル
              )
{
	VS_OUTPUT Out;
	float2 texadd = UVScroll * time_0_X;
	texadd.y *= -1;
	float2 texpos = Tex - texadd;
	//texpos /= WaveSplitLevel;
	Pos.z = 0;
	Pos.z += (tex2Dlod(HeightSampler1,float4(-texpos,0,0)).r) + 
	(tex2Dlod(RippleHeightSampler1,float4(-texpos,0,0)).r);
	Pos.z = Pos.z * 2 - 1;
	Pos.z = pow(Pos.z*1,2);
	Pos.z = Pos.z * WaveHeight * 0.5;
	Pos.z += (sin(time_0_X*WaveUpDownSpd)+sin(time_0_X*WaveUpDownSpd/4))*WaveUpDownLen;

    Out.DefPos = float4(Pos,1.0f);
	Out.Pos    = mul( float4( Pos, 1.0f ), wvpmat );
	Out.LastPos = Out.Pos;
	Out.Tex    = Tex;

	Out.Normal =  normalize(mul(  normal, (float3x3)WorldMatrix ));
	
	Out.WorldPos = mul(float4(Pos,1),WorldMatrix);
	    
    // テクスチャ座標
    Out.Tex = Tex;
	
	if ( dot(wvmat[2].xyz,wvmat[3].xyz) > 0 ) {
        // 鏡の表の面の場合、X軸を反転して描画しているので、ここで反転する。
        Out.Tex.x = 1 - Out.Tex.x;
    }
	
	return Out;
}
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View); 
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}
//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

//==================================================================================================
// ピクセルシェーダー 
//==================================================================================================
float4 PS_SeaMain( VS_OUTPUT In,uniform bool Shadow ) : COLOR
{
	//ライトコントローラが存在した場合、ライト情報を書き変え
	if(use_light)
	{
		LightDirection = normalize(LightPos*2.0 - WorldMatrix[2]);
		LightAmbient.r = 1-morph_r;
		LightAmbient.g = 1-morph_g;
		LightAmbient.b = 1-morph_b;	
	}
	float4 Color = { 0.0, 0.0, 0.0, 1.0 };
	float2 tex = In.Tex;

	float3 Eye = normalize(CameraPos.xyz - In.WorldPos.xyz);
	//水面上か下かの判定
	if(Eye.y > 0)
	{
		refractiveRatio = -refractiveRatio;
	}else{
		tex.x *= -1;
	}
	float2 temp = tex + UVScroll * time_0_X;//PiT add
	//float4 NormalColor = tex2D( NormalSampler, (tex + UVScroll * time_0_X * 0.1)*WaveSplitLevel); //PiT mod below
	float4 NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	NormalColor.g *= -1;
	NormalColor = NormalColor.rbga;
	NormalColor.a = 1;

	//float4 RiplNormalColor = tex2D( RippleNormalSampler, (tex + UVScroll * time_0_X * 0.1)); //PiT mod below
	float4 RiplNormalColor = tex2D( RippleNormalSampler, temp);
	RiplNormalColor.g *= -1;
	RiplNormalColor = RiplNormalColor.rbga;
	RiplNormalColor.a = 1;
	
	float3x3 tangentFrame = compute_tangent_frame(In.Normal, Eye, In.Tex);
	float3 normal = normalize(mul(2.0f * NormalColor - 1.0f, tangentFrame));
	float3 Riplnormal = normalize(mul(2.0f * RiplNormalColor - 1.0f, tangentFrame));
	normal = normalize(normal+Riplnormal*2);

    float3 reflVec = reflect(normalize(-Eye), normal);
	
	//フレネル反射率計算
    float A = refractiveRatio;
    float B = dot(-Eye, normal);
    float C = sqrt(1.0f - A*A * (1-B*B));
    float AxB = A*B; // PiT add
    float AxC = A*C; // PiT add
    float AxBmC = AxB - C; // PiT add
    float AxBpC = AxB + C; // PiT add
    float AxCmB = AxC - B; // PiT add
    float AxCpB = AxC + B; // PiT add

    //float Rs = (A*B-C) * (A*B-C) / ((A*B+C) * (A*B+C)); // PiT mod below
    //float Rp = (A*C-B) * (A*C-B) / ((A*C+B) * (A*C+B)); // PiT mod below
    float Rs = (AxBmC) * (AxBmC) / ((AxBpC) * (AxBpC));
    float Rp = (AxCmB) * (AxCmB) / ((AxCpB) * (AxCpB));
    float alpha = (Rs + Rp) / 2;
    alpha = min( alpha*MirrorPow, 1.0);
    
    tex = In.Tex + (normal.xz)*0.1;
    float4 diffuseColor = tex2D(MirrorView,tex);
    diffuseColor.rgb *= WaterColor;
    diffuseColor.rgb += WaterColorAdd;
    //diffuseColor.rgb += tex2D(HDRMirrorView,tex).rgb;
	
	// 平行光源
	
    Color = diffuseColor;	
	
	//float w = abs(dot(NormalColor.rgb,float3(0,1,0))); //PiT mod below
	//w = 1-(w+0.5); //PiT mod below
	//Color += w*1; //PiT mod below
	Color += 0.5f - abs(dot(NormalColor.rgb,float3(0,1,0)));

	//float CamLen = length(In.WorldPos.xz - CameraPos.xz); //PiT mod below
	//float len = min(CamLen / FogLen,1);//PiT mod below

    Color.a = alpha;//lerp(alpha,0, pow(min(length(In.WorldPos.xz - CameraPos.xz) / FogLen,1),32) );
    
    float2 w_tex = float2(In.LastPos.x/In.LastPos.w,In.LastPos.y/In.LastPos.w);
	float3 TgtPos = In.LastPos.xyz/In.LastPos.w;
	TgtPos.y *= -1;
	TgtPos.xy += 1;
	TgtPos.xy *= 0.5;
	
	Color.rgb *= Color.a;
	
	float4 UnderCol = 1;
	
	float2 under_tex;
	float ypos;
	float ylen;
	
	
	In.WorldPos.y += 0xffff;
	float len_f = 1;

        float3 Chromatic_01 = 0.1*Chromatic; //PiT add
	//under_tex = (normal.xz)*0.1*Chromatic.r; //PiT mod below
	under_tex = (normal.xz)*Chromatic_01.r;
	ypos = tex2D(NoWaterNormalView,TgtPos.xy + under_tex).a;
	ylen = saturate((In.WorldPos.y - ypos) * len_f);
	UnderCol.r = tex2D(NoWaterView,TgtPos.xy+under_tex * ylen).r;
	
	//under_tex = (normal.xz)*0.1*Chromatic.g;
	under_tex = (normal.xz)*Chromatic_01.g;
	ypos = tex2D(NoWaterNormalView,TgtPos.xy + under_tex).a;
	ylen = saturate((In.WorldPos.y - ypos) * len_f);
	UnderCol.g = tex2D(NoWaterView,TgtPos.xy+under_tex * ylen).g;
	
	//under_tex = (normal.xz)*0.1*Chromatic.b;
	under_tex = (normal.xz)*Chromatic_01.b;
	ypos = tex2D(NoWaterNormalView,TgtPos.xy + under_tex).a;
	ylen = saturate((In.WorldPos.y - ypos) * len_f);
	UnderCol.b = tex2D(NoWaterView,TgtPos.xy+under_tex * ylen).b;
	
	UnderCol *= (1-Color.a);
	
	float3 n = normalize(float3(normal.r,normal.g*0.1,normal.b));
	float nd= dot(n,-LightDirection);	
    nd = pow(nd,64)*0.5;
    
    float fLightPow = ((dot( normalize(normal * float3(1,0.2,1)), -LightDirection )));

    //マスク処理＋なみうち際消し処理
	under_tex = (normal.xz)*0.1;
	ypos = tex2D(NoWaterNormalView,TgtPos.xy + under_tex).a;
	ylen = saturate((In.WorldPos.y - ypos) * len_f);
	
    if(ypos > In.WorldPos.y+1)
    {	
    	ylen = 1;
    }
    
    float wave_end = pow(1-saturate(ylen),8)*WaveEndPow;
    float wave_end_col = pow(1-saturate(ylen),4)*WaveEndPow;
    Color.a = tex2D(TexMaskView,In.Tex * float2(-1,1)).r * (1-wave_end);
    //泡
    //float WavePow = (1-abs(dot(normal,float3(0,1,0))))*16; // PiT mod
    float3 bubble = tex2D(BubbleSampler,In.Tex*1+(normal.xz)).rgb;
    //UnderCol.rgb += bubble*min(1,wave_end_col+WavePow * BubblePow * LightAmbient;// PiT mod
    UnderCol.rgb += bubble*min(1,wave_end_col+((1-abs(dot(normal,float3(0,1,0))))*16))*BubblePow * LightAmbient;
    
    UnderCol.rgb += (nd * LightAmbient*2 + pow(fLightPow * 0.99,64) * LightAmbient)*SpeculerPow;
    Color.rgb += UnderCol.rgb;
    
    float4 HDR = tex2D(HDROutSamp,In.Tex);
    Color.rgb += HDR.rgb*1;
    
    
    if(Shadow)
    {
    	float4 ShadowColor = Color * float4(ShadowPow,ShadowPow,ShadowPow,1);
    	//高さ情報分持ちあげる
    	temp.y *= -1;
    	float Height = ((tex2D( HeightSampler1, temp * WaveSplitLevel).r + 
    	tex2D( RippleHeightSampler1_Linear, temp ).r)*2);
    	In.DefPos.z -= Height*ShadowHeight;
	    float4 ZCalcTex = mul( In.DefPos, LightWorldViewProjMatrix );
		// テクスチャ座標に変換
		ZCalcTex /= ZCalcTex.w;
		float2 TransTexCoord;
		TransTexCoord.x = (1.0f + ZCalcTex.x)*0.5f;
		TransTexCoord.y = (1.0f - ZCalcTex.y)*0.5f;

		if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
		    // シャドウバッファ外
		    return Color;
		    return float4(1,0,0,1);
		} else {
		    float comp = 0;
			float U = SoftShadowParam / SHADOWMAP_SIZE;
			float V = SoftShadowParam / SHADOWMAP_SIZE;
		    if(parthf) {
		        // セルフシャドウ mode2
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		    } else {
		        // セルフシャドウ mode1
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII1-0.3f);
		        comp += saturate(max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII1-0.3f);
		    }
		    comp = 1-saturate(comp/9);
			
		    float4 ans = lerp(ShadowColor, Color, comp);
		    return ans;
		}
    }
    return Color;
}

VS_OUTPUT VS_HDROut( float4 Pos : POSITION,float3 normal : NORMAL,float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float2 texadd = UVScroll * time_0_X;
	texadd.y *= -1;
	float2 texpos = Tex - texadd;
	//texpos /= WaveSplitLevel;
	Pos.z = 0;//WaveHeight/2;
	
	Pos.z += (sin(time_0_X*WaveUpDownSpd)+sin(time_0_X*WaveUpDownSpd/4))*WaveUpDownLen;

   
	Out.Pos    = mul( Pos, wvpmat );
	Out.LastPos = Out.Pos;
	Out.Pos = Pos;
	Out.Tex    = Tex;

	Out.Normal =  normalize(mul(  normal, (float3x3)WorldMatrix ));
	
	Out.WorldPos = mul(Pos,WorldMatrix);
	    
    // テクスチャ座標
    Out.Tex = Tex;
	
	return Out;
}
float4 PS_HDROut( VS_OUTPUT In ) : COLOR
{
	float2 tex = In.Tex;

	float3 Eye = normalize(CameraPos.xyz - In.WorldPos.xyz);
	//水面上か下かの判定
	if(Eye.y > 0)
	{
		refractiveRatio = -refractiveRatio;
	}else{
		tex.x *= -1;
	}
	float2 temp = tex + UVScroll * time_0_X;//PiT add
	//float4 NormalColor = tex2D( NormalSampler, (tex + UVScroll * time_0_X * 0.1)*WaveSplitLevel); //PiT mod below
	float4 NormalColor = tex2D( NormalSampler, temp * WaveSplitLevel);
	NormalColor.g *= -1;
	NormalColor = NormalColor.rbga;
	NormalColor.a = 1;

	float3x3 tangentFrame = compute_tangent_frame(In.Normal, Eye, In.Tex);
	float3 normal = normalize(mul(2.0f * NormalColor - 1.0f, tangentFrame));
    
    tex = In.Tex + (normal.xz)*0.01;
    
    return tex2D(HDRMirrorView,tex)*1;
}

//水面マスク生成
float4 PS_MaskMain( VS_OUTPUT In ) : COLOR
{
    return 1;
}

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
	float4(-1.0f,  0.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4(+1.0f,  0.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4( 0.0f, -1.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4( 0.0f, +1.0f, 0.0f, 0.0f) / TEX_WIDTH,
};
//入力された値をそのまま吐く
PS_IN_BUFFER VS_Standard( float4 Pos: POSITION, float2 Tex: TEXCOORD )
{
   PS_IN_BUFFER Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5/TEX_WIDTH, 0.5/TEX_HEIGHT);
   return Out;
}

//--高さマップ計算
PS_OUT PS_Height1( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	float Height;
	float Velocity;
	if(time_0_X == 0)
	{
		Out.Height   = tex2D( HeightSampler_Zero, In.Tex );
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

		//float4 fForceTbl = HeightTbl - Height; // PiT mod below 
		//float fForce = dot( fForceTbl, float4( 1.0, 1.0, 1.0, 1.0 ) ); // PiT mod below
		//float fForce = dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) );

		//Out.Velocity = Velocity + (fForce * WaveSpeed);
		Out.Velocity = Velocity + ((dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) )) * WaveSpeed);
		Out.Height = Height + Out.Velocity;
		
		In.Tex.y = 1-In.Tex.y;
		
		Out.Height = max(-1,min(1,Out.Height));
		Out.Velocity = max(-1,min(1,Out.Velocity));
		
		//Out.Height *= DownPow;
	}
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
//--波紋用
//--高さマップ計算
PS_OUT PS_RippleHeight1( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	float Height;
	float Velocity;
	if(time_0_X == 0)
	{
		Out.Height   = 0;
		Out.Velocity   = 0;
	}else{
		Height   = tex2D( RippleHeightSampler2, In.Tex );
		Velocity = tex2D( RippleVelocitySampler2, In.Tex );
		float4 HeightTbl = {
			tex2D( RippleHeightSampler2, In.Tex + TextureOffsetTbl[0] ).r,
			tex2D( RippleHeightSampler2, In.Tex + TextureOffsetTbl[1] ).r,
			tex2D( RippleHeightSampler2, In.Tex + TextureOffsetTbl[2] ).r,
			tex2D( RippleHeightSampler2, In.Tex + TextureOffsetTbl[3] ).r,
		};

		//float4 fForceTbl = HeightTbl - Height; //PiT mod below
		//float fForce = dot( fForceTbl, float4( 1.0, 1.0, 1.0, 1.0 ) );//PiT mod below
		//float fForce = dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) );

		//Out.Velocity = Velocity + (fForce * WaveSpeed); //PiT mode below
		Out.Velocity = Velocity + ((dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) )) * WaveSpeed);

		Out.Height = Height + Out.Velocity;
		
		In.Tex.y = 1-In.Tex.y;
		//float4 pow = tex2D(HitView,In.Tex.xy - UVScroll * time_0_X).r * WavePow; //PiT mod
		//Out.Height += pow*10;
		Out.Height += (tex2D(HitView,In.Tex.xy - UVScroll * time_0_X).r * WavePow);
		
		Out.Height = max(-1,min(1,Out.Height));
		Out.Velocity = max(-1,min(1,Out.Velocity));
		
		
		Out.Height *= DownPow;
	}
	Out.Velocity.a = 1;
	Out.Height.a = 1;
	return Out;
}
//高さマップコピー
PS_OUT PS_RippleHeight2( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	
	Out.Height = tex2D( RippleHeightSampler1, In.Tex );
	Out.Velocity = tex2D( RippleVelocitySampler1, In.Tex );
	return Out;
}
//法線マップの作成

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
	float2 fInvSize = float2( 1.0, 1.0 ) / (float)TEX_WIDTH;

	Out.Tex[0] = Tex + float2( 0.0, -fInvSize.y );		// 上
	Out.Tex[1] = Tex + float2( 0.0, +fInvSize.y );		// 下
	Out.Tex[2] = Tex + float2( -fInvSize.x, 0.0 );		// 左
	Out.Tex[3] = Tex + float2( +fInvSize.x, 0.0 );		// 右

	return Out;
}
float4 PS_Normal( VS_TO_PS In ) : COLOR
{
	
	//float HeightU = tex2D( HeightSampler1, In.Tex[0] ); //PiT mod
	//float HeightD = tex2D( HeightSampler1, In.Tex[1] ); //PiT mod
	//float HeightL = tex2D( HeightSampler1, In.Tex[2] ); //PiT mod
	//float HeightR = tex2D( HeightSampler1, In.Tex[3] ); //PiT mod

	//float HeightHx = (HeightR - HeightL) * 3.0; //PiT mod
	//float HeightHy = (HeightU - HeightD) * 3.0; //PiT mod
	float HeightHx = (tex2D( HeightSampler1, In.Tex[3] ) - tex2D( HeightSampler1, In.Tex[2] )) * 3.0;
	float HeightHy = (tex2D( HeightSampler1, In.Tex[0] ) - tex2D( HeightSampler1, In.Tex[1] )) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	//float3 Out = (normalize( cross( AxisU, AxisV ) ) * 1) + 0.5;//PiT modified
	float3 Out = (normalize( cross( AxisU, AxisV ) ) ) + 0.5;
	
	Out.g = -1;
	return float4( Out, 1 );
}
float4 PS_NormalRipple( VS_TO_PS In ) : COLOR
{
	
	//float HeightU = tex2D( RippleHeightSampler1, In.Tex[0]); //PiT mod
	//float HeightD = tex2D( RippleHeightSampler1, In.Tex[1]); //PiT mod
	//float HeightL = tex2D( RippleHeightSampler1, In.Tex[2]); //PiT mod
	//float HeightR = tex2D( RippleHeightSampler1, In.Tex[3]); //PiT mod

	//float HeightHx = (HeightR - HeightL) * 3.0; //PiT mod
	//float HeightHy = (HeightU - HeightD) * 3.0; //PiT mod
	float HeightHx = (tex2D( RippleHeightSampler1, In.Tex[3]) - tex2D( RippleHeightSampler1, In.Tex[2])) * 3.0;
	float HeightHy = (tex2D( RippleHeightSampler1, In.Tex[0]) - tex2D( RippleHeightSampler1, In.Tex[1])) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	//float3 Out = (normalize( cross( AxisU, AxisV ) ) * 1) + 0.5;
	float3 Out = (normalize( cross( AxisU, AxisV ) )) + 0.5; //PiT mod
	Out.g = -1;
	return float4( Out, 1 );
}
#define BLENDMODE_SRC SRCALPHA
#define BLENDMODE_DEST INVSRCALPHA
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;
//==================================================================================================
// テクニック
//==================================================================================================
technique Technique_Sample
<
	string MMDPass = "object";
    string Script = 
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
    	//メイン水面計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=HeightTex1;"
        "RenderColorTarget1=VelocityTex1;"
	    "Pass=height1;"
        
        "RenderColorTarget0=HeightTex2;"
        "RenderColorTarget1=VelocityTex2;"
	    "Pass=height2;"

        "RenderColorTarget0=NormalTex;"
        "RenderColorTarget1=;"
		"Pass=normal;"
        
		//波紋計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=RippleHeightTex1;"
        "RenderColorTarget1=RippleVelocityTex1;"
	    "Pass=ripple_height1;"
        
        "RenderColorTarget0=RippleHeightTex2;"
        "RenderColorTarget1=RippleVelocityTex2;"
	    "Pass=ripple_height2;"
        
        "RenderColorTarget0=RippleNormalTex;"
        "RenderColorTarget1=;"
		"Pass=ripple_normal;"

		//水面描画
        "RenderColorTarget0=;"
        "RenderColorTarget1=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPath;"
	    
        "RenderColorTarget0=HDROutTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=HDRPath;"
    ;
> {
	//--メイン用
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
	//--波紋用
	//高さ情報計算
	pass height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight1();
	}
	//高さ情報コピーして保存
	pass height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight2();
	}

	//--波紋用
	//高さ情報計算
	pass ripple_height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight1();
	}
	//高さ情報コピーして保存
	pass ripple_height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight2();
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
	pass ripple_normal < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Normal();
	    PixelShader = compile ps_2_0 PS_NormalRipple();
	}
	//HDR書き込み
	pass HDRPath < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_HDROut();
	    PixelShader = compile ps_3_0 PS_HDROut();
	}
	//メインパス 
   pass MainPath 
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = TRUE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      //使用するシェーダを設定
      VertexShader = compile vs_3_0 VS_SeaMain();
      PixelShader = compile ps_3_0 PS_SeaMain(false);
   }
   //水面マスク作成
   pass MaskPath
   {
      ZENABLE = FALSE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = FALSE;
      //使用するシェーダを設定
      VertexShader = compile vs_3_0 VS_SeaMain();
      PixelShader = compile ps_3_0 PS_MaskMain();
   }
}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {

}

technique Technique_Shadow
<
	string MMDPass = "object_ss";
    string Script = 
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
    	//メイン水面計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=HeightTex1;"
        "RenderColorTarget1=VelocityTex1;"
	    "Pass=height1;"
        
        "RenderColorTarget0=HeightTex2;"
        "RenderColorTarget1=VelocityTex2;"
	    "Pass=height2;"

        "RenderColorTarget0=NormalTex;"
        "RenderColorTarget1=;"
		"Pass=normal;"
        
		//波紋計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=RippleHeightTex1;"
        "RenderColorTarget1=RippleVelocityTex1;"
	    "Pass=ripple_height1;"
        
        "RenderColorTarget0=RippleHeightTex2;"
        "RenderColorTarget1=RippleVelocityTex2;"
	    "Pass=ripple_height2;"
        
        "RenderColorTarget0=RippleNormalTex;"
        "RenderColorTarget1=;"
		"Pass=ripple_normal;"

		//水面描画
        "RenderColorTarget0=;"
        "RenderColorTarget1=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPath;"
	    
        "RenderColorTarget0=HDROutTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=HDRPath;"
    ;
> {
	//--メイン用
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
	//--波紋用
	//高さ情報計算
	pass height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight1();
	}
	//高さ情報コピーして保存
	pass height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight2();
	}

	//--波紋用
	//高さ情報計算
	pass ripple_height1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight1();
	}
	//高さ情報コピーして保存
	pass ripple_height2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Standard();
	    PixelShader = compile ps_2_0 PS_RippleHeight2();
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
	pass ripple_normal < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_2_0 VS_Normal();
	    PixelShader = compile ps_2_0 PS_NormalRipple();
	}
	//HDR書き込み
	pass HDRPath < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_HDROut();
	    PixelShader = compile ps_3_0 PS_HDROut();
	}
	//メインパス 
   pass MainPath 
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = TRUE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      //使用するシェーダを設定
      VertexShader = compile vs_3_0 VS_SeaMain();
      PixelShader = compile ps_3_0 PS_SeaMain(true);
   }
   //水面マスク作成
   pass MaskPath
   {
      ZENABLE = FALSE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = FALSE;
      //使用するシェーダを設定
      VertexShader = compile vs_3_0 VS_SeaMain();
      PixelShader = compile ps_3_0 PS_MaskMain();
   }
}
