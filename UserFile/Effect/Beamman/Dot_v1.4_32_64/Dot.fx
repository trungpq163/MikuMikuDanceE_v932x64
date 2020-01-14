//ドット絵風になったらいいなエフェクト
//ビームマンP

//アンチエイリアスフラグ trueで有効
#define AA_FLG false

#define VIEWPORT_RATIO 0.25

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

static float2 SampStep = (float2(1,1)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = VIEWPORT_RATIO;
    int MipLevels = 1;
    bool AntiAlias = AA_FLG;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};
// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = VIEWPORT_RATIO;
    string Format = "D24S8";
>;

texture EdgeRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Dot.fx";
    float2 ViewPortRatio = VIEWPORT_RATIO;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = AA_FLG;
    string DefaultEffect = 
        "* = Edge.fx";
>;

//パレットテクスチャ
texture PalletTex
<
   string ResourceName = "pallet.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler PalletView = sampler_state {
    texture = <PalletTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};
//タイルパターンテクスチャ
texture TileTex
<
   string ResourceName = "tile.png";
   float width = 64.0;
   float height = 8.0;
>;
sampler TileView = sampler_state {
    texture = <TileTex>;
    AddressU  = WRAP;
    AddressV = WRAP;
    Filter = NONE;
};


struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};



sampler EdgeView = sampler_state {
    texture = <EdgeRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

VS_OUTPUT VS_passMain( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos; 
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);

    return Out;
}
#define OFFSET (8.0/64.0)
float4 PS_passMain(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color = tex2D(EdgeView,Tex);

    //使用色
    float4 TgtCol = 0;
    float4 TgtCol2 = 0;
    //色差保存用
    float min = 0xffff;
    float min2 = 0xffff;
    
    for(int i=0;i<254;i++)
    {
    	float fi = i;
    	float4 w = tex2D(PalletView,float2(fi/255.0,0.5));

    	float len = length(w.rgb - Color.rgb);
    	if(len <= min)
    	{
    		min2 = min;
    		min = len;
    		TgtCol2 = TgtCol;
    		TgtCol = w;
    	}
    }

    float tgtlen = saturate(length(min-min2)*16);
    float2 TileTex = Tex/(ViewportOffset*16/VIEWPORT_RATIO);
    TileTex = (TileTex/float2(8,1))%float2(OFFSET,1)+float2(OFFSET*(int(tgtlen*8)),0);
    float Tile = tex2D(TileView,TileTex).r;    
    
    TgtCol = lerp(TgtCol,TgtCol2,Tile);
    TgtCol.a = Color.a;
    
    return TgtCol;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Dot <
    string Script = 
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Main;"
    ;
> {

    pass Main < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
