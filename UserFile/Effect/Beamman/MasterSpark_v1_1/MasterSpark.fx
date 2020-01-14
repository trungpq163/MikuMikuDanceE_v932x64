//パラメータ

float param_size : CONTROLOBJECT < string name = "MasterSparkController.pmd"; string item = "太さ"; >;
float param_length : CONTROLOBJECT < string name = "MasterSparkController.pmd"; string item = "長さ"; >;


//長さ最大値
float fLen = 0.01;

//太さ
float fSize = 1.0;

//広がり係数
float fSpread = 1;

//サイズランダム幅
float2 SizeRnd = float2(0.9,1.2);

//ランダム速度
float fRndSpd = 100.0;

//UV繰り返し
float2 UVRap = float2(1,1);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

texture OutTex
<
   string ResourceName = "OutTex.png";
>;
sampler OutTexSamp = sampler_state
{
   Texture = (OutTex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
texture InTex
<
   string ResourceName = "InTex.png";
>;
sampler InTexSamp = sampler_state
{
   Texture = (InTex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//乱数取得
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

//時間
float Time : TIME;


// 変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix      : WORLD;
//カメラ座標
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// 頂点シェーダ
struct OutVS
{
	float4 Pos : POSITION;
	float2 UV  : texCoord0;
	float2 RevUV : texCoord1;
	float3 Normal : texCoord2;
	float4 LocalPos : texCoord3;
	float  Len		: texCoord4;
};

OutVS Outer_VS(float4 Pos : POSITION, float2 UV : texCoord0, float3 Normal : NORMAL)
{
	OutVS Out;
    float4 bufpos = Pos;
    Out.LocalPos = Pos;
    
    //--材質番号1　外周部
    //ローカルZ方向に伸ばす
    Pos.z += -pow(bufpos.z*2,8)*fLen*(1-param_length);
    float l = -(bufpos.z/2);
    Pos.xy = lerp(bufpos.xy,normalize(bufpos.xy),l);
    Pos.xy *= (fSize+l*fSpread)*(1-param_size);
    //UVスクロール
    Out.UV = (UV+float2(Time,0))*UVRap;
    Out.RevUV = (0.25+UV-float2(Time,0))*UVRap;
    
    //法線の出力
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    Out.Len = l;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    return Out;
}

// ピクセルシェーダ
float4 Outer_PS(OutVS IN) : COLOR
{
    // カメラとの相対位置
    float3 Eye = CameraPosition - mul( IN.LocalPos, WorldMatrix );
    
    //テクスチャから画像を取得
	float4 Color = tex2D(OutTexSamp,IN.UV);
	
	Color.rgb *= 0.5;
	
	//中央部ほど色を弱く
	float d = saturate(abs(1-max(0,dot( IN.Normal, normalize(Eye) ))));

	Color.rgb = Color.rgb*0.1 + Color.rgb * pow(d,8);
	Color.rgb *= 20*MaterialDiffuse.a;
	float out_col = tex2D(InTexSamp,IN.UV+float2(0,-Time)).r+tex2D(InTexSamp,IN.RevUV+float2(0,-Time)).r;
	out_col *= 0.5;
	out_col = pow(1-IN.Len,8)*5*pow(out_col,1);
	Color.rgb += out_col;
	return Color;
}

float4 Black_PS(OutVS IN) : COLOR
{
    // カメラとの相対位置
    float3 Eye = CameraPosition - mul( IN.LocalPos, WorldMatrix );

	//中央部ほど色を弱く
	float d = abs(1-max(0,dot( IN.Normal, normalize(Eye) )));

	float4 Color = float4(0,0,0,1);
	return Color;
}
OutVS Inner_VS(float4 Pos : POSITION, float2 UV : texCoord0, float3 Normal : NORMAL)
{
	OutVS Out;
    float4 bufpos = Pos;
    Out.LocalPos = Pos;
    
    //--材質番号1　外周部
    //ローカルZ方向に伸ばす
    float l = -(bufpos.z/2);
    Pos.z += -pow(bufpos.z*2,8)*fLen*(1-param_length);
    Pos.xy = lerp(bufpos.xy,normalize(bufpos.xy),l);
    Pos.xy *= (fSize+l*fSpread)*(1-param_size);

    Pos.xy *= saturate(l-0.1);
    Pos.xy *= SizeRnd.x + getRandom(Time*fRndSpd)*(SizeRnd.y - SizeRnd.x);
    
    //UVスクロール
    UV.x += -Time;
    UV.y += -Time;
    
    Out.UV = UV*float2(2,2);
    Out.RevUV = -Out.UV;
    //法線の出力
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    Out.Len = l;
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    return Out;
}

// ピクセルシェーダ
float4 Inner_PS(OutVS IN) : COLOR
{
	float4 Color = tex2D(InTexSamp,IN.UV);
	Color.rgb = saturate(pow(Color.rgb,5)*10)+0.5;
	return Color;
}
// オブジェクト描画用テクニック
technique MainPass  < string MMDPass = "object"; > {
    pass DrawBlack {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND=SRCALPHA;
		DESTBLEND=INVSRCALPHA;
        VertexShader = compile vs_3_0 Outer_VS();
        PixelShader  = compile ps_3_0 Black_PS();
    }
    pass DrawOuter {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND=ONE;
		DESTBLEND=ONE;
        VertexShader = compile vs_3_0 Outer_VS();
        PixelShader  = compile ps_3_0 Outer_PS();
    }
    pass DrawInner {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND=ONE;
		DESTBLEND=ONE;
        VertexShader = compile vs_3_0 Inner_VS();
        PixelShader  = compile ps_3_0 Inner_PS();
    }
}
technique MainPass_SS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND=ONE;
		DESTBLEND=ONE;
        VertexShader = compile vs_3_0 Outer_VS();
        PixelShader  = compile ps_3_0 Outer_PS();
    }
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}
