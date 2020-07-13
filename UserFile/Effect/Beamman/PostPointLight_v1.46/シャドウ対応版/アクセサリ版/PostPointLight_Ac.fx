
#define WIDTH       1024
#define HEIGHT      1024
#define ANTI_ALIAS  false

#define Z_MAX   1024.0
#define Z_MIN   1.0

//自身の座標
float3 Position : CONTROLOBJECT < string name = "(self)";>;
//ポイントライトの減衰力(1～推奨）
float LightPow = 1.0;

texture EnvMapF: OFFSCREENRENDERTARGET <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format="R32F";
    bool AntiAlias = ANTI_ALIAS;
    int Miplevels=1;
    string DefaultEffect = 
        "self = hide;"
        "*=DPEnvMapF.fx;";
>;

sampler sampEnvMapF = sampler_state {
    texture = <EnvMapF>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture EnvMapB: OFFSCREENRENDERTARGET <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format="R32F";
    bool AntiAlias = ANTI_ALIAS;
    int Miplevels=1;
    string DefaultEffect = 
        "self = hide;"
        "*=DPEnvMapB.fx;";
>;

sampler sampEnvMapB = sampler_state {
    texture = <EnvMapB>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

float4 texDP(sampler2D sampFront, sampler2D sampBack, float3 vec,float2 add) {
    vec = normalize(vec);
    bool front = (vec.z >= 0);
    if ( !front ) vec.xz = -vec.xz;
    
    float2 uv;
    uv = vec.xy / (1+vec.z);
    uv.y = -uv.y;
    uv = uv * 0.5 + 0.5;
    uv += add;
    
    if ( front ) {
        return tex2D(sampFront, uv);
    } else {
        return tex2D(sampBack, uv);
    }
}
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//ライト描画用RT
texture PointLightRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for PostPointLight.fx";
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    
    string DefaultEffect = 
        "self = hide;"
        "* = RT_Model.fx;";
>;
sampler PPL_Samp = sampler_state
{
   Texture = (PointLightRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};
//座標描画用RT
texture PointLightPosRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for PostPointLight.fx";
    int Width = 1024;
    int Height = 1024;
    float4 ClearColor = { 0, 0, 0, 0 };
    string Format = "D3DFMT_A32B32G32R32F" ;
    float ClearDepth = 1.0;
    
    string DefaultEffect = 
        "self = hide;"
        "* = RT_ModelPos.fx;";
>;
sampler PPLPos_Samp = sampler_state
{
   Texture = (PointLightPosRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

static float2 SampStep = (float2(2,2)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_Main( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}
#define Z_MAX   1024.0
#define Z_MIN   1.0

float4 PS_Main(float2 Tex: TEXCOORD0) : COLOR
{
    float4 WPos = tex2D(PPLPos_Samp,Tex);
    float len = length(WPos.xyz - Position);
    len = (len - Z_MIN)/(Z_MAX-Z_MIN);
    float3 Vec = normalize(WPos.xyz - Position);
    float z = texDP(sampEnvMapF,sampEnvMapB,Vec,float2(0,0));
	float comp = 0;
	
	float add = 0.001;
	//5点サンプリング
	comp += 1-saturate(max(len - texDP(sampEnvMapF,sampEnvMapB,Vec,float2(0,0)) , 0.0f)*1500-0.3f);
	comp += 1-saturate(max(len - texDP(sampEnvMapF,sampEnvMapB,Vec,float2(add,0)) , 0.0f)*1500-0.3f);
	comp += 1-saturate(max(len - texDP(sampEnvMapF,sampEnvMapB,Vec,float2(0,add)) , 0.0f)*1500-0.3f);
	comp += 1-saturate(max(len - texDP(sampEnvMapF,sampEnvMapB,Vec,float2(-add,0)) , 0.0f)*1500-0.3f);
	comp += 1-saturate(max(len - texDP(sampEnvMapF,sampEnvMapB,Vec,float2(0,-add)) , 0.0f)*1500-0.3f);
	comp /= 5;
	
	
    float4 Color;
	Color = tex2D(PPL_Samp,Tex);
	Color.rgb = pow(Color.rgb,LightPow);
	Color.rgb *= comp;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique PostPointLight <
    string Script = 
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Main;"
    ;
> {

    pass Main < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = ONE;
		DESTBLEND = ONE;
        VertexShader = compile vs_2_0 VS_Main();
        PixelShader  = compile ps_2_0 PS_Main();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
