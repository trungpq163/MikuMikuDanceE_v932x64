//波の減衰力
float DownPow = 0.9;

//テクスチャスクロール速度
float2 UVScroll = float2(0.01,0);

float WavePow = 0.5;
float WaveSpeed = 0.01;

//風用係数
float WindPow = 2;

//波のなめらかさ
float PushGauss = 0.2;

//草高さアップ
float AddHeight = -0.5;

//計算用テクスチャサイズ 数値が大きいほど細かい波を出力する
//0～
//基本的に128,256,512,1024を推奨 それ以外は非常に不安定な動きになります
//また、変更後は波のパラメータが壊れるので、一度再生ボタンを押すと直ります。
#define TEX_SIZE 256
#define HITTEX_SIZE 512

//バッファテクスチャのアンチエイリアス設定
#define BUFFER_AA true

//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//シャドウマップサイズ
//通常：1024 CTRL+Gで解像度を上げた場合 4096
#define SHADOWMAP_SIZE 1024

//--よくわからない人はここから触らない--//

//座標変換行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix		: VIEW;

//ライト関連
bool	 LightEnables[MMM_LightCount]		: LIGHTENABLES;		// 有効フラグ
float4x4 LightWVPMatrices[MMM_LightCount]	: LIGHTWVPMATRICES;	// 座標変換行列
float3   LightDirection[MMM_LightCount]		: LIGHTDIRECTIONS;	// 方向
float3   LightPositions[MMM_LightCount]		: LIGHTPOSITIONS;	// ライト位置
float    LightZFars[MMM_LightCount]			: LIGHTZFARS;		// ライトzFar値

//材質モーフ関連
float4	 AddingTexture		  : ADDINGTEXTURE;	// 材質モーフ加算Texture値
float4	 AddingSphere		  : ADDINGSPHERE;	// 材質モーフ加算SphereTexture値
float4	 MultiplyTexture	  : MULTIPLYINGTEXTURE;	// 材質モーフ乗算Texture値
float4	 MultiplySphere		  : MULTIPLYINGSPHERE;	// 材質モーフ乗算SphereTexture値

//カメラ位置
float3	 CameraPosition		: POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse	: DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient	: AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive	: EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float    SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float4   MaterialToon		: TOONCOLOR;
float4   EdgeColor			: EDGECOLOR;
float    EdgeWidth			: EDGEWIDTH;
float4   GroundShadowColor	: GROUNDSHADOWCOLOR;

bool	 spadd;    			// スフィアマップ加算合成フラグ
bool     usetoontexturemap;	// Toonテクスチャフラグ

// ライト色
float3   LightDiffuses[MMM_LightCount]      : LIGHTDIFFUSECOLORS;
float3   LightAmbients[MMM_LightCount]      : LIGHTAMBIENTCOLORS;
float3   LightSpeculars[MMM_LightCount]     : LIGHTSPECULARCOLORS;

// ライト色
static float4 DiffuseColor[3]  = { MaterialDiffuse * float4(LightDiffuses[0], 1.0f)
				 , MaterialDiffuse * float4(LightDiffuses[1], 1.0f)
				 , MaterialDiffuse * float4(LightDiffuses[2], 1.0f)};
static float3 AmbientColor[3]  = { saturate(MaterialAmbient * LightAmbients[0]) + MaterialEmmisive
				 , saturate(MaterialAmbient * LightAmbients[1]) + MaterialEmmisive
				 , saturate(MaterialAmbient * LightAmbients[2]) + MaterialEmmisive};
static float3 SpecularColor[3] = { MaterialSpecular * LightSpeculars[0]
				 , MaterialSpecular * LightSpeculars[1]
				 , MaterialSpecular * LightSpeculars[2]};

#define TEX_WIDTH TEX_SIZE
#define TEX_HEIGHT TEX_SIZE

float time_0_X : TIME;

//==================================================================================================
// テクスチャーサンプラー
//==================================================================================================

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

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
        "*=HitObject.fxsub;";
>;

sampler HitView = sampler_state {
    texture = <HitRT>;
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
texture NormalTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
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
    AddressU = WRAP;		// 繰り返し
    AddressV = WRAP;		// 繰り返し
};
sampler RippleHeightSampler_GY = sampler_state
{
	// 利用するテクスチャ
	Texture = <RippleHeightTex_GY>;
    Filter = LINEAR;
    AddressU = WRAP;		// 繰り返し
    AddressV = WRAP;		// 繰り返し
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
texture RippleNormalTex : RenderColorTarget
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

//==================================================================================================
// 頂点フォーマット
//==================================================================================================

struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float4 SubTex	: TEXCOORD1;	// サブテクスチャ/スフィアマップテクスチャ座標
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float4 SS_UV1   : TEXCOORD4;	// セルフシャドウテクスチャ座標
	float4 SS_UV2   : TEXCOORD5;	// セルフシャドウテクスチャ座標
	float4 SS_UV3   : TEXCOORD6;	// セルフシャドウテクスチャ座標
	float4 Color	: COLOR0;		// ライト0による色
};

// 頂点シェーダ
VS_OUTPUT VS_SeaMain(MMM_SKINNING_INPUT IN, uniform bool useSelfShadow)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    //ローカル高さ
    float Height = IN.Pos.y;
    //0～1.0に
    Height = saturate(Height/4.0);
    
    float2 texadd = UVScroll * time_0_X;
    //計算用座標
    float2 Work = IN.Pos.xz/5.05790;
	Work = 1-(Work * 0.5 + 0.5);
    float3 WaveNormal = tex2Dlod(NormalSampler,float4(Work+texadd,0,0)).rgb*2.0-1.0
    + tex2Dlod(RippleNormalSampler,float4(Work,0,0)).rgb*2.0-1.0;
    float2 AddPos = IN.Pos.y * -WaveNormal.rb;
    IN.Pos.y *= (1+AddHeight);
    IN.Pos.xz -= AddPos*(1+AddHeight);
    IN.Pos.y -= length(AddPos)*0.5*(1+AddHeight);
    
	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。座標と法線を取得する。
	//================================================================================
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	
	// 頂点座標
	Out.Pos = mul(SkinOut.Position, WorldViewProjMatrix);

	// カメラとの相対位置
	Out.Eye = CameraPosition - mul( SkinOut.Position.xyz, WorldMatrix );
	// 頂点法線
	Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

	// ディフューズ色＋アンビエント色 計算
	float3 color = float3(0, 0, 0);
	float3 ambient = float3(0, 0, 0);
	float count = 0;
	for (int i = 0; i < 3; i++) {
		if (LightEnables[i]) {
			color += (float3(1,1,1) - color) * (max(0, DiffuseColor[i] * dot(Out.Normal, -LightDirection[i])));
			ambient += AmbientColor[i];
			count = count + 1.0;
		}
	}
	Out.Color.rgb = saturate(ambient / count + color);
	Out.Color.a = MaterialDiffuse.a;

	// テクスチャ座標
	Out.Tex = IN.Tex;
	Out.SubTex.xy = IN.AddUV1.xy;

	if (useSelfShadow) {
		float4 dpos = mul(SkinOut.Position, WorldMatrix);
		//デプスマップテクスチャ座標
		Out.SS_UV1 = mul(dpos, LightWVPMatrices[0]);
		Out.SS_UV2 = mul(dpos, LightWVPMatrices[1]);
		Out.SS_UV3 = mul(dpos, LightWVPMatrices[2]);
		
		Out.SS_UV1.y = -Out.SS_UV1.y;
		Out.SS_UV2.y = -Out.SS_UV2.y;
		Out.SS_UV3.y = -Out.SS_UV3.y;

		Out.SS_UV1.z = (length(LightPositions[0] - SkinOut.Position) / LightZFars[0]);
		Out.SS_UV2.z = (length(LightPositions[1] - SkinOut.Position) / LightZFars[1]);
		Out.SS_UV3.z = (length(LightPositions[2] - SkinOut.Position) / LightZFars[2]);
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
float4 PS_SeaMain( VS_OUTPUT IN,uniform bool useSelfShadow ) : COLOR
{
	float4 Color = IN.Color;
	float4 texColor = float4(1,1,1,1);

	//スペキュラ色計算
	float3 HalfVector;
	float3 Specular = 0;
	for (int i = 0; i < 3; i++) {
		if (LightEnables[i]) {
			HalfVector = normalize( normalize(IN.Eye) + -LightDirection[i] );
			Specular += pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor[i];
		}
	}

    // テクスチャ適用
    float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
    Color *= TexColor;

	// アルファ適用
	Color.a = IN.Color.a * texColor.a;

	// セルフシャドウなしのトゥーン適用
	float3 color;
	/*なんか上手く動かないのでシャドウは無し
	// セルフシャドウ
	if (useSelfShadow) {
			Color.rgb = MMM_GetSelfShadowToonColor(MaterialToon, IN.Normal, IN.SS_UV1, IN.SS_UV2, IN.SS_UV3, false, true);
	}
	*/

	// スペキュラ適用
	Color.rgb += Specular;

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
	//if(time_0_X == 0)
	if(true)
	{
		Out.Height   = (tex2D( HeightSampler_Zero, In.Tex )-0.5)*WindPow;
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
		Out.Velocity = Velocity + ((dot( (HeightTbl - Height), float4( 1.0, 1.0, 1.0, 1.0 ) )) * WaveSpeed);

		Out.Height = Height + Out.Velocity;
		
		
		In.Tex.y = 1-In.Tex.y;
		float HitData = tex2D(HitView,In.Tex.xy).r;
		
		Out.Height += (HitData * WavePow);
		//Out.Velocity *= 1-HitData;
		//Out.Height = max(-1,min(1,Out.Height));
		//Out.Velocity = max(-1,min(1,Out.Velocity));
	
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
	    
        "RenderColorTarget1=;"
        
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
      VertexShader = compile vs_3_0 VS_SeaMain(false);
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

        "RenderColorTarget1=;"
        
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
      VertexShader = compile vs_3_0 VS_SeaMain(true);
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
