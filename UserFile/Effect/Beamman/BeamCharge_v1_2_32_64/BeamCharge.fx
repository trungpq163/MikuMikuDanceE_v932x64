//ターゲット取得
#define TGTNAME "BeamCharge_Tgt.x"
bool bTgt : CONTROLOBJECT < string name = TGTNAME; >;
float4x4 TgtMat : CONTROLOBJECT < string name = TGTNAME; >;

//複製数
#define CLONE_NUM 1000

//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize = float( 10 );

//射出遅延ランダム幅(0:遅延無し 1以下推奨）
float ShotDelay = 1;

//弾く広さ
float UpSize = 1;

//初期位置のランダム幅(0:みんな同じ距離）
float ShotRand = 1;

//回転速度
float RotationSpd = 5;

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


//--よくわからない人はここから下はさわっちゃだめ--//

float fcnum = CLONE_NUM;
int CloneNum = CLONE_NUM;

//現在の描画番号
int index;

texture2D rndtex <
    string ResourceName = "random1024.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
};


//ラインの長さ：変更不可
#define LINE_LENGTH 100

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

float time_0_X : TIME <bool SyncInEditMode=false;>;

//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD ((ROTATE * PI) / 180.0)

float4x4 CenterWorld : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;
float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 view_trans_matrix : ViewTranspose;

float morph_num : CONTROLOBJECT < string name = "(self)"; string item = "個数調整"; >;
float morph_t : CONTROLOBJECT < string name = "(self)"; string item = "進行"; >;
float morph_gsi : CONTROLOBJECT < string name = "(self)"; string item = "全体Si"; >;
float morph_len : CONTROLOBJECT < string name = "(self)"; string item = "距離"; >;
float morph_si : CONTROLOBJECT < string name = "(self)"; string item = "ラインSi"; >;
float morph_de : CONTROLOBJECT < string name = "(self)"; string item = "遅延rnd"; >;
float morph_len_rnd : CONTROLOBJECT < string name = "(self)"; string item = "距離rnd"; >;
float morph_rot : CONTROLOBJECT < string name = "(self)"; string item = "回転"; >;
float param_h : CONTROLOBJECT < string name = "(self)"; string item = "色相"; >;
float param_s : CONTROLOBJECT < string name = "(self)"; string item = "彩度"; >;
float param_b : CONTROLOBJECT < string name = "(self)"; string item = "明度"; >;
float param_alpha : CONTROLOBJECT < string name = "(self)"; string item = "透明度"; >;

//HSB変換用色テクスチャ
texture2D ColorPallet <
    string ResourceName = "ColorPallet.png";
>;
sampler PalletSamp = sampler_state {
    texture = <ColorPallet>;
};

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   //ランダム値取得
   float4 rnddata = tex2Dlod(rnd,float4(cos(index+123),0,0,1))*2*3.1415;
   
	//モーフ適用
	//複製数
	CloneNum *= (1-morph_num)*100;

	//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
	lineSize *= morph_si;

	//射出遅延ランダム幅(0:遅延無し 1以下推奨）
	ShotDelay *= morph_de;

	//弾く広さ
	UpSize *= morph_len;

	//初期位置のランダム幅(0:みんな同じ距離）
	ShotRand *= morph_len_rnd*morph_len;

	//回転速度
	RotationSpd *= morph_rot;
   
   	UpSize += (rnddata.r%1.0)*ShotRand;
	UpSize *= 10;
   float3 TgtPos = 0;
   
   
   
   
   int idx = round(Pos.z*LINE_LENGTH);
   //IDが規定の長さより長かったら最大値に固定
   if(idx >= LINE_LENGTH)
   {
		idx = LINE_LENGTH-1;
   }
   
   
   
   //自分のID
   float fid = 1.0 - (float) idx / (float)LINE_LENGTH;
   //次のID
   float fnextid = 1.0 - (float) (idx+1) / (float)LINE_LENGTH;

   //0点の座標
   float3 wpos = 0;

   //現在の移動座標
   float3 nowpos = lerp(wpos+float3(0,0,UpSize*10),wpos,fid);
	
   float3 pos = Pos.xyz;
   pos.z = 0;
   pos *= lineSize;

   pos += nowpos;
   
   float4x4 matRot;
   
   rnddata.xyz += RotationSpd*fid;
   
   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(rnddata.x),sin(rnddata.x),0); 
   matRot[2] = float4(0,-sin(rnddata.x),cos(rnddata.x),0); 
   matRot[3] = float4(0,0,0,1); 
   
   pos = mul(float4(pos,1),matRot);
   
   //Y軸回転 
   matRot[0] = float4(cos(rnddata.y),0,-sin(rnddata.y),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rnddata.y),0,cos(rnddata.y),0); 
   matRot[3] = float4(0,0,0,1); 
 
   pos = mul(float4(pos,1),matRot).xyz;
 
   //Z軸回転
   matRot[0] = float4(cos(rnddata.z),sin(rnddata.z),0,0); 
   matRot[1] = float4(-sin(rnddata.z),cos(rnddata.z),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   
   pos = mul(float4(pos,1),matRot).xyz;
   
   pos.xyz *= 1+morph_gsi*10;
   
   Out.Pos = mul(float4(pos, 1),CenterWorld);
   if(bTgt)
   {
   	   Out.Pos.xyz *= 0.1;
	   Out.Pos = mul(Out.Pos,TgtMat);
   }
   Out.Pos = mul(Out.Pos, world_view_proj_matrix);
   
   //頂点UV値の計算
   Out.texCoord.x = Pos.z;
   Out.texCoord.y = ((Pos.x + Pos.y) + 0.5);
   //UVスクロール
   float findex = floor(index);
   
   Out.texCoord.x -= ((1-morph_t)*3-2)+(findex/fcnum)*ShotDelay;
   Out.color = fid;
   
   if(morph_num <= findex/fcnum)
   {
   		Out.color = 0;
   }

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
   MIPFILTER = NONE;
};
//彩度計算用
const float4 calcY = float4( 0.2989f, 0.5866f, 0.1145f, 0.00f );

float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float alpha: TEXCOORD1) : COLOR {
	
	float4 Color = float4(tex2D(LineTexSampler,texCoord));
	Color.a = alpha;
	
	float r = Color.rgb * calcY;
	r *= param_b*10;

	float4 pallet = tex2D(PalletSamp,float2(param_h,param_s));
	Color.rgb *= pallet.rgb;
	Color.rgb += r;
	Color.a *= 1-param_alpha;
	return Color;
}
technique lineSystem <
    string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=CloneNum;"
        "LoopGetIndex=index;"
	    "Pass=lineSystem;"
        "LoopEnd=;"
    ;
> {
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

technique lineSystem_ss <
	string MMDPass = "object_ss";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=CloneNum;"
        "LoopGetIndex=index;"
	    "Pass=lineSystem;"
        "LoopEnd=;"
    ;
> {
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
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}
