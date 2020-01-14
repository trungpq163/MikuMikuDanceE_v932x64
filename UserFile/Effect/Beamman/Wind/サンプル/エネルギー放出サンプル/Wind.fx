//風エフェクト
//つくったひと：ロベリア（ビームマンP）


//複製の本数
int CloneNum = 1024;

//テクスチャ名
texture Aura_Tex1
<
   string ResourceName = "Wind_Tex.png";
>;

//全体の再生速度
float AnmSpd = 1;

//全体の高さ
float Height = 100;

//配置時の中央からのずれの乱数幅
float SetPosRand = 0.1;

//風ひとつひとつの高さ最大値
float LocalHeight = 2;

//風の広がり強さ
float WindSizeSpd = 1;

//広がりの乱数幅
float WindSizeRnd = 2;

//テクスチャ繰り返し数
float ScrollNum = 1;

//色設定
float3 Color = float3( 1, 1, 0 );

//明るさ
float Brightness = 15;

//歪み力
float DifPow = 5.0;

//全体の回転速度
float RotateSpd = 1;

//個別回転係数（傾きのばらつき）
float RotateRatio = 0.1;

//最小半径
float MinSize = 1;

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
#define BLENDMODE_DEST INVSRCALPHA


//--よくわからない人はここから下はさわっちゃだめ--//


//計算用テクスチャサイズ
#define TEX_SIZE 256

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
   float2 CenterTex: TEXCOORD3;
   float2 DistTex: TEXCOORD4;
};

//保存用変数
int index = 0;
//発射時間
float ThunderWaitTime = 60;

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;
    float findex = index;
	float offset = findex*(ThunderWaitTime / (CloneNum*ThunderWaitTime)) + sin(findex)*ShotRandOffset;
	float time_buf = time_0_X*AnmSpd + offset;
    float t = time_buf*60;
 
 //ランダム値
  float3 rand = tex2Dlod(rnd, float4(findex/(float)CloneNum,0,0,1));
   t %= ThunderWaitTime;

 
   Out.texCoord.y = (Pos.x + 1)/2 - 0.001;
   Out.texCoord.x = Pos.z * ScrollNum + rand.x;
   if(t > ThunderWaitTime/2 * (60/ThunderWaitTime))
   {
   		t = 0;
   }
   Out.alpha = t / (ThunderWaitTime/2 * (60/ThunderWaitTime));
   
   MinSize += t*0.05*WindSizeSpd*WindSizeRnd*rand.z;
   float h = saturate(t*0.05)*LocalHeight;
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
	float rady = time_0_X*AnmSpd * RotateSpd;
	
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
   
   Out.Pos.y += rand.y*Height;
   Center.y  += rand.y*Height;
   Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
   Center = mul(Center, WorldViewProjMatrix);
   Out.color = t;


	//WVP変換済み座標からスクリーン座標に変換
	float3 TgtPos = Out.Pos.xyz/Out.Pos.w;
	TgtPos.y *= -1;
	TgtPos.xy += 1;
	TgtPos.xy *= 0.5;
	
	Out.DistTex = TgtPos.xy;
	
	float4 wc = mul( TgtPos, WorldViewProjMatrix );

	TgtPos = Center.xyz/Center.w;
	TgtPos.y *= -1;
	TgtPos.xy += 1;
	TgtPos.xy *= 0.5;
	
	Out.CenterTex = TgtPos.xy;   
   return Out;
}

//テクスチャの設定
sampler AuraTex1Sampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Aura_Tex1);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = CLAMP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

//ピクセルシェーダ

//彩度計算用
const float4 calcY = float4( 0.2989f, 0.5866f, 0.1145f, 0.00f );

float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float color: TEXCOORD1,float alpha: TEXCOORD2,float2 CenterTex: TEXCOORD3,float2 DistTex: TEXCOORD4) : COLOR {
   //入力されたテクスチャ座標に従って色を選択する
   
   float4 col = float4(tex2D(AuraTex1Sampler,texCoord+float2(color*0.01,0)));   

   float dif = col.r*DifPow;  
   if(alpha > 0.5) alpha = 1-alpha;

   color = saturate(color*0.05);
   
   col.a = col.r * Brightness * DiffuseColor.a * color * alpha;
 
   col.rgb *= Brightness;
   col.rgb *= Color.rgb;
   
   //テクスチャのベクトル
   float2 tex_vec = normalize(DistTex - CenterTex);
   col.rgb += tex2D(DistortionView,DistTex+tex_vec*0.025*dif).rgb;
   col.rgb *= col.a;
   
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

