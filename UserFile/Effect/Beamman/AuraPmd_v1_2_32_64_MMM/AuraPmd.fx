//MME_AuraPMD ver1.0
//つくったひと：ロベリア（ビームマンP）

float4x4 World : CONTROLOBJECT < string name = "(self)";string item = "センター";>;

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
texture Aura_Tex1
<
   string ResourceName = "MME_Aura_tex1.png";
>;
texture Aura_Tex2
<
   string ResourceName = "MME_Aura_tex2.png";
>;

//外周サイズ（Si外周モーフ*このサイズ）
float OutSize = float( 10 );
//内周サイズ（Si内周モーフ*このサイズ）
float InSize = float( 10 );
//高さ(Si高さモーフ*このサイズ)
float Height = float( 10 );
//全体の拡大（縮小）最大値
float MaxSize = float(25);

//分割角度（360で全周囲）
float SpritRot = float( 360 );

//テクスチャスクロール初期速度
float ScrollSpd = float( 0 );

//テクスチャ繰り返し最大数
float ScrollNum = float( 10 );

//色設定
float4 Color = float4( 1, 1, 1, 1 );

//明るさ最大値
float Brightness = float( 10 );

//初期透明度
float DefAlpha = float( 1 );

float param_outsize : CONTROLOBJECT < string name = "(self)"; string item = "Si外周+"; >;
float param_insize : CONTROLOBJECT < string name = "(self)"; string item = "Si内周+"; >;
float param_height : CONTROLOBJECT < string name = "(self)"; string item = "Si高さ+"; >;
float param_outsize_m : CONTROLOBJECT < string name = "(self)"; string item = "Si外周-"; >;
float param_insize_m : CONTROLOBJECT < string name = "(self)"; string item = "Si内周-"; >;
float param_height_m : CONTROLOBJECT < string name = "(self)"; string item = "Si高さ-"; >;
float param_local_p : CONTROLOBJECT < string name = "(self)"; string item = "Si全体+"; >;
float param_local_m : CONTROLOBJECT < string name = "(self)"; string item = "Si全体-"; >;
float param_h : CONTROLOBJECT < string name = "(self)"; string item = "色相"; >;
float param_s : CONTROLOBJECT < string name = "(self)"; string item = "彩度"; >;
float param_b : CONTROLOBJECT < string name = "(self)"; string item = "明度"; >;
float param_split : CONTROLOBJECT < string name = "(self)"; string item = "分割角度"; >;
float param_scroll_p : CONTROLOBJECT < string name = "(self)"; string item = "速度+"; >;
float param_scroll_m : CONTROLOBJECT < string name = "(self)"; string item = "速度-"; >;
float param_scroll_num : CONTROLOBJECT < string name = "(self)"; string item = "繰り返し"; >;
float param_endanm1 : CONTROLOBJECT < string name = "(self)"; string item = "消アニメ1"; >;
float param_endanm2 : CONTROLOBJECT < string name = "(self)"; string item = "消アニメ2"; >;
float param_alpha : CONTROLOBJECT < string name = "(self)"; string item = "透明度"; >;



//--よくわからない人はここから下はさわっちゃだめ--//
//HSB変換用色テクスチャ
texture2D ColorPallet <
    string ResourceName = "ColorPallet.png";
>;
sampler PalletSamp = sampler_state {
    texture = <ColorPallet>;
};


float time_0_X : Time;
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD(x) ((x * PI) / 180.0)

float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION,float2 Tex:TEXCOORD0){
   VS_OUTPUT Out;
   
   //パラメータ適用
   OutSize = OutSize * (param_outsize - param_outsize_m);
   InSize = InSize * (param_insize - param_insize_m);
   Height = Height * (param_height - param_height_m);
   SpritRot = SpritRot*(1-param_split);
   ScrollSpd += (param_scroll_p - param_scroll_m);
   
   Out.texCoord.x = Tex.y*(1+(ScrollNum*param_scroll_num));
   Out.texCoord.y = Tex.x;
   
   //Z値（0～１）から角度を計算し、ラジアン値に変換する
   float rad = RAD(Tex.y * SpritRot);

   //--xz座標上に配置する
   //テクスチャ座標が0.5以下
   if(Tex.x < 0.5)
   {
   		Out.Pos.x = cos(rad) * OutSize;	
   		Out.Pos.z = sin(rad) * OutSize;
   		//y値は高さパラメータそのまま
   		//WAVEの場合はTR値によって高さ変化
   		float w = Height;
	    w = lerp(0,Height,(1-param_endanm1));
   		Out.Pos.y = w;
   }else{
	   //内周
	   //DISCの場合はTR値によって内周変化
	    float w = InSize;
	    w = lerp(OutSize,InSize,(1-param_endanm2));
   		Out.Pos.x = cos(rad) * w;		   
   		Out.Pos.z = sin(rad) * w;
   		Out.Pos.y = 0;
   } 
   Out.Pos *= (param_local_p - param_local_m)*MaxSize + 2.0;
   Out.Pos.w = 1;
   Out.Pos = mul(Out.Pos, World);
   Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
   Out.color = (time_0_X * ScrollSpd) % 1.0;
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
//テクスチャの設定
sampler AuraTex2Sampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Aura_Tex2);
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

float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float color: TEXCOORD1) : COLOR {
	//入力されたテクスチャ座標に従って色を選択する

	float2 add = float2(color,0);
	float4 col = float4(tex2D(AuraTex1Sampler,texCoord + add));
	add.x += 0.1;
	float4 col2 = float4(tex2D(AuraTex2Sampler,texCoord - add));

	float4 c = col * col2;

	float r = c * calcY;
	r *= param_b*Brightness;

	float4 pallet = tex2D(PalletSamp,float2(param_h,param_s));
	Color.rgb *= pallet.rgb;
	c *= Color + r;

	c.a = max(col.a,col2.a) * (1-param_endanm1) * (1-param_endanm2) * DefAlpha * (1-param_alpha);

	return c;
}

//テクニックの定義
technique lineSystem_ss  < string MMDPass = "object_ss"; > {
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
      VertexShader = compile vs_2_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 lineSystem_Pixel_Shader_main();
   }
}
technique lineSystem  < string MMDPass = "object"; > {
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
      VertexShader = compile vs_2_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 lineSystem_Pixel_Shader_main();
   }
}
technique EdgeTec < string MMDPass = "edge"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}