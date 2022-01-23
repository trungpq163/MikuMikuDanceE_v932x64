////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Post_Appeal.fx ver0.0.3  アピールエフェクト(ポストフェクトキャンセル版)  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// 放射光描画パラメータ設定
#define RADIANT_TYPE   1        // 放射光の種類(とりあえず1～3で選択)
float3 RadiantColor = {1.0, 1.0, 0.5};  // 放射光の乗算色(RBG)
float RadiantSizeMin = 0.2;     // 放射光最小サイズ
float RadiantSizeMax = 25.0;    // 放射光最大サイズ
float RadiantAlpha = 1.0;       // 放射光のα値

// キラキラ描画パラメータ設定
float3 KiraColor = {0.5, 1.0, 1.0};  // キラキラ粒子の乗算色(RBG)
int KiraCount = 17;             // キラキラ粒子の描画オブジェクト数
float KiraSize = 1.8;           // キラキラ粒子のサイズ
float KiraStartPos = 0.2;       // キラキラ粒子の開始位置
float KiraEndPos = 0.8;         // キラキラ粒子の終了位置
float KiraRotSpeed = 2.0;       // キラキラ粒子の回転スピード
float KiraCross = 1.0;          // キラキラ粒子の十字度(大きくすると十字が鮮明になる)
float KiraAlpha = 1.0;          // キラキラ粒子のα値

// パーティクル描画パラメータ設定
#define PARTICLE_TYPE   1         // パーティクルの種類(とりあえず1～3で選択, 1:星, 2:ハート, 3:音符)
int ParticleCount = 22;           // パーティクルの描画オブジェクト数
float3 ParticleColor = {1.0, 0.8, 1.0};  // パーティクルの乗算色(RBG)
float ParticleRandamColor = 0.5;  // パーティクル色のばらつき度(0.0～1.0)
float ParticleSize = 2.0;         // パーティクルのサイズ
float ParticleStartPos = 0.6;     // パーティクルの開始位置
float ParticleEndPos = 0.9;       // パーティクルの終了位置
float ParticleRotSpeed = 2.0;     // パーティクルの回転スピード
float ParticleAlpha = 1.0;        //パーティクルのα値

// 乱数シード設定
int SeedXY = 5;         // 配置に関する乱数シード
int SeedSize = 5;       // サイズに関する乱数シード
int SeedRotSpeed = 13;  // 回転スピードに関する乱数シード
int SeedColor = 7;      // パーティクル色のばらつきに関する乱数シード
int SeedView = 11;      // フェードイン･アウトに関する乱数シード



// 必要に応じて放射光のテクスチャをここで定義
#if RADIANT_TYPE == 1
    #define RadiantTexFile  "放射1.png"     // 放射光のテクスチャファイル名
#endif

#if RADIANT_TYPE == 2
    #define RadiantTexFile  "放射2.png"     // 放射光のテクスチャファイル名
#endif

#if RADIANT_TYPE == 3
    #define RadiantTexFile  "放射3.png"     // 放射光のテクスチャファイル名
#endif


// 必要に応じてパーティクルのテクスチャをここで定義
#if PARTICLE_TYPE == 1
    #define ParticleTexFile  "星.png"  // パーティクルに貼り付けるテクスチャファイル名
    #define TEX_PARTICLE_XNUM  2       // パーティクルテクスチャのx方向粒子数
    #define TEX_PARTICLE_YNUM  1       // パーティクルテクスチャのy方向粒子数
    #define USE_MIPMAP  0              // テクスチャのミップマップ生成,0:しない,1:する
#endif

#if PARTICLE_TYPE == 2
    #define ParticleTexFile  "ハート.png"  // パーティクルに貼り付けるテクスチャファイル名
    #define TEX_PARTICLE_XNUM  2       // パーティクルテクスチャのx方向粒子数
    #define TEX_PARTICLE_YNUM  1       // パーティクルテクスチャのy方向粒子数
    #define USE_MIPMAP  0              // テクスチャのミップマップ生成,0:しない,1:する
#endif

#if PARTICLE_TYPE == 3
    #define ParticleTexFile  "音符.png"  // パーティクルに貼り付けるテクスチャファイル名
    #define TEX_PARTICLE_XNUM  8       // パーティクルテクスチャのx方向粒子数
    #define TEX_PARTICLE_YNUM  1       // パーティクルテクスチャのy方向粒子数
    #define USE_MIPMAP  0              // テクスチャのミップマップ生成,0:しない,1:する
#endif


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float3 AcsPos : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#define PAI 3.14159265f   // π

int Index;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// 放射光テクスチャ
texture2D RadiantTex <
    string ResourceName = RadiantTexFile;
>;
sampler RadiantSamp = sampler_state {
    texture = <RadiantTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// キラキラテクスチャ1
texture2D KiraTex1 <
    string ResourceName = "kira1.png";
>;
sampler KiraSamp1 = sampler_state {
    texture = <KiraTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// キラキラテクスチャ1
texture2D KiraTex2 <
    string ResourceName = "kira2.png";
>;
sampler KiraSamp2 = sampler_state {
    texture = <KiraTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// パーティクルテクスチャ
#if(USE_MIPMAP == 1)
texture2D ParticleTex <
    string ResourceName = ParticleTexFile;
    int MipLevels = 0;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
#else
texture2D ParticleTex <
    string ResourceName = ParticleTexFile;
    int MipLevels = 1;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
#endif

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 放射光描画
struct VS_OUTPUT
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float4 Color : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT Radiant_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 放射光配置
    float scale = (RadiantSizeMin * (1.0f - AcsTr) + RadiantSizeMax * AcsTr);
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;
    Pos.xy += AcsPos.xy;
    Out.Pos = Pos;

    // テクスチャの乗算色
    float alpha = (1.0f - smoothstep(0.05f, 0.5f, abs(AcsTr - 0.5f))) * RadiantAlpha;
    Out.Color = saturate( float4(RadiantColor*alpha, 1.0f) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Radiant_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( RadiantSamp, IN.Tex.xy );
    Color *= IN.Color;
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////
// キラキラ描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Kira_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // パーティクルサイズ
    float scale = KiraSize * (sin(44 * SeedSize * Index + 13) + cos(87 * SeedSize * Index + 17) + 3.0f) * 0.25f;
    Pos.xy *= scale;

    // パーティクル回転配置
    float rot = KiraRotSpeed * AcsTr;
    Pos.xy = Rotation2D( Pos.xy, rot );

    // パーティクル配置
    float r = (sin(124 * SeedXY * Index*2 + 13) + cos(235 * SeedXY * Index + 17) + 1.5f) * 0.2f;
    float s = (sin(83 * SeedXY * Index*2 + 9) + cos(91 * SeedXY * Index + 11) + 3.0f) * 0.25f;
    float2 Pos0 = float2( 0.0f, lerp(r * KiraStartPos, (r + s) * KiraEndPos, AcsTr) );
    Pos.xy += Rotation2D(Pos0, ((float)Index/(float)KiraCount)*2.0f*PAI );
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Pos.xy += AcsPos.xy;
    Out.Pos = Pos;

    // テクスチャの乗算色
    float alpha = (1.0f - smoothstep(0.05f, 0.5f, abs(AcsTr - 0.5f))) * KiraAlpha;
    Out.Color = saturate( float4(KiraColor*alpha, 1.0f) );

    // テクスチャ座標
    float rand = (sin(47 * SeedSize * Index + 13) + cos(81 * SeedSize * Index + 17) + 3.0f) * 0.1f;
    Out.Tex = float3(Tex, 1.0f+KiraCross*rand);

    return Out;
}

// ピクセルシェーダ
float4 Kira_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( KiraSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( KiraSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= IN.Color.xyz*0.5f;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// HSVからRGBへの変換 H:0.0～360.0, S:0.0～1.0, V:0.0～1.0 (S==0時は省略)
float3 HSV2RGB(float h, float s, float v)
{
   h = fmod(h, 360.0f);
   int hi = floor(fmod(floor(h/60.0f), 6.0f));
   float f = h/60.0f - (float)hi;
   float p = v*(1.0f - s);
   float q = v*(1.0f - f*s);
   float t = v*(1.0f - (1.0f-f)*s);
   float3 Color;
   if(hi == 0){
      Color = float3(v, t, p);
   }else if(hi == 1){
      Color = float3(q, v, p);
   }else if(hi == 2){
      Color = float3(p, v, t);
   }else if(hi == 3){
      Color = float3(p, q, v);
   }else if(hi == 4){
      Color = float3(t, p, v);
   }else if(hi == 5){
      Color = float3(v, p, q);
   }
   return Color;
}

///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

// 頂点シェーダ
VS_OUTPUT Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // パーティクルサイズ
    float scale = ParticleSize * (sin(37 * SeedSize * Index + 13) + cos(71 * SeedSize * Index + 17) + 3.0f) * 0.25f;
    Pos.xy *= scale * AcsSi*0.1f;

    // パーティクル回転配置
    float rot = ParticleRotSpeed * (sin(53 * SeedRotSpeed * Index + 13) + cos(61 * SeedRotSpeed * Index + 17)) * AcsTr;
    Pos.xy = Rotation2D( Pos.xy, rot );

    // パーティクル配置
    float r = (sin(124 * SeedXY * Index + 13) + cos(235 * SeedXY * Index + 17) + 2.1f) * 0.25f;
    float s = (sin(83 * SeedXY * Index + 13) + cos(91 * SeedXY * Index + 17) + 3.0f) * 0.25f;
    Pos.x += lerp(r * ParticleStartPos, (r + s) * ParticleEndPos, AcsTr);
    Pos.xy = Rotation2D(Pos.xy, ((float)Index/(float)ParticleCount)*2.0f*PAI );
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Pos.xy += AcsPos.xy;
    Out.Pos = Pos;

    // テクスチャの乗算色
    float a = (sin(47 * SeedView * Index + 13) + cos(19 * SeedView * Index + 17)) * 0.04f;
    float alpha = (1.0f - smoothstep(0.25f+a, 0.5f, abs(AcsTr - 0.5f))) * ParticleAlpha;
    float rand = abs(0.6f*sin(83 * SeedColor * Index + 23) + 0.4f*cos(91 * SeedColor * Index + 29));
    float3 randColor = HSV2RGB(rand*360.0f, 1.0f, 1.0f);
    randColor = ParticleRandamColor * (randColor - 1.0f) + 1.0f;
    Out.Color = float4(ParticleColor * randColor, alpha);

    // テクスチャ座標
    int texIndex = Index % (TEX_PARTICLE_XNUM * TEX_PARTICLE_YNUM);
    int tex_i = texIndex % TEX_PARTICLE_XNUM;
    int tex_j = texIndex / TEX_PARTICLE_XNUM;
    Out.Tex = float2((Tex.x + tex_i)/TEX_PARTICLE_XNUM, (Tex.y + tex_j)/TEX_PARTICLE_YNUM);

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp, IN.Tex );
    Color *= IN.Color;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
            "Pass=DrawRadiant;"
            "LoopByCount=KiraCount;"
               "LoopGetIndex=Index;"
               "Pass=DrawKira;"
            "LoopEnd=;"
            "LoopByCount=ParticleCount;"
               "LoopGetIndex=Index;"
               "Pass=DrawParticle;"
            "LoopEnd=;" ; >
{
    pass DrawRadiant {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_2_0 Radiant_VS();
        PixelShader  = compile ps_2_0 Radiant_PS();
    }
    pass DrawKira {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_2_0 Kira_VS();
        PixelShader  = compile ps_2_0 Kira_PS();
    }
    pass DrawParticle {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        DestBlend = INVSRCALPHA;
        SrcBlend = SRCALPHA;
        VertexShader = compile vs_2_0 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}



