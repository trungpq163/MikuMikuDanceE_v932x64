////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PopTex.fx ver0.0.3  テクスチャ画像を盛り上げてから，ぷるんぷるんさせます．
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile     "pudding.png"         // 画面に貼り付けるテクスチャファイル名
#define HeightFile  "puddingHeight.png"   // 高さマップテクスチャファイル名
#define ElasticFile "puddingSoft.png"     // 軟度マップテクスチャファイル名

float RectSlace = 1.0;   // 画像の縦横比

float HeightScale = 1.0;      // 高さスケール
float ElasticScale = 1000.0;  // 弾性スケール
float ViscosityScale = 20.0;  // 粘性スケール

#define MappingType  0  // マッピングに使う値 0:グレースケール割り当て,1:α値を割り当て

// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// モデル頂点数（Xファイルと連動しているので、変更不可）
#define VERTEX_WIDTH   256
#define VERTEX_HEIGHT  256

static float XRate = ((float)VERTEX_WIDTH - 1.0f)/(float)VERTEX_WIDTH;
static float YRate = ((float)VERTEX_HEIGHT - 1.0f)/(float)VERTEX_HEIGHT;
static float XStep = 1.0f/(float)VERTEX_WIDTH;
static float YStep = 1.0f/(float)VERTEX_HEIGHT;

// PMDパラメータ
float PmdHeight : CONTROLOBJECT < string name = "PopTexControl.pmd"; string item = "高さ"; >;
float PmdSoft : CONTROLOBJECT < string name = "PopTexControl.pmd"; string item = "柔らかさ"; >;
float PmdElastic : CONTROLOBJECT < string name = "PopTexControl.pmd"; string item = "弾力"; >;
float PmdViscosity : CONTROLOBJECT < string name = "PopTexControl.pmd"; string item = "粘り"; >;
static float Height = PmdHeight*HeightScale;
static float Soft = PmdSoft;
static float Elastic = PmdElastic*ElasticScale;
static float Viscosity = PmdViscosity*ViscosityScale;


// 座標変換行列
float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;
float4x4 ProjMatrix          : PROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 LightViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float4   GroundShadowColor : GROUNDSHADOWCOLOR;

// ライト色
#ifndef MIKUMIKUMOVING
float3 LightDiffuse      : DIFFUSE  < string Object = "Light"; >;
float3 LightAmbient      : AMBIENT  < string Object = "Light"; >;
float3 LightSpecular     : SPECULAR < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;
#else
float3 LightDiffuses[MMM_LightCount]   : LIGHTDIFFUSECOLORS;
float3 LightAmbients[MMM_LightCount]   : LIGHTAMBIENTCOLORS;
float3 LightSpeculars[MMM_LightCount]  : LIGHTSPECULARCOLORS;
static float4 DiffuseColor = MaterialDiffuse * float4(LightDiffuses[0], 1.0f);
static float3 AmbientColor = MaterialAmbient * LightAmbients[0] + MaterialEmmisive*1.3f;
static float3 SpecularColor = MaterialSpecular * LightSpeculars[0] * 0.1f;
#endif

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000

// 画面に貼り付けるテクスチャ
texture2D screen_tex <
    string ResourceName = TexFile;
    int MipLevels = 0;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 高さ情報を記録したテクスチャ
texture2D screen_height <
    string ResourceName = HeightFile;
    int MipLevels = 1;
>;
sampler HeightSampler = sampler_state {
    texture = <screen_height>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 弾性情報を記録したテクスチャ
texture2D screen_elastic <
    string ResourceName = ElasticFile;
    int MipLevels = 1;
>;
sampler ElasticSampler = sampler_state {
    texture = <screen_elastic>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 共通の深度ステンシルバッファ
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=VERTEX_WIDTH;
   int Height=VERTEX_HEIGHT;
    string Format = "D24S8";
>;

// 初期座標記録用
texture VertexBaseTex : RenderColorTarget
<
   int Width=VERTEX_WIDTH;
   int Height=VERTEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpVertexBase = sampler_state
{
   Texture = (VertexBaseTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 1ステップ前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=VERTEX_WIDTH;
   int Height=VERTEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpCoordOld = sampler_state
{
   Texture = (CoordTexOld);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 現在の座標記録用
texture CoordTex : RenderColorTarget
<
   int Width=VERTEX_WIDTH;
   int Height=VERTEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpCoord : register(s3) = sampler_state
{
   Texture = (CoordTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 速度記録用
texture VelocityTex : RenderColorTarget
<
   int Width=VERTEX_WIDTH;
   int Height=VERTEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpVelocity = sampler_state
{
   Texture = (VelocityTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 時間間隔計算(MMMでは ELAPSEDTIME はオフスクリーンの有無で大きく変わるので使わない)

float time : Time;

#ifndef MIKUMIKUMOVING

float elapsed_time : ELAPSEDTIME;
static float Dt = clamp(elapsed_time, 0.001f, 0.1f);

#else

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_R32F" ;
>;
sampler TimeTexSmp = sampler_state
{
   Texture = <TimeTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D3DFMT_D24S8";
>;
static float Dt = clamp(time - tex2D(TimeTexSmp, float2(0.5f,0.5f)).r, 0.001f, 0.1f);

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   return float4(time, 0, 0, 1);
}

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT2 {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

VS_OUTPUT2 Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT2 Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/VERTEX_WIDTH, 0.5f/VERTEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 初期状態の座標を設定

float4 Base_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float x = 2.0f*texCoord.x-1.0f;
   float y = (1.0f-2.0f*texCoord.y) * RectSlace;

   texCoord += float2(0.5f/VERTEX_WIDTH, 0.5f/VERTEX_HEIGHT);
   float4 h = tex2D(HeightSampler, texCoord);
#if( MappingType==0 )
   float v = -(1.0f - (h.r + h.g + h.b) * 0.33333333) * Height;
#else
   float v = -h.a * Height;
#endif

   float4 Pos = float4(x, y, v, 1.0f);
   // ボーンに連動させるためワールド座標で管理する
   Pos = mul( Pos, WorldMatrix );

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 計算座標をクリア

float4 Clear_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos;
   if( time < 0.001f){
      // 0フレーム再生でリセット
      Pos = tex2D(SmpVertexBase, texCoord);
   }else{
      Pos = tex2D(SmpCoord, texCoord);
   }

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 速度の計算

float4 Velocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 vel = float4(0,0,0,0);
   if( time > 0.001f){
      float4 Pos1 = tex2D(SmpCoordOld, texCoord);
      float4 Pos2 = tex2D(SmpCoord, texCoord);
      vel = ( Pos2 - Pos1 )/Dt;
   }

   return vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 現座標値を1ステップ前の座標にコピー

float4 PosCopy_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(SmpCoord, texCoord);
   return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 現座標値を物理計算で更新

float4 PosPhysics_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // 基準位置
    float4 Pos0 = tex2D(SmpVertexBase, texCoord);
    // 1ステップ前の位置
    float4 Pos1 = tex2D(SmpCoordOld, texCoord);
    // 速度
    float4 Vel = tex2D(SmpVelocity, texCoord);
    // 軟度値
    texCoord += float2(0.5f/VERTEX_WIDTH, 0.5f/VERTEX_HEIGHT);
    float4 e = tex2D(ElasticSampler, texCoord);
#if( MappingType==0 )
    float v = 1.0f - (e.r + e.g + e.b)*0.33333333;
#else
    float v = e.a;
#endif

    // 加速度計算
    float4 Accel = (Pos0 - Pos1) * v * Elastic - Viscosity * Vel;

    // 新しい座標に更新
    float4 Pos = Pos1 + Dt * (Vel + Dt * Accel);

    // ボーン追従度
    Pos = lerp(Pos0, Pos, pow(v*Soft, 0.03));

    return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_TRANS {
    float4 Pos;    // 頂点座標
    float3 Normal; // 頂点法線
};

// 頂点の座標･法線を取得
VS_TRANS TransPos(float4 Pos)
{
   VS_TRANS Out = (VS_TRANS)0;

   // 頂点座標が格納されているテクスチャの座標
   float x = 0.5f*(Pos.x * XRate + 1.0f);
   float y = 0.5f*(Pos.y * YRate + 1.0f);

   // 隣接する頂点座標が格納されているテクスチャの座標
   float x1 = x - XStep;
   float x2 = x + XStep;
   float y1 = y - YStep;
   float y2 = y + YStep;

   // 頂点ワールド座標を取得
   Out.Pos = float4(tex2Dlod(SmpCoord, float4(x, y, 0, 0)).xyz, 1);

   // 頂点法線の計算
   float4 PosX1 = tex2Dlod(SmpCoord, float4(x1, y, 0, 0));
   float4 PosX2 = tex2Dlod(SmpCoord, float4(x2, y, 0, 0));
   float4 PosY1 = tex2Dlod(SmpCoord, float4(x, y1, 0, 0));
   float4 PosY2 = tex2Dlod(SmpCoord, float4(x, y2, 0, 0));
   float3 vx = (float3)(PosX2 - PosX1);
   float3 vy = (float3)(PosY2 - PosY1);
   Out.Normal = cross(vx, vy);
//   Out.Normal = cross(vy, vx);

   return Out;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // 頂点のワールド座標･法線を取得
    VS_TRANS Tr = TransPos(Pos);

    // 光源の仮位置(平行光源なので)
    float3 LightPos = (float3)Tr.Pos + LightDirection;

    // 地面に投影
    float3 PlanarPos = float3(0, 0.1, 0);
    float3 PlanarNormal = float3(0, 1, 0);
    float a = dot(PlanarNormal, PlanarPos - LightPos);
    float b = dot(PlanarNormal, Tr.Pos.xyz - PlanarPos);
    float c = dot(PlanarNormal, Tr.Pos.xyz - LightPos);
    Pos = float4(Tr.Pos.xyz * a + LightPos * b, c);

    // カメラ視点のビュー射影変換
    return mul( Pos, ViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // 地面影色で塗りつぶし
    return GroundShadowColor;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        #ifdef MIKUMIKUMOVING
        StencilEnable = TRUE;
        StencilRef = 1;
        StencilMask = 0xff;
        StencilFunc = GREATER;
        StencilFail = KEEP;
        StencilZFail = KEEP;
        StencilPass = INCRSAT;
        CullMode = NONE;
        #endif
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 頂点のワールド座標･法線を取得
    VS_TRANS Tr = TransPos(Pos);

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Tr.Pos, WorldMatrix ).xyz;
    // 頂点法線
    Out.Normal = normalize( mul( Tr.Normal, (float3x3)WorldMatrix ) );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Tr.Pos, GET_VPMAT(Tr.Pos) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;
    // テクスチャ適用
    float2 texCoord = float2(IN.Tex.x, 1.0f-IN.Tex.y);
    Color *= tex2D( TexSampler, texCoord );

    // スペキュラ適用
    Color.rgb += Specular;

    return Color;
}

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=VertexBaseTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosBase;"
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosClear;"
        "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcVelocity;"
        "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosUpdate;"
        #ifdef MIKUMIKUMOVING
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
        #endif
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
>{
    pass PosBase < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Base_PS();
     }
    pass PosClear < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Clear_PS();
    }
    pass CalcVelocity < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Velocity_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosPhysics_PS();
    }
    #ifdef MIKUMIKUMOVING
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
    #endif
    pass DrawObject {
        ZEnable = TRUE;
        CullMode = NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}

#ifndef MIKUMIKUMOVING
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

    // 頂点のワールド座標･法線を取得
    VS_TRANS Tr = TransPos(Pos);
    // ライトの目線によるビュー射影変換をする
    Out.Pos = mul( Tr.Pos, LightViewProjMatrix );

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
    float2 SpTex    : TEXCOORD4;    // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // 頂点のワールド座標･法線を取得
    VS_TRANS Tr = TransPos(Pos);

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Tr.Pos, ViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Tr.Pos, WorldMatrix ).xyz;
    // 頂点法線
    Out.Normal = normalize( mul( Tr.Normal, (float3x3)WorldMatrix ) );
    // ライト視点によるビュー射影変換
    Out.ZCalcTex = mul( Tr.Pos, LightViewProjMatrix );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN) : COLOR
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    // テクスチャ適用
    float2 texCoord = float2(IN.Tex.x, 1.0f-IN.Tex.y);
    float4 TexColor = tex2D( TexSampler, texCoord );
    Color *= TexColor;
    ShadowColor *= TexColor;
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
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}

// オブジェクト描画用テクニック
technique MainTecBS0  < string MMDPass = "object_ss";
    string Script = 
        "RenderColorTarget0=VertexBaseTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosBase;"
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosClear;"
        "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcVelocity;"
        "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
>{
    pass PosBase < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Base_PS();
     }
    pass PosClear < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Clear_PS();
    }
    pass CalcVelocity < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 Velocity_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosPhysics_PS();
    }
    pass DrawObject {
        CullMode = NONE;
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
#endif

