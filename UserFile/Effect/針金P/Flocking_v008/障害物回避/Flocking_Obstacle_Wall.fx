////////////////////////////////////////////////////////////////////////////////////////////////
//
// Flocking_Obstacle_Wall.fx  フロッキングアルゴリズム(障害物回避：遮蔽壁として使用,Pmd版)
//  作成: 針金P( 舞力介入P氏のbasic.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float AvoidanceFactor = 15.0;       // 回避度(大きくすると障害物から衝突回避しやすくなる)


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

// PMDパラメータ
float4x4 PmdWorldMatrix : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;
float XScale10  : CONTROLOBJECT < string name = "(self)"; string item = "X*10"; >;
float XScale100 : CONTROLOBJECT < string name = "(self)"; string item = "X*100"; >;
float YScale10  : CONTROLOBJECT < string name = "(self)"; string item = "Y*10"; >;
float YScale100 : CONTROLOBJECT < string name = "(self)"; string item = "Y*100"; >;
float ZScale10  : CONTROLOBJECT < string name = "(self)"; string item = "Z*10"; >;
float ZScale100 : CONTROLOBJECT < string name = "(self)"; string item = "Z*100"; >;
float PmdClear  : CONTROLOBJECT < string name = "(self)"; string item = "透明"; >;
static float Xmax = 5.0f + 45.0f * XScale10 + 495.0f * XScale100;
static float Ymax = 5.0f + 45.0f * YScale10 + 495.0f * YScale100;
static float Zmax = 5.0f + 45.0f * ZScale10 + 495.0f * ZScale100;
static float Xmin = -Xmax;
static float Ymin = -Ymax;
static float Zmin = -Zmax;
static bool ClearFlag = PmdClear>0.5f ? true : false;

#define TEX_WIDTH  1               // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

float time1 : Time;

float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// ユニットの座標が記録されているテクスチャ
shared texture Flocking_CoordTex : RenderColorTarget;
sampler Flocking_SmpCoord = sampler_state
{
   Texture = <Flocking_CoordTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ユニットの向き・速度が記録されているテクスチャ
shared texture Flocking_VelocityTex : RenderColorTarget;
sampler Flocking_SmpVelocity = sampler_state
{
   Texture = <Flocking_VelocityTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ユニットのポテンシャルによる操舵力を記録するテクスチャ
shared texture Flocking_PotentialTex : RenderColorTarget;
sampler Flocking_SmpPotential = sampler_state
{
   Texture = <Flocking_PotentialTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 共通の深度ステンシルバッファ
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
// ワールド変換行列の逆行列
// 行列が等倍，回転，平行移動しか含まないことを前提条件とする．
float4x4 inverseWorldMatrix(float4x4 mat)
{
    float3x3 mat3x3_inv = transpose((float3x3)mat);
    return float4x4( mat3x3_inv[0], 0, 
                     mat3x3_inv[1], 0, 
                     mat3x3_inv[2], 0, 
                     -mul(mat._41_42_43,mat3x3_inv), 1 );
}
static float4x4 WorldInvMatrix = inverseWorldMatrix( PmdWorldMatrix );

////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの回転逆行列
float3x3 InvRotMatrix(float3 Angle)
{
   float3 AngleY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosy = -Angle.z;
   float siny = sign(Angle.x) * sqrt(1.0f - cosy*cosy);
   float3 AngleXY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosx = dot( Angle, AngleXY );
   float sinx = sign(Angle.y) * sqrt(1.0f - cosx*cosx);

   float3x3 rMat = { cosy, -sinx*siny, -cosx*siny,
                     0.0f,  cosx,      -sinx,     
                     siny,  sinx*cosy,  cosx*cosy };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ

struct VS_OUTPUT2 {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

VS_OUTPUT2 Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ(障害物回避の操舵力を求める)

float4 Potential_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // ポテンシャルによるユニットの操舵力
    float4 SteerForce = tex2D(Flocking_SmpPotential, texCoord);

    // ユニットの位置
    float3 Pos0 = (float3)tex2D(Flocking_SmpCoord, texCoord);

    // ユニットの方向・速度
    float4 v = tex2D(Flocking_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 障害物の方向ベクトル
    float sgn = 1.0f;
    float3 Pos1 = (float3)mul( float4(Pos0, 1.0f), WorldInvMatrix );
    float3 ObstaclePos = float3( clamp( Pos1.x, Xmin, Xmax ),
                                 clamp( Pos1.y, Ymin, Ymax ),
                                 clamp( Pos1.z, Zmin, Zmax ) );
    if( ObstaclePos.x==Pos1.x && ObstaclePos.y==Pos1.y && ObstaclePos.z==Pos1.z ){ // 障害物の内部にはいってしまった場合の処理
            if( Pos1.y*Xmax<-Pos1.x*Ymax && Pos1.y*Xmax>Pos1.x*Ymax && Pos1.z*Xmax<-Pos1.x*Zmax && Pos1.z*Xmax>Pos1.x*Zmax ) ObstaclePos.x = Xmin;
       else if( Pos1.y*Xmax>-Pos1.x*Ymax && Pos1.y*Xmax<Pos1.x*Ymax && Pos1.z*Xmax>-Pos1.x*Zmax && Pos1.z*Xmax<Pos1.x*Zmax ) ObstaclePos.x = Xmax;
       else if( Pos1.z*Ymax<-Pos1.y*Zmax && Pos1.z*Ymax>Pos1.y*Zmax && Pos1.x*Ymax<-Pos1.y*Xmax && Pos1.x*Ymax>Pos1.y*Xmax ) ObstaclePos.y = Ymin;
       else if( Pos1.z*Ymax>-Pos1.y*Zmax && Pos1.z*Ymax<Pos1.y*Zmax && Pos1.x*Ymax>-Pos1.y*Xmax && Pos1.x*Ymax<Pos1.y*Xmax ) ObstaclePos.y = Ymax;
       else if( Pos1.x*Zmax<-Pos1.z*Xmax && Pos1.x*Zmax>Pos1.z*Xmax && Pos1.y*Zmax<-Pos1.z*Ymax && Pos1.y*Zmax>Pos1.z*Ymax ) ObstaclePos.z = Zmin;
       else if( Pos1.x*Zmax>-Pos1.z*Xmax && Pos1.x*Zmax<Pos1.z*Xmax && Pos1.y*Zmax>-Pos1.z*Ymax && Pos1.y*Zmax<Pos1.z*Ymax ) ObstaclePos.z = Zmax;
       sgn = -1.0f;
    }
    ObstaclePos = (float3)mul( float4(ObstaclePos, 1.0f), PmdWorldMatrix );
    float3 ObstacleAngle = sgn * normalize( ObstaclePos - Pos0 );

    // 障害物表面までの距離
    float ObstacleLength = length( Pos0 - ObstaclePos );

    // 障害物に衝突の可能性がある場合は操舵力を付加
    if( ObstacleLength < AvoidanceFactor && dot( Angle, ObstacleAngle ) > -abs(cos(time1)) ){
       // 障害物のポテンシャル
       float len1 = clamp( ObstacleLength, 0.001f, AvoidanceFactor );
       float len2 = max( AvoidanceFactor-ObstacleLength, 0.0f );
       float p = sgn>0.0f ? max( 1.0f/len1, 0.0f ) + len2*len2 : ObstacleLength*ObstacleLength*50.0f;
       float3 pa = mul( -ObstacleAngle, InvRotMatrix(Angle) );
       if(sgn>0.0f) pa.z = 0.0f;
       SteerForce.xyz += normalize(pa)*p;
    }

    return SteerForce;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifdef MIKUMIKUMOVING
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define SKINNING_OUTPUT  MMM_SKINNING_OUTPUT
    #define GETPOSNORMAL  MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
#else
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float3 Normal : NORMAL;
        float2 Tex    : TEXCOORD0;
    };
    struct SKINNING_OUTPUT{
        float4 Position;
        float3 Normal;
    };
    #define GETPOSNORMAL  {IN.Pos, IN.Normal}
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Normal     : TEXCOORD1;   // 法線
    float3 Eye        : TEXCOORD2;   // カメラとの相対位置
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(VS_INPUT IN)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    SKINNING_OUTPUT SkinOut = GETPOSNORMAL;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( SkinOut.Position, WorldViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( SkinOut.Position, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = saturate( max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb + AmbientColor );
    Out.Color.a = DiffuseColor.a;

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;

    // トゥーン適用
    float LightNormal = dot( IN.Normal, -LightDirection );
    // if(LightNormal<0){Color.rgb*=MaterialToon;} としてもよいが、境界のドットが見えてしまうのでぼかす
    Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));

    // スペキュラ適用
    Color.rgb += Specular;

    // 非表示設定
    if( ClearFlag ) Color.a = 0.0f;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

//セルフシャドウなし
technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
        ;
>{
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

//セルフシャドウあり
technique MainTec1 < string MMDPass = "object_ss";
    string Script = 
        "RenderColorTarget0=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
        ;
>{
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }
