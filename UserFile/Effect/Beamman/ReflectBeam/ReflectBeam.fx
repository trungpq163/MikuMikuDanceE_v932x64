
//複製数
int CloneNum = 10;

//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize = float( 10 );

//射出遅延ランダム幅(0:遅延無し 1以下推奨）
float ShotDelay = 0.1;

//弾く広さ
float UpSize = 17.0;

//曲線の柔らかさ
float CurvePow = 10.0;

//ターゲットの名前
float3 TgtPos : CONTROLOBJECT < string name = "reflect_tgt.x"; >;


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


//角度（0～360推奨）
#define ROTATE 0

//テクスチャ名
texture Line_Tex
<
   string ResourceName = "Line.png";
>;


//--よくわからない人はここから下はさわっちゃだめ--//

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

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
   
   //ランダム値取得
   float4 rnddata = tex2Dlod(rnd,float4(cos(index),0,0,1))*2*3.1415;
   
   
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

	//ワールドのベクトル
	float3 wvec = normalize(world_matrix[2].xyz);

	//ワールド回転行列を作成　ワールドマトリックスをコピーして
	float4x4 world_rotate = world_matrix;
	//移動情報を除去する
	world_rotate[3] = 0;

   //0点の座標
   float3 wpos = world_matrix[3].xyz;

    //現在の移動座標
    float3 nowpos = lerp(wpos,TgtPos,fid);
    
    //次座標
    float3 nextpos = lerp(wpos,TgtPos,fnextid);
    
    //目標点へのベクトル
    float3 TgtVec = normalize(wpos - TgtPos);
    
    //上ベクトル
    float3 UpVec = normalize(cos(rnddata.rgb));
    
    //横ベクトル
    float3 SideVec = normalize(cross(TgtVec,UpVec));
    
    //上ベクトル再計算
    UpVec = normalize(cross(TgtVec,SideVec));

   float3 pos = Pos;
   pos.z = 0;
   pos *= lineSize;
   pos += (1-pow(1-fid,CurvePow))*UpVec*UpSize;      

   pos += nowpos;
   
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   
   //頂点UV値の計算
   Out.texCoord.x = Pos.z;
   Out.texCoord.y = ((Pos.x + Pos.y) + 0.5);
   //UVスクロール
   float fcnum = CloneNum;
   float findex = index;
   
   Out.texCoord.x -= (MaterialDiffuse.a*3-2)+(findex/fcnum)*(ShotDelay);
   Out.color = 1-fid;

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
float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float alpha: TEXCOORD1) : COLOR {
	
	float4 Color = float4(tex2D(LineTexSampler,texCoord));
	Color.a = alpha;
	return Color;
}

technique lineSystem <
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

