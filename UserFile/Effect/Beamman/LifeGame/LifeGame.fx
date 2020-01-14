//計算時間
int CalcSpd = 2;

//色設定（0～1)
float4 DotColor[]=
{
{0,0,0,0},	//生存値0(背景)
{0,0,2,1},	//生存値1
{0,1,3,1},	//生存値2
{0,2,4,1},	//生存値3
};

//テクスチャサイズ
#define TEX_SIZE 64

//画面端繰り返し設定
//#define AddresMode WRAP
#define AddresMode Border

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse        : WORLDVIEWINVERSE;

//ライフゲーム用計算テクスチャ
texture LifeTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
>;
sampler LifeTex_Samp = sampler_state
{
	// 利用するテクスチャ
	Texture = <LifeTex>;
    Filter = NONE;
    AddressU = AddresMode;		// 繰り返し
    AddressV = AddresMode;		// 繰り返し
};
//ライフゲーム用テクスチャ保存用
texture LifeTex_Buf : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
>;
sampler LifeTex_Buf_Samp = sampler_state
{
	// 利用するテクスチャ
	Texture = <LifeTex_Buf>;
    Filter = NONE;
    AddressU = AddresMode;		// 繰り返し
    AddressV = AddresMode;		// 繰り返し
};
//ライフゲーム初期値テクスチャ
texture Life_Zero
<
   string ResourceName = "life.png";
>;
sampler Life_Zero_Samp = sampler_state
{
	// 利用するテクスチャ
	Texture = <Life_Zero>;
    Filter = NONE;
    AddressU = AddresMode;		// 繰り返し
    AddressV = AddresMode;		// 繰り返し
};
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
    string Format = "D24S8";
>;

float time : Time;
static float2 SampStep = (float2(1,1)/TEX_SIZE);

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};

//ライフゲーム計算用
VS_OUTPUT Cpu_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5/TEX_SIZE, 0.5/TEX_SIZE);
   return Out;
}
static float2 test[8] = 
		{
			{0,1},{0,-1},
			{1,0},{1,1},{1,-1},
			{-1,0},{-1,1},{-1,-1},
		};

float4 Calc_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
	float4 col = 0;
	
	int nTime = time*30;
	
	//0F目は初期値を入れる
	if(time == 0)
	{
		col = tex2D( Life_Zero_Samp, Tex);
	}else if(nTime%CalcSpd == 0){
		//メイン計算
		float4 Now = tex2D(LifeTex_Buf_Samp,Tex);
		
		int LiveCnt = 0;
		for(int i=0;i<8;i++)
		{
			float4 Tgt = tex2D(LifeTex_Buf_Samp,Tex+test[i]*SampStep);
			LiveCnt += (Tgt.r != 0);
		}
		//生存
		if(Now.r != 0 && (LiveCnt == 2 || LiveCnt == 3))
		{
			if(LiveCnt == 3)
				col.rgb = float3(1,0.5,0);
			else
				col.rgb = float3(1,0.75,0);
		}else
		//誕生
		if(LiveCnt == 3)
		{
			col.rgb = float3(0.5,1,0);
		}else		
		//消滅
		if(LiveCnt <= 1 || LiveCnt >= 4)
		{
			col.rgb = 0;
		}
	}else{
		col = tex2D(LifeTex_Buf_Samp,Tex);
	}
	col.a = 1;
	//return tex2D(Life_Zero_Samp,Tex);

    return col;
}
float4 Cpy_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
	float4 col;
	col = tex2D( LifeTex_Samp, Tex );
    return col;
}

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}
// ピクセルシェーダ
float4 Mask_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
	float4 col = tex2D( LifeTex_Buf_Samp, Tex );
	if(col.g < 0.5-0.1)
	{
		col = DotColor[0];
	}else if(col.g < 0.75-0.1){
		col = DotColor[1];
	}else if(col.g <  1-0.1){
		col = DotColor[2];
	}else{
		col = DotColor[3];
	}
    return col;
}

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

technique MainTec < 
	string MMDPass = "object";
	string Script = 
		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
    	
    	//テクスチャ計算
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=LifeTex;"
	    "Pass=CalcLife;"
        
        //テクスチャコピー
        "RenderColorTarget0=LifeTex_Buf;"
	    "Pass=CopyLife;"

		//メイン描画
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPath;"
    ;
 > {
    pass CalcLife < string Script = "Draw=Buffer;";> {
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Cpu_VS();
        PixelShader  = compile ps_3_0 Calc_PS();
    }
    pass CopyLife < string Script = "Draw=Buffer;";> {
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Cpu_VS();
        PixelShader  = compile ps_3_0 Cpy_PS();
    }
    pass MainPath {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}

