

float MaxLength = 1500;
float MaxHeight = 2000;

////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//フォグ用Z深度用RT
texture ZFogRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for ZFog_post.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    string Format="G32R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler FogSamp = sampler_state
{
   Texture = (ZFogRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = NONE;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//アルファ値取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スケール値取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;


float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 


static float4 FogColor = float4(matWorld._41, matWorld._42, matWorld._43, alpha1);//float4(0.05, 0.05, 0.05, 0.5);


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


struct VS_OUTPUT {
    float4 Pos      : POSITION;
    float2 Tex      : TEXCOORD0;
};

VS_OUTPUT VS_passFog( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos; 
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_passFog(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color = FogColor;
    
    float4 FogValue = tex2D( FogSamp, Tex );
    float z = FogValue.r;
    
    float a = saturate(z / MaxLength / scaling);
    
    a *= (1 - saturate(FogValue.y / MaxHeight) * 0.5);
    
    Color.a *= a;
    
    a = 0.1;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique ZFogPost <
    string Script = 
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        "Pass=Fog;"
    ;
> {

    pass Fog < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_passFog();
        PixelShader  = compile ps_2_0 PS_passFog();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
