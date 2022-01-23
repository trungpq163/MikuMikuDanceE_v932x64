////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Flocking_Leader1.fx  フロッキングアルゴリズムを使った群れ行動制御(リーダー追従,グループ1)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float FollowFactor = 10.0;       // 追従度(大きくすると近くに集まりやすくなる)
int GroupNum = 0;   // グループ番号(0～)

// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////


#define TEX_WIDTH  1               // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

// 座標変換行列
float4x4 WorldMatrix : WORLD;
static float3 AcsOffset = WorldMatrix._41_42_43;
static float AcsScaling = length(WorldMatrix._11_12_13)*3.0f; 

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
// ピクセルシェーダ(リーダーに追従するの操舵力を求める)

float4 Potential_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // ポテンシャルによるユニットの操舵力
    float4 SteerForce = tex2D(Flocking_SmpPotential, texCoord);

    // ユニットの位置・グループ番号
    float4 P0 = tex2D(Flocking_SmpCoord, texCoord);
    float3 Pos0 = P0.xyz;
    int iGroup = round( P0.w );

    if( iGroup == GroupNum ){
        // ユニットの方向・速度
        float4 v = tex2D(Flocking_SmpVelocity, texCoord);
        float3 Angle = v.xyz;
        float3 Vel = Angle * v.w;

        // リーダーの方向ベクトル
        float3 LeaderAngle = normalize( AcsOffset - Pos0 );

        // リーダーまでの距離
        float LeaderLength = length( Pos0 - AcsOffset );

        // 操舵力を付加
        if( LeaderLength < AcsScaling && dot( Angle, LeaderAngle ) < 0.5f ){
           // リーダーのポテンシャル
           float p = FollowFactor*FollowFactor - 1.0f/(LeaderLength*LeaderLength);
           float3 pa = mul( LeaderAngle, InvRotMatrix(Angle) );
           pa.z = 0.0f;
           SteerForce.xyz += normalize(pa)*p;
        }
    }

    return SteerForce;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float3 LightDirection    : DIRECTION < string Object = "Light"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float  SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
// ライト色
float3 LightDiffuse      : DIFFUSE  < string Object = "Light"; >;
float3 LightAmbient      : AMBIENT  < string Object = "Light"; >;
float3 LightSpecular     : SPECULAR < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

struct VS_OUTPUT {
    float4 Pos    : POSITION;    // 射影変換座標
    float3 Normal : TEXCOORD2;   // 法線
    float3 Eye    : TEXCOORD3;   // カメラとの相対位置
    float4 Color  : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Object_VS(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    return Out;
}

// ピクセルシェーダ
float4 Object_PS(VS_OUTPUT IN) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;

    // スペキュラ適用
    Color.rgb += Specular;

    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

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
        VertexShader = compile vs_3_0 Object_VS();
        PixelShader  = compile ps_3_0 Object_PS();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////

// 輪郭は表示しない
technique EdgeTec < string MMDPass = "edge"; > { }
// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }

 