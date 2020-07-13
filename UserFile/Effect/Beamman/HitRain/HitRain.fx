////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//粒子表示数
int count
<
   string UIName = "count";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 15000;
> = 15000;

//表示領域
float Height
<
   string UIName = "Height";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 100;

float WidthX
<
   string UIName = "WidthX";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 250;

float WidthZ
<
   string UIName = "WidthZ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 250;


//落下速度
float Speed
<
   string UIName = "Speed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100.0;
> = 100;

//パーティクルサイズ
float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.5;
> = 1;

//テクスチャのアスペクト比
float Aspect
<
   string UIName = "Aspect";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.1;


//遠方でフェードアウトする距離
float FadeLength
<
   string UIName = "FadeLength";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1000.0;
> = 300;



//パーティクルテクスチャ
texture2D Tex1 <
    string ResourceName = "rain6.png";
    int MipLevels = 0;
>;
sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};
texture2D Tex2 <
    string ResourceName = "splash.png";
    int MipLevels = 0;
>;
sampler Tex2Samp = sampler_state {
    texture = <Tex2>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256


float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float ftime : TIME <bool SyncInEditMode = false;>;


// 座法変換行列
float4x4 WorldMatrix : World;
float4x4 ViewProjMatrix : ViewProjection;
float4x4 ViewTransMatrix : ViewTranspose;
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float scaling = length(WorldMatrix._11_12_13) * 0.1;

float3   CameraPosition     : POSITION  < string Object = "Camera"; >;

// ワールド回転行列
static float3x3 WorldRotMatrix = {
    normalize(WorldMatrix[0].xyz),
    normalize(WorldMatrix[1].xyz),
    normalize(WorldMatrix[2].xyz),
};

#define HITTEX_SIZE 1024

texture HitRainRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for HitRain.fx";
    int Width = HITTEX_SIZE;
    int Height = HITTEX_SIZE;
    string Format = "D3DFMT_R16F" ;
    float4 ClearColor = { 1, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "*=Length.fx;";
>;
sampler LengthSamp = sampler_state {
    texture = <HitRainRT>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 WPos	  : TEXCOORD0;
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float  Alpha      : COLOR0;
};

//乱数取得
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float index = Pos.z;
    Pos.z = 0;
    
    
    // ランダム配置
    float4 base_pos = getRandom(index);
    base_pos.xz -= 0.5;
    base_pos.xz *= 0.25;
    base_pos.y = frac(base_pos.y - (Speed * ftime / Height));
    Out.WPos = base_pos.xyz;
	Out.WPos.xz += 0.5;
	Out.WPos.z *= -1;
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    //領域変更
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    //base_pos.xyz *= 0.1;
    
    
    
    // Y軸回りラインビルボード
    float3 Axis = float3(0, 1, 0);
    
    //ワールド回転変換
    base_pos.xyz = mul( base_pos.xyz, WorldRotMatrix );
    Axis = mul( Axis, WorldRotMatrix );
    
    //パーティクル原点のワールド座標
    float3 WorldPos = WorldMatrix[3].xyz + base_pos.xyz;
    
    //カメラからのベクトル
    float3 Eye = normalize(WorldPos - CameraPosition);
    
    //軸ベクトルとカメラベクトルの外積で横方向ベクトルを得る
    float3 Side = normalize(cross(Axis,Eye));
    
    //元オブジェクトの座標からボード形成
    Out.Pos = float4(WorldPos, 1);
    Out.Pos.xyz += (Pos.y * Axis + Pos.x * Side * Aspect) * ParticleSize * 10 * scaling;
    
    
    //表示上限より上のパーティクルは彼方へスッ飛ばす
    Out.Pos.z -= (index >= count) * 100000;

    
    // カメラ視点のビュー射影変換
    Out.Pos = mul( Out.Pos, ViewProjMatrix );
    
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
	float len = tex2D(LengthSamp,input.WPos.xz).r;
	float test = (1-len);
	float len_buf = (input.WPos.y > test);
	float4 color = tex2D( Tex1Samp, input.Tex );
    color.a *= input.Alpha*len_buf;
    //color.rgb = 1;
    //color.a = sign(color.a);
    return color;
}


// 頂点シェーダ
VS_OUTPUT Drop_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float index = Pos.z;
    Pos.z = 0;
    
    
    // ランダム配置
    float4 base_pos = getRandom(index);
    float base_y = base_pos.y;
    //base_y = frac(base_y - (Speed * ftime / Height));
    
    base_pos.xz -= 0.5;
    base_pos.y = 0;
    base_pos.xz *= 0.25;
    Out.WPos = base_pos.xyz;
	Out.WPos.xz += 0.5;
	Out.WPos.z *= -1;
	
	float len = 1-tex2Dlod(LengthSamp,float4(Out.WPos.xz,0,0)).r;
    base_pos.y += len;

    //領域変更
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    //base_pos.xyz *= 0.1;
    
    
    // Y軸回りラインビルボード
    float3 Axis = float3(0, 1, 0);
    
    //ワールド回転変換
    base_pos.xyz = mul( base_pos.xyz, WorldRotMatrix );
    Axis = mul( Axis, WorldRotMatrix );
    
    //パーティクル原点のワールド座標
    float3 WorldPos = WorldMatrix[3].xyz + base_pos.xyz;
    
    //カメラからのベクトル
    float3 Eye = normalize(WorldPos - CameraPosition);
    
    //軸ベクトルとカメラベクトルの外積で横方向ベクトルを得る
    float3 Side = normalize(cross(Axis,Eye));
    
    //元オブジェクトの座標からボード形成
    Out.Pos = float4(WorldPos, 1);
    Out.Pos.xyz += (Pos.y * Axis + Pos.x * Side * Aspect) * ParticleSize * 20 * scaling;
    
    
    //表示上限より上のパーティクルは彼方へスッ飛ばす
    Out.Pos.z -= (index >= count) * 100000;

    
    // カメラ視点のビュー射影変換
    Out.Pos = mul( Out.Pos, ViewProjMatrix );
    
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    Out.Alpha *= smoothstep(0.9,1,1-frac((-base_y)+len+((Speed * ftime / Height)))) * 1;
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Drop_PS( VS_OUTPUT input ) : COLOR0
{
    float4 color = tex2D( Tex2Samp, input.Tex );
    color.a *= input.Alpha;
    color.a *= 0.5;
    return color;
}

struct CPU_TO_VS
{
	float4 Pos		: POSITION;
};
struct VS_TO_PS
{
	float4 Pos		: POSITION;
	float2 Tex		: TEXCOORD0;
};
VS_TO_PS VS_Length( CPU_TO_VS In )
{
	VS_TO_PS Out;

	// 位置そのまま
	Out.Pos = In.Pos;

	float2 Tex = (In.Pos.xy+1)*0.5;
	Out.Pos.xy *= 0.3;
	Out.Pos.xy += 1-0.3;
	// テクスチャ座標は中心からの４点
	float2 fInvSize = float2( 1.0, 1.0 ) / (float)HITTEX_SIZE;

    Out.Tex = Tex;
	return Out;
}
float4 PS_Length( VS_TO_PS In ) : COLOR
{
	float4 col = tex2D(LengthSamp,In.Tex);

	return pow(saturate(col),1);
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec {
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        CullMode = NONE; //裏表描画
        
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
    pass DrawDrop {
        ZWRITEENABLE = false; //Zバッファを更新しない
        CullMode = NONE; //裏表描画
        
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        
        VertexShader = compile vs_3_0 Drop_VS();
        PixelShader  = compile ps_3_0 Drop_PS();
    }
    /*
    pass DrawLength < string Script = "Draw=Buffer;";> {
        VertexShader = compile vs_3_0 VS_Length();
        PixelShader  = compile ps_3_0 PS_Length();
    }
    */
}

