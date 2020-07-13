//風エフェクト コントローラ対応版
//つくったひと：ロベリア（ビームマンP）

//コントローラ名定義
#define CONTORLLER_NAME "WindController_0.pmx"

//パラメータ取得
float3 b_AnmSpd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b再生速度"; >;
float3 b_TexNum : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b繰り返し数"; >;
float3 b_LHeight : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b個別高さ"; >;
float3 b_LRot : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b角度幅"; >;
float3 b_ObjNum : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b複製数"; >;
float3 b_WHeight : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b全体高さ"; >;
float3 b_Scale : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b広がり強さ"; >;
float3 b_ScaleRnd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b広がり幅"; >;
float3 b_WRot : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b回転速度"; >;
float3 b_PosRnd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b位置ずれ"; >;
float3 b_h : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b色相"; >;
float3 b_s : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b彩度"; >;
float3 b_b : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b明度"; >;
float3 b_a : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b透明度"; >;
float3 b_d : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b歪み力"; >;
float3 b_bri : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b輝度"; >;
float3 b_Size : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "b最小半径"; >;


float m_AnmSpd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "再生速度"; >;
float m_TexNum : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "繰り返し数"; >;
float m_LHeight : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "個別高さ"; >;
float m_LRot : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "角度幅"; >;
float m_ObjNum : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "個数調整"; >;
float m_WHeight : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "全体高さ"; >;
float m_Scale : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "広がり強さ"; >;
float m_ScaleRnd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "広がり幅"; >;
float m_WRot : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "回転速度"; >;
float m_PosRnd : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "位置ずれ"; >;
float m_h : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "色相"; >;
float m_s : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "彩度"; >;
float m_b : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "明度"; >;
float m_a : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "透明度"; >;
float m_d : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "歪み力"; >;
float m_bri : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "輝度"; >;
float m_Size : CONTROLOBJECT < string name = CONTORLLER_NAME; string item = "最小半径"; >;





//複製の本数
int CloneNum = 128;

//テクスチャ名
texture Aura_Tex1
<
   string ResourceName = "Wind_Tex.png";
>;

//全体の再生速度
float AnmSpd = 2;

//全体の高さ
float Height = 30;

//配置時の中央からのずれの乱数幅
float SetPosRand = 32;

//風ひとつひとつの高さ最大値
float LocalHeight = 2;

//風の広がり強さ
float WindSizeSpd = 5;

//広がりの乱数幅
float WindSizeRnd = 0;

//テクスチャ繰り返し数
float ScrollNum = 1;

//色設定
float3 Color = float3( 1, 1, 1 );

//明るさ
float Brightness = 10;

//歪み力
float DistPow = 10;

//全体の回転速度
float RotateSpd = 0.5;

//個別回転係数（傾きのばらつき）
float RotateRatio = 0.25;

//最小半径
float MinSize = 5;

//発射時間オフセット（ランダム値）
float ShotRandOffset = 0;

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


//--よくわからない人はここから下はさわっちゃだめ--//

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//HSB変換用色テクスチャ
texture2D ColorPallet <
    string ResourceName = "ColorPallet.png";
>;
sampler PalletSamp = sampler_state {
    texture = <ColorPallet>;
    AddressU  = WRAP;
    AddressV = CLAMP;
};


//計算用テクスチャサイズ
#define TEX_SIZE 1024

#define TEX_WIDTH TEX_SIZE
#define TEX_HEIGHT TEX_SIZE

texture DistortionRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for DistortionField.fx";
    int Width = TEX_SIZE;
    int Height = TEX_SIZE;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;";
>;

sampler DistortionView = sampler_state {
    texture = <DistortionRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



texture2D rndtex <
    string ResourceName = "random1024.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
};


float time_0_X : Time;
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD(x) ((x * PI) / 180.0)

float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float alpha: TEXCOORD2;
   float4 CenterPos: TEXCOORD3;
   float4 DistPos: TEXCOORD4;
};

//保存用変数
int index = 0;
//発射時間
float ThunderWaitTime = 60;

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){

	m_ObjNum = saturate(m_ObjNum+(b_ObjNum.x)*0.1);
	m_Size += (b_Size.x)*0.025;
	m_PosRnd += (b_PosRnd.x)*0.005;
	m_LHeight += (b_LHeight.x)*0.1;
	m_LRot += (b_LRot.x)*0.1;
	m_WHeight += (b_WHeight.x)*0.1;
	m_Scale += (b_Scale.x)*0.1;
	m_ScaleRnd += (b_ScaleRnd.x)*0.1;
	m_WRot += (b_WRot.x)*0.1;
	m_TexNum += (b_TexNum.x)*0.1;
	m_AnmSpd += (b_AnmSpd.x)*0.1;



	SetPosRand *= m_PosRnd;
	WindSizeSpd*= m_Scale;
	WindSizeRnd+= m_ScaleRnd*2;
	ScrollNum+=m_TexNum*5;
	RotateRatio *= m_LRot;
	RotateSpd *= m_WRot;
	MinSize *= m_Size;
	
   VS_OUTPUT Out;
    float fCloneNum = CloneNum;
    fCloneNum *= m_ObjNum;
    float findex = index;
	float offset = findex*(ThunderWaitTime / (fCloneNum*ThunderWaitTime)) + sin(findex)*ShotRandOffset;
	float time_buf = time_0_X*AnmSpd*m_AnmSpd + offset;
    float t = time_buf*60;
 
 //ランダム値
  float3 rand = tex2Dlod(rnd, float4(findex/(float)fCloneNum,0,0,1));
   t %= ThunderWaitTime;

 
   Out.texCoord.y = (Pos.x + 1)/2 - 0.001;
   Out.texCoord.x = Pos.z * ScrollNum + rand.x;
   if(t > ThunderWaitTime/2 * (60/ThunderWaitTime))
   {
   		t = 0;
   }
   Out.alpha = t / (ThunderWaitTime/2 * (60/ThunderWaitTime));
   
   MinSize += t*0.05*WindSizeSpd*WindSizeRnd*rand.z;
   float h = saturate(t*0.05)*LocalHeight*m_LHeight;
   //Z値（0～１）から角度を計算し、ラジアン値に変換する
   float rad = RAD(Pos.z * 360);
   
   
   //--xz座標上に配置する
   
   //xがマイナス=外周
   if(Pos.x < 0)
   {
   		Out.Pos.x = cos(rad) * MinSize;	
   		Out.Pos.z = sin(rad) * MinSize;
   		//y値は高さパラメータそのまま
   		Out.Pos.y = h/2;
   }else{
	   //内周
   		Out.Pos.x = cos(rad) * MinSize;		   
   		Out.Pos.z = sin(rad) * MinSize;
   		Out.Pos.y = -h/2;
   } 
   float4 Center = Out.Pos;
   Center.y = 0;
   Center.w = 1;
   Out.Pos.w = 1;
   
	float radx = (-0.5 + rand.x)*2*2*3.1415;
	float radz = (-0.5 + rand.z)*2*2*3.1415;
	float rady = time_0_X*RotateSpd*10*m_WRot;
	radx *= RotateRatio;
	radz *= RotateRatio;

  float4x4 matRot;
   
   //Y軸回転 
   matRot[0] = float4(cos(rady),0,-sin(rady),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(rady),0,cos(rady),0); 
   matRot[3] = float4(0,0,0,1); 
 
   Out.Pos = mul(Out.Pos,matRot);
   Center = mul(Center,matRot);
   
   
   //X軸回転
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(radx),sin(radx),0); 
   matRot[2] = float4(0,-sin(radx),cos(radx),0); 
   matRot[3] = float4(0,0,0,1); 
   
   Out.Pos = mul(Out.Pos,matRot);
   Center = mul(Center,matRot);
 
   //Z軸回転
   matRot[0] = float4(cos(radz),sin(radz),0,0); 
   matRot[1] = float4(-sin(radz),cos(radz),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   
   Out.Pos = mul(Out.Pos,matRot);
   Center = mul(Center,matRot);
   
   Out.Pos.x += rand.x*SetPosRand-SetPosRand/2;
   Out.Pos.z += rand.z*SetPosRand-SetPosRand/2;
   
   Out.Pos.y += rand.y*Height*m_WHeight;
   Center.y  += rand.y*Height*m_WHeight;
   Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
   Center = mul(Center, WorldViewProjMatrix);
   Out.color = t;


	Out.DistPos = Out.Pos;
	Out.CenterPos = Center;
	
	//個数上限チェック
	if(findex >= fCloneNum)
	{
		Out.Pos.w = -2;
	}
	
   return Out;
}

//テクスチャの設定
sampler AuraTex1Sampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Aura_Tex1);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループCenter
   ADDRESSU = WRAP;
   ADDRESSV = CLAMP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

//ピクセルシェーダ

float4 lineSystem_Pixel_Shader_main(VS_OUTPUT IN) : COLOR {
   //入力されたテクスチャ座標に従って色を選択する
   	
	m_h += (b_h.x)*0.1;
	m_s += (b_s.x)*0.1;
	m_b += (b_b.x)*0.1;
	m_a = saturate(m_a + (b_a)*0.1);
	m_d += (b_d.x)*0.1;
	m_bri += (b_bri.x)*0.1;	
	
	//アルファ値
	float a = saturate(IN.alpha+m_a);
	
	float4 col;
	//デカールテクスチャ形状読み込み
	float4 decal = float4(tex2D(AuraTex1Sampler,IN.texCoord));   

	//--歪み入り背景取得--//
	
	//スクリーン上座標を計算
	float3 Center;
	Center = IN.CenterPos.xyz/IN.CenterPos.w;
	Center.y *= -1;
	Center.xy += 1;
	Center.xy *= 0.5;
	float3 DistTgt;
	DistTgt = IN.DistPos.xyz/IN.DistPos.w;
	DistTgt.y *= -1;
	DistTgt.xy += 1;
	DistTgt.xy *= 0.5;
	
	
	
	DistPow = m_d*DistPow*a;
	float dif = decal.r*DistPow;  
	//テクスチャのベクトル
	float2 tex_vec = normalize(DistTgt.xy - Center.xy);
	col.rgb = tex2D(DistortionView,DistTgt.xy+tex_vec*0.025*dif).rgb;
	col.a = 1;

	//パレットから色取得
	float4 pallet = tex2D(PalletSamp,float2(m_h,m_s))*(1-m_a);
	pallet.a = 1;
	//デカールの白成分に従って削る
	pallet.rgb *= (pallet.rgb + decal.r) * decal.r * a * 10;
	//各色成分で1を超えた分は他色に溢れる
	float3 over_col = saturate((pallet.rgb - 0.5)*0.5);
	float over = over_col.r + over_col.g + over_col.b;
	pallet.rgb += over*5*m_bri;
	pallet.rgb *= (1-IN.alpha);
	pallet.rgb *= (1-m_a);
	//ベースに加算する
	col += pallet;
	col -= m_b*5*(1-m_a);
	col = saturate(col);
	col.a = decal.r*10;
	col.a *= 1-saturate(IN.alpha);

	return col;
}

//テクニックの定義
technique lineSystem <
    string Script = 
		//描画対象をメイン画面に
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    //パスの選択
		"LoopByCount=CloneNum;"
        "LoopGetIndex=index;"
	    "Pass=lineSystem;"
        "LoopEnd=;"
    ;
> {
   //メインパス
   pass lineSystem
   {
      //Z値の考慮：する
      ZENABLE = TRUE;
      //Z値の描画：しない
      ZWRITEENABLE = FALSE;
      //カリングオフ（両面描画
      CULLMODE = NONE;
      //αブレンドを使用する
      ALPHABLENDENABLE = TRUE;
      //αブレンドの設定（詳しくは最初の定数を参照）
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      //使用するシェーダを設定
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main();
   }
}

