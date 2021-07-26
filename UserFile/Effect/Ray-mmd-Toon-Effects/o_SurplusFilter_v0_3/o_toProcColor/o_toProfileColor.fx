//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　プロセスカラーへ単純変換するフィルター v0.1
//　　　by おたもん（user/5145841）
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　Profileフォルダ内のインク色プロファイルを指定する。例："JapanColor_Coat"、"Sepia" など
#define INK_PROFILE "JapanColor_Coat"

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力【初期値】）
#define NON_TRANSPARENT 1

//　透明時の背景色。半透明部分に影響する。（0.0で黒背景、1.1で白背景、初期値は0.5）
#define B_COLOR 0.5

//　淡色モード（ 0: コントラストを変えないように補正する【初期値】、1: 手抜き処理・なんとなく淡くなります）
#define PALE_MODE 0

//　処理モード（ 0: 簡易変換・CMYKのみ計算する、 1: CMYインキの混色(RGB)も追加して計算する【初期値】）
#define HQ_MODE 1

//　無彩色の扱い（ 0: 黒インキに基づく、1: 理想的な黒【初期値】）
#define NEUTRAL_GRAY 0

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

//　トーン補正用プリセットビットマップ
texture2D Tone <
	string ResourceName = "Profile\\"INK_PROFILE".png";
	int MipLevels = 1;
	string Format = "X8R8G8B8";
>;
sampler ToneSamp = sampler_state{
	Texture = <Tone>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

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
#define COLOR_GRID (1.0 / 16.0) + (1.0 / 8.0)
static const float3 RGB_WHITE   = tex2D(ToneSamp, float2( COLOR_GRID * 0, 0.5)).rgb;
static const float3 RGB_RED     = tex2D(ToneSamp, float2( COLOR_GRID * 1, 0.5)).rgb;
static const float3 RGB_YELLOW  = tex2D(ToneSamp, float2( COLOR_GRID * 2, 0.5)).rgb;
static const float3 RGB_GREEN   = tex2D(ToneSamp, float2( COLOR_GRID * 3, 0.5)).rgb;
static const float3 RGB_CYAN    = tex2D(ToneSamp, float2( COLOR_GRID * 4, 0.5)).rgb;
static const float3 RGB_BLUE    = tex2D(ToneSamp, float2( COLOR_GRID * 5, 0.5)).rgb;
static const float3 RGB_MAGENTA = tex2D(ToneSamp, float2( COLOR_GRID * 6, 0.5)).rgb;
#if NEUTRAL_GRAY
static const float3 RGB_KEY     = float3(0,0,0);
#else
static const float3 RGB_KEY     = tex2D(ToneSamp, float2( COLOR_GRID * 7, 0.5)).rgb;
#endif

float4 PS_passRGBtoCMYK(float2 Tex: TEXCOORD0) : COLOR
{
	float4 Color;
	float4 ColorOrg = tex2D(ScnSamp, Tex);	//　MMD出力を得る

	float3 ColorCMYK = 1.0 - ColorOrg.rgb;		//　CYMKを得る。r=C、g=M、b=Y
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

	Color.rgb = RGB_WHITE;	//　紙色を適用
	Color.rgb *= lerp(1.0, RGB_KEY, KEY);	//　Key Plate を適用

#if HQ_MODE	//　C,M,Yの各プレートが重なった時の色（R,G,B）を補正する。これはインキが混ざらない為
	float BLUE = min(CYAN, MAGENTA);
	MAGENTA -= BLUE;
	CYAN    -= BLUE;

	float GREEN = min(CYAN, YELLOW);
	YELLOW -= GREEN;
	CYAN   -= GREEN;

	float RED = min(MAGENTA, YELLOW);
	YELLOW  -= RED;
	MAGENTA -= RED;

  #if PALE_MODE == 0
	MAGENTA /= 1.0 - BLUE;
	CYAN    /= 1.0 - BLUE;

	YELLOW  /= 1.0 - GREEN;
	CYAN    /= 1.0 - GREEN;

	YELLOW  /= 1.0 - RED;
	MAGENTA /= 1.0 - RED;
  #endif

	Color.rgb *= lerp(1.0, RGB_RED, RED);		//　M + Y = R を補正
	Color.rgb *= lerp(1.0, RGB_GREEN, GREEN);	//　C + Y = G を補正
	Color.rgb *= lerp(1.0, RGB_BLUE, BLUE);		//　C + M = B を補正
#endif
	Color.rgb *= lerp(1.0, RGB_CYAN, CYAN);			//　Cyan Plate を適用
	Color.rgb *= lerp(1.0, RGB_MAGENTA, MAGENTA);	//　Magenta Plate を適用
	Color.rgb *= lerp(1.0, RGB_YELLOW, YELLOW);		//　Yellow Plate を適用

	//　色調補正量を暗さに比例させて合成
    Color.rgb = lerp(Color.rgb * ColorFilter * ObjXYZ, Color.rgb, Color.rgb);

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

		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader  = compile ps_3_0 PS_passRGBtoCMYK();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
