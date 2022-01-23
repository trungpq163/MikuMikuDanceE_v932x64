////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FootmarkSnow.fx ver0.0.2 モデルの動きに合わせて積雪の上に足跡をつけます
//  (FootmarkSnow.xを足首ボーンに付けて使用します)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float FootSize = 1.0;                 // 足跡のサイズ
float3 FootOffset = {0.0, 0.0, 0.0};  // 足跡位置の座標調整値
float FootStartDecrement = 300.0;     // 足跡消失を開始する時間(秒)
float FootEndDecrement = 360.0;       // 足跡消失を完了する時間(秒)

//ここの調整が重要!!
float FootHeight = 1.85;    // 足跡検出判定高(足首ボーンのY座標がこれ以下の時に検出,よって少しだけ高い値を設定)
float FootDistance = 0.3;   // 足跡検出判定距離(一つ前の足跡との距離がこれ以上なら新規追加)
float FootRotation = 20.0;  // 足跡検出判定回転角(一つ前の足跡との回転角がこれ以上なら新規追加,deg)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define TEX_WIDTH    1   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 521   // 座標情報テクスチャピクセル高さ

float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

// 床判定の位置と向き
bool flagFloorCtrl : CONTROLOBJECT < string name = "FloorControl.x"; >;
float4x4 FloorCtrlWldMat : CONTROLOBJECT < string name = "FloorControl.x"; >;
static float3 FloorPos = flagFloorCtrl ? FloorCtrlWldMat._41_42_43  : float3(0, 0, 0);
static float3 FloorNormal = flagFloorCtrl ? normalize(FloorCtrlWldMat._21_22_23) : float3(0, 1, 0);

// スケーリングなしの床ワールド変換行列
static float4x4 FloorWldMat = flagFloorCtrl ? float4x4( normalize(FloorCtrlWldMat._11_12_13), 0,
                                                        normalize(FloorCtrlWldMat._21_22_23), 0,
                                                        normalize(FloorCtrlWldMat._31_32_33), 0,
                                                        FloorCtrlWldMat[3] )
                                            : float4x4( 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 );

// ワールド変換行列で、スケーリングなしの逆行列を計算する。
float4x4 InverseWorldMatrix(float4x4 mat) {
    float3x3 mat3x3_inv = transpose((float3x3)mat);
    float3x3 mat3x3_inv2 = float3x3( normalize(mat3x3_inv[0]),
                                     normalize(mat3x3_inv[1]),
                                     normalize(mat3x3_inv[2]) );
    return float4x4( mat3x3_inv2[0], 0, 
                     mat3x3_inv2[1], 0, 
                     mat3x3_inv2[2], 0, 
                     -mul(mat._41_42_43, mat3x3_inv2), 1 );
}
// スケーリングなしの床ワールド逆変換行列
static float4x4 InvFloorWldMat = flagFloorCtrl ? InverseWorldMatrix( FloorCtrlWldMat )
                                               : float4x4( 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 );

int Count = TEX_HEIGHT;
int Index;

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

float3 LightDirection    : DIRECTION < string Object = "Light"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;

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
static float4 DiffuseColor = MaterialDiffuse * float4(LightDiffuses[0]*1.3, 1.0f);
static float3 AmbientColor = MaterialAmbient * LightAmbients[0] + MaterialEmmisive*1.8f;
static float3 SpecularColor = MaterialSpecular * LightSpeculars[0];
#endif

bool use_texture;   // テクスチャの有無

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};

// 足跡座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s3) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = WRAP;
    AddressV = WRAP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// オブジェクトのワールド座標記録用
texture WorldCoord : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp = sampler_state
{
   Texture = <WorldCoord>;
   AddressU = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture WorldCoordDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D24S8";
>;

texture WorldCoord2 : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp2 = sampler_state
{
   Texture = <WorldCoord2>;
   AddressU = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
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
// 座標の2D回転
float3 Rotation2D(float3 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.z * sin(rot);
    float z = pos.x * sin(rot) + pos.z * cos(rot);

    return float3(x, pos.y, z);
}


////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}


// 0フレーム再生で座標を初期化
float4 InitPos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Pos;
   if( time < 0.001f ){
      // 0フレーム再生でリセット
      Pos = mul( WorldMatrix[3], InvFloorWldMat );
      Pos = float4(Pos.x, atan2(WorldMatrix._13, WorldMatrix._33), Pos.z, 0.0f);
   }else{
      Pos = tex2D(CoordSmp, Tex);
   }

   return Pos;
}


// 足跡の発生・座標計算(xz:座標,y:回転角,w:経過時間+1sec)
float4 UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // 足跡の座標
   float4 Pos = tex2D(CoordSmp, Tex);

   if(Pos.w > 1.001f){
      // すでに発生している足跡は経過時間を進める
      Pos.w += Dt;
      Pos.w *= step(Pos.w-1.0f, FootEndDecrement); // 指定時間を超えると0
   }

   // 足首ボーンのワールド座標
   float3 WPos0 = tex2D(WorldCoordSmp2, float2(0.5f, 0.5f)).xyz;
   float4 WPos1 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
   float3 WPos2 = mul( WorldMatrix[3], InvFloorWldMat ).xyz;

   // 足跡index
   int index = floor( Tex.y*TEX_HEIGHT );
   // ボーン高さが基準高以下で降下→上昇すると新たに足跡を発生させる(前跡とダブる場合は除外)
   if(round(WPos1.w) == index){
      if(WPos1.y < FootHeight){
         if((WPos1.y-WPos0.y) < 0.0f && (WPos2.y-WPos1.y) > 0.0f){
            float2 texCoord = float2(0.5f/TEX_WIDTH, (index-0.5f)/TEX_HEIGHT);
            float4 Pos0 = tex2D(CoordSmp, texCoord);
            float len = distance(Pos0.xz, WPos1.xz);
            float rot = atan2(WorldMatrix._13, WorldMatrix._33) - atan2(FloorWldMat._13, FloorWldMat._33);
            if(len > FootDistance || abs(Pos0.y-rot) > radians(FootRotation)){
               Pos.x = WPos1.x;
               Pos.y = rot;
               Pos.z = WPos1.z;
               Pos.w = 1.0011f;  // Pos.w>1.001で足跡発生
            }
         }
      }
   }

   return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトのワールド座標記録(xyz:座標,w:次発生足跡index)

// 共通の頂点シェーダ
float4 WorldCoord_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

// 0フレーム再生でワールド座標を初期化
float4 InitWorldCoord_PS() : COLOR
{
   float4 Pos;
   if( time < 0.001f ){
      // 0フレーム再生でリセット
      Pos = mul( WorldMatrix[3], InvFloorWldMat );
      Pos.w = 0.0f;
   }else{
      Pos = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
   }

   return Pos;
}

// ワールド座標をバックアップ
float4 WorldCoord_PS() : COLOR
{
   // オブジェクトのワールド座標
   float4 Pos = mul( WorldMatrix[3], InvFloorWldMat );
   Pos.w = tex2D(WorldCoordSmp2, float2(0.5f, 0.5f)).w;

   return Pos;
}

// 0フレーム再生でワールド座標を初期化
float4 InitWorldCoord2_PS() : COLOR
{
   float4 Pos;
   if( time < 0.001f ){
      // 0フレーム再生でリセット
      Pos = mul( WorldMatrix[3], InvFloorWldMat );
      Pos.w = 0.0f;
   }else{
      Pos = tex2D(WorldCoordSmp2, float2(0.5f, 0.5f));
   }

   return Pos;
}

// バックアップワールド座標のコピー&足跡index
float4 WorldCoord2_PS() : COLOR
{
   float4 WPos0 = tex2D(WorldCoordSmp2, float2(0.5f, 0.5f));
   float4 WPos1 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
   float3 WPos2 = mul( WorldMatrix[3], InvFloorWldMat ).xyz;

   // 足跡index
   int index = round( WPos0.w );

   // 次発生足跡のindex
   if(WPos1.y < FootHeight){
      if((WPos1.y-WPos0.y) < 0.0f && (WPos2.y-WPos1.y) > 0.0f){
         float2 texCoord = float2(0.5f/TEX_WIDTH, (index-0.5f)/TEX_HEIGHT);
         float4 Pos0 = tex2D(CoordSmp, texCoord);
         float len = distance(Pos0.xz, WPos1.xz);
         float rot = atan2(WorldMatrix._13, WorldMatrix._33) - atan2(FloorWldMat._13, FloorWldMat._33);
         if(len > FootDistance || abs(Pos0.y-rot) > radians(FootRotation)){
            WPos1.w += 1.0f;  // 新規足跡発生でインクリメント
            WPos1.w *= step(WPos1.w, TEX_HEIGHT-1.0f);
         }
      }
   }

   return WPos1;
}


///////////////////////////////////////////////////////////////////////////////////////
// 足跡描画

struct VS_OUTPUT2 {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT2 Foot_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

   float2 texCoord = float2(0.5f/TEX_WIDTH, (Index+0.5f)/TEX_HEIGHT);

   // 足跡の起点座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 1));

   // 経過時間
   float etime = Pos0.w - 1.0f;
   // 足跡の大きさ
   Pos.xyz *= FootSize * AcsSi;

   // 足跡の回転
   Pos.xyz += FootOffset;
   Pos.xyz = Rotation2D(Pos.xyz, Pos0.y);

   // 足跡のワールド座標
   Pos.x += Pos0.x;
   Pos.y += 0.05f;
   Pos.z += Pos0.z;
   Pos.w = 1.0f;
   Pos = mul( Pos, FloorWldMat);
   Pos.xyz *= step(0.001f, etime);

   // カメラとの相対位置
   Out.Eye = CameraPosition - Pos.xyz;

   // 頂点法線
   Out.Normal = normalize( mul( Rotation2D(Normal, Pos0.y), (float3x3)FloorWldMat) );

#ifndef MIKUMIKUMOVING
   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );
#else
   // 頂点座標
   if (MMM_IsDinamicProjection)
   {
       float4x4 vpmat = mul( ViewMatrix, MMM_DynamicFov(ProjMatrix, length( Out.Eye )) );
       Out.Pos = mul( Pos, vpmat );
   }
   else
   {
       Out.Pos = mul( Pos, ViewProjMatrix );
   }
#endif

   // 経過時間に対する足跡透過度
   float alpha = smoothstep(-FootEndDecrement, -FootStartDecrement, -etime);

   // ディフューズ色＋アンビエント色 計算
   Out.Color.rgb = AmbientColor + max(0, DiffuseColor.rgb * dot( Out.Normal, -LightDirection ));
   Out.Color.a = DiffuseColor.a * alpha * step(0.001f, etime);
   Out.Color = saturate( Out.Color );

   // テクスチャ座標
   Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 Foot_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;
    if ( use_texture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }

    // スペキュラ適用
    Color.rgb += Specular;

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "0";
   string Script = 
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=InitPos;"
       "RenderColorTarget0=WorldCoord;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=InitWorldCoord;"
       "RenderColorTarget0=WorldCoord2;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=InitWorldCoord2;"
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=WorldCoord2;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord2;"
       "RenderColorTarget0=WorldCoord;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord;"
       #ifdef MIKUMIKUMOVING
       "RenderColorTarget0=TimeTex;"
           "RenderDepthStencilTarget=TimeDepthBuffer;"
           "Pass=UpdateTime;"
       #endif
       "RenderColorTarget0=;"
	   "RenderDepthStencilTarget=;"
           "LoopByCount=Count;"
           "LoopGetIndex=Index;"
               "Pass=DrawObject;"
           "LoopEnd=;";
>{
   pass InitPos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 Common_VS();
       PixelShader  = compile ps_2_0 InitPos_PS();
   }
   pass InitWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 InitWorldCoord_PS();
   }
   pass InitWorldCoord2 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 InitWorldCoord2_PS();
   }
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 Common_VS();
       PixelShader  = compile ps_2_0 UpdatePos_PS();
   }
   pass UpdateWorldCoord2 < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord2_PS();
   }
   pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS();
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
       VertexShader = compile vs_3_0 Foot_VS();
       PixelShader  = compile ps_3_0 Foot_PS();
   }
}

technique MainTec2 < string MMDPass = "object"; string Subset = "1-1000";
   string Script = 
           "LoopByCount=Count;"
           "LoopGetIndex=Index;"
               "Pass=DrawObject;"
           "LoopEnd=;";
>{
   pass DrawObject {
       VertexShader = compile vs_3_0 Foot_VS();
       PixelShader  = compile ps_3_0 Foot_PS();
   }
}

