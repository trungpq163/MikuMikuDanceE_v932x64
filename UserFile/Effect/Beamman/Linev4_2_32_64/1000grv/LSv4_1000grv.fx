//コントローラの行列
bool bCont : CONTROLOBJECT < string name = "tgt.x"; >;
float4x4 ContWorld : CONTROLOBJECT < string name = "tgt.x"; >;

float CutSpeed = 0;
float CutPow = 10;

//ラインの長さ（0～2048の範囲で指定）
#define LINE_LENGTH 1000

//ビルボードフラグ（ワールド回転追随との併用不可。ビルボードが優先される）
#define BILLBORAD false
//ワールド回転追随フラグ（追随するオブジェの回転に合わせる。サイズが大きい、オブジェの回転角度が急だと非常によくない感じになる)
#define WORLD_ROTATE false

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
   string ResourceName = "Line.png";
>;
//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize
<
   string UIName = "lineSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 0.25 );
//ラインのスピード
float LineSpd
<
   string UIName = "LineSpd";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = -100.0;
   int UIMax = 100.0;
> = float(0);

//減衰力
float SpdDown = 1;

//重力
float3 Grv = float3(0,-0.5,0);

//--よくわからない人はここから下はさわっちゃだめ--//

#define LINE_CROSS

#define ADD_UV (0.5/PARTICLE_COUNT)

float time_0_X : Time;
// Xファイルと連動しているので、変更不可
#define PARTICLE_COUNT  10000
// 位置記録用テクスチャのサイズ
#define TEX_WIDTH  PARTICLE_COUNT
#define TEX_HEIGHT  1
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD ((ROTATE * PI) / 180.0)


float4x4 world_matrix : World;
float4x4 wvp : WorldViewProjection;
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
texture AlphaTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;

//複製
texture WorldTex1_buf : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex2_buf : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex3_buf : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture WorldTex4_buf : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture AlphaTex_buf : RenderColorTarget
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

sampler AlphaBase = sampler_state
{
   Texture = (AlphaTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase1_buf = sampler_state
{
   Texture = (WorldTex1_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase2_buf = sampler_state
{
   Texture = (WorldTex2_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase3_buf = sampler_state
{
   Texture = (WorldTex3_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler WorldBase4_buf = sampler_state
{
   Texture = (WorldTex4_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler AlphaBase_buf = sampler_state
{
   Texture = (AlphaTex_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler AlphaBase_get = sampler_state
{
   Texture = (AlphaTex_buf);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float2 IDTex: TEXCOORD2;
};
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION,uniform float rad){
   VS_OUTPUT Out;
   float DelFlg = 1;
   int idx = round(Pos.z*PARTICLE_COUNT);
   //IDが規定の長さより長かったら削除対象
   if(idx >= LINE_LENGTH-2)
   {
   		DelFlg = 0;
   }
   //現在の座標を取得
   float2 base_tex_coord = float2(Pos.z,0.5);
   Out.IDTex = base_tex_coord;
   float4x4 base_mat = float4x4(tex2Dlod(WorldBase1_buf, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase2_buf, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase3_buf, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase4_buf, float4(base_tex_coord,0,1)));
   
   Out.color = tex2Dlod(AlphaBase_buf, float4(base_tex_coord,0,1)).r;
   
   float3 pos = Pos.xyz;
   pos.z = 0;      

   
   float4 rspos = 0;
   if(BILLBORAD)
   {
	   //ラインのビルボード化
	   float3 vec = 0;
	   for(int i = 1;i<LINE_LENGTH;i++)
	   {
		   //ベクトル計算用目標ＩＤ
		   int tgt = idx+i;
		   //次ＩＤのマトリクスを取得
		   float2 tgt_tex_coord = float2(float(tgt) / TEX_WIDTH ,0.5);
		   float4x4 tgt_mat = float4x4(tex2Dlod(WorldBase1_buf, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase2_buf, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase3_buf, float4(tgt_tex_coord,0,1)),tex2Dlod(WorldBase4_buf, float4(tgt_tex_coord,0,1)));
		   
		   //tgtの座標を保存
		   float3 tgt_pos = tgt_mat._41_42_43;
		   
		   //tgtへのベクトルを計算
		   float3 sabun = base_mat._41_42_43 - tgt_pos;
		   vec = normalize(sabun);
		   
		   //誤差により同一座標を取得、ベクトルが０の場合
		   if(length(sabun) != 0)
		   {
		      //取得成功ループを抜ける
		      break;
		   }
        }	   

		//カメラからのベクトル
		float3 eyevec = normalize(view_trans_matrix[2].xyz);

		//進行ベクトルとカメラベクトルの外積で横方向を得る
		float3 side = normalize(cross(vec,eyevec));

		if(rad > 0)
		{
			side = 	normalize(cross(vec,side));
		}
		//横幅に合わせて拡大
		side *= lineSize/16;

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
       
       

	   //非ビルボードライン処理
	   if(WORLD_ROTATE)
	   {
		   //-ワールドマトリックスに合わせて回転、拡縮処理
		   //ワールドマトリックスから移動情報を削除
		   float4x4 matRotScale = base_mat;
		   matRotScale[3] = 0;
		   //マトリックス計算
		   rspos = mul(rspos,matRotScale);
	   }else{
	   	   rspos = mul(rspos,length(world_matrix[0]));
	   }
		//Z軸回転
		float4x4 matRot;
		
		matRot[0] = float4(cos(rad),sin(rad),0,0); 
		matRot[1] = float4(-sin(rad),cos(rad),0,0); 
		matRot[2] = float4(0,0,1,0); 
		matRot[3] = float4(0,0,0,1); 
        rspos = mul(rspos,matRot);
   }
   pos.x = rspos.x;
   pos.y = rspos.y;
   pos.z = rspos.z;
   
   pos += base_mat._41_42_43;
   
   float4 LastPos = float4(pos,1);
   /*
   if(bCont)
   {
   		LastPos = mul(LastPos,ContWorld);
   		LastPos.xyz *= 0.1;
   }
   */
   Out.Pos = mul(LastPos, view_proj_matrix);
   
   
   //Out.Pos = mul(Pos,wvp);
   //頂点UV値の計算
   Out.texCoord.x = (Pos.z * ((float)PARTICLE_COUNT/(float)LINE_LENGTH));
   Out.texCoord.y = ((Pos.x + Pos.y) + 0.5);
   Out.color *= DelFlg;

   return Out;
}
sampler LineTexSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Line_Tex);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float alpha: TEXCOORD1,float2 IDTex: TEXCOORD2) : COLOR {
   float4 col = tex2D(LineTexSampler,saturate(abs(texCoord)));
   col.a *= alpha;
   return float4(col);
}

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   
};

VS_OUTPUT2 WorldBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex+ADD_UV;
   return Out;
}
//座標をテクスチャに保存
float4 WorldBase1_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   
    int idx = round(texWork.x*TEX_WIDTH);
   
   //IDがLINE_LENGTH(先頭）だったらワールド移動値を保存
   //また、再生されて0.05秒間は初期位置に合わせる
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._11_12_13,0);
   }else{
	   
	   //IDからUV座標を計算
	   idx-=1;
	   
	   float4 prev;
	   float2 base_tex_coord = float2(float(idx)/TEX_WIDTH,0.5);
       prev = tex2D(WorldBase1_buf, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
    int idx = round(texWork.x*TEX_WIDTH);
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._21_22_23,0);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2(float(idx)/TEX_WIDTH,0.5);
       prev = tex2D(WorldBase2_buf, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase3_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
    int idx = round(texWork.x*TEX_WIDTH);
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._31_32_33,0);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2(float(idx)/TEX_WIDTH,0.5);
       prev = tex2D(WorldBase3_buf, base_tex_coord);
   	   return prev;
   }
}
float4 WorldBase4_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
    int idx = round(texWork.x*TEX_WIDTH);
    
   if(idx == 0 || time_0_X < 0.05)
   {
   		return float4(world_matrix._41_42_43,0);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2(float(idx)/TEX_WIDTH,0.5);
       prev = tex2D(WorldBase4_buf, base_tex_coord);
       prev += normalize(tex2D(WorldBase3_buf, base_tex_coord)) *- LineSpd*pow(SpdDown,idx);
       prev.xyz += Grv*0.1*idx;
   	   return prev;
   }
}
float4 AlphaBase_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   float2 texWork = texCoord;
   int idx = round(texWork.x*TEX_WIDTH);
    
   float2 base_tex_coord = float2(float(idx)/TEX_WIDTH,0.5);
   float2 base_tex_coord_next = float2(float(idx+1.0)/TEX_WIDTH + ADD_UV,0.5);
   
   bool bClear = (MaterialDiffuse.a == 0);
   
   if(idx == 0 || time_0_X < 0.05)
   {
   		//現在の座標
   		float3 NowPos = tex2D(WorldBase4_buf, base_tex_coord).xyz;
   		float3 PrevPos = tex2D(WorldBase4_buf, base_tex_coord_next).xyz;
   		
   		float buf_a = MaterialDiffuse.a;
   		//buf_a = saturate(MaterialDiffuse.a - 0.1)/0.9;
   		//buf_a *= pow(saturate(length(NowPos - PrevPos)/CutSpeed),CutPow);

   		return float4(buf_a,0,0,1);
   }else if(!bClear){
   	   float test = 1-(fmod(time_0_X,2.0));
	   idx-=1;
	   float4 prev;
   	   float2 base_tex_coord_prev = float2(float(idx)/TEX_WIDTH,0.5);
       prev = tex2D(AlphaBase_buf, base_tex_coord_prev);
   	   return prev;
   }else{
   		return float4(0,0,0,1);
   }
}

VS_OUTPUT2 Base_BufCpy_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex+ADD_UV;
   return Out;
}

float4 Base_BufCpy_PS(float2 texCoord: TEXCOORD0,uniform int samp_no) : COLOR {
	[flatten] if(samp_no == 0)
	{
		//return float4(0.5,0,0,1);
		return tex2D(WorldBase1, texCoord);
	}else if(samp_no == 1)
	{
		//return float4(1,0,0,1);
		return tex2D(WorldBase2, texCoord);
	}else if(samp_no == 2)
	{
		//return float4(0,0.5,0,1);
		return tex2D(WorldBase3, texCoord);
	}else if(samp_no == 3)
	{
		//return float4(0,1,0,1);
		return tex2D(WorldBase4, texCoord);
	}else if(samp_no == 4)
	{
		//return float4(0,0,0.5,1);
		return tex2D(AlphaBase, texCoord);
	}else{
		//return float4(0,0,1,1);
		return 1;
	}
}
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

technique lineSystem <
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=WorldTex1;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase1;"
	    
        "RenderColorTarget0=WorldTex1_buf;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase1_buf;"
	    
	    "RenderColorTarget0=WorldTex2;"
		"Clear=Color;" "Clear=Depth;"	    
	    "Pass=WorldBase2;"
	    
        "RenderColorTarget0=WorldTex2_buf;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase2_buf;"
	    
	    "RenderColorTarget0=WorldTex3;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase3;"
	    
        "RenderColorTarget0=WorldTex3_buf;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase3_buf;"
	    
	    "RenderColorTarget0=WorldTex4;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase4;"
	    
        "RenderColorTarget0=WorldTex4_buf;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=WorldBase4_buf;"
	    
	    "RenderColorTarget0=AlphaTex;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=AlphaBase;"
	    
        "RenderColorTarget0=AlphaTex_buf;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=AlphaBase_buf;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=lineSystem;"
	    #ifdef LINE_CROSS
		    "Pass=lineSystem_90;"
		#endif
    ;
> {
	pass WorldBase1 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 WorldBase1_Pixel_Shader_main();
	}
	pass WorldBase2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 WorldBase2_Pixel_Shader_main();
	}
	pass WorldBase3 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 WorldBase3_Pixel_Shader_main();
	}
	pass WorldBase4 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 WorldBase4_Pixel_Shader_main();
	}
	pass AlphaBase < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 AlphaBase_Pixel_Shader_main();
	}
	
	pass WorldBase1_buf < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 Base_BufCpy_VS();
	    PixelShader = compile ps_3_0 Base_BufCpy_PS(0);
	}
	pass WorldBase2_buf < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 Base_BufCpy_VS();
	    PixelShader = compile ps_3_0 Base_BufCpy_PS(1);
	}
	pass WorldBase3_buf < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 Base_BufCpy_VS();
	    PixelShader = compile ps_3_0 Base_BufCpy_PS(2);
	}
	pass WorldBase4_buf < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 Base_BufCpy_VS();
	    PixelShader = compile ps_3_0 Base_BufCpy_PS(3);
	}
	pass AlphaBase_buf < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 Base_BufCpy_VS();
	    PixelShader = compile ps_3_0 Base_BufCpy_PS(4);
	}
	
   pass lineSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main(0);
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main();
   }
   pass lineSystem_90
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main(radians(90));
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main();
   }
}

