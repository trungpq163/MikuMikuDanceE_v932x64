//トレス支援エフェクト
//製作：ビームマンP

//輪郭閾値
//ここを調節すると「輪郭強度」の最大値を増減できる
float p_ThresholdC = 0.01;





//ここからさわらない

#define CONTROLLER_NAME "TraceGuide_Controller.pmd"


float m_EdgeMode : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "輪郭モード"; >;
float m_EdgePow : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "輪郭強度"; >;
float m_Alpha : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "透明度"; >;
float m_Asp_w : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "縦"; >;
float m_Asp_h : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "横"; >;

//色差エッジ閾値
static float ThresholdC = p_ThresholdC;


//ウィンドウテクスチャ
texture WinTex
<
   string ResourceName = "window.png";
>;
sampler WinSamp = sampler_state {
    texture = <WinTex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
float4x4 worldMatrix : World;
float4x4 projectionMatrix : PROJECTION;
float4x4 view_proj_matrix : ViewProjection;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

float fSize = 1.25;
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

float time_0_X : TIME <bool SyncInEditMode=false;>;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

VS_OUTPUT TraceGuide_VS(float4 Pos: POSITION){
   VS_OUTPUT Out;
   Out.Pos = 0;
   Out.texCoord = 0; 

   Out.texCoord = Pos.xy*0.5+0.5;

   float3 pos = 0;
   float2 ViewportRatio = normalize(Viewport);
   
   pos = Pos * 1 * (1+worldMatrix[3].z*-0.1);
   pos *= length(worldMatrix[0])*0.1;
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   pos.xy *= float2(1-m_Asp_w,1-m_Asp_h);
   
   float4 tgt2D = worldMatrix[3]*0.05;

   pos += tgt2D.xyz;
   pos.z = 0;
   Out.Pos = float4(pos, 1);

   return Out;
}
static float2 test[4] = 
{
	{0,1},{1,0},{-1,0},{0,-1}
};
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 SampStep = (float2(1,1)/ViewportSize);

float4 TraceGuide_PS(float2 texCoord: TEXCOORD0) : COLOR {
     
	float4 col = 0;
	col = tex2D(ObjTexSampler, texCoord);
	col.a *= MaterialDiffuse.a;

	float3 add = 0;
	for(int i=0;i<2;i++)
	{
		float4 w;
		//色の差分を計算
		w = tex2D(ObjTexSampler,texCoord + test[i]*SampStep*1);
		
		
		add += (ThresholdC*(1+m_EdgePow*10) < length(w.rgb - col.rgb));	 
	}
	float w = saturate(add);
	col = float4(col.rgb * lerp(1,add,m_EdgeMode),1);
	col.a *= (1-m_Alpha) * lerp(1,w,m_EdgeMode);
	return col;
}
float4 Window_PS(float2 texCoord: TEXCOORD0) : COLOR {
     
	float4 col = 0;
	col = tex2D(WinSamp, texCoord);

	return col;
}
technique MultiMonitor
{
   pass mainpass
   {
      ZENABLE = FALSE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_1_1 TraceGuide_VS();
      PixelShader = compile ps_2_0 TraceGuide_PS();
   }
   pass window
   {
      ZENABLE = FALSE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_1_1 TraceGuide_VS();
      PixelShader = compile ps_2_0 Window_PS();
   }
}

