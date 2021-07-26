//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　プロセスカラーへ単純変換するフィルター v0.1
//　　　by おたもん（user/5145841）
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力【初期値】）
#define NON_TRANSPARENT 0

//　透明時の背景色。半透明部分に影響する。（0.0で黒背景、1.1で白背景、初期値は0.5）
#define B_COLOR 0.5

//　淡色モード（ 0: コントラストを変えないように補正する【初期値】、1: 手抜き処理・なんとなく淡くなります）
#define PALE_MODE 0

//　処理モード（ 0: 簡易変換・CMYKのみ計算する、 1: CMYインキの混色(RGB)も追加して計算する【初期値】）
#define HQ_MODE 1

//　JAPANCOLOR_MODE 1 時の無彩色の扱い（ 0: JapanColorの黒インキに基づく、1: 理想的な黒・リッチブラック（R=G=B=0）【初期値】）
#define NEUTRAL_GRAY 1

//　原色【R,G,B,C,M,Y,K】の色指定（ 0: 光の三原色に基づく・無意味、1: 日本のオフセット印刷での標準色に基づく【初期値】）
#define JAPANCOLOR_MODE 1

//　簡易色調補正（ 赤, 緑, 青（,α）の順に指定、1で変化なし）
//　　初期設定 1.0, 1.0, 1.0, 1.0
float3 ColorFilter
<
   string UIName = "簡易色調補正";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float3 UIMin = float3( 0.0, 0.0, 0.0 );
   float3 UIMax = float3( 2.0, 2.0, 2.0 );
> = float3( 1.0, 1.0, 1.0 );

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

#if JAPANCOLOR_MODE		//　JapanColor に基づいた原色のRGB値
 #define RGB_CYAN		float3(         0, 0.62745098, 0.91372549)
 #define RGB_MAGENTA	float3(0.89411765,          0, 0.49803922)
 #define RGB_YELLOW		float3(1.00000000, 0.94509804,          0)

 #define RGB_RED		float3(0.90196078,          0, 0.07058824)
 #define RGB_GREEN		float3(         0, 0.60000000, 0.26666667)
 #define RGB_BLUE		float3(0.11372549, 0.12549020, 0.53333333)

 #if (NEUTRAL_GRAY && !PALE_MODE)	//　黒色のRGB値 上がRGB黒、下がCMYK黒
  #define RGB_KEY		float3(0.0, 0.0, 0.0)
 #else
  #define RGB_KEY		float3(0.13725490, 0.09411765, 0.08235294)
 #endif

#else					//　光の三原色に基づく原色。変化しないため無意味である。
 #define RGB_CYAN		float3(0, 1, 1)
 #define RGB_MAGENTA	float3(1, 0, 1)
 #define RGB_YELLOW		float3(1, 1, 0)

 #define RGB_RED		float3(1, 0, 0)
 #define RGB_GREEN		float3(0, 1, 0)
 #define RGB_BLUE		float3(0, 0, 1)

 #define RGB_KEY		float3(0, 0, 0)
#endif

#define RGB_WHITE		float3(1.0, 1.0, 1.0)
#define RGB_1			float3(1.0, 1.0, 1.0)
#define RGB_0			float3(0.0, 0.0, 0.0)

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1.0, 1.0, 1.0, 1.0};
#else
float4 ClearColor = {B_COLOR, B_COLOR, B_COLOR, 0.0};
#endif
float ClearDepth  = 1.0;

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	int AntiAlias = 1;
	string Format = "A8R8G8B8";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　共通頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　RGBをCMYKに変換しインキ色を元にRGBに再変換する

float4 PS_passRGBtoCMYK(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color;
	float4 ColorOrg = tex2D(ScnSamp, Tex);	//　MMD出力を得る

	//　色調補正量を暗さに比例させて合成
    ColorOrg.rgb = lerp(ColorOrg.rgb * ColorFilter * ObjXYZ, ColorOrg.rgb, ColorOrg.rgb);

	float3 ColorCMYK = RGB_1 - ColorOrg.rgb;		//　CYMKを得る。r=C、g=M、b=Y
	float KEY = min(ColorCMYK.r, min(ColorCMYK.g, ColorCMYK.b));	//　Key Plate = Black

#if PALE_MODE
	ColorCMYK.rgb -= KEY;
#else
	ColorCMYK.rgb = KEY < 1.0 ? (ColorCMYK.rgb - KEY) / (1.0 - KEY) : 0.0;
//	ColorCMYK.rgb = (ColorCMYK.rgb - KEY) / (1.0 - KEY);	//　こっちのほうが高速だが…
#endif

	// ColorCMYK.rgb だと混乱するので分り易い変数名に代入
	float CYAN    = ColorCMYK.r;
	float MAGENTA = ColorCMYK.g;
	float YELLOW  = ColorCMYK.b;

	Color.rgb = RGB_WHITE;	//　紙色 を適用
	Color.rgb *= lerp(RGB_1, RGB_KEY, KEY);	//　Key Plate を適用

#if HQ_MODE	//　C,M,Yの各プレートが重なった時の色（R,G,B）を補正する。これはインキが混ざらない為
	float BLUE  = min(CYAN, MAGENTA);
	float GREEN = min(CYAN, YELLOW);
	float RED   = min(MAGENTA, YELLOW);

  #if PALE_MODE
	MAGENTA -= BLUE + RED;
	CYAN    -= BLUE + GREEN;
	YELLOW  -= GREEN + RED;

  #else
	MAGENTA = (MAGENTA - BLUE - RED)   / ((1.0 - BLUE) * (1.0 - RED));
	CYAN    = (CYAN    - BLUE - GREEN) / ((1.0 - BLUE) * (1.0 - GREEN));
	YELLOW  = (YELLOW  - RED  - GREEN) / ((1.0 - RED)  * (1.0 - GREEN));

  #endif

	Color.rgb *= lerp(RGB_1, RGB_RED, RED);		//　M + Y = R を補正
	Color.rgb *= lerp(RGB_1, RGB_GREEN, GREEN);	//　C + Y = G を補正
	Color.rgb *= lerp(RGB_1, RGB_BLUE, BLUE);		//　C + M = B を補正
#endif
	Color.rgb *= lerp(RGB_1, RGB_CYAN, CYAN);			//　Cyan Plate を適用
	Color.rgb *= lerp(RGB_1, RGB_MAGENTA, MAGENTA);	//　Magenta Plate を適用
	Color.rgb *= lerp(RGB_1, RGB_YELLOW, YELLOW);		//　Yellow Plate を適用

	//　アクセサリの不透明度を元にオリジナルと合成
	Color = lerp(ColorOrg, Color, alpha1);

#if NON_TRANSPARENT
	Color.a = 1.0;
#else
	Color.a = ColorOrg.a;
#endif

	return Color;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

technique o_ProcColor <
	string Script = 
		
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=RGBtoCMYK;"
	;
	
> {
	pass RGBtoCMYK < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_2_0 VS_passDraw();
		PixelShader  = compile ps_2_0 PS_passRGBtoCMYK();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
