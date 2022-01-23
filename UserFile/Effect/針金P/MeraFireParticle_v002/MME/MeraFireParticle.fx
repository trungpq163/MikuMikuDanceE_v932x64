////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MeraFireParticle.fx ver0.0.2 メラメラ感のある粒子系炎エフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float ParticleSize = 0.15;       // 粒子大きさ
float ParticleSpeedMax = 3.0;    // 粒子初速最大値
float ParticleSpeedMin = 2.0;    // 粒子初速最小値
float ParticleInitPos = 0.5;     // 粒子発生時の位置(大きくすると粒子の配置がばらつきます)
float ParticleLife = 1.0;        // 粒子の寿命(秒)
float ParticleDecrement = 0.2;   // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float ParticleOccur = 1.0;       // 粒子発生度(大きくすると粒子が出やすくなる)
float DiffusionAngle = 30.0;     // 噴射拡散角(0.0～180.0)
float SpeedDampCoef = 2.0;       // 噴射速度の減衰係数
float SpeedFixCoef = 0.3;        // 噴射速度の固定係数

#define FireSourceTexFile  "FireSource.png" // 炎の種となるテクスチャファイル名
#define FireColorTexFile   "palette1.png" // 炎色palletテクスチャファイル名

//メラメラ感を決めるパラメータ,ここを弄れば見た目が結構代わる。
float fireDisFactor = 0.02f; 
float fireSizeFactor = 3.0f;
float fireShakeFactor = 0.3f;

float fireRiseFactor = 4.0;    // 炎の上昇度
float fireWvAmpFactor = 1.0;   // 炎の左右の揺らぎ振幅
float fireWvFreqFactor = 0.3;  // 炎の左右の揺らぎ周波数

#define RISE_DIREC  1  // 炎の上昇方向を 0:アクセサリ操作可, 1:上方向固定
#define ADD_FLG     1  // 0:半透明合成, 1:加算合成


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define ArrangeFileName "Arrange.pfm" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A   4   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH     1   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 1024   // 配置･乱数情報テクスチャピクセル高さ

// 作業レイヤサイズ
#define TEX_WORK_WIDTH  256
#define TEX_WORK_HEIGHT 512

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

static float diffD = radians( clamp(90.0f - DiffusionAngle, -90.0f, 90.0f) );

float time : TIME;
float elapsed_time : ELAPSEDTIME;
static float Dt = clamp(elapsed_time, 0.001f, 0.1f);

static float P_Count = ParticleOccur * (Dt / ParticleLife) * 10.0f; // 1フレーム当たりの粒子発生数
static float fireShake = fireShakeFactor / (Dt * 60.0f);

// 座標変換行列
float4x4 WorldMatrix          : WORLD;
float4x4 WorldViewMatrix      : WORLDVIEW;
float4x4 ViewProjMatrix       : VIEWPROJECTION;
float4x4 WorldViewProjMatrix  : WORLDVIEWPROJECTION;
float4x4 ViewMatrixInverse    : VIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

// カメラZ軸回転行列
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float4 WPos = float4(WorldMatrix._41_42_43, 1);
static float4 pos0 = mul( WPos, ViewProjMatrix);
#if RISE_DIREC==0
    static float4 posY = mul( float4(WPos.xyz + WorldMatrix._21_22_23, 1), ViewProjMatrix);
#else
    static float4 posY = mul( float4(WPos.x, WPos.y+1, WPos.z, 1), ViewProjMatrix);
#endif
static float2 rotVec0 = posY.xy/posY.w - pos0.xy/pos0.w;
static float2 rotVec = normalize( float2(rotVec0.x*ViewportSize.x/ViewportSize.y, rotVec0.y) );
static float3x3 RotMatrix = float3x3( rotVec.y, -rotVec.x, 0,
                                      rotVec.x,  rotVec.y, 0,
                                             0,         0, 1 );
static float3x3 BillboardZRotMatrix = mul( RotMatrix, BillboardMatrix);

// 上下カメラアングルによる縮尺(適当)
float3 CameraDirection : DIRECTION < string Object = "Camera"; >;
#if RISE_DIREC==0
    static float absCosD = abs( dot(normalize(WorldMatrix._21_22_23), -CameraDirection) );
#else
    static float absCosD = abs( dot(float3(0,1,0), -CameraDirection) );
#endif
static float yScale = 1.0 - 0.7*smoothstep(0.5, 1.0, absCosD);

// 炎の種となるテクスチャ
texture2D ParticleTex <
    string ResourceName = FireSourceTexFile;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 炎色palletテクスチャ
texture2D FireColor <
    string ResourceName = FireColorTexFile; 
    int Miplevels = 1;
    >;
sampler2D FireColorSamp = sampler_state {
    texture = <FireColor>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// ノイズテクスチャ
texture2D NoiseOne <
    string ResourceName = "NoiseFreq1.png"; 
    int Miplevels = 1;
>;
sampler2D NoiseOneSamp = sampler_state {
    texture = <NoiseOne>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV = WRAP;
};
texture2D NoiseTwo <
    string ResourceName = "NoiseFreq2.png"; 
    int Miplevels = 1;
>;
sampler2D NoiseTwoSamp = sampler_state {
    texture = <NoiseTwo>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// 炎アニメーション作業レイヤ
texture2D WorkLayer : RENDERCOLORTARGET <
    int Width = TEX_WORK_WIDTH;
    int Height = TEX_WORK_HEIGHT;
    int Miplevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D WorkLayerSamp = sampler_state {
    texture = <WorkLayer>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture WorkLayerDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WORK_WIDTH;
   int Height=TEX_WORK_HEIGHT;
    string Format = "D24S8";
>;

// 配置･乱数情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};

// 粒子座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s3) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp = sampler_state
{
   Texture = <VelocityTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す

float3 Color2Float(int index, int item)
{
    return tex2D(ArrangeSmp, float2((item+0.5f)/TEX_WIDTH_A, (index+0.5f)/TEX_HEIGHT)).xyz;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

// 粒子の発生・座標計算(xyz:座標,w:経過時間)
float4 UpdatePos_PS(float2 texCoord: TEXCOORD0, uniform bool flag) : COLOR
{
   float p_count;
   if( flag ){
      p_count = P_Count;
   }else{
      p_count = 0.0f;
   }

   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 1.001f){
      // 未発生粒子の中から新たに粒子を発生させる
      int j = floor( texCoord.y*TEX_HEIGHT );
      float3 pos = Color2Float(j, 0);
      float4 WPos = float4(pos.x, 1.0f-abs(pos.y), pos.z, 1.0f);
      WPos.xyz *= ParticleInitPos * AcsSi * 0.01f;
      #if RISE_DIREC==0
          WPos = mul( WPos, WorldMatrix );
      #else
          WPos.xyz = WPos.xyz * length(WorldMatrix._11_12_13) + WorldMatrix._41_42_43;
      #endif
      Pos.xyz = WPos.xyz / WPos.w;  // 発生初期座標

      // 新たに粒子を発生させるかどうかの判定
      float p_index = float(j);
      if(p_index < Vel.w) p_index += float(TEX_WIDTH*TEX_HEIGHT);
      if(p_index < Vel.w+p_count){
         Pos.w = 1.0011f;  // Pos.w>1.001で粒子発生
      }
   }else{
      // 粒子の座標更新
      Pos.xyz += Vel.xyz * Dt;

      // すでに発生している粒子は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w-1.0f, ParticleLife); // 指定時間を超えると0
   }

   return Pos;
}

// 粒子の速度計算
float4 UpdateVelocity_PS(float2 texCoord: TEXCOORD0, uniform bool flag) : COLOR
{
   float p_count;
   if( flag ){
      p_count = P_Count;
   }else{
      p_count = 0.0f;
   }

   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 1.00111f){
      // 発生したての粒子に初速度与える
      int j = floor( texCoord.y*TEX_HEIGHT );
      float3 rand = Color2Float(j, 2);
      float time1 = time + 100.0f;
      float ss, cs;
      sincos( lerp(diffD, PAI*0.5f, frac(rand.x*time1)), ss, cs );
      float st, ct;
      sincos( lerp(-PAI, PAI, frac(rand.y*time1)), st, ct );
      float3 vec  = float3( cs*ct, ss, cs*st );
      float speed = lerp(ParticleSpeedMin, ParticleSpeedMax, 1.0f-rand.z*rand.z);
      #if RISE_DIREC==0
          Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) ) * speed;
      #else
          Vel.xyz = normalize( vec ) * speed;
      #endif
   }else{
      // すでに発生している粒子の速度を減衰させる
      float speedRate = (exp(-SpeedDampCoef*(Pos.w-1.0f) ) + SpeedFixCoef) /
                        (exp(-SpeedDampCoef*(Pos.w-1.0f-Dt)) + SpeedFixCoef);
      Vel.xyz *= float3(speedRate, pow(speedRate, 0.3), speedRate);
   }

   // 次発生粒子の起点
   Vel.w += p_count;
   if(Vel.w >= float(TEX_WIDTH*TEX_HEIGHT)) Vel.w -= float(TEX_WIDTH*TEX_HEIGHT);
   if(time < 0.001f) Vel.w = 0.0f;

   return Vel;
}

///////////////////////////////////////////////////////////////////////////////////////
// 炎アニメーションの描画

// 頂点シェーダ
VS_OUTPUT VS_FireAnimation( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out;
    
    Out.Pos = Pos;
    Out.texCoord = Tex + float2(0.5f/TEX_WORK_WIDTH, 0.5f/TEX_WORK_HEIGHT);
    
    return Out;
}

// ピクセルシェーダ
float4 PS_FireAnimation(float2 Tex: TEXCOORD0, uniform bool flag) : COLOR0
{
    float2 oldTex = Tex;
    // 上に炎をずらす ※参照位置を下にずらすと絵は上にずれる
    //oldTex.y += (0.5f/TEX_WORK_HEIGHT * fireRiseFactor);
    //oldTex.x += 0.5f/TEX_WORK_WIDTH * fireWvAmpFactor * (abs(frac(fireWvFreqFactor*time)*2.0f - 1.0f) - 0.5f);
    float2 moveVec = float2( 0.5f/TEX_WORK_WIDTH * fireWvAmpFactor * (abs(frac(fireWvFreqFactor*time)*2.0f - 1.0f) - 0.5f),
                      0.5f/TEX_WORK_HEIGHT * fireRiseFactor * yScale );
    oldTex += moveVec;

    float4 oldCol = tex2D(WorkLayerSamp, oldTex);
    
    float4 tmp = oldCol;
    if( flag ){
        // 作業レイヤに燃焼物を描画 ※前回の炎をずらした後に描画する事で燃焼物自体は、同じ位置に描画できる。
        tmp = max(oldCol, tex2D(ParticleSamp, Tex));
    }
    
    // ノイズの追加
    float2 noiseTex;
    noiseTex = Tex;
    noiseTex.y += time * fireShake;
    tmp = saturate(tmp - fireDisFactor * tex2D(NoiseOneSamp, noiseTex * fireSizeFactor));
    
    noiseTex = Tex;
    noiseTex.x += time * fireShake;
    tmp = saturate(tmp - fireDisFactor * 0.5f * tex2D(NoiseTwoSamp, noiseTex * fireSizeFactor));
    
    return float4(tmp.rgb,1);
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float  Alpha : COLOR0;      // 粒子の透過度
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out;

   int Index0 = round( Pos.z * 100.0f );
   Pos.x = 2.0f * (Tex.x - 0.5f);
   Pos.y = 4.0f * (0.5f - Tex.y);
   Pos.z = 0.0f;
   int i0 = Index0 / 1024;
   int i = i0 * 8;
   int j = Index0 % 1024;
   float2 texCoord = float2((i0+0.5)/TEX_WIDTH, (j+0.5)/TEX_HEIGHT);

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 1));

   // 経過時間
   float etime = Pos0.w - 1.0f;

   // 経過時間に対する粒子拡大度
   float scale = 4.0f * sqrt(etime) + 2.0f;
   scale *= 1.0f + 0.5f * (0.66f * sin(22.1f * Index0) + 0.33f * cos(33.6f * Index0));

   // 粒子の位置・大きさ補正
   Pos.y += 1.5f;
   Pos.xy *= ParticleSize * scale * AcsSi;

   // ビルボード+z軸回転
   Pos.xyz = mul( Pos.xyz, BillboardZRotMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.xyz *= step(0.001f, etime);
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の乗算色
   Out.Alpha = step(0.001f, etime) * smoothstep(0.0f, min(0.5f, ParticleLife*ParticleDecrement), etime)
                                   * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -etime);

   // テクスチャ座標
   Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float tmp = tex2D(WorkLayerSamp, IN.Tex).r;
    float4 FireCol = tex2D(FireColorSamp, saturate(float2(tmp, 0.5f)));

    #if ADD_FLG == 1
        FireCol.rgb *=  0.5f * IN.Alpha * AcsTr;
    #else
        FireCol.a *= tmp * IN.Alpha * AcsTr;
    #endif

    return FireCol;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec0 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=WorkLayer;"
            "RenderDepthStencilTarget=WorkLayerDepthBuffer;"
            "Pass=FireAnimation;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
           "Pass=DrawObject;";
>{
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS(true);
   }
   pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS(true);
   }
   pass FireAnimation < string Script= "Draw=Buffer;"; > {
       ZWriteEnable = FALSE;
       VertexShader = compile vs_2_0 VS_FireAnimation();
       PixelShader  = compile ps_2_0 PS_FireAnimation(true);
   }
   pass DrawObject {
        ZENABLE = TRUE;
        ZWriteEnable = FALSE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}


technique MainTec1 < string MMDPass = "object_ss";
   string Script = 
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=WorkLayer;"
            "RenderDepthStencilTarget=WorkLayerDepthBuffer;"
            "Pass=FireAnimation;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
           "Pass=DrawObject;";
>{
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS(false);
   }
   pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS(false);
   }
   pass FireAnimation < string Script= "Draw=Buffer;"; > {
       ZWriteEnable = FALSE;
       VertexShader = compile vs_2_0 VS_FireAnimation();
       PixelShader  = compile ps_2_0 PS_FireAnimation(false);
   }
   pass DrawObject {
        ZENABLE = TRUE;
        ZWriteEnable = FALSE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}



///////////////////////////////////////////////////////////////////////////////////////////////
// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }

