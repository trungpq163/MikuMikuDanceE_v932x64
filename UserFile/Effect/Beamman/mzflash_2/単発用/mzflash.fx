//===============================================//
//マズルフラッシュエフェクト
//作った人：ビームマンP（ロベリア）


//--マズルフラッシュアニメーション速度--//
float FlashSpd = 5.0;

//--点滅間隔--//
int FlashRld = 16;




//合成方法の設定
//
//半透明合成：
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST INVSRCALPHA
//
//加算合成：
//
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST ONE

#define BLENDMODE_SRC SRCALPHA
#define BLENDMODE_DEST ONE

//テクスチャ名
texture Line_Tex
<
   string ResourceName = "mzflash_0.png";
   //string ResourceName = "mzflash_1.png";
   //string ResourceName = "mzflash_2.png";
>;
//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize
<
   string UIName = "lineSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 2 );
//ラインの長さ
float lineLength
<
   string UIName = "lineLength";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 3 );
//UVスクロール速度
float UScroll
<
   string UIName = "UScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0);
float VScroll
<
   string UIName = "VScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0);

//UV繰り返し数
float UWrapNum
<
   string UIName = "UWrapNum";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 100.0;
> = float(1);
float VWrapNum
<
   string UIName = "VWrapNum";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 100.0;
> = float(1);
//--よくわからない人はここから下はさわっちゃだめ--//

//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD ((ROTATE * PI) / 180.0)

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION,uniform int type){
   VS_OUTPUT Out;
   float time_0_X = 1-MaterialDiffuse.a;
   if(type == 2)
   {
		Out.texCoord = Pos.xz*0.5+0.5;
		//ワールド拡大率に合わせて拡大
		float w = cos(time_0_X * 1);
		if(w > 0)
		{
		    w = pow(w,32);
		}else{
		    w = 0;
		}
		Pos.xz *= w*0.5;
		Out.Pos = mul(Pos.xzyw, WorldViewProjMatrix);
		Out.color = 1;
		return Out;
   }else{
		//ローカル座標を0点に初期化
		Out.Pos = float4(0,0,0,1);

		//進行ベクトルとカメラベクトルの外積で横方向を得る
		float3 side = 0;
		if(type == 0)
		{
			side = float3(1,0,0);
		}
		if(type == 1)
		{
			side = float3(0,1,0);
		}

		float w = cos(time_0_X * 1);
		if(w > 0)
		{
		    w = pow(w,32);
		}else{
		    w = 0;
		}
		//横幅に合わせて拡大
		side *= lineSize/2/2;

		//ワールド拡大率に合わせて拡大（横だけ
		side *= length(world_matrix[0]) * w;

		//入力座標のX値でローカルな左右判定
		if(Pos.x > 0)
		{
		    //左側
		    Out.texCoord.y = 0;
		    Out.Pos += float4(side,0);
		}else{
		    //右側
		    Out.texCoord.y = 1 * VWrapNum; 
		    Out.Pos -= float4(side,0);
		}

		//長さに合わせて進行ベクトルを伸ばす
		float3 vec = float3(0,0,1);
		vec *= -lineLength * 5.0 * DiffuseColor.a * (1-w);

		//ローカルのZ値が＋の場合、進行ベクトルを加える
		if(Pos.z > 0)
		{
		    Out.texCoord.x = 0; 
		    Out.Pos += float4(vec,0);
		}else{
		    Out.texCoord.x = 1.0 * UWrapNum;
		}

		Out.texCoord += float2(UScroll,VScroll) * time_0_X;

		//ワールド拡大率に合わせて拡大

		Out.Pos.xyz *= 0.2;
		Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
		Out.color = 1;
		return Out;
	}
}

//テクスチャの設定
sampler LineTexSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Line_Tex);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

texture Center_Tex
<
   string ResourceName = "mzflash_center.png";
>;
sampler CenterSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Center_Tex);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
//ピクセルシェーダ
float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,uniform int type) : COLOR {
	//入力されたテクスチャ座標に従って色を選択する
	float Color = MaterialDiffuse.a;
	if(type == 0)
	{
		return Color*float4(tex2D(LineTexSampler,texCoord));
	}else{
		return Color*float4(tex2D(CenterSampler,texCoord));
	}
}

//テクニックの定義
technique lineSystem <
    string Script = 
		//描画対象をメイン画面に
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    //パスの選択
	    "Pass=lineSystem_w;"
	    "Pass=lineSystem_h;"
	    "Pass=lineSystem_c;"
    ;
> {
   //メインパス
   pass lineSystem_w
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main(0);
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main(0);
   }
   pass lineSystem_h
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main(1);
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main(0);
   }
   pass lineSystem_c
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main(2);
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main(1);
   }
}

