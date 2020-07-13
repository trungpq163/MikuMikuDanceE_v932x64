//--------------------------------------------------------------//
// lineSystem
// つくったひと：ロベリア
// ベースにしたシェーダ―：FireParticleSystemEx
// つくった日：2010/10/7
// こうしんりれき
// 10/10/7:つくった
// 10/10/7:WORLD_ROTATEをちゃんと実装・テクスチャ4個とかぶっちゃけありえない…
//--------------------------------------------------------------//

//ラインの長さ（0～100の範囲で指定）
#define LINE_LENGTH 15

//ビルボードフラグ（ビルボード処理は未実装なのでtrueにしても何も起きない）
#define BILLBORAD false
//ワールド回転追随フラグ（追随するオブジェの回転に合わせる。サイズが大きい、オブジェの回転角度が急だと非常によくない感じになる)
#define WORLD_ROTATE true
//角度（0～360推奨）
#define ROTATE 0

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
   string ResourceName = "blade.png";
>;
//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize
<
   string UIName = "lineSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 1.5 );


//--よくわからない人はここから下はさわっちゃだめ--//

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
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   int idx = round(Pos.z*PARTICLE_COUNT);
   //IDが規定の長さより長かったら最大値に固定
   if(idx >= LINE_LENGTH)
   {
		idx = LINE_LENGTH;
   }
   //現在の座標を取得
   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/TEX_HEIGHT + 0.05);
   float4x4 base_mat = float4x4(tex2Dlod(WorldBase1, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase2, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase3, float4(base_tex_coord,0,1)),tex2Dlod(WorldBase4, float4(base_tex_coord,0,1)));
   float3 pos = Pos;
   pos.z = 0;      
   pos *= lineSize;


   //非ビルボードライン処理
   float4 rspos = float4(pos,1);
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
   //ローカル回転処理
   //回転行列の作成
   float4x4 matRot;
   matRot[0] = float4(cos(RAD),sin(RAD),0,0); 
   matRot[1] = float4(-sin(RAD),cos(RAD),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 

   rspos = mul(rspos,matRot);
   pos.x = rspos.x;
   pos.y = rspos.y;
   pos.z = rspos.z;
   

   pos += base_mat._41_42_43;
   
   if(BILLBORAD)
   {
	   //ラインのビルボード化
	   //
	   //このへんに追記
	   //
   }else{
   }
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   
   //頂点UV値の計算
   Out.texCoord.x = Pos.z * ((float)PARTICLE_COUNT/(float)LINE_LENGTH);
   Out.texCoord.y = (Pos.x + Pos.y) + 0.5;
   Out.color = 1;

   return Out;
}
sampler LineTexSampler = sampler_state
{
   Texture = (Line_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return float4(tex2D(LineTexSampler,texCoord));
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
   		return float4(world_matrix._11_12_13,0);
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
   		return float4(world_matrix._21_22_23,0);
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
   		return float4(world_matrix._31_32_33,0);
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
   		return float4(world_matrix._41_42_43,0);
   }else{
	   idx-=1;
	   float4 prev;
	   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
       prev = tex2D(WorldBase4, base_tex_coord);
   	   return prev;
   }
}

technique lineSystem <
    string Script = 
	    "RenderDepthStencilTarget=DepthBuffer;"
        "RenderColorTarget0=WorldTex1;"
	    "Pass=WorldBase1;"
	    "RenderColorTarget0=WorldTex2;"
	    "Pass=WorldBase1;"
	    "RenderColorTarget0=WorldTex3;"
	    "Pass=WorldBase2;"
	    "RenderColorTarget0=WorldTex4;"
	    "Pass=WorldBase4;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=lineSystem;"
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
   pass lineSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main();
   }
}

