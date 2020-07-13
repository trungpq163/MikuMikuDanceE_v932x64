//本体色
float3 MainColor = float3(255,64,0)/255;

//残像色
float3 BlurColor = float3(255,32,0)/255;



//オニオン描画モード
//指定可能定数
//1:SOLID 	: ポリゴン描画
//2:WIREFRAME : ワイヤーフレーム描画
//3:POINT		: 頂点描画

#define Onion_DrawMode SOLID
//#define Onion_DrawMode WIREFRAME
//#define Onion_DrawMode POINT

//#define ONION_ADD
//オニオン描画数
//最大４まで
#define Onion_DrawNum 4

//オニオン透明度　初期値
float Onion_Alpha = 0.75;

//オニオン透明度　減衰値
float Onion_AlphaSub = 0.5;



//良くわからない人はここから触らない

int loop_index;
int count = Onion_DrawNum;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

#define VPBUF_WIDTH  256
#define VPBUF_HEIGHT 256
//頂点座標バッファサイズ
static float2 VPBufSize = float2(VPBUF_WIDTH, VPBUF_HEIGHT);
static float2 VPBufOffset = float2(0.5 / VPBUF_WIDTH, 0.5 / VPBUF_HEIGHT);

shared texture VertexPosRT: OFFSCREENRENDERTARGET <
    string Description = "SaveVertexPos for OnionSkin.fx";

    int width = VPBUF_WIDTH * 2;
    int height = VPBUF_HEIGHT * 2;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string Format="A32B32G32R32F";
    string DefaultEffect = 
        "self = SavePos.fx;"
        "* = hide;"
    ;
>;

sampler PosSamp = sampler_state {
    texture = <VertexPosRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


//頂点座標バッファ取得
float4 getVertexPosBuf(int index)
{
    float4 Color = 0;
    float2 tpos = 0;
	tpos.x = modf((float)index / VPBUF_WIDTH, tpos.y);
	tpos.y /= VPBUF_HEIGHT;
	tpos += VPBufOffset;
	tpos.xy *= 0.5;
	
	tpos.x += (loop_index%2)*0.5;
	tpos.y += (loop_index/2)*0.5;
	
	Color = tex2Dlod(PosSamp, float4(tpos,0,0));
	
	return Color;
}
// 頂点シェーダ

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * AmbientColor;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

VS_OUTPUT Onion_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,int index: _INDEX, uniform bool useTexture, uniform bool useSphereMap)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	Pos.xyz = getVertexPosBuf(index);
	
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;

    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
	
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color.rgb *= tex2D(ObjSphareSampler,IN.SpTex).rgb;
    }
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    }
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    Color.rgb = length(Color.rgb)*MainColor;
    return Color;
}
// ピクセルシェーダ
float4 Onion_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR0
{
    // スペキュラ色計算
    float4 Color = IN.Color;
	
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color.rgb *= tex2D(ObjSphareSampler,IN.SpTex).rgb;
    }
    Color.a *= Onion_Alpha * pow(Onion_AlphaSub,loop_index);
    Color.rgb = length(Color.rgb)*BlurColor;
    return Color;
}

//ループ用定数
#define LOOPSCR	"LoopByCount=count;" \
                "LoopGetIndex=loop_index;" \
                "Pass=DrawObject_Onion;" \
                "LoopEnd=;" \
                 "Pass=DrawObject;" \
                
// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; 
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, false);
        PixelShader  = compile ps_3_0 Onion_PS(false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; 
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, false);
        PixelShader  = compile ps_3_0 Onion_PS(true, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; 
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, true);
        PixelShader  = compile ps_3_0 Onion_PS(false, true);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, true);
        PixelShader  = compile ps_3_0 Onion_PS(true, true);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, false);
        PixelShader  = compile ps_3_0 Onion_PS(false, false);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, false);
        PixelShader  = compile ps_3_0 Onion_PS(true, false);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
    
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, true);
        PixelShader  = compile ps_3_0 Onion_PS(false, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
    
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, true);
        PixelShader  = compile ps_3_0 Onion_PS(true, true);
    }
}
technique MainTec0_SS < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, false);
        PixelShader  = compile ps_3_0 Onion_PS(false, false);
    }
}

technique MainTec1_SS < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, false);
        PixelShader  = compile ps_3_0 Onion_PS(true, false);
    }
}

technique MainTec2_SS < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, true);
        PixelShader  = compile ps_3_0 Onion_PS(false, true);
    }
}

technique MainTec3_SS < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, true);
        PixelShader  = compile ps_3_0 Onion_PS(true, true);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4_SS < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, false);
        PixelShader  = compile ps_3_0 Onion_PS(false, false);
    }
}

technique MainTec5_SS < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, false);
        PixelShader  = compile ps_3_0 Onion_PS(true, false);
    }
}

technique MainTec6_SS < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
    
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(false, true);
        PixelShader  = compile ps_3_0 Onion_PS(false, true);
    }
}

technique MainTec7_SS < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;  
	string Script = LOOPSCR;
	> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
    
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
    	ZEnable = true;
    	ZWriteEnable = false;
    	#ifdef ONION_ADD
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	#endif
        VertexShader = compile vs_3_0 Onion_VS(true, true);
        PixelShader  = compile ps_3_0 Onion_PS(true, true);
    }
}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}
float4 Shadow_Onion_VS(float4 Pos : POSITION, int index : _INDEX) : POSITION
{
	Pos.xyz = getVertexPosBuf(index);
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}
// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}
float4 Shadow_Onion_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb * Onion_Alpha * pow(Onion_AlphaSub,loop_index), 0.65f);
}
// 影描画用テクニック
technique ShadowTec < 
    string MMDPass = "shadow";
    string Script = LOOPSCR;
> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
    pass DrawObject_Onion {
    	FillMode = Onion_DrawMode;
        VertexShader = compile vs_3_0 Shadow_Onion_VS();
        PixelShader  = compile ps_3_0 Shadow_Onion_PS();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 黒で塗りつぶし
    return float4(0,0,0,1);
}

// 輪郭描画用テクニック
technique EdgeTec <string MMDPass = "edge";> {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_3_0 ColorRender_VS();
        PixelShader  = compile ps_3_0 ColorRender_PS();
    }
}
