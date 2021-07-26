//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　1ピクセルボカし v0.1
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//　高画質モード（ 0：一般的な整数テクスチャを使います。1 が重かったりエラーが出る場合に使用して下さい。
//　　　　　　　　 1：16bit 浮動小数点数テクスチャを使います。特に問題なければこちらをご使用ください）
//　　　　　　　　 2：R 要素のみの32bit 浮動小数点数テクスチャを使います。XDOF の DepthRT 専用）
#define HQ_MODE 1

//　非透過モード 0 時の背景色（0.0：黒色、0.5：灰色【初期値。o_disAlphaBlendと併用する場合向け】、1.0：白色）
#define B_COLOR 0.5


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {B_COLOR,B_COLOR,B_COLOR,0};
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

static float2 halfPixel = float2(1.0f, 1.0f) / (ViewportSize * 2);
static float2 fullPixel = float2(1.0f, 1.0f) / (ViewportSize);
static float AspectRatio = (ViewportSize.x / ViewportSize.y);


//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
#if HQ_MODE == 1
	string Format = "A16B16G16R16F";
#elif HQ_MODE == 2
	string Format = "D3DFMT_R32F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passBlur( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　周囲ピクセルの色と混ぜることでボカす
float4 PS_passBlur(float2 inTex: TEXCOORD0) : COLOR
{
	float4 Color = tex2D( ScnSamp, inTex );		//　処理後のピクセルカラーを格納
	float4 ColorOrg = Color;	//　処理前のピクセルカラーを格納
	float4 ColorMono = Color;

	Color += tex2D(ScnSamp, float2(inTex.x + halfPixel.x, inTex.y + halfPixel.y))
					+ tex2D(ScnSamp, float2(inTex.x + halfPixel.x, inTex.y - halfPixel.y))
					+ tex2D(ScnSamp, float2(inTex.x - halfPixel.x, inTex.y + halfPixel.y))
					+ tex2D(ScnSamp, float2(inTex.x - halfPixel.x, inTex.y - halfPixel.y));
	Color *= 0.2;

	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique Blur <
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
		"Pass=BlurExec;"
	;
	
> {
	pass BlurExec < string Script= "Draw=Buffer;"; > {
//		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_passBlur();
		PixelShader  = compile ps_2_0 PS_passBlur();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
