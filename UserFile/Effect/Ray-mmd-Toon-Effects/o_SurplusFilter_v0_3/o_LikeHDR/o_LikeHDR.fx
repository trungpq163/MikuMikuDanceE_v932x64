//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　HDR合成っぽいフィルタ v0.1
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 0

//　モノクロ化アルゴリズム指定
//　　1:平均算出法　2:BT.601(NTSC)ベース　3:BT.709(HDTV)ベース（デフォルト）
#define MONO_ALGO 3
//　BT.709ベースでモノクロ化する際に用いるガンマ値（基本: 2.2、推奨値範囲: 1.0 ～ 5.0）
#define GAMMA 2.2

//　簡易色調補正（ 赤, 緑, 青（,α）の順に指定、1で変化なし）
//　　初期設定 1.0, 1.0, 1.0, 1.0
float4 ColorFilter
<
   string UIName = "ColorFilter";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = float4( 0, 0, 0, 1);
   float UIMax = float4( 2, 2, 2, 1);
> = float4( 1.0, 1.0, 1.0, 1.0 );


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {0.5,0.5,0.5,0};
#endif
float ClearDepth  = 1.0;

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//　最明度を記録するためのレンダーターゲット
texture2D HighColorMap : RENDERCOLORTARGET <
	float4 ClearColor = {0,0,0,1};
	int Width = 1;
	int Height = 1;
	string Format = "X8R8G8B8" ;
>;
sampler2D HighColorSamp = sampler_state {
	texture = <HighColorMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//　最暗度を記録するためのレンダーターゲット
texture2D LowColorMap : RENDERCOLORTARGET <
	float4 ClearColor = {1,1,1,1};
	int Width = 1;
	int Height = 1;
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D LowColorSamp = sampler_state {
	texture = <LowColorMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#if MONO_ALGO == 2	//　輝度算出法（BT601:NTSC）
static const float3 LumiFactor = {0.29891, 0.58661, 0.11448};

#elif MONO_ALGO == 3	//　輝度算出法（BT709:HDTV）
static const float3 LumiFactor = {0.2126, 0.7152, 0.0722};
#endif
	
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　プリセットビットマップを元に色の置き換え

float4 PS_passAutoTone(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color = tex2D( ScnSamp, Tex );		//　処理後のピクセルカラーを格納
	float4 ColorOrg = Color;	//　処理前のピクセルカラーを格納
	
	#if MONO_ALGO == 1		//　平均算出法
		float3 negativeGray = 1.0 - dot(Color.rgb, 0.3333333);

	#elif MONO_ALGO == 2	//　輝度算出法（BT601:NTSC）
		float3 negativeGray = 1.0 - dot(LumiFactor, Color.rgb);

	#else					//　輝度算出法（BT709:HDTV）
		float3 negativeGray = pow(Color.rgb, GAMMA);
		negativeGray = 1.0 - pow(dot(LumiFactor, negativeGray.rgb), 1.0 / GAMMA);
	#endif
	
	//　オーバーレイ合成
	Color.rgb = ColorOrg.rgb < 0.5 ? ColorOrg.rgb * negativeGray * 2.0
									: 1.0 - 2.0 * (1.0 - ColorOrg.rgb) * (1.0 - negativeGray);

	//	ソフトライト合成
	Color.rgb = ColorOrg.rgb < 0.5 ? pow(Color.rgb, 2.0 * (1.0 - ColorOrg.rgb))
									: pow(Color.rgb, 1.0 / (2.0 * ColorOrg.rgb));

	//　色調補正量を暗さに比例させて合成
    Color.rgb = lerp(Color.rgb * ColorFilter.rgb * ObjXYZ, Color.rgb, Color.rgb);

	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique AutoTone <
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
		"Pass=AutoToneExec;"
	;
	
> {
	pass AutoToneExec < string Script= "Draw=Buffer;"; > {
//		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_passDraw();
		PixelShader  = compile ps_2_0 PS_passAutoTone();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
