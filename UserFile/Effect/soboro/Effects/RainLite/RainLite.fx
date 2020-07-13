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
> = 8000;

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
> = 60;

//パーティクルサイズ
float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.5;
> = 1.8;

//テクスチャのアスペクト比
float Aspect
<
   string UIName = "Aspect";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.25;


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


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
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
    base_pos.y = frac(base_pos.y - (Speed * ftime / Height));
    
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
    float3 WorldPos = WorldMatrix[3].xyz + base_pos.xyz * scaling;
    
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
    float4 color = tex2D( Tex1Samp, input.Tex );
    color.a *= input.Alpha;
    return color;
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
}

