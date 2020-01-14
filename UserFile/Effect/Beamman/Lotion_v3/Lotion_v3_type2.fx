////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ローション風エフェクト
//	つくったひと：ロベリア
//
//  改造元：ソフトライトHLシェーダ
//  furia様
//
////////////////////////////////////////////////////////////////////////////////////////////////

//使用UV選択：
//0:初期UV使用
//1:追加UV1番使用
#define USE_UV 0

//歪み係数
float DistParam = 10;

//反射力の強さ
int LotionPower = 128;
//着色の強さ（LotionPowerより下だと綺麗に出る）
int LotionDiffusePower = 10;
//UV値スケール
float LotionUVScale = 1;

//UVスクロールスピード
float2 UVSpd = float2(0,-0.003);

float3 LotionSpecularColor = float3(1,1,1);
float4 LotionColor = float4(1,1,1,0.5); 

//---ソフトシャドウ設定---//

//ソフトシャドウ明るさ補正
float LightParam = 1;
//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//シャドウマップサイズ
//通常：1024 CTRL+Gで解像度を上げた場合 4096
#define SHADOWMAP_SIZE 1024

//ここから触らない

//ソフトライト合成関数
float3 SoftLight(float3 fg , float3 bg){
	float3 under  = bg+(bg-pow(bg,2.0))*(2.0f*fg-1.0f);
	float3 middle = bg+(bg-pow(bg,2.0f))*(2.0f*fg-1.0f)*(3.0f-8.0f*bg);
	float3 upper  = bg+(pow(bg,0.5f)-bg)*(2.0f*fg-1.0f);

	const float bgLimit = 32.0f / 255.0f;
	
	float3 Dst = (float3)0;
	
	Dst.r = fg.r < 0.5f ? under.r : bg.r <= bgLimit ? middle.r : upper.r;
	Dst.g = fg.g < 0.5f ? under.g : bg.g <= bgLimit ? middle.g : upper.g;
	Dst.b = fg.b < 0.5f ? under.b : bg.b <= bgLimit ? middle.b : upper.b;

	return Dst;
}



// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

//絵を保存するテクスチャ
texture MyColTex : RenderColorTarget
<
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "A8R8G8B8" ;
>;
sampler MyColSampler = sampler_state {
    texture = <MyColTex>;
    Filter = LINEAR;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


float time : TIME;

//ローション用法線
texture2D LotionNormalTex <
    string ResourceName = "Lotion_Tex_N_0.png";
    //string ResourceName = "Lotion_Tex_N_1.png";
    //string ResourceName = "Lotion_Tex_N_2.png";
    //string ResourceName = "Lotion_Tex_N_3.png";
>;
sampler LotionNormalSampler = sampler_state {
    texture = <LotionNormalTex>;
    Filter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};


// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

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

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
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

        VertexShader = compile vs_3_0 ColorRender_VS();
        PixelShader  = compile ps_3_0 ColorRender_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
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
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
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


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float2 Tex      : TEXCOORD0;    // テクスチャ
    float2 AddTex   : TEXCOORD1;    // 追加テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 WPos     : TEXCOORD5;     // ワールド座標値
    float4 LastPos	: TEXCOORD6;
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,float4 AddTex : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.WPos = mul(Pos,WorldMatrix);
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    Out.AddTex = AddTex.xy;
    Out.LastPos = Out.Pos;
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    
    float4 ans;
    float comp = 1;
    if(useToon){
        comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
		ans = ShadowColor * (comp+float4(MaterialToon,1)*(1-comp)) +  float4(Specular,0) * comp;
		
		float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
		
	    float RimPower = max( 0.0f, dot( -normalize(IN.Eye), -LightDirection ) );
	    float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(IN.Eye)) );
	    diffContrib += Rim*RimPower;
	    
	    diffContrib = pow(diffContrib,1.0f/0.75);
	    
		float3 mColor = diffContrib * ans;
		float3 sColor = SoftLight( diffContrib * 0.75f, ans);

		//彩度取得
		float Imax,Imin;
		Imax = max(ans.r , max(ans.g , ans.b ));
		Imin = min(ans.r , min(ans.g , ans.b ));
		
		//HSV 彩度
		float s = (Imax-Imin) / Imax;

		s = s/2.0f;
		s = pow(s,1.0f/0.5f);

        ans.rgb = lerp(sColor,mColor,s);
        
    }else{
        ans = (0 + MaterialDiffuse * pow(dot(normalize(IN.Normal), -LightDirection ) *0.5+0.5,1/0.5));
        ans = (ans*Color + float4(Specular,0))*comp + 0*Color*(1-comp);
    }
    return ans;
}
///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float2 AddTex   : TEXCOORD2;    // 追加テクスチャ
    float3 Normal   : TEXCOORD3;    // 法線
    float3 Eye      : TEXCOORD4;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD5;	 // スフィアマップテクスチャ座標
    float4 WPos     : TEXCOORD6;     // ワールド座標値
    float4 LastPos	: TEXCOORD7;
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,float4 AddTex : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	Out.WPos = mul(Pos,WorldMatrix);
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    Out.AddTex = AddTex.xy;
    Out.LastPos = Out.Pos;
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}
// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
       		 // シャドウバッファ外
       		 float4 ans;
       		 float comp = 1;
	       if(useToon){
	       		comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
				ans = ShadowColor * (comp+float4(MaterialToon,1)*(1-comp)) +  float4(Specular,0) * comp;
				
				float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
				
			    float RimPower = max( 0.0f, dot( -normalize(IN.Eye), -LightDirection ) );
			    float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(IN.Eye)) );
			    diffContrib += Rim*RimPower;
			    
			    diffContrib = pow(diffContrib,1.0f/0.75);
			    
				float3 mColor = diffContrib * ans;
				float3 sColor = SoftLight( diffContrib * 0.75f, ans);

				//彩度取得
				float Imax,Imin;
				Imax = max(ans.r , max(ans.g , ans.b ));
				Imin = min(ans.r , min(ans.g , ans.b ));
				
				//HSV 彩度
				float s = (Imax-Imin) / Imax;

				s = s/2.0f;
				s = pow(s,1.0f/0.5f);

	        	ans.rgb = lerp(sColor,mColor,s);
	        	
	        }else{
	       		ans = (0 + MaterialDiffuse * pow(dot(normalize(IN.Normal), -LightDirection ) *0.5+0.5,1/0.5));
	       		ans = (ans*Color + float4(Specular,0))*comp + 0*Color*(1-comp);
	        }
	       	return ans;
    } else {
        float comp = 0;
		float U = SoftShadowParam / SHADOWMAP_SIZE;
		float V = SoftShadowParam / SHADOWMAP_SIZE;
        if(parthf) {
            // セルフシャドウ mode2
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII1-0.3f);
        }
        comp = 1-saturate(comp/9);
        float4 ans;
        if(useToon){
			ans = ShadowColor * (comp+float4(MaterialToon,1)*(1-comp)) +  float4(Specular,0) * comp;
			
			float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
			
		    float RimPower = max( 0.0f, dot( -normalize(IN.Eye), -LightDirection ) );
		    float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(IN.Eye)) );
		    diffContrib += Rim*RimPower;
		    
		    diffContrib = pow(diffContrib,1.0f/0.75);
		    
			float3 mColor = diffContrib * ans;
			float3 sColor = SoftLight( diffContrib * 0.75f, ans);

			//彩度取得
			float Imax,Imin;
			Imax = max(ans.r , max(ans.g , ans.b ));
			Imin = min(ans.r , min(ans.g , ans.b ));
			
			//HSV 彩度
			float s = (Imax-Imin) / Imax;

			s = s/2.0f;
			s = pow(s,1.0f/0.5f);

        	ans.rgb = lerp(sColor,mColor,s);
        	
        }else{
       		ans = (0 + MaterialDiffuse * pow(dot(normalize(IN.Normal), -LightDirection ) *0.5+0.5,1/0.5));
       		ans = (ans*Color + float4(Specular,0))*comp + 0*Color*(1-comp);
        }
        
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}
// ピクセルシェーダ
float4 Lotion_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
	#if(USE_UV == 0)
		float2 lot_tex = IN.Tex;
	#else
		float2 lot_tex = IN.AddTex+(IN.Tex-0.5)*0.01;
	#endif
	lot_tex += UVSpd * time;
	float3 normal;
	float4 NormalColor = tex2D( LotionNormalSampler, lot_tex * LotionUVScale);
	float4 DiffColor = tex2D( LotionNormalSampler, lot_tex * LotionUVScale);
	DiffColor = (DiffColor.r + DiffColor.g + DiffColor.b)/3;
	
	NormalColor = NormalColor.rgba;
	NormalColor.a = 1; 
	float3 Eye = normalize(CameraPosition.xyz - IN.WPos.xyz); 
	float3x3 tangentFrame = compute_tangent_frame(IN.Normal, Eye, lot_tex);
	normal = normalize(mul(2.0f * NormalColor - 1.0f, tangentFrame));
	
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    //ローションのスペキュラを追加
    float LotionPow = pow( max(0,dot( HalfVector, normalize(normal) )), LotionPower );
    float LotionDiffPow = pow( max(0,dot( HalfVector, normalize(normal) )), LotionDiffusePower );
    float3 LotionSpecular = LotionPow * LotionSpecularColor;
    Specular += LotionSpecular * LightSpecular;
    
    float4 Color = float4(Specular,1);
    
	float2 ScrTex;
    ScrTex.x = (IN.LastPos.x / IN.LastPos.w)*0.5+0.5;
	ScrTex.y = (-IN.LastPos.y / IN.LastPos.w)*0.5+0.5;
    
    float4 Base = tex2D(MyColSampler,ScrTex);
    
    ScrTex += pow(normalize(mul(normal,WorldViewProjMatrix).xy),10)*DistParam*(0.05/length(IN.Eye));

	Color = tex2D(MyColSampler,ScrTex);
	Color = lerp(Base,Color,pow(Color.a,10));
	//Color = Base;
	
    //ローションの着色
    Color.rgb = lerp(Color.rgb,LotionColor.rgb,LotionDiffPow*LotionColor.a);
    // スペキュラ適用
    Color.rgb += Specular;
    return Color;
}
//SS無し
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec0  < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 Lotion_PS(false, false, false);
    }
}
technique MainTec1  < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 Lotion_PS(true, false, false);
    }
}

technique MainTec2  < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 Lotion_PS(false, true, false);
    }
}

technique MainTec3  < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 Lotion_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4  < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 Lotion_PS(false, false, true);
    }
}

technique MainTec5  < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 Lotion_PS(true, false, true);
    }
}

technique MainTec6  < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 Lotion_PS(false, true, true);
    }
}

technique MainTec7  < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 Lotion_PS(true, true, true);
    }
}

//SS有り
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 Lotion_PS(false, false, false);
    }
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 Lotion_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 Lotion_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 Lotion_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 Lotion_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 Lotion_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 Lotion_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
    string Script = 
        "RenderColorTarget0=MyColTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "Pass=DrawCol;"

	    //最終合成
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawCol {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 Lotion_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
