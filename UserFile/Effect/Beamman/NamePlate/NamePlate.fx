//--------------------------------------------------------------//
// LensFlare
// つくったひと：ロベリア
// ベースにしたシェーダ―：ParticleSystem
// つくった日：2010/10/12
// こうしんりれき
// 10/10/12:つくった
// 10/10/17:更新
//--------------------------------------------------------------//

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

float fSize = 1.25;
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};


//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

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

VS_OUTPUT LensFlare_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
   Out.Pos = 0;
   Out.texCoord = 0; 

   Out.texCoord = Pos.xy*0.5+0.5;

   float3 pos = 0;
   pos = Pos * 0.25 * fSize;
   pos *= length(worldMatrix[0])*0.1;
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   
   //光源の位置を2Dに変換
   float4 tgt2D = toProj(worldMatrix[3]);
   
   if(tgt2D.w < 0)
   {
   		return Out;
   }
   
   
   pos += tgt2D.xyz;
   pos.z = 0;
   Out.Pos = float4(pos, 1);

   return Out;
   
   /*
  VS_OUTPUT Out;
   Out.color = 0;
   Out.Pos = 0;
   Out.texCoord = 0;
   Out.useMain = 0;

   //IDを計算
   float id = 100.0 * Pos.z + 0.05;
   if(id > FlareNum)
   {
   		return Out;
   }
   

   float3 pos = 0;
   pos = Pos * (0.25);
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   
   //光源の位置を2Dに変換
   float4 tgt2D = toProj(TgtPos);
   
   if(tgt2D.w < 0)
   {
   		return Out;
   }
   
   pos += tgt2D.xyz;
   pos.z = 0;
   
}
   */
   
}
texture Grf_tex
<
   string ResourceName = "Grf.png";
>;
sampler Grf = sampler_state
{
   Texture = (Grf_tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR; 
};
float4 LensFlare_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
     
   float4 col = 0;
   col = tex2D(Grf, texCoord);
   col.a *= MaterialDiffuse.a;
   
   return col;
}

technique LensFlare
{
   pass LensFlare
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_1_1 LensFlare_Vertex_Shader_main();
      PixelShader = compile ps_2_0 LensFlare_Pixel_Shader_main();
   }

}

