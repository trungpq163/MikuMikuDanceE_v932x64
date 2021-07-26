
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
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 17000;
> = 17000;

//表示領域
float AreaSize
<
   string UIName = "AreaSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 50;
   int UIMax = 2000;
> = 100;


//落下速度
float Speed
<
   string UIName = "Speed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 250.0;
> = 0;

//パーティクルサイズ
float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = 0.15;

//落下軌道のゆらぎ
float NoizeLevel
<
   string UIName = "NoizeLevel";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 4.0;
> = 1;

//ゆらぎ速度
float NoizeSpeed
<
   string UIName = "NoizeSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 4.0;
> = 0.4;

//テクスチャの回転速度
float RotationSpeed
<
   string UIName = "RotationSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = 0.5;

//回転ゆらぎ
float RotationNoize
<
   string UIName = "RotationNoize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 3.0;
> = 3;

//サイズゆらぎ
float Flicker
<
   string UIName = "Flicker";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 4;

//サイズゆらぎ速度
float FlickerSpeed
<
   string UIName = "FlickerSpeed";
  string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 0.3;

//ブラー
float Blur
<
   string UIName = "Blur";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 1.0;

//強調
float AlphaAppend
<
   string UIName = "AlphaAppend";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 4.0;
> = 2.0;



//パーティクルテクスチャ
texture2D Tex1 <
    string ResourceName = "t.png";
    int MipLevels = 0;
>;
sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    AddressU  = Clamp;
    AddressV = Clamp;
    MAXANISOTROPY = 16;
};

texture2D Tex2 <
    string ResourceName = "t1.png";
    int MipLevels = 0;
>;
sampler Tex2Samp = sampler_state {
    texture = <Tex2>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    AddressU  = Clamp;
    AddressV = Clamp;
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


float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float size1 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float size = size1 * 0.1;

float ftime : TIME <bool SyncInEditMode = false;>;

float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 
static float pos_y = matWorld._42;
static float pos_z = matWorld._43;

// 座法変換行列
float4x4 WorldMatrix : WORLD;
float4x4 ViewProjMatrix    : VIEWPROJECTION;
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;

float4x4 WorldMatrixInverse : WORLDINVERSE;
float4x4 ViewMatrixInverse : VIEWINVERSE;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;


static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

static float3x3 RotMatrix = {
    normalize(WorldMatrix[0].xyz),
    normalize(WorldMatrix[1].xyz),
    normalize(WorldMatrix[2].xyz),
};
static float3x3 RotMatrixInverse = {
    normalize(WorldMatrixInverse[0].xyz),
    normalize(WorldMatrixInverse[1].xyz),
    normalize(WorldMatrixInverse[2].xyz),
};

float3 CameraDirection : DIRECTION < string Object = "Camera"; >;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;


// Controller対応 ////////////////////////////////////////////////////////////

bool flag1 : CONTROLOBJECT < string name = "WorldParticleController.pmd"; >;
//bool flag1 = false;

float count_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "粒子数"; >;
float AreaSize_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "領域広さ"; >;

float Speed_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "落下速度"; >;
float ParticleSize_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "粒子ｻｲｽﾞ"; >;
float NoizeLevel_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "ゆらぎ"; >;

float R : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "R"; >;
float G : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "G"; >;
float B : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "B"; >;
float Shine : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "明るく"; >;

float NoizeSpeed_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "ゆれ速度"; >;
float RotationSpeed_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "回転"; >;
float RotationNoize_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "回転ゆれ"; >;
float Flicker_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "ｻｲｽﾞゆれ"; >;

float Blur_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "ブラー"; >;

float TextureSelect : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "ﾃｸｽﾁｬ"; >;
float Transparent : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "透過"; >;
float AlphaAppend_e : CONTROLOBJECT < string name = "WorldParticleController.pmd"; string item = "強調"; >;


static float count_m = flag1 ? (count_e * 30000) : count;
static float AreaSize_m = flag1 ? (AreaSize_e * 1000) : AreaSize;

static float Speed_m = flag1 ? (Speed_e * Speed_e * 300) : Speed;
static float ParticleSize_m = (flag1 ? (ParticleSize_e * ParticleSize_e * 40) : ParticleSize) * size;
static float NoizeLevel_m = flag1 ? (NoizeLevel_e * 4) : NoizeLevel;
static float Flicker_m = flag1 ? (Flicker_e * 1) : Flicker;

static float3 ParticleColor_m = flag1 ? (float3(R,G,B) * pow(10, Shine * 3)) : ParticleColor;

static float NoizeSpeed_m = flag1 ? (NoizeSpeed_e * 5) : NoizeSpeed;
static float RotationSpeed_m = flag1 ? (RotationSpeed_e * 10) : RotationSpeed;
static float RotationNoize_m = flag1 ? RotationNoize_e : RotationNoize;
static float Blur_m = flag1 ? Blur_e : Blur;
static float AlphaAppend_m = flag1 ? (AlphaAppend_e * 4) : AlphaAppend;


// 表示領域中心
static float3 AreaCenter = CameraPosition + CameraDirection * AreaSize_m / 4;
static float3 AreaCenterT = AreaCenter / AreaSize_m;



///////////////////////////////////////////////////////////////////////////////////////////////

//乱数取得
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5, 0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,0));
}

///////////////////////////////////////////////////////////////////////////////////////////////

//粒子位置決定関数
float4 getParticlePos(float index, float time){
    
    // ランダム配置
    float4 base_pos = getRandom(index);
    
    //落下
    base_pos.y = frac(base_pos.y - (Speed_m * time / AreaSize_m));
    
    //ノイズ付加
    float stime = time * NoizeSpeed_m;
    base_pos.x += (sin(stime * 0.8 + index) + cos(stime * 0.5 + index) * 0.5) * (NoizeLevel_m / AreaSize_m);
    base_pos.z += (sin(stime * 0.45 + index) * 0.6 + cos(stime * 0.9 + index) * 0.8) * (NoizeLevel_m / AreaSize_m);
    base_pos.y += (sin(stime * 0.45 + index) * 0.6 + cos(stime * 0.9 + index) * 0.8) * (NoizeLevel_m / AreaSize_m);
    //領域変更
    float3 rotinvcenter = mul(AreaCenterT, RotMatrixInverse);
    base_pos.xyz -= rotinvcenter;
    float3 inner_pos = frac(base_pos.xyz); //領域内座標
    inner_pos -= 0.5;
    base_pos.xyz = inner_pos + rotinvcenter;
    
    //領域サイズ変更
    base_pos.xyz *= AreaSize_m;
    
    //回転
    base_pos.xyz = mul(base_pos.xyz, RotMatrix);
    
    return base_pos;
}

///////////////////////////////////////////////////////////////////////////////////////////////

//粒子フェード関数
float ParticleFade(float4 particle_pos){
    float alpha;
    
    //地面フェード
    alpha = saturate((particle_pos.y - pos_y) * 0.2);
    
    //遠方は薄く
    float fadelen = (AreaSize_m * 0.75);
    float camera_len = length(particle_pos.xyz - CameraPosition.xyz);
    float farfade = saturate((fadelen - camera_len) / fadelen);
    
    farfade = pow(farfade, 0.4);
    //farfade = sqrt(farfade);
    
    alpha *= farfade;
    
    //至近距離は薄く
    alpha *= saturate((camera_len - 10) * 0.05);
    
    return alpha;
}

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 TexRot     : TEXCOORD1;   // テクスチャ回転
    float4 ZCalcTex   : TEXCOORD2;   // Z値
    float  Alpha      : COLOR0;
};

///////////////////////////////////////////////////////////////////////////////////////////////

// 頂点シェーダ
VS_OUTPUT WPEngine_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform bool Shadow)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float index = Pos.z;
    Pos.z = 0;
    
    //サイズ変更
    float fstime = ftime * FlickerSpeed * NoizeSpeed_m;
    float flicker = (sin(fstime * 5 + index) * 0.5 + 0.5) + (cos(fstime * 2.3 + index) * 0.5 + 0.5) * 0.5;
    
    flicker = lerp(1, flicker, Flicker_m);
    
    Pos.xy *= ParticleSize_m * flicker;
    
    // ビルボード化
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    //パーティクル座標の取得
    float4 particle_pos = getParticlePos(index, ftime);
    
    Pos.xyz += particle_pos.xyz;
    
    //表示上限より上のパーティクルは隠す
    Pos.z -= (index >= count_m) * 100000;
    
    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    
    //アルファ適用
    Out.Alpha *= ParticleFade(particle_pos);
    Out.Alpha *= alpha1 * (1 - Transparent);
    Out.Alpha *= 1 + AlphaAppend_m;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    //回転単位ベクトルの作成
    float rot = ftime * RotationSpeed_m * (1 - (sin(index) * RotationNoize_m)) + index * 6;
    Out.TexRot.xy = float2(cos(rot), sin(rot)); //Ut
    Out.TexRot.zw = float2(-sin(rot), cos(rot)); //Vt
    
    if(Shadow){
        // ライト視点によるワールドビュー射影変換
        float4 uwpos = Pos;
        uwpos.xyz /= size1;
        uwpos.xyz = mul(uwpos.xyz, RotMatrixInverse);
        Out.ZCalcTex = mul( uwpos, LightWorldViewProjMatrix );
        
    }else{
        Out.ZCalcTex = 0;
    }
    
    return Out;
}

///////////////////////////////////////////////////////////////////////////////////////////////

// ピクセルシェーダ
float4 WPEngine_PS( VS_OUTPUT input ) : COLOR0
{
    //UVの座標変換
    float2 tex = input.Tex - 0.5;
    tex = input.TexRot.xy * tex.x + input.TexRot.zw * tex.y;
    tex += 0.5;
    
    float4 color1 = tex2D( Tex1Samp, tex );
    float4 color2 = tex2D( Tex2Samp, tex );
    float4 color = lerp(color1, color2, TextureSelect);
    color.rgb = ParticleColor_m;
    color.a *= input.Alpha;
    
    //color = float4(1,1,1,1);
    
    return color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

// シャドウバッファのサンプラ
sampler DefSampler : register(s0);

// ピクセルシェーダ(シャドウ版)
float4 WPEngine_S_PS( VS_OUTPUT input ) : COLOR0
{
    //UVの座標変換
    float2 tex = input.Tex - 0.5;
    tex = input.TexRot.xy * tex.x + input.TexRot.zw * tex.y;
    tex += 0.5;
    
    float4 color1 = tex2D( Tex1Samp, tex );
    float4 color2 = tex2D( Tex2Samp, tex );
    float4 color = lerp(color1, color2, TextureSelect);
    color.rgb *= ParticleColor_m;
    color.a *= input.Alpha;
    
    //シャドウ対応
    
    float light = 1;
    float darklight = 0.3;
    
    // テクスチャ座標に変換
    input.ZCalcTex /= input.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord = 0.5 + (input.ZCalcTex.xy * float2(0.5, -0.5));
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        light = darklight;
    } else {
        light = (input.ZCalcTex.z >= tex2D(DefSampler,TransTexCoord).r) ? darklight : 1;
    }
    
    color *= light;
    
    return color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        
        VertexShader = compile vs_3_0 WPEngine_VS(false);
        PixelShader  = compile ps_3_0 WPEngine_PS();
    }
}

technique MainTec2 < string MMDPass = "object_ss"; > {
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        
        VertexShader = compile vs_3_0 WPEngine_VS(true);
        PixelShader  = compile ps_3_0 WPEngine_S_PS();
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
technique ZplotTec < string MMDPass = "zplot"; > {
    /*pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS();
    }*/
}

// 地面影なし
technique ShadowTec < string MMDPass = "shadow"; > { }