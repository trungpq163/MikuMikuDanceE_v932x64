//--------------------------------------------------------------//
// lineSystem
// つくったひと：ロベリア
// ベースにしたシェーダ―：LineSystem
// つくった日：2010/10/9
// こうしんりれき
// 10/10/9:つくった
//--------------------------------------------------------------//

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

//発射時間オフセット
float ShotOffset = 0;
//発射時間オフセット（ランダム値）
float ShotRandOffset = 0;


//複製の本数
int CloneNum = 100;

//ジグザグのランダム幅
float ThunderRand = 1;

//ジグザグの範囲
float ThunderRange = 5;

//ランダム用初期値（複数出した時、疑似乱数が同数にならない為にここは変えておくと吉）
float RandSeed = 0;


//放射の半径
float ShotRange = 3;

//ビルボードフラグ（角度との併用不可。ビルボードが優先される）
#define BILLBORAD true

//角度（0～360推奨）
#define ROTATE 0

//射出時の勢い
float3 StartSpd =  float3( 0,0,0 );

//着弾時の勢い
float3 EndSpd =  float3( 0,0,0 );

//テクスチャ名
texture Line_Tex
<
   string ResourceName = "Line.png";
>;

//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize = float( 1 );

//UVスクロール速度
float UScroll = float(2);
float VScroll = float(0);

//UV繰り返し数
float UWrapNum = float(1);
float VWrapNum = float(1);

//--よくわからない人はここから下はさわっちゃだめ--//

//ラインの長さ：変更不可
#define LINE_LENGTH 100

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

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

//エルミート補完関数
float3 HermiteLerp(float3 s,float3 e,float3 svec,float3 evec,float t)
{
	return (((t-1)*(t-1))*(2*t+1)*s) + ((t*t)*(3-2*t)*e) +((1-(t*t))*t*svec) + ((t-1)*(t*t)*evec);
}
//保存用変数
int index = 0;
texture2D rndtex <
    string ResourceName = "random1024.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
};

//雷の発射時間
float ThunderWaitTime = 60;

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

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
   
   float findex = index;
	float offset = findex*(ThunderWaitTime / (CloneNum*ThunderWaitTime)) + sin(findex)*ShotRandOffset;
	float time_buf = time_0_X + offset;
    float t = time_buf*60;
    
	//ワールドのベクトル
	float3 wvec = normalize(world_matrix[2].xyz);

	//ワールド回転行列を作成　ワールドマトリックスをコピーして
	float4x4 world_rotate = world_matrix;
	//移動情報を除去する
	world_rotate[3] = 0;

	//全体、始点、終点ベクトルをワールド回転
	StartSpd = mul(StartSpd,world_rotate);
	EndSpd = mul(EndSpd,world_rotate);


	//始点ベクトル
	float3 svec = StartSpd;

	//終点ベクトル
	float3 evec = -EndSpd;

   //0点の座標
   float3 wpos = world_matrix[3].xyz;

	//目標座標を決定
	int nw = t/ThunderWaitTime;

	nw += index + nw*123;
	float w = nw;
	float3 TgtPos = float3(0,0,-1);
	
	float radx = tex2Dlod(rnd, float4(w*0.0123,0,0,1))*123;
	float rady = tex2Dlod(rnd, float4(w*0.0456,0,0,1))*456;
	float radz = tex2Dlod(rnd, float4(w*0.0789,0,0,1))*789;
	
	radx %= 2*3.1415;
	rady %= 2*3.1415;
	radz %= 2*3.1415;
	radx -= 3.1415;
	rady -= 3.1415;
	radz -= 3.1415;
	
	radx *= MaterialDiffuse.a;
	rady *= MaterialDiffuse.a;
	radz *= MaterialDiffuse.a;
	
	
   float4x4 matRot;
   
   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(radx),sin(radx),0); 
   matRot[2] = float4(0,-sin(radx),cos(radx),0); 
   matRot[3] = float4(0,0,0,1); 
   
   TgtPos = mul(TgtPos,matRot);
   svec = mul(svec,matRot);
   evec = mul(evec,matRot);
   
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
 
   TgtPos = mul(TgtPos,matRot);
   svec = mul(svec,matRot);
   evec = mul(evec,matRot);
 
   //Z軸回転
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   
   TgtPos = mul(TgtPos,matRot);
   svec = mul(svec,matRot);
   evec = mul(evec,matRot);
	
	TgtPos = normalize(mul(TgtPos,world_rotate));
	TgtPos *= ShotRange*10;
	TgtPos += wpos;


    //現在の移動座標
    float3 nowpos = HermiteLerp(wpos,TgtPos,svec,evec,fid);
    
    //次座標
    float3 nextpos = HermiteLerp(wpos,TgtPos,svec,evec,fnextid);
    

   float3 pos = Pos;
   pos.z = 0;      

   float4 rspos = 0;
   if(BILLBORAD)
   {
	    //ラインのビルボード化
	    float3 vec = normalize(nowpos - nextpos);

		//カメラからのベクトル
		float3 eyevec = normalize(view_trans_matrix[2].xyz);

		//進行ベクトルとカメラベクトルの外積で横方向を得る
		float3 side = normalize(cross(vec,eyevec));

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
	   
   }else{
	   pos *= lineSize;
       rspos = float4(pos,0);
	   //非ビルボードライン処理
	   //ローカル回転処理
	   //回転行列の作成
	   float4x4 matRot;
	   matRot[0] = float4(cos(RAD),sin(RAD),0,0); 
	   matRot[1] = float4(-sin(RAD),cos(RAD),0,0); 
	   matRot[2] = float4(0,0,1,0); 
	   matRot[3] = float4(0,0,0,1); 
	   rspos = mul(rspos,matRot);
   }
   pos.x = rspos.x;
   pos.y = rspos.y;
   pos.z = rspos.z;
   

   
   idx /= ThunderRange;
   pos.x += sin(RandSeed+index+idx*1)*ThunderRand;
   pos.y += sin(RandSeed+index+idx*23)*ThunderRand;
   pos.z += sin(RandSeed+index+idx*456)*ThunderRand;

   pos += nowpos;
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);

   
   t %= ThunderWaitTime;
   if(t > ThunderWaitTime/2 * (60/ThunderWaitTime))
   {
   		t = 0;
   }else{
   		t = 1;
   }
   
   //頂点UV値の計算
   Out.texCoord.x = Pos.z * UWrapNum * 0.5;
   Out.texCoord.y = ((Pos.x + Pos.y) + 0.5) * -VWrapNum;
   //UVスクロール
   Out.texCoord.x += float2(UScroll,VScroll) * time_buf;
   Out.texCoord *= t;
   Out.color = t;

   return Out;
}
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
float4 lineSystem_Pixel_Shader_main(VS_OUTPUT IN,float2 texCoord: TEXCOORD0) : COLOR {
	float4 col = float4(tex2D(LineTexSampler,texCoord));
	if(texCoord.x < 1)
	{
		col = 0;
	}

   return col;
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

