//--------------------------------------------------------------//
// DistLine
// 作った人：ビームマンP
//--------------------------------------------------------------//

//軌跡の着色
float4 LineColor = float4(0.1,0.5,0.1,1);
//歪み力
float DistPow = 0.25;
//最低速度（0で常にでっぱなし）
float CutSpeed = 0;

//ラインの長さ（～100）
#define LINE_LENGTH 50

//ビルボードフラグ
#define BILLBORAD true


//UVスクロール速度
float UScroll = 0;
float VScroll = 0;

//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize = 0.1;

//ラインのスピード(射出速度）
float LineSpd = 0;




//ローカルベクトルの使用選択(コメントアウト // ←つける　すると使用オフ）
//#define USE_LOCAL_VEC
//ワールドベクトルの使用選択(コメントアウト // ←つける　すると使用オフ）
#define USE_WORLD_VEC
//ローカルベクトル（角度に関係なくこの方向に加算される。LineSpdが0なら効果なし）
float3 LocalVec = float3(0,1,0);

//マスクテクスチャの有効度
float MaskParam = 1.0;


//--よくわからない人はここから下はさわっちゃだめ--//

#if(LINE_LENGTH > 98)
	#define LINE_LENGTH 98
#elif(LINE_LENGTH < 2)
	#define LINE_LENGTH 2
#endif

//UV繰り返し数
float UWrapNum = 1;
float VWrapNum = 1;

texture DistortionRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DistortionField.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
    	"LineSystem.x = hide;"
        "self = hide;";
>;

sampler DistortionView = sampler_state {
    texture = <DistortionRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//テクスチャ名
texture Line_Tex
<
   string ResourceName = "Line.png";
>;

sampler LineTexSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Line_Tex);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理

   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   FILTER = LINEAR;
};
texture Mask_Tex
<
   string ResourceName = "MaskTex.png";
>;

sampler MaskSamp = sampler_state
{
   //使用するテクスチャ
   Texture = (Mask_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
float time_0_X : Time;
// Xファイルと連動しているので、変更不可
#define PARTICLE_COUNT  100
// 位置記録用テクスチャのサイズ  (TEX_WIDTH*TEX_HEIGHT==PARTICLE_COUNT)
#define TEX_WIDTH  10
#define TEX_HEIGHT  10
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD ((ROTATE * PI) / 180.0)

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
//ワールド行列を保存するテクスチャー
texture WorldTex1 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex2 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex3 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex4 : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler WorldBase1 = sampler_state
{
   Texture = (WorldTex1);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase2 = sampler_state
{
   Texture = (WorldTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase3 = sampler_state
{
   Texture = (WorldTex3);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase4 = sampler_state
{
   Texture = (WorldTex4);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float2 texCoordDef: TEXCOORD1;
   float4 LastPos: TEXCOORD2;
   float2 Vec: TEXCOORD3;
   float Len: TEXCOORD4;
};
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   int idx = round(Pos.z*PARTICLE_COUNT);

   //現在の座標を取得
   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/TEX_HEIGHT + 0.05);
   float4x4 base_mat = float4x4(tex2Dlod(WorldBase1, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase2, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase3, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase4, float4(base_tex_coord,0,1)));
   
   base_mat._14 = 0;
   base_mat._24 = 0;
   base_mat._34 = 0;
   base_mat._44 = 1;
   float3 pos = Pos;
   pos.z = 0;      

   float4 rspos = 0;
   float3 vec = 0;
   float3 tgt_pos;
   for(int i = 1;i<LINE_LENGTH;i++)
   {
	   //ベクトル計算用目標ＩＤ
	   int tgt = idx+i;
	   //次ＩＤのマトリクスを取得
	   float2 tgt_tex_coord = float2( float(tgt%TEX_WIDTH)/TEX_WIDTH + 0.05, float(tgt/TEX_WIDTH)/TEX_HEIGHT + 0.05);
	   float4x4 tgt_mat = float4x4(tex2Dlod(WorldBase1, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase2, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase3, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase4, float4(tgt_tex_coord,0,1)));
	   
	   //tgtの座標を保存
	   tgt_pos = tgt_mat._41_42_43;
	   
	   //tgtへのベクトルを計算
	   vec = normalize(base_mat._41_42_43 - tgt_pos);
	   
	   //誤差により同一座標を取得、ベクトルが０の場合
	   if((vec.x + vec.y + vec.z) != 0)
	   {
	      //取得成功ループを抜ける
	      break;
	   }
    }	 
   if(BILLBORAD)
   {
	   //ラインのビルボード化
  

		//カメラからのベクトル
		float3 eyevec = normalize(view_trans_matrix[2].xyz);

		//進行ベクトルとカメラベクトルの外積で横方向を得る
		float3 side = normalize(cross(vec,eyevec));

		//横幅に合わせて拡大
		side *= lineSize/5;

		//ワールド拡大率に合わせて拡大（横だけ
		side *= length(world_matrix[0]);

		//入力座標のX値でローカルな左右判定
		if(Pos.x > 0)
		{
		    //左側
		    rspos += float4(side,0);
		}else{
		    //右側
		    rspos -= float4(side,0);
		}
	   
	   rspos = mul(rspos,length(world_matrix[0]));
   }else{
	   pos *= lineSize;
       rspos = float4(pos,0);
	   //-ワールドマトリックスに合わせて回転、拡縮処理
	   //ワールドマトリックスから移動情報を削除
	   float4x4 matRotScale = base_mat;
	   //マトリックス計算
	   rspos = mul(rspos,matRotScale);
   	   //rspos = mul(rspos,length(world_matrix[0]));
   }
   pos.xyz = rspos.xyz;
   
   pos += base_mat._41_42_43;
   //pos += world_matrix[2]*Pos.z;
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   Out.LastPos = Out.Pos;
   
   //頂点UV値の計算
   Out.texCoord.x = (Pos.z * ((float)PARTICLE_COUNT/(float)LINE_LENGTH));
   Out.texCoord.y = 1-(((Pos.x + Pos.y) + 0.5));

	//初期テクスチャ値を保存
   Out.texCoordDef = Out.texCoord;
   
   Out.texCoord *= float2(UWrapNum,VWrapNum);
   
   //UVスクロール
   Out.texCoord += float2(UScroll,VScroll) * time_0_X;
   
	float2 NowScPos;
	float2 TgtScPos;
	float4 Now = mul(float4(base_mat._41_42_43,1),view_proj_matrix);
	float4 Prev = mul(float4(tgt_pos,1),view_proj_matrix);
	
	
	NowScPos.x = (Now.x / Now.w)*0.5+0.5;
	NowScPos.y = (-Now.y / Now.w)*0.5+0.5;
   
	TgtScPos.x = (Prev.x / Prev.w)*0.5+0.5;
	TgtScPos.y = (-Prev.y / Prev.w)*0.5+0.5;
   
   Out.Vec = normalize(NowScPos - TgtScPos);

   Out.Len = length(base_mat._41_42_43 - tgt_pos);

   //IDが規定の長さより長かったら消す
   if(idx >= LINE_LENGTH-1)
   {
   		Out.Pos.z = -2;
   }

   return Out;
}

float4 lineSystem_Pixel_Shader_main_dist(VS_OUTPUT IN) : COLOR {

	float4 col = tex2D(LineTexSampler,IN.texCoord);
	col.a *= MaterialDiffuse.a;

	//スクリーン座標を計算
	float2 UVPos;
	UVPos.x = (IN.LastPos.x / IN.LastPos.w)*0.5+0.5;
	UVPos.y = (-IN.LastPos.y / IN.LastPos.w)*0.5+0.5;
	col.r *= lerp(1,tex2D(MaskSamp,IN.texCoordDef).r,MaskParam);
	//return float4(IN.texCoordDef,0,1);
	
	float4 Dist = tex2D(DistortionView,UVPos + IN.Vec * col.r * DistPow);
	
	col.rgb = lerp(Dist.rgb,Dist.rgb+LineColor.rgb*LineColor.a,col.r);
	col.a *= saturate((IN.Len > CutSpeed));
	return col;
	
}
struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

VS_OUTPUT2 WorldBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex ;
   return Out;
}
//座標をテクスチャに保存
float4 WorldBase1_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   
    int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
   
   //IDがLINE_LENGTH(先頭）だったらワールド移動値を保存
   //また、再生されて0.05秒間は初期位置に合わせる
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._11_12_13,1);
   }else{
	   
	   //IDからUV座標を計算
	   idx-=1;
	   
	   float4 prev;
	   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
       prev = tex2D(WorldBase1, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._21_22_23,1);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
       prev = tex2D(WorldBase2, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase3_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._31_32_33,1);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
       prev = tex2D(WorldBase3, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase4_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._41_42_43,1);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
       prev = tex2D(WorldBase4, base_tex_coord);
       
       float3 Vec = 0;

       #ifdef USE_WORLD_VEC
       		Vec = normalize(tex2D(WorldBase3,base_tex_coord));
       #endif
       #ifdef USE_LOCAL_VEC
       		Vec = normalize(Vec+normalize(LocalVec));
       #endif
       
       prev.xyz += Vec * -LineSpd;
   	   return prev;
   }
}

technique lineSystem <
    string Script = 
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=WorldTex1;"
	    "Pass=WorldBase1;"
	    "RenderColorTarget0=WorldTex2;"
	    "Pass=WorldBase2;"
	    "RenderColorTarget0=WorldTex3;"
	    "Pass=WorldBase3;"
	    "RenderColorTarget0=WorldTex4;"
	    "Pass=WorldBase4;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=lineSystem_dist;"
    ;
> {
	pass WorldBase1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 WorldBase1_Pixel_Shader_main();
	}
	pass WorldBase2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 WorldBase2_Pixel_Shader_main();
	}
	pass WorldBase3 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 WorldBase3_Pixel_Shader_main();
	}
	pass WorldBase4 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 WorldBase4_Pixel_Shader_main();
	}
   pass lineSystem_dist
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=SRCALPHA;
      DESTBLEND=INVSRCALPHA;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main_dist();
   }
}

