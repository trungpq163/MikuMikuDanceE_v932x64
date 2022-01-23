////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Screen_Otome.fx ver0.0.4  乙女フィルターエフェクト･スクリーン固定版
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx,FireParticleSystem.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 水玉描画パラメータ設定
int BallCount = 30;           // 水玉の描画オブジェクト数
float3 BallColor = {1.0, 1.0, 1.0}; // 水玉の乗算色(RBG)
float BallRandamColor = 0.6;  // 水玉色のばらつき度(0.0～1.0)
float BallScale = 3.0;        // 水玉大きさ
float BallSpeed = 0.07;       // 水玉スピード
float BallAlpha = 0.5;        // 水玉Tr=1の時のα値
float BallPosParam = 0.4;     // 水玉上下より分けパラメータ(0で均等,1に近づくほど上下により分けられる)


// 光粒子描画パラメータ設定
int LightCount = 50;          // 光粒子の描画オブジェクト数
float3 LightColor = {1.0, 1.0, 0.8}; // 水玉の乗算色(RBG)
float LightRandamColor = 0.2; // 粒子色のばらつき度(0.0～1.0)
float LightScale = 1.0;       // 光粒子大きさ
float LightSpeed = 0.03;      // 光粒子スピード
float LightRotSpeed = 0.2;    // 光粒子回転スピード
float LightPower = 0.5;       // 光粒子の輝き強度
float LightAmp = 1.0;         // 光粒子瞬き振幅
float LightFreq = 1.0;        // 光粒子瞬き周波数
// キラキラ描画パラメータ設定
int GlareCount = 2;           // 主光芒の数(この数の2倍が実際の光芒数)
int SubGlareCount = 8;        // 副光芒の数(主光芒の間の短い光芒の数)
float GlareThick = 3.0;       // 主光芒の太さ
float SubGlareThick = 1.0;    // 副光芒の太さ
float SubGlareLength = 0.5;   // 副光芒の長さ(主光芒長さとの比)
float LightCenter = 0.5;      // 光粒子中央部の大きさ(主光芒長さとの比)


// 乱数シード設定
int BallSeedXY = 18;          // 水玉配置に関する乱数シード
int BallSeedSize = 12;        // 水玉サイズに関する乱数シード
int BallSeedSpeed = 17;       // 水玉スピードに関する乱数シード
int BallSeedColor = 5;        // 水玉色に関する乱数シード
int LightSeedXY = 9;          // 光粒子配置に関する乱数シード
int LightSeedSize = 13;       // 光粒子サイズに関する乱数シード
int LightSeedSpeed = 17;      // 光粒子スピードに関する乱数シード
int LightSeedBlink = 13;      // 光粒子瞬きに関する乱数シード
int LightSeedCross = 19;      // 光粒子十字度合いに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define TEX_WORK_SIZE  512 // キラキラ粒子テクスチャ作成の作業レイヤサイズ

#define PAI 3.14159265f   // π

int GlareIndex;      // 主光芒描画インデックス
int SubGlareIndex;   // 副光芒描画インデックス

float Xmin = -1.3f;
float Xmax = 1.3f;
float Ymin = -1.1f;
float Ymax = 1.1f;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int Index;

float time : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

texture2D BallTex <
    string ResourceName = "ball.png";
>;
sampler BallSamp = sampler_state {
    texture = <BallTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex1 <
    string ResourceName = "Particle1.png";
>;
sampler ParticleSamp1 = sampler_state {
    texture = <ParticleTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex2 <
    string ResourceName = "Particle2.png";
>;
sampler ParticleSamp2 = sampler_state {
    texture = <ParticleTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// 作業レイヤサイズ
#define TEX_WORK_WIDTH  TEX_WORK_SIZE
#define TEX_WORK_HEIGHT TEX_WORK_SIZE

// キラキラ粒子テクスチャ作成の作業レイヤ
texture2D WorkLayer : RENDERCOLORTARGET <
    int Width = TEX_WORK_WIDTH;
    int Height = TEX_WORK_HEIGHT;
    int Miplevels = 0;
    string Format = "A8R8G8B8" ;
>;
sampler2D WorkLayerSamp = sampler_state {
    texture = <WorkLayer>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D WorkDepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width = TEX_WORK_WIDTH;
    int Height = TEX_WORK_HEIGHT;
    string Format = "D24S8";
>;

// レンダリングターゲットのクリア値
float4 ClearColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
float ClearDepth  = 1.0f;


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// HSVからRGBへの変換 H:0.0～360.0, S:0.0～1.0, V:0.0～1.0 (S==0時は省略)
float4 HSV2RGB(float h, float s, float v) : COLOR
{
   h %= 360.0;
   int hi = (int)(h/60.0f) % 6;
   float f = h/60.0f - (float)hi;
   float p = v*(1.0f - s);
   float q = v*(1.0f - f*s);
   float t = v*(1.0f - (1.0f-f)*s);
   float4 Color;
   if(hi == 0){
      Color = float4(v, t, p, 1.0f);
   }else if(hi == 1){
      Color = float4(q, v, p, 1.0f);
   }else if(hi == 2){
      Color = float4(p, v, t, 1.0f);
   }else if(hi == 3){
      Color = float4(p, q, v, 1.0f);
   }else if(hi == 4){
      Color = float4(t, p, v, 1.0f);
   }else if(hi == 5){
      Color = float4(v, p, q, 1.0f);
   }
   return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 水玉描画

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // 色
};

// 頂点シェーダ
VS_OUTPUT Ball_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // 乱数定義
    float rand0 = abs(0.6f*sin(35 * BallSeedSize * Index + 13) + 0.4f*cos(73 * BallSeedSize * Index + 17));
    float rand1 = abs(0.4f*sin(51 * BallSeedSpeed * Index + 17) + 0.6f*cos(63 * BallSeedSpeed * Index + 19));
    float rand2 = abs(0.7f*sin(122 * BallSeedXY * Index + 19) + 0.3f*cos(237 * BallSeedXY * Index + 23));
    float rand3 = abs(0.6f*sin(81 * BallSeedXY * Index + 23) + 0.4f*cos(97 * BallSeedXY * Index + 29));
    float rand4 = abs(0.4f*sin(47 * BallSeedColor * Index + 29) + 0.6f*cos(83 * BallSeedColor * Index + 31));

    // 水玉サイズ
    float scale = (0.5f + rand0) * BallScale;
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;

    // 水玉配置
    float speed = lerp(-BallSpeed, BallSpeed,rand1);
    float x = lerp(Xmin, Xmax, rand2);
    float y = lerp(Ymin-BallPosParam, Ymax+BallPosParam, rand3);
    Pos.x += ((x+speed*(time+60.0f)-Xmin)%(Xmax-Xmin)+Xmin+step(speed,0.0f)*(Xmax-Xmin));
    Pos.y += sign(y)*pow(abs(y), max(1.0f-BallPosParam, 0.0f));
    Out.Pos = Pos;

    // 水玉の色
    float alpha = AcsTr * BallAlpha;
    float4 Color = HSV2RGB(360.0f*rand4, 1.0f, 1.0f);
    Color = BallRandamColor * (Color - 1.0f) + 1.0f;
    Out.Color = float4(Color.rgb*BallColor, alpha);

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Ball_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( BallSamp, IN.Tex.xy );
    Color *= IN.Color;
    return Color;
}

// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0";
    string Script = "LoopByCount=BallCount;"
                        "LoopGetIndex=Index;"
                        "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Ball_VS();
        PixelShader  = compile ps_2_0 Ball_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// キラキラ粒子テクスチャ描画

// 頂点シェーダ
VS_OUTPUT LightParticle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD, uniform bool flag)
{
   VS_OUTPUT Out = (VS_OUTPUT)0; 

   // 光芒インデックス
   int index = int(!flag)*(SubGlareIndex + 1) + GlareIndex*(SubGlareCount + 1);

   // 乱数設定
   float rand0 = 0.5f * (0.66f * sin(22.1f * index) + 0.33f * cos(33.6f * index) + 1.0f);
   float rand1 = 0.5f * (0.38f * sin(55.1f * index) + 0.62f * cos(44.4f * index) + 1.0f);
   float rand2 = 0.5f * (0.31f * sin(45.3f * index) + 0.69f * cos(73.4f * index) + 1.0f);

   // 光芒回転角
   float rot = PAI * float(index) / float( (SubGlareCount+1) * GlareCount );

   // 座標変換
   if(flag){
      Pos.x *= 0.7f + 0.3f * rand0;
      Pos.x *= (1.0f - rand1 * (sin(2.0f*PAI*(LightFreq*time+rand2))+1.0f) * 0.2f);
      Pos.y *= GlareThick / 16.0f;
   }else{
      Pos.x *= 0.1f + 0.9f * rand0;
      Pos.x *= SubGlareLength * (1.0f - rand1 * (sin(2.0f*PAI*(LightFreq*time+rand2))+1.0f) * 0.4f);
      Pos.y *= SubGlareThick / 16.0f;
   }
   Out.Pos.xy = Rotation2D( Pos.xy, rot );
   Out.Pos.zw = float2(0.0f, 1.0f);

   // テクスチャ座標
   Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 LightParticle_PS( VS_OUTPUT IN ) : COLOR0
{
   // 粒子の色
   return tex2D( ParticleSamp1, IN.Tex );
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // 色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand0 = abs(0.5f*sin(35 * LightSeedSize * Index + 13) + 0.5f*cos(73 * LightSeedSize * Index + 17));
    float rand1 = abs(0.6f*sin(51 * LightSeedSpeed * Index + 17) + 0.4f*cos(63 * LightSeedSpeed * Index + 19));
    float rand2 = abs(0.4f*sin(122 * LightSeedXY * Index + 19) + 0.6f*cos(237 * LightSeedXY * Index + 23));
    float rand3 = abs(0.7f*sin(81 * LightSeedXY * Index + 23) + 0.3f*cos(97 * LightSeedXY * Index + 29));
    float rand4 = 0.5f*sin(53 * LightSeedBlink * Index + 17) + 0.5f*cos(61 * LightSeedBlink * Index + 19);
    float rand5 = (sin(47 * LightSeedCross * Index + 29) + cos(83 * LightSeedCross * Index + 31) + 3.0f) * 0.1f;

    // パーティクル回転
    Pos.xy = Rotation2D(Pos.xy, time*LightRotSpeed);

    // パーティクルサイズ
    float scale = (0.5f + rand0)*LightScale + LightAmp*sin(LightFreq*time+rand4*6.28f);
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;

    // パーティクル配置
    float speed = lerp(-LightSpeed, LightSpeed, rand1);
    float x = lerp(Xmin, Xmax, rand2);
    Pos.x += (x+speed*time-Xmin)%(Xmax-Xmin)+Xmin+step(speed,0.0f)*(Xmax-Xmin);
    Pos.y += lerp(Ymin, Ymax, rand3);
    Out.Pos = Pos;

    // パーティクルの色
    Out.Color = float4(LightColor*AcsTr, 1.0f);
    Out.Color.rgb *= lerp(float3(1.0f,1.0f,1.0f), float3(rand0,rand1,rand2), LightRandamColor);

    // テクスチャ座標
    Out.Tex = float3(Tex, 1.0f / (LightCenter * lerp(0.5f, 1.0f, rand5)));

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( WorkLayerSamp, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy - 0.5f) * IN.Tex.z + 0.5f;
    float4 Color1 = tex2D( ParticleSamp2, Tex1 );
    Color += Color1;
    Color.rgb *= IN.Color.rgb*LightPower;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "1-1000";
    string Script = 
       "RenderColorTarget0=WorkLayer;"
            "RenderDepthStencilTarget=WorkDepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "LoopByCount=GlareCount;"
                "LoopGetIndex=GlareIndex;"
                "Pass=DrawLightParticle1;"
                "LoopByCount=SubGlareCount;"
                    "LoopGetIndex=SubGlareIndex;"
                    "Pass=DrawLightParticle2;"
                "LoopEnd=;"
            "LoopEnd=;"
       "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "LoopByCount=LightCount;"
                "LoopGetIndex=Index;"
                "Pass=DrawObject;"
            "LoopEnd=;"
       ;
> {
    pass DrawLightParticle1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        ALPHABLENDENABLE = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_2_0 LightParticle_VS(true);
        PixelShader  = compile ps_2_0 LightParticle_PS();
    }
    pass DrawLightParticle2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        ALPHABLENDENABLE = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_2_0 LightParticle_VS(false);
        PixelShader  = compile ps_2_0 LightParticle_PS();
    }
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

