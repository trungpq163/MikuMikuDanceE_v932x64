////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FunyaFunya_Post.fx ver0.0.2  ふにゃふにゃエフェクト(ポストエフェクトver)
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

bool WaveType <      // 揺れ方の種類を切り替え
   string UIName = "揺れ方のタイプ";
   bool UIVisible =  true;
> = true;

float2 WaveNumber <  // 波数ベクトル(大きくすると波形が小刻みになります)
   string UIName = "波数ベクトル";
   string UIHelp = "大きくすると波形が小刻みになります";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = float2(0.0, 20.0);

float AngularFrequency <  // 角周波数(大きくすると波の進行が速くなります)
   string UIName = "角周波数";
   string UIHelp = "大きくすると波の進行が速くなります";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 30.0;
> = 2.0;

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

float Amplitude = 0.01;  // 波の振幅(画面幅の比率で入力)

float time : Time;

// アクセサリパラメータ
float3 AcsPos : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float  AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5f, 0.5f)/ViewportSize);
static float2 SampStep = (float2(1,1)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// ふにゃふにゃ描画

struct VS_OUTPUT {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Funya( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
//    Out.Tex = Tex + float2(0, ViewportOffset.y);
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


// ピクセルシェーダ
float4 PS_Funya( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

    float a = Amplitude * AcsSi*0.1f;
    float kx = WaveNumber.x + AcsPos.x;
    float ky = WaveNumber.y + AcsPos.y;
    float freq = AngularFrequency + AcsPos.z;

    float2 wave;
    if( WaveType ){
        wave.x = a*sin(kx*Tex.x - ky*Tex.y - freq*time);
        wave.y = a*sin(ky*Tex.x + kx*Tex.y - freq*time);
    }else{
        wave.x = a*sin(ky*Tex.y - freq*time);
        wave.y = a*sin(kx*Tex.x - freq*time);
    }

    Color = tex2D( ScnSamp, Tex+wave );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique FunyaTech <
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
	    "Pass=FunyaPass;"
    ;
> {
    pass FunyaPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Funya();
        PixelShader  = compile ps_2_0 PS_Funya();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
