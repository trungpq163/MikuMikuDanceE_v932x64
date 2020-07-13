////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


//コントローラ名
#define CONT_NAME "BaloonController.pmd"


int index = 0; //ループ用変数

//パーティクル数最大値
#define CLONE_NUM 1024

int count = CLONE_NUM;
int count_ss = CLONE_NUM*2;

float Height= 80;

float WidthX = 100;

float WidthZ = 100;

float Speed = -10;

float ParticleSize = 1;

float NoizeLevel = 2;

float RotationSpeed = 0.5;

//拡散力
float dispersion = 10;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
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

float ftime : TIME;

float3 ControllerPos : CONTROLOBJECT < string name = CONT_NAME; string item = "センター"; >;
float morph_spd : CONTROLOBJECT < string name = CONT_NAME; string item = "速度調節"; >;
float morph_width_x : CONTROLOBJECT < string name = CONT_NAME; string item = "範囲X"; >;
float morph_width_z : CONTROLOBJECT < string name = CONT_NAME; string item = "範囲Z"; >;
float morph_height : CONTROLOBJECT < string name = CONT_NAME; string item = "範囲Y"; >;
float morph_num : CONTROLOBJECT < string name = CONT_NAME; string item = "個数調節"; >;
float morph_rand : CONTROLOBJECT < string name = CONT_NAME; string item = "ゆらぎ"; >;
float morph_dis_s : CONTROLOBJECT < string name = CONT_NAME; string item = "始拡散"; >;
float morph_dis_e : CONTROLOBJECT < string name = CONT_NAME; string item = "終拡散"; >;

float3 MyPos : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;

//回転行列
static float rot_x = ftime * RotationSpeed + index * 12;
static float rot_y = ftime * RotationSpeed + index * 34;
static float rot_z = ftime * RotationSpeed + index * 56;

static float3x3 RotationX = {
    {1,	0,	0},
    {0, cos(rot_x), sin(rot_x)},
    {0, -sin(rot_x), cos(rot_x)},
};
static float3x3 RotationY = {
    {cos(rot_y), 0, -sin(rot_y)},
    {0, 1, 0},
	{sin(rot_y), 0,cos(rot_y)},
    };
static float3x3 RotationZ = {
    {cos(rot_z), sin(rot_z), 0},
    {-sin(rot_z), cos(rot_z), 0},
    {0, 0, 1},
};

float4 ClonePos(float4 Pos : POSITION) : POSITION 
{
	//表示数上限設定に引っ掛かったら消し飛ばす
	if(index >= (1-morph_num)*(float)count)
	{
		Pos.xyzw = 0;
		return Pos;
	}


	float findex = index;
    
    //回転・サイズ変更
    //Pos.xyz = mul( Pos.xyz, RotationX );
    Pos.xyz -= MyPos;
    Pos.xyz = mul( Pos.xyz, RotationY );
    Pos.xyz += MyPos;
    //Pos.xyz = mul( Pos.xyz, RotationZ );
    Pos.xyz *= ParticleSize;
    
    // ランダム配置
    float4 base_pos;
    float rand = findex;
    
    float w_rad = frac(cos(rand*0.123))*3.1415*2;
    float w_len = frac(tan(rand*0.456));
    
    base_pos.x = cos(w_rad)*w_len;
    base_pos.y = frac(sin(rand*456));
    base_pos.z = sin(w_rad)*w_len;
    base_pos.w = 1;

    base_pos.xz *= (1-morph_dis_s);
    //上昇
    base_pos.y = frac(base_pos.y - ((Speed * (1-morph_spd)) * ftime / Height));
    //拡散
    dispersion *= morph_dis_e;
    float up_pow = pow(base_pos.y,2);
    base_pos.x += ((frac(cos(findex * 11))-0.5) * dispersion ) * up_pow;
    base_pos.z += ((frac(sin(findex * 22))-0.5) * dispersion ) * up_pow;
       
    //領域変更
    WidthX *= 1.0+morph_width_x*10.0;
    WidthZ *= 1.0+morph_width_z*10.0;
    Height *= 1.0+morph_height*10.0;
    
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    float2 vec = ControllerPos.xz*0.1;
    vec *= base_pos.y;
    base_pos.xz += vec;
    
    //ノイズ付加
    base_pos.x += noise(float2(findex * 0.1 + ftime * 0.2, findex * 12)) * NoizeLevel*morph_rand;
    //base_pos.y += noise(float2(findex * 0.1 + ftime * 0.2, findex * 34)) * NoizeLevel*morph_rand;
    base_pos.z += noise(float2(findex * 0.1 + ftime * 0.2, findex * 56)) * NoizeLevel*morph_rand;
    
    Pos.xyz += base_pos;
    return Pos;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( ClonePos(Pos), WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 黒で塗りつぶし
    return float4(0,0,0,1);
}

// 輪郭描画用テクニック
technique EdgeTec <
	string MMDPass = "edge";
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawEdge;"
        "LoopEnd=;"
	;
> {
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_3_0 ColorRender_VS();
        PixelShader  = compile ps_3_0 ColorRender_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( ClonePos(Pos), WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < 
	string MMDPass = "shadow";
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawShadow;"
        "LoopEnd=;"
	;
> {
    pass DrawShadow {
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Pos = ClonePos(Pos);
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Normal = mul( Normal, RotationY );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor.rgb;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor;
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

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    //float3 Specular = (float3)0;
    
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color += tex2D(ObjSphareSampler,IN.SpTex);
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    }
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    return Color;
}


// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; 
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	
	Pos = ClonePos(Pos);
	
    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot";
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=ZValuePlot;"
        "LoopEnd=;"
	;
> {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
    
	Pos = ClonePos(Pos);
	
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Normal = mul( Normal, RotationY );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor.rgb;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor;
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

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor.rgb, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color += TexColor;
            ShadowColor += TexColor;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    Color.rgb += Specular;
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        return Color;
    } else {
        float comp;
        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
        
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
	string Script =
		"LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
	;
> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
