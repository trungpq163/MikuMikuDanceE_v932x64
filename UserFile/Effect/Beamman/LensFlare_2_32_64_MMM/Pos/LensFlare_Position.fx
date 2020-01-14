//--------------------------------------------------------------//
// LensFlare
// つくったひと：ロベリア
// ベースにしたシェーダ―：ParticleSystem
// つくった日：2010/10/12
// こうしんりれき
// 10/10/12:つくった
// 10/10/17:更新
// 10/12/17:自座標版作成
//--------------------------------------------------------------//

#define MaskTexSize 1024

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);

float4x4 worldMatrix : World;
float4x4 projectionMatrix : PROJECTION;
float4x4 view_proj_matrix : ViewProjection;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

texture ObjectMaskRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for LensFlare_Position.fx";
    int Width = MaskTexSize;
    int Height = MaskTexSize;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string Format = "D3DFMT_R32F" ;
    string DefaultEffect = 
        "self = hide;"
        "LensFlare*.x = hide;"
        "*=BlackObject.fx;";
>;

sampler MaskView = sampler_state {
    texture = <ObjectMaskRT>;
    Filter = LINEAR;
    AddressU  = WRAP;
    AddressV = WRAP;
};

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float useMain: TEXCOORD1;
   float color: TEXCOORD2;
   float3 ScnPos: TEXCOORD3;
};

//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD(x) ((x * PI) / 180.0)

float4 toProj(float3 tgtpos)
{
	// VP変換
	float4 tgt = mul(float4(tgtpos,1), view_proj_matrix);
	tgt.x /= tgt.w;
	tgt.y /= tgt.w;
	tgt.z /= tgt.w;
		
	return tgt;
}

float time_0_X : TIME <bool SyncInEditMode=false;>;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

//描画するフレアの数
float FlareNum = 16;

VS_OUTPUT LensFlare_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out = (VS_OUTPUT)0;

   //IDを計算
   float id = 100.0 * Pos.z + 0.05;
   if(id > FlareNum)
   {
   		return Out;
   }
   

   float3 pos = 0;
   pos = Pos * (0.25 + 0.05 * id);
   if((int)id == 1)
   {
   		//id1番（ライト中央）のみ拡大
   		pos *= 5;
   		Out.useMain = 1.0;
   }else{
   		Out.useMain = 0.0;
   }
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   
   float4 TgtPos = worldMatrix[3];
   
   //光源の位置を2Dに変換
   float4 tgt2D = toProj(TgtPos);
   
   if(tgt2D.w < 0)
   {
   		return Out;
   } 
   
   
   pos += tgt2D.xyz;
   pos.z = 0;
   
   
   //光源の位置から画面中央に向けてのベクトル
   float3 vec = -normalize(tgt2D.xyz);
   vec.z = 0;
   //IDをかける
   pos += vec * (id - 1)*0.5;
   
   Out.Pos = float4(pos, 1);
   
	//WVP変換済み座標からスクリーン座標に変換
	TgtPos = mul(TgtPos,view_proj_matrix);
	float3 SPos = TgtPos.xyz/TgtPos.w;
	SPos.y *= -1;
	SPos.xy += 1;
	SPos.xy *= 0.5;
	
	Out.ScnPos.xy = SPos.xy;
	//自分のZ深度を取得
	Out.ScnPos.z = length(CameraPosition - worldMatrix[3].xyz);
	
	
   if(Out.useMain == 0)
   {
	   Out.texCoord = ((Pos.xy + 1.0) * 0.5) * 0.25;
	   Out.texCoord.x += 0.25 * ((int)id % 4);
	   Out.texCoord.y += 0.25 * ((int)id / 4);
   }else{
	   Out.texCoord = ((Pos.xy + 1.0) * 0.5);   
   }
   float len = 1 - min(1,length(tgt2D.xy));
   
   Out.color = (len * (FlareNum - id) / FlareNum) * MaterialDiffuse.a;

   //マスク画像を取得
   float mask = tex2Dlod(MaskView,float4(Out.ScnPos.xy,0,0)).r;
   if(mask==0) mask = 0xffffffff;
   Out.color *= min(1,max(0,(mask - Out.ScnPos.z)));

   return Out;
}
texture FlareSub_Tex
<
   string ResourceName = "FlareSub.png";
>;
sampler FlareSub = sampler_state
{
   Texture = (FlareSub_Tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
texture FlareMain_Tex
<
   string ResourceName = "FlareMain.png";
>;
sampler FlareMain = sampler_state
{
   Texture = (FlareMain_Tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR; 
};
float4 LensFlare_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float usemain: TEXCOORD1, float color: TEXCOORD2,float2 ScnPos: TEXCOORD3) : COLOR {

   float4 col = 0;
   if(usemain != 0)
   {
	   col = tex2D(FlareMain, texCoord);
   }else{
	   col = tex2D(FlareSub, texCoord);   	
   }
   col.a *= color;
   return col;
}

technique LensFlare
<
    string Script = 

	     //レンズフレア本体を描画
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
   		"Pass=LensFlare;"
    ;
>
{
   pass LensFlare
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      //DESTBLEND = INVSRCALPHA;
      DESTBLEND = ONE;

      VertexShader = compile vs_3_0 LensFlare_Vertex_Shader_main();
      PixelShader = compile ps_3_0 LensFlare_Pixel_Shader_main();
   }

}

