
//色
float3 ToonCol = float3(0.25,0.5,1);
//閾値
float Threshold = 5.0;
//線太さ
float LineSize = 0.50;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

//フォグ用Z深度用RT
texture NeonPost_DepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for NeonPost.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    string Format="R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler DepthSamp = sampler_state
{
   Texture = (NeonPost_DepthRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = NONE;
};

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

static float2 SampStep = (float2(LineSize,LineSize)/ViewportSize);

static float2 test[8] = 
		{
			{0,1},{0,-1},
			{1,0},{1,1},{1,-1},
			{-1,0},{-1,1},{-1,-1},
		};

VS_OUTPUT VS_passNeon( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = Pos; 
    Out.Tex = Tex + float2(ViewportOffset.x, 0);

    return Out;
}


float4 PS_passNeon(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 col = tex2D(DepthSamp,Tex);
	//周囲８ピクセルとの深度の差異を保存する変数
	float sabun = 0;
	for(int i=0;i<8;i++)
	{
		float4 w = tex2D(DepthSamp,Tex + test[i]*SampStep);	
		//Zの差分を加算
		sabun += abs(col.r - w.r);
	}
	if( sabun < Threshold )
	{
		sabun = 0;
	}else{
		//sabun = 1;
	}
	sabun *= 0.25;
	sabun = saturate(sabun);
	col = float4(sabun,sabun,sabun,1);
	col.rgb *= ToonCol * MaterialDiffuse.a;
	col.a = 1;
	return col;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique NeonPost <
    string Script = 
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=NeonPost;"
    ;
> {

    pass NeonPost < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_passNeon();
        PixelShader  = compile ps_3_0 PS_passNeon();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
