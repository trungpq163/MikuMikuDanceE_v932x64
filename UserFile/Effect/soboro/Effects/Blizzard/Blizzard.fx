////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


//粒子色
float3 ParticleColor
<
   string UIName = "ParticleColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float3(1,1,1);

//粒子表示数
int count
<
   string UIName = "count";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 15000;
> = 15000;

//ループ数
int loop
<
   string UIName = "loop";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 8;
> = 3;



//表示領域
float Height
<
   string UIName = "Height";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 200;

float WidthX
<
   string UIName = "WidthX";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 200;

float WidthZ
<
   string UIName = "WidthZ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 400;


//落下速度
float Speed
<
   string UIName = "Speed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 40.0;
> = 42;

//パーティクルサイズ
float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.5;
> = 7;

//落下軌道の傾き
float SlopeLevel
<
   string UIName = "SlopeLevel";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 1.5;

//落下軌道のゆらぎ
float NoizeLevel
<
   string UIName = "NoizeLevel";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.8;


//遠方でフェードアウトする距離
float FadeLength
<
   string UIName = "FadeLength";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1000.0;
> = 150;

//シャッタースピード
float ShutterSpeed
<
   string UIName = "ShutterSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 1.0;

//一方向のサンプリング数
#define SAMP_NUM   12


//パーティクルテクスチャ
texture2D Tex1 <
    string ResourceName = "snow2.png";
    int MipLevels = 0;
>;
sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
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


// BlizzardController対応 ////////////////////////////////////////////////////////////

bool flag1 : CONTROLOBJECT < string name = "BlizzardController.pmd"; >;
//bool flag1 = false;

float count_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "粒子数"; >;
float Height_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "領域Y"; >;
float WidthX_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "領域X"; >;
float WidthZ_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "領域Z"; >;

float Speed_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "落下速度"; >;
float ParticleSize_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "サイズ"; >;
float SlopeLevel_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "傾き"; >;
float NoizeLevel_e : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "ゆらぎ"; >;

float R : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "R"; >;
float G : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "G"; >;
float B : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "B"; >;
float Shine : CONTROLOBJECT < string name = "BlizzardController.pmd"; string item = "明るく"; >;

static float count_m = flag1 ? (count_e * 15000) : count;
static float Height_m = flag1 ? (Height_e * 1000) : Height;
static float WidthX_m = flag1 ? (WidthX_e * 1000) : WidthX;
static float WidthZ_m = flag1 ? (WidthZ_e * 1000) : WidthZ;

static float Speed_m = flag1 ? (Speed_e * 120) : Speed;
static float ParticleSize_m = flag1 ? (ParticleSize_e * 20) : ParticleSize;
static float SlopeLevel_m = flag1 ? (SlopeLevel_e * 3) : SlopeLevel;
static float NoizeLevel_m = flag1 ? (NoizeLevel_e) : NoizeLevel;

static float3 ParticleColor_m = flag1 ? (float3(R,G,B) * pow(10, Shine * 2)) : ParticleColor;

//////////////////////////////////////////////////////////////////////////////////////

int loopindex = 0;

float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float ftime : TIME <bool SyncInEditMode = false;>;
float elapsed_time1 : ELAPSEDTIME<bool SyncInEditMode = false;>;

// 座法変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

//ワールドビュー射影行列などの記録

#define INFOBUFSIZE 8

texture DepthBufferMB : RenderDepthStencilTarget <
   int Width=INFOBUFSIZE;
   int Height=1;
    string Format = "D24S8";
>;
texture MatrixBufTex : RenderColorTarget
<
    int Width=INFOBUFSIZE;
    int Height=1;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;

float4 MatrixBufArray[INFOBUFSIZE] : TEXTUREVALUE <
    string TextureName = "MatrixBufTex";
>;

//前フレームのワールドビュー射影行列
static float4x4 lastMatrix = float4x4(MatrixBufArray[0], MatrixBufArray[1], MatrixBufArray[2], MatrixBufArray[3]);

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Tex        : TEXCOORD0;   // テクスチャ
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


//パーティクル位置取得関数
float4 getParticlePosAndAlpha(float index, float time){
    float4 pos;
    
    
    // ランダム配置
    pos = getRandom(index);
    
    pos.xz -= 0.5;
    pos.y = frac(pos.y - (Speed_m * time / Height));
    
    //出現後と消滅直前はフェード
    pos.w = saturate((1 - pos.y) * 4) * saturate(pos.y * 60);
    
    //領域変更
    pos.xyz *= float3(WidthX_m, Height_m, WidthZ_m);
    pos.xyz *= 0.1;
    
    //斜め
    pos.x += pos.y * SlopeLevel_m;
    
    //ループ
    pos.x += (loopindex - (loop - 1) * 0.5) * WidthX_m / 10;
    
    //ノイズ付加
    float nspeed = Speed_m / 10;
    pos.xz += (sin(time * 0.2 * nspeed + index) + cos(time * 0.5 * nspeed + index) * 0.5)  * NoizeLevel_m;
    
    return pos;
}

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float index = Pos.z;
    
    // 位置取得
    float4 base_pos = getParticlePosAndAlpha(index, ftime);
    float4 last_pos = getParticlePosAndAlpha(index, ftime - elapsed_time1 * ShutterSpeed);
    
    float len1 = length(base_pos.xyz - CameraPosition);
    
    //出現後と消滅直前はフェード
    Out.Alpha = base_pos.w;
    
    base_pos.w = last_pos.w = 1;
    
    //スクリーン座標に変換
    base_pos = mul( base_pos, WorldViewProjMatrix );
    last_pos = mul( last_pos, lastMatrix );
    
    //粒子描画サイズ
    float drawsize = ParticleSize_m / base_pos.w;
    
    //スクリーン速度取得
    float2 Velocity = (base_pos.xy / base_pos.w) - (last_pos.xy / last_pos.w);
    Velocity.x *= ViewportAspect;
    
    //単位ベクトル
    float2 AxU = normalize(Velocity);
    float2 AxV = float2(AxU.y, -AxU.x);
    
    float4 spos = (Pos.x > 0) ? base_pos : last_pos;
    
    //座標決定
    Pos.xy *= drawsize;
    Out.Pos.xy = (Pos.x * AxU + Pos.y * AxV);
    Out.Pos.x /= ViewportAspect;
    Out.Pos.xy = spos.xy + Out.Pos.xy * spos.w;
    Out.Pos.zw = spos.zw;
    
    //表示上限より上のパーティクルは彼方へスッ飛ばす
    Out.Pos.y += (index >= count_m) * -100000;
    
    // テクスチャ座標
    Out.Tex.xy = Tex;
    Out.Tex.z = length(Velocity) / drawsize * 4;
    Out.Tex.x *= (Out.Tex.z + 1);
    
    //Zを渡す
    Out.Tex.w = Out.Pos.z;
    
    
    //遠方は薄く
    float alpha2 = 0.2 + 0.8 * saturate(1 - ((len1 - 50) / FadeLength));
    //alpha2 = pow(alpha2, Out.Tex.z / 5);
    
    //alpha2 *= 1 - saturate((1 - alpha2) * (Out.Tex.z * 100));
    
    Out.Alpha *= alpha1 * alpha2;
    Out.Alpha = length(Velocity) < 0.5 ? Out.Alpha : 0;
    
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
    
    float2 stex;
    float4 color = float4(0,0,0,0);
    float4 scolor;
    
    [unroll] //ループ展開
    for(int i = 0; i <= SAMP_NUM; i++){
        stex.y = input.Tex.y;
        stex.x = input.Tex.x - (input.Tex.z * ((float)i / SAMP_NUM));
        scolor = tex2D( Tex1Samp, stex );
        color += scolor;
    }
    
    color = saturate(color / SAMP_NUM);
    color.rgb = ParticleColor_m;
    color.a *= input.Alpha * 1.2;
    
    color.a *= saturate((input.Tex.w - 10) * 0.7);
    
    return color;
}

/////////////////////////////////////////////////////////////////////////////////////
//情報バッファの作成

struct VS_OUTPUT2 {
    float4 Pos: POSITION;
    float2 texCoord: TEXCOORD0;
};


VS_OUTPUT2 DrawMatrixBuf_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
    VS_OUTPUT2 Out;
    
    Out.Pos = Pos;
    Out.texCoord = Tex;
    return Out;
}

float4 DrawMatrixBuf_PS(float2 texCoord: TEXCOORD0) : COLOR {
    
    int dindex = (int)((texCoord.x * INFOBUFSIZE) + 0.2); //テクセル番号
    float4 Color;
    
    if(dindex < 4){
        Color = WorldViewProjMatrix[(int)dindex]; //行列を記録
        
    }else{
        Color = float4(1, 1, 0, 1);
    }
    
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

stateblock makeMatrixBufState = stateblock_state
{
    AlphaBlendEnable = false;
    AlphaTestEnable = false;
    VertexShader = compile vs_3_0 DrawMatrixBuf_VS();
    PixelShader  = compile ps_3_0 DrawMatrixBuf_PS();
};


technique MainTec <

string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "LoopByCount=loop;"
        "LoopGetIndex=loopindex;"
            "RenderColorTarget=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
    ;

> {
    
    pass DrawMatrixBuf < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        CullMode = none;
        
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}

