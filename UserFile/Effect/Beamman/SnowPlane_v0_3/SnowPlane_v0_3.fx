//当たり判定が雪を押す力
float PushPow = 100.0;
//雪の色
float3 SnowColor = float3(1.25,1.25,1.25);
//踏み荒らした部分のなめらかさ
float PushGauss = 1;

//潰れた部分の変色強さ（踏み荒らされたべっちゃり感）
float DownColor = 0.75;


#define TEX_SIZE 1024

//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//シャドウマップサイズ
//通常：1024 CTRL+Gで解像度を上げた場合 4096
#define SHADOWMAP_SIZE 1024
//影の濃さ
float ShadowPow = 0.5;

//マスクテクスチャ指定
texture TexMask
<
   string ResourceName = "mask.png";
>;

//--よくわからない人はここから触らない--//

//自分のスケール値
float Scale : CONTROLOBJECT < string name = "(self)";string item = "Si";>;
//自分のTr値
float Alpha1 : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;


float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
bool     parthf;   // パースペクティブフラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

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
    int Width = TEX_SIZE;
    int Height = TEX_SIZE;
    string Format = "D3DFMT_R16F" ;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "SnowPlane_*.x = hide;"
        "*=HitObject.fx;";
>;

sampler HitView = sampler_state {
    texture = <HitRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

sampler TexMaskView = sampler_state {
    texture = <TexMask>;
    Filter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
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
//高さ情報を保存するテクスチャー
texture HeightTex2 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="R32F";
>;
//法線情報を保存するテクスチャー
shared texture NormalTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
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

//波紋ガウス用X
texture RippleHeightTex_GX : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="R32F";
>;

//波紋ガウス用Y及び波紋高さマップ使用テクスチャ
texture RippleHeightTex_GY : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format="R32F";
>;

sampler RippleHeightSampler_GX = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex_GX>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler RippleHeightSampler_GY = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex_GY>;
    Filter = LINEAR;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};

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
    Filter = NONE;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
sampler HeightSampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <HeightTex2>;
    Filter = NONE;
    AddressU = Wrap;		// 繰り返し
    AddressV = Wrap;		// 繰り返し
};
//--波紋用
sampler RippleHeightSampler1 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex1>;
    Filter = NONE;
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
sampler RippleHeightSampler2 = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex2>;
    Filter = NONE;
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
   float  DownPow	: TEXCOORD5;
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
	
	float2 texpos = Tex;
	
	float mask = 1-tex2Dlod(TexMaskView, float4(-texpos,0,0)).r;
	
	Pos.y = (tex2Dlod(HeightSampler1,float4(-texpos,0,0)).r)
	+tex2Dlod(RippleHeightSampler_GY,float4(-texpos,0,0)).r
	+mask;
	Pos.y = saturate(Pos.y);
	
	Out.DownPow = pow(Pos.y,8);
	Pos.y = -Pos.y*(WorldMatrix[3].y/Scale);
	Pos.y += 0.001;

	Out.DefPos = float4(Pos,1.0f);
	Out.Pos    = mul( float4( Pos, 1.0f ), wvpmat );
	Out.LastPos = Out.Pos;
	Out.Tex    = Tex;


	Out.Normal = normal;
	Pos.y = 0;
	Out.WorldPos = mul(float4(Pos,1),WorldMatrix);
	    
    // テクスチャ座標
    Out.Tex = Tex;
	
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
	float4 Color = float4(SnowColor,1);
	float2 tex = In.Tex * float2(-1,1);

	float3 Eye = normalize(CameraPos.xyz - In.WorldPos.xyz);
	
	float4 NormalColor = tex2D( NormalSampler, tex);
	NormalColor.g *= -1;
	NormalColor = NormalColor.rbga;
	NormalColor.a = 1;

	float4 RiplNormalColor = tex2D( RippleNormalSampler, tex);

	RiplNormalColor.g *= -1;
	RiplNormalColor = RiplNormalColor.rbga;
	RiplNormalColor.a = 1;
	
	float3x3 tangentFrame = compute_tangent_frame(In.Normal, Eye, In.Tex);
	float3 normal = normalize(mul(2.0f * NormalColor - 1.0f, tangentFrame));
	normal.g *= 0.15;
	tangentFrame = compute_tangent_frame(normal, Eye, In.Tex);
    normal = normalize(mul(2.0f * RiplNormalColor - 1.0f, tangentFrame));
	
	//
	normal = normalize(normal);
	
        
    normal.xz *= -1;

    Color.rgb = lerp(Color.rgb,Color.rgb*DownColor,In.DownPow);
    
    Color *= LightAmbient+0.5;
    
    float4 ShadowColor = Color * float4(ShadowPow,ShadowPow,ShadowPow,1);
    
    float LightNormal = dot(normal, -LightDirection );
    Color = lerp(ShadowColor, Color,saturate(LightNormal * 1 ));
    
    float mask = pow(saturate(tex2D(TexMaskView, -In.Tex).r*4),8);
    Color.a *= mask;
    ShadowColor.a *= mask;
    
    Color = saturate(Color);
    ShadowColor = saturate(ShadowColor);
    
    if(Shadow)
    {
    	//高さ情報分持ちあげる
    	tex.y *= -1;
    	float Height = ((tex2D( HeightSampler1, tex).r + 
    	tex2D( RippleHeightSampler1_Linear, tex ).r));
	    float4 ZCalcTex = mul( In.DefPos, LightWorldViewProjMatrix );
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

struct PS_IN_BUFFER
{
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
struct PS_OUT
{
	float4 Height		: COLOR0;
};

float4 TextureOffsetTbl[5] = {
	float4(-1.0f,  0.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4(+1.0f,  0.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4( 0.0f, -1.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4( 0.0f, +1.0f, 0.0f, 0.0f) / TEX_WIDTH,
	float4( 0.0f, 0.0f, 0.0f, 0.0f) / TEX_WIDTH,
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
	Out.Height   = tex2D( HeightSampler_Zero, In.Tex );
	
	return Out;
}
//高さマップコピー
PS_OUT PS_Height2( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	Out.Height = tex2D( HeightSampler1, In.Tex );
	return Out;
}
//--波紋用
//--高さマップ計算

PS_OUT PS_RippleHeight1( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	float Height;
	if(time_0_X == 0)
	{
		Out.Height   = 0;
	}else{
		Height   = tex2D( RippleHeightSampler2, In.Tex );
		Out.Height = Height;
		In.Tex.y = 1-In.Tex.y;
		
		Out.Height += (tex2D(HitView,In.Tex.xy).r * PushPow);
		Out.Height = saturate(Out.Height-(1-Alpha1));
	}
	Out.Height.a = 1;
	return Out;
}
//高さマップコピー
PS_OUT PS_RippleHeight2( PS_IN_BUFFER In ) : COLOR
{
	PS_OUT Out;
	
	Out.Height = tex2D( RippleHeightSampler1, In.Tex );
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
	float HeightHx = (tex2D( HeightSampler1, In.Tex[3] ) - tex2D( HeightSampler1, In.Tex[2] )) * 3.0;
	float HeightHy = (tex2D( HeightSampler1, In.Tex[0] ) - tex2D( HeightSampler1, In.Tex[1] )) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	float3 Out = (normalize( cross( AxisU, AxisV ) ) ) + 0.5;
	
	Out.g = -1;
	return float4( Out, 1 );
}
float4 PS_NormalRipple( VS_TO_PS In ) : COLOR
{
	float HeightHx = (tex2D( RippleHeightSampler_GY, In.Tex[3]) - tex2D( RippleHeightSampler_GY, In.Tex[2])) * 3.0;
	float HeightHy = (tex2D( RippleHeightSampler_GY, In.Tex[0]) - tex2D( RippleHeightSampler_GY, In.Tex[1])) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	//float3 Out = (normalize( cross( AxisU, AxisV ) ) * 1) + 0.5;
	float3 Out = (normalize( cross( AxisU, AxisV ) )) + 0.5; //PiT mod
	Out.g = -1;
	return float4( Out, 1 );
}

////////////////////////////////////////////////////////////////////////////////////////////////

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379


////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし
// スクリーンサイズ
static float2 ViewportOffset = (float2(0.5,0.5)/TEX_SIZE);
static float2 SampStep = (float2(PushGauss,PushGauss)/TEX_SIZE);

PS_IN_BUFFER VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    PS_IN_BUFFER Out = (PS_IN_BUFFER)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	
	Color  = WT_0 *   tex2D( RippleHeightSampler1, Tex );
	Color += WT_1 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x  ,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*2,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*3,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*4,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*5,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*6,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( RippleHeightSampler1, Tex+float2(SampStep.x*7,0) ) + tex2D( RippleHeightSampler1, Tex-float2(SampStep.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

PS_IN_BUFFER VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    PS_IN_BUFFER Out = (PS_IN_BUFFER)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = WT_0 *   tex2D( RippleHeightSampler_GX, Tex );
	Color += WT_1 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y  ) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*2) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*3) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*4) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*5) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*6) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( RippleHeightSampler_GX, Tex+float2(0,SampStep.y*7) ) + tex2D( RippleHeightSampler_GX, Tex-float2(0,SampStep.y*7) ) );
	
	
    return Color;
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
	    "Pass=height1;"
        
        "RenderColorTarget0=HeightTex2;"
	    "Pass=height2;"

        "RenderColorTarget0=NormalTex;"
		"Pass=normal;"
        
		//波紋計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=RippleHeightTex1;"
	    "Pass=ripple_height1;"

        "RenderColorTarget0=RippleHeightTex2;"
	    "Pass=ripple_height2;"

		//波紋ガウスX
        "RenderColorTarget0=RippleHeightTex_GX;"
	    "Pass=Gaussian_X;"

		//波紋ガウスY
        "RenderColorTarget0=RippleHeightTex_GY;"
	    "Pass=Gaussian_Y;"
        
        "RenderColorTarget0=RippleNormalTex;"
		"Pass=ripple_normal;"
		
		//水面描画
        "RenderColorTarget0=;"
        "RenderColorTarget1=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPath;"
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
}
///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
    float2 Tex			: TEXCOORD1;
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION,float2 Tex : TEXCOORD0 )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

	float2 texpos = Tex;

	float mask = 1-tex2Dlod(TexMaskView, float4(-texpos,0,0)).r;
	
	Pos.y = (tex2Dlod(HeightSampler1,float4(-texpos,0,0)).r)
	+tex2Dlod(RippleHeightSampler_GY,float4(-texpos,0,0)).r
	+mask;
	Pos.y = saturate(Pos.y);
	
	Pos.y = -Pos.y*(WorldMatrix[3].y/Scale);
	Pos.y += 0.001;
	
	
    
    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;
    
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0,float2 Tex : TEXCOORD1) : COLOR
{
    // R色成分にZ値を記録する
    float a = tex2D(TexMaskView, -Tex).r;
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,a);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}
technique Technique_Shadow
<
	string MMDPass = "object_ss";
    string Script = 
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
    	//メイン水面計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=HeightTex1;"
	    "Pass=height1;"
        
        "RenderColorTarget0=HeightTex2;"
	    "Pass=height2;"

        "RenderColorTarget0=NormalTex;"
		"Pass=normal;"
        
		//波紋計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=RippleHeightTex1;"
	    "Pass=ripple_height1;"

        "RenderColorTarget0=RippleHeightTex2;"
	    "Pass=ripple_height2;"

		//波紋ガウスX
        "RenderColorTarget0=RippleHeightTex_GX;"
	    "Pass=Gaussian_X;"

		//波紋ガウスY
        "RenderColorTarget0=RippleHeightTex_GY;"
	    "Pass=Gaussian_Y;"
        
        "RenderColorTarget0=RippleNormalTex;"
		"Pass=ripple_normal;"
		
		//水面描画
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPath;"
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
}
