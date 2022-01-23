////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DLEX_Object.fx : DiscoLightExオブジェクト描画(Lat式モデル専用)
//  ( DiscoLightEx.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
//(DiscoLightEx.fxと同名パラメータは同じ値に設定してください)

// Lat式モデルのフェイス材質番号リスト
#define LatFaceNo  "7,17,19,22,24"  // ←Lat式ミクVer2.31_Normal.pmdの例, モデルによって書き換える必要あり

// セルフシャドウの有無
#define Use_SelfShadow  1  // 0:なし, 1:有り

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024   // 512, 1024, 2048, 4096 のどれかで選択

float LightPowerMax = 2.0; // ライト最大発光強度

float LightDistance = 0.5;   // 光源の距離に対する減衰量係数(0.0～1.0程度で調整)

float AmbientPower = 0.03; // 光源よる散乱光の強さ(0.0～1.0程度で調整)

float BallRotateMax = 1.5; // ライト回転速度最大値

#define LightTexNum   6    // ライトテクスチャ種類数(最大6まで)

// ライトに貼るテクスチャファイル名
#define LightTexFile1   "LightTex01.png"
#define LightTexFile2   "LightTex02.png"
#define LightTexFile3   "LightTex03.png"
#define LightTexFile4   "LightTex04.png"
#define LightTexFile5   "LightTex05.png"
#define LightTexFile6   "LightTex06.png"

// テクスチャにキューブベース色の乗算を、1:行う, 0:行わない
#define CubeBackColor1   1
#define CubeBackColor2   1
#define CubeBackColor3   1
#define CubeBackColor4   0
#define CubeBackColor5   1
#define CubeBackColor6   0


#define FLG_EXCEPTION  0  // MMDでモデル描画が正常にされない場合はここを1にする


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////
// パラメータセット

#ifndef MIKUMIKUMOVING
    #define DLEX_OBJNAME   "(OffscreenOwner)"
#else
    #define DLEX_OBJNAME   "DiscoLightEx.pmx"
#endif

// ライトの表示のON/OFF
bool LightOn : CONTROLOBJECT < string Name = DLEX_OBJNAME; >;

// 光源位置
float3 LightPosition : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "光源位置"; >;

// 光源の距離に対する減衰量係数
static float Attenuation = 1.0f/max(lerp(0.1f, 5.0f, LightDistance), 0.1f);

//ライト種類
float NowLightTex : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "ﾗｲﾄ種類"; >;

//ライトパワー
float MorphLtPow : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "発光強度"; >;
static float LightPower = LightOn ? saturate(1.0f - MorphLtPow) * LightPowerMax : LightPowerMax;

float MorphSdBulr : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "影ぼかし"; >;
float MorphSdDens : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "影濃度"; >;
static float ShadowBulrPower = LightOn ? max( lerp(0.5f, 5.0f, MorphSdBulr), 0.0f) : 1.0f; // ソフトシャドウのぼかし強度
static float ShadowDensity = LightOn ? saturate(1.0f - MorphSdDens) : 0.0f;                // セルフ影の濃度

#define CUBECOLOR1  float3(0.5, 1.0, 0.5);
#define CUBECOLOR2  float3(1.0, 0.5, 0.5);
#define CUBECOLOR3  float3(1.0, 1.0, 0.5);
#define CUBECOLOR4  float3(0.5, 0.5, 1.0);
#define CUBECOLOR5  float3(0.5, 1.0, 1.0);
#define CUBECOLOR6  float3(1.0, 0.5, 1.0);

float pmdRotX1 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "+X回転"; >;
float pmdRotY1 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "+Y回転"; >;
float pmdRotZ1 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "+Z回転"; >;
float pmdRotX2 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "-X回転"; >;
float pmdRotY2 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "-Y回転"; >;
float pmdRotZ2 : CONTROLOBJECT < string name = DLEX_OBJNAME; string item = "-Z回転"; >;

static float ballRotX = (pmdRotX1 - pmdRotX2) * BallRotateMax;
static float ballRotY = (pmdRotY1 - pmdRotY2) * BallRotateMax;
static float ballRotZ = (pmdRotZ1 - pmdRotZ2) * BallRotateMax;

// 顔ボーン座標
float4x4 BoneFaceMatrix : CONTROLOBJECT < string name = "(self)"; string item = "頭"; >;
static float3 LatFacePos = BoneFaceMatrix._41_42_43;
static float3 LatFaceDirec = -normalize( BoneFaceMatrix._31_32_33 );

////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャのキューブ配置関連の処理

// ボール回転行列
float BallTime : TIME;
float3x3 CalcRotateMatrix(float time)
{
   float cosX, sinX;
   float cosY, sinY;
   float cosZ, sinZ;

   sincos(ballRotX * time, sinX, cosX);
   sincos(ballRotY * time, sinY, cosY);
   sincos(ballRotZ * time, sinZ, cosZ);

   return float3x3(
      cosY * cosZ + sinX * sinY * sinZ,  cosY * sinZ - sinX * sinY * cosZ, cosX * sinY,
     -cosX * sinZ,                       cosX * cosZ,                      sinX, 
      sinX * cosY * sinZ - sinY * cosZ, -sinY * sinZ - sinX * cosY * cosZ, cosX * cosY
   );
}
static float3x3 BallRotateMatrix = CalcRotateMatrix(BallTime);

// ライトボールテクスチャ
texture2D LightTex1
<
   string ResourceName = LightTexFile1;
>;
sampler LightTexSmp1 = sampler_state
{
    Texture = (LightTex1);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};

#if LightTexNum > 1
texture2D LightTex2
<
   string ResourceName = LightTexFile2;
>;
sampler LightTexSmp2 = sampler_state
{
    Texture = (LightTex2);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 2
texture2D LightTex3
<
   string ResourceName = LightTexFile3;
>;
sampler LightTexSmp3 = sampler_state
{
    Texture = (LightTex3);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 3
texture2D LightTex4
<
   string ResourceName = LightTexFile4;
>;
sampler LightTexSmp4 = sampler_state
{
    Texture = (LightTex4);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 4
texture2D LightTex5
<
   string ResourceName = LightTexFile5;
>;
sampler LightTexSmp5 = sampler_state
{
    Texture = (LightTex5);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

#if LightTexNum > 5
texture2D LightTex6
<
   string ResourceName = LightTexFile6;
>;
sampler LightTexSmp6 = sampler_state
{
    Texture = (LightTex6);
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
};
#endif

static const float lightNum = 1.0f / max(2.0*(LightTexNum-1), 1.0f);

// ライトボール色計算(2Dテクスチャをキューブ配置にして参照)
float3 GetTexCubeColor( float3 dir )
{
   float3 absDir = abs(dir);
   float2 uv;
   float3 color;

   if(absDir.x >= absDir.y && absDir.x >= absDir.z){
      if(dir.x > 0){
         uv = float2(-dir.y, dir.z) / dir.x;
         color = CUBECOLOR1;
      }else{
         uv = float2(dir.y, dir.z) / dir.x;
         color = CUBECOLOR2;
      }
   }else if(absDir.y >= absDir.x && absDir.y >= absDir.z){
      if(dir.y > 0){
         uv = float2(dir.z, -dir.x) / dir.y;
         color = CUBECOLOR3;
      }else{
         uv = float2(-dir.z, -dir.x) / dir.y;
         color = CUBECOLOR4;
      }
   }else{
      if(dir.z > 0){
         uv = float2(-dir.x, dir.y) / dir.z;
         color = CUBECOLOR5;
      }else{
         uv = float2(dir.x, dir.y) / dir.z;
         color = CUBECOLOR6;
      }
   }

   uv = 0.5f * (uv + 1.0f);

   #if LightTexNum > 1
   if(NowLightTex < lightNum)
   #endif
   {
      return tex2D(LightTexSmp1, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor1);
   }
#if LightTexNum > 1
   else
   #if LightTexNum > 2
   if(NowLightTex < lightNum*3.0f)
   #endif
   {
      return tex2D(LightTexSmp2, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor2);
   }
#endif
#if LightTexNum > 2
   else
   #if LightTexNum > 3
   if(NowLightTex < lightNum*5.0f)
   #endif
   {
      return tex2D(LightTexSmp3, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor3);
   }
#endif
#if LightTexNum > 3
   else
   #if LightTexNum > 4
   if(NowLightTex < lightNum*7.0f)
   #endif
   {
      return tex2D(LightTexSmp4, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor4);
   }
#endif
#if LightTexNum > 4
   else
   #if LightTexNum > 5
   if(NowLightTex < lightNum*9.0f)
   #endif
   {
      return tex2D(LightTexSmp5, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor5);
   }
#endif
#if LightTexNum > 5
   else{
      return tex2D(LightTexSmp6, uv).rgb * lerp(float3(1,1,1), color, CubeBackColor6);
   }
#endif

}


////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウマップ関連の処理

#if Use_SelfShadow==1

// Zプロット範囲
#define Z_NEAR  1.0     // 最近値
#define Z_FAR   1000.0  // 最遠値

// シャドウマップバッファサイズ
#if ShadowMapSize==512
    #define SMAPSIZE_WIDTH   512
    #define SMAPSIZE_HEIGHT  1024
#endif
#if ShadowMapSize==1024
    #define SMAPSIZE_WIDTH   1024
    #define SMAPSIZE_HEIGHT  2048
#endif
#if ShadowMapSize==2048
    #define SMAPSIZE_WIDTH   2048
    #define SMAPSIZE_HEIGHT  4096
#endif
#if ShadowMapSize==4096
    #define SMAPSIZE_WIDTH   4096
    #define SMAPSIZE_HEIGHT  8192
#endif

#if LightID > 1
    #define  ShadowMap(n)  FL_ShadowMap##n  // シャドウマップ(前面)テクスチャ名
#else
    #define  ShadowMap(n)  FL_ShadowMap   // シャドウマップ(前面)テクスチャ名
#endif

// 独自シャドウマップサンプラー
shared texture DL_ShadowMap : OFFSCREENRENDERTARGET;
sampler ShadowMapSamp = sampler_state {
    texture = <DL_ShadowMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


#if UseSoftShadow==1
// シャドウマップのサンプリング間隔
static float2 SMapSampStep = float2(ShadowBulrPower/1024.0f, ShadowBulrPower/2048.0f);

// シャドウマップの周辺サンプリング1
float4 GetZPlotSampleBase1(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv));
    return (Color / 6.0f);
}

// シャドウマップの周辺サンプリング2
float4 GetZPlotSampleBase2(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv));
    return (Color / 6.0f);
}
#endif

#define MSC   0.98  // マップ縮小率

// 双放物面シャドウマップよりZプロット読み取り
float2 GetZPlotDP(float3 Vec)
{
    bool flagFront = (Vec.z >= 0) ? true : false;

    if ( !flagFront ) Vec.yz = -Vec.yz;
    float2 Tex = Vec.xy * MSC / (1.0f + Vec.z);
    Tex.y = -Tex.y;
    Tex = (Tex + 1.0f) * 0.5f;
    Tex.y = flagFront ? 0.5f*Tex.y : 0.5f*(Tex.y+1.0f) + 1.0f/SMAPSIZE_HEIGHT;

    #if UseSoftShadow==1
    float4 Color;
    Color  = GetZPlotSampleBase1(Tex, 1.0f) * 0.508f;
    Color += GetZPlotSampleBase2(Tex, 2.0f) * 0.254f;
    Color += GetZPlotSampleBase1(Tex, 3.0f) * 0.127f;
    Color += GetZPlotSampleBase2(Tex, 4.0f) * 0.063f;
    Color += GetZPlotSampleBase1(Tex, 5.0f) * 0.032f;
    Color += GetZPlotSampleBase2(Tex, 6.0f) * 0.016f;
    #else
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex,0,0));
    #endif

    return Color.xy;
}

#endif


#ifndef MIKUMIKUMOVING
////////////////////////////////////////////////////////////////////////////////////////////////
//  以下MikuMikuEfect仕様コード
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse  : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient  : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower    : SPECULARPOWER < string Object = "Geometry"; >;
float3 MaterialToon     : TOONCOLOR;
float4 EdgeColor        : EDGECOLOR;

// テクスチャ材質モーフ値
#if(FLG_EXCEPTION == 0)
float4 TextureAddValue : ADDINGTEXTURE;
float4 TextureMulValue : MULTIPLYINGTEXTURE;
float4 SphereAddValue  : ADDINGSPHERETEXTURE;
float4 SphereMulValue  : MULTIPLYINGSPHERETEXTURE;
#else
float4 TextureAddValue = float4(0,0,0,0);
float4 TextureMulValue = float4(1,1,1,1);
float4 SphereAddValue  = float4(0,0,0,0);
float4 SphereMulValue  = float4(1,1,1,1);
#endif

bool use_texture;       // テクスチャの有無
bool use_spheremap;     // スフィアマップの有無
bool use_subtexture;    // サブテクスチャフラグ
bool spadd;    // スフィアマップ加算合成フラグ

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// トゥーンマップのテクスチャ
texture ObjectToonTexture: MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state {
    texture = <ObjectToonTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 VS_Edge(float4 Pos : POSITION) : POSITION
{
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 PS_Edge() : COLOR
{
    // 黒で塗りつぶし
    return float4(0, 0, 0, EdgeColor.a);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 VS_Edge();
        PixelShader  = compile ps_2_0 PS_Edge();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos       : POSITION;    // 射影変換座標
    float4 WPos      : TEXCOORD1;   // ワールド座標
    float2 Tex       : TEXCOORD2;   // テクスチャ
    float3 Normal    : TEXCOORD3;   // 法線
    float3 Eye       : TEXCOORD4;   // カメラとの相対位置
    float2 SpTex     : TEXCOORD5;   // スフィアマップテクスチャ座標
    float3 BallDir   : TEXCOORD6;   // ボールの向き
};

// 頂点シェーダ
VS_OUTPUT VS_Object(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool isLatFace)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // ワールド座標
    Out.WPos = mul( Pos, WorldMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;

    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // テクスチャ座標
    Out.Tex = Tex;

    if ( use_spheremap ) {
        if ( use_subtexture ) {
            // PMXサブテクスチャ座標
            Out.SpTex = Tex2;
        } else {
            // スフィアマップテクスチャ座標
            float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
            Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
            Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
        }
    }

    // ボールの向き
    if( isLatFace ){
        Out.BallDir = mul(LatFacePos - LightPosition, BallRotateMatrix);
    }else{
        Out.BallDir = mul(Out.WPos.xyz - LightPosition, BallRotateMatrix);
    }

    return Out;
}


// ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN, uniform bool isLatFace, uniform bool useSelfShadow) : COLOR0
{
    // ライト方向
    float3 LightDirection;
    if( isLatFace ){
        LightDirection = normalize(LatFacePos - LightPosition);
    }else{
        LightDirection = normalize(IN.WPos.xyz - LightPosition);
    }

    // ピクセル法線
    float3 Normal = normalize( IN.Normal );
    if( isLatFace ){
        Normal = LatFaceDirec;
    }else{
        Normal = normalize( IN.Normal );
    }

    // ライト色計算
    float3 LightColor = GetTexCubeColor( normalize( IN.BallDir ) );
    float LightNormal = dot( Normal, -LightDirection );
    LightColor = lerp(float3(0,0,0), LightColor, saturate(LightNormal * 2 + 0.5)) * LightOn;

    // 描画色
    float4 DiffuseColor  = MaterialDiffuse  * float4(LightColor, 1.0f);
    float3 AmbientColor  = MaterialEmmisive * LightColor * AmbientPower;
    float3 SpecularColor = MaterialSpecular * LightColor;

    // ディフューズ色＋アンビエント色 計算
    float4 Color = float4(AmbientColor, DiffuseColor.a);
    float4 ShadowColor = Color;  // 影の色
    if( isLatFace ){
        Color.rgb += lerp(0.03f, 0.7f, max(0.0f, dot(LatFaceDirec, -LightDirection))) * DiffuseColor.rgb;
        ShadowColor = Color;
    }else{
        Color.rgb += max(0.0f, dot(Normal, -LightDirection)) * DiffuseColor.rgb;
    }
    Color = saturate( Color );
    ShadowColor = saturate( ShadowColor );

    if ( use_texture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        if( useSelfShadow ) {
            // テクスチャ材質モーフ数
            TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
        }
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( use_spheremap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if( useSelfShadow ) {
            // スフィアテクスチャ材質モーフ数
            TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
        }
        if(spadd){ Color.rgb += TexColor.rgb; ShadowColor.rgb += TexColor.rgb; }
        else     { Color.rgb *= TexColor.rgb; ShadowColor.rgb *= TexColor.rgb; }
        Color.a *= TexColor.a;
        ShadowColor.a *= TexColor.a;
    }

    // トゥーン適用
    #if(FLG_EXCEPTION == 0)
    Color.rgb *= tex2D( ObjToonSampler, float2(0.0f, 0.5f - LightNormal * 0.5f) ).rgb;
    #else
    Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    #endif
    ShadowColor.rgb *= MaterialToon;

    // スペキュラ適用
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0, dot( HalfVector, Normal )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.3f;

    // ライト強度
    if( isLatFace ){
        float LtPower = LightPower / max( pow(length(LatFacePos - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }else{
        float LtPower = LightPower / max( pow(length(IN.WPos.xyz - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }

#if Use_SelfShadow==1

    // Z値
    float L = length(IN.WPos.xyz - LightPosition);
    float z = ( Z_FAR / L ) * ( L - Z_NEAR ) / ( Z_FAR - Z_NEAR );

    // シャドウマップZプロット
    float2 zplot = GetZPlotDP( LightDirection );

    #if UseSoftShadow==1
    // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
    float variance = max( zplot.y - zplot.x * zplot.x, 0.002f );
    float Comp = variance / (variance + max(z - zplot.x, 0.0f));
    #else
    // 影部判定(ソフトシャドウ無し)
    float Comp = 1.0 - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
    #endif

    // 影の合成
    ShadowColor = lerp(Color, ShadowColor, ShadowDensity);
    Color = lerp(ShadowColor, Color, Comp);

#endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウOFF）
technique MainTec0 < string MMDPass = "object"; string Subset=LatFaceNo; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true);
        PixelShader  = compile ps_3_0 PS_Object(true, false);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウOFF）
technique MainTec4 < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false);
        PixelShader  = compile ps_3_0 PS_Object(false, false);
    }
}

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウON）
technique MainTecSS0 < string MMDPass = "object_ss"; string Subset=LatFaceNo; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true);
        PixelShader  = compile ps_3_0 PS_Object(true, true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウON）
technique MainTecSS4 < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false);
        PixelShader  = compile ps_3_0 PS_Object(false, true);
    }
}


#else
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
//  以下MikuMikuMoving仕様コード
///////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//座標変換行列
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;

//材質モーフ関連
float4 AddingTexture    : ADDINGTEXTURE;       // 材質モーフ加算Texture値
float4 AddingSphere     : ADDINGSPHERE;        // 材質モーフ加算SphereTexture値
float4 MultiplyTexture  : MULTIPLYINGTEXTURE;  // 材質モーフ乗算Texture値
float4 MultiplySphere   : MULTIPLYINGSPHERE;   // 材質モーフ乗算SphereTexture値

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse    : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient    : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive   : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular   : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower      : SPECULARPOWER < string Object = "Geometry"; >;
float4 MaterialToon       : TOONCOLOR;
float4 EdgeColor          : EDGECOLOR;
float  EdgeWidth          : EDGEWIDTH;

bool use_texture;       // テクスチャの有無
bool use_spheremap;     // スフィアマップの有無
bool spadd;             // スフィアマップ加算合成フラグ
bool usetoontexturemap; // Toonテクスチャフラグ

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


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos     : POSITION;     // 射影変換座標
    float4 WPos    : TEXCOORD0;    // ワールド座標
    float2 Tex     : TEXCOORD2;    // テクスチャ
    float4 SubTex  : TEXCOORD3;    // サブテクスチャ/スフィアマップテクスチャ座標
    float3 Normal  : TEXCOORD4;    // 法線
    float3 Eye     : TEXCOORD5;    // カメラとの相対位置
    float3 BallDir : TEXCOORD6;    // ボールの向き
};

//==============================================
// 頂点シェーダ
// MikuMikuMoving独自の頂点シェーダ入力(MMM_SKINNING_INPUT)
//==============================================
VS_OUTPUT VS_Object(MMM_SKINNING_INPUT IN, uniform bool isLatFace)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    //================================================================================
    //MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。座標と法線を取得する。
    //================================================================================
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

    // ワールド座標
    Out.WPos = mul( SkinOut.Position, WorldMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( SkinOut.Position, WorldMatrix ).xyz;

    // 頂点法線
    Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

    // 頂点座標
    if (MMM_IsDinamicProjection)
    {
        float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, length(Out.Eye)));
        Out.Pos = mul( SkinOut.Position, wvpmat );
    }
    else
    {
        Out.Pos = mul( SkinOut.Position, WorldViewProjMatrix );
    }

    // テクスチャ座標
    Out.Tex = IN.Tex;
    Out.SubTex.xy = IN.AddUV1.xy;

    if ( use_spheremap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
        Out.SubTex.z = NormalWV.x * 0.5f + 0.5f;
        Out.SubTex.w = NormalWV.y * -0.5f + 0.5f;
    }

    // ボールの向き
    if( isLatFace ){
        Out.BallDir = mul(LatFacePos - LightPosition, BallRotateMatrix);
    }else{
        Out.BallDir = mul(Out.WPos.xyz - LightPosition, BallRotateMatrix);
    }

    return Out;
}


// ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN, uniform bool isLatFace) : COLOR0
{
    // ライト方向
    float3 LightDirection;
    if( isLatFace ){
        LightDirection = normalize(LatFacePos - LightPosition);
    }else{
        LightDirection = normalize(IN.WPos.xyz - LightPosition);
    }

    // ピクセル法線
    float3 Normal = normalize( IN.Normal );
    if( isLatFace ){
        Normal = LatFaceDirec;
    }else{
        Normal = normalize( IN.Normal );
    }

    // ライト色計算
    float3 LightColor = GetTexCubeColor( normalize( IN.BallDir ) );
    float LightNormal = dot( Normal, -LightDirection );
    LightColor = lerp(float3(0,0,0), LightColor, saturate(LightNormal * 2 + 0.5)) * LightOn;

    // 描画色
    float4 DiffuseColor  = MaterialDiffuse  * float4(LightColor, 1.0f);
    float3 AmbientColor  = MaterialEmmisive * LightColor * AmbientPower;
    float3 SpecularColor = MaterialSpecular * LightColor;

    // ディフューズ色＋アンビエント色 計算
    float4 Color = float4(AmbientColor, DiffuseColor.a);
    float4 ShadowColor = Color;  // 影の色
    if( isLatFace ){
        Color.rgb += lerp(0.03f, 0.7f, max(0.0f, dot(LatFaceDirec, -LightDirection))) * DiffuseColor.rgb;
        ShadowColor = Color;
    }else{
        Color.rgb += max(0.0f, dot(Normal, -LightDirection)) * DiffuseColor.rgb;
    }
    Color = saturate( Color );
    ShadowColor = saturate( ShadowColor );

    float4 texColor = float4(1,1,1,1);
    float  texAlpha = MultiplyTexture.a + AddingTexture.a;

    // テクスチャ適用
    if (use_texture) {
        texColor = tex2D(ObjTexSampler, IN.Tex);
        texColor.rgb = (texColor.rgb * MultiplyTexture.rgb + AddingTexture.rgb) * texAlpha + (1.0 - texAlpha);
    }
    Color.rgb *= texColor.rgb;
    ShadowColor.rgb *= texColor.rgb;

    // スフィアマップ適用
    if ( use_spheremap ) {
        // スフィアマップ適用
        float3 texSphare = tex2D(ObjSphareSampler,IN.SubTex.zw).rgb * MultiplySphere.rgb + AddingSphere.rgb;
        if(spadd){ Color.rgb += texSphare; ShadowColor.rgb += texSphare; }
        else     { Color.rgb *= texSphare; ShadowColor.rgb *= texSphare; }
    }
    // アルファ適用
    Color.a *= texColor.a;
    ShadowColor.a *= texColor.a;

    // セルフシャドウなしのトゥーン適用
    if (usetoontexturemap ) {
        //================================================================================
        // MikuMikuMovingデフォルトのトゥーン色を取得する(MMM_GetToonColor)
        //================================================================================
        float3 color = MMM_GetToonColor(MaterialToon, Normal, LightDirection, LightDirection, LightDirection);
        Color.rgb *= color;
        ShadowColor.rgb *= MaterialToon.rgb;
    }

    // スペキュラ適用
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0, dot( HalfVector, Normal )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;
    ShadowColor.rgb += Specular*0.3f;

    // ライト強度
    if( isLatFace ){
        float LtPower = LightPower / max( pow(length(LatFacePos - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }else{
        float LtPower = LightPower / max( pow(length(IN.WPos.xyz - LightPosition) * 0.1f, Attenuation), 1.0f);
        Color.rgb *= LtPower;
        ShadowColor.rgb *= LtPower;
    }

#if Use_SelfShadow==1

    // Z値
    float L = length(IN.WPos.xyz - LightPosition);
    float z = ( Z_FAR / L ) * ( L - Z_NEAR ) / ( Z_FAR - Z_NEAR );

    // シャドウマップZプロット
    float2 zplot = GetZPlotDP( LightDirection );

    #if UseSoftShadow==1
    // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
    float variance = max( zplot.y - zplot.x * zplot.x, 0.002f );
    float Comp = variance / (variance + max(z - zplot.x, 0.0f));
    #else
    // 影部判定(ソフトシャドウ無し)
    float Comp = 1.0 - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
    #endif

    // 影の合成
    ShadowColor = lerp(Color, ShadowColor, ShadowDensity);
    Color = lerp(ShadowColor, Color, Comp);

#endif

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウOFF）
technique MainTec0 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true);
        PixelShader  = compile ps_3_0 PS_Object(true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウOFF）
technique MainTec4 < string MMDPass = "object"; bool UseSelfShadow = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false);
        PixelShader  = compile ps_3_0 PS_Object(false);
    }
}

// オブジェクト描画用テクニック（Lat式フェイス, セルフシャドウON）
technique MainTecSS0 < string MMDPass = "object"; string Subset=LatFaceNo; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(true);
        PixelShader  = compile ps_3_0 PS_Object(true);
    }
}

// オブジェクト描画用テクニック（PMD・PMXLフェイス以外, セルフシャドウON）
technique MainTecSS4 < string MMDPass = "object"; bool UseSelfShadow = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 VS_Object(false);
        PixelShader  = compile ps_3_0 PS_Object(false);
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 VS_Edge(MMM_SKINNING_INPUT IN) : POSITION
{
    //================================================================================
    //MikuMikuMoving独自のスキニング関数(MMM_SkinnedPosition)。座標を取得する。
    //================================================================================
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

    // ワールド座標
    float4 Pos = mul(SkinOut.Position, WorldMatrix);

    // 法線方向
    float3 Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

    // 頂点座標
    if (MMM_IsDinamicProjection)
    {
        float dist = length(CameraPosition - Pos.xyz);
        float4x4 vpmat = mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, dist));

        Pos += float4(Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(Pos.xyz, CameraPosition) * MMM_GetDynamicFovEdgeRate(dist);
        Pos = mul( Pos, vpmat );
    }
    else
    {
        Pos += float4(Normal, 0) * IN.EdgeWeight * EdgeWidth * distance(Pos.xyz, CameraPosition);
        Pos = mul( Pos, ViewProjMatrix );
    }

    return Pos;
}

//==============================================
// ピクセルシェーダ
//==============================================
float4 PS_Edge() : COLOR
{
    // 黒で塗りつぶし
    return float4(0, 0, 0, EdgeColor.a);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 VS_Edge();
        PixelShader  = compile ps_2_0 PS_Edge();
    }
}


#endif
///////////////////////////////////////////////////////////////////////////////////////////////
//地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }

