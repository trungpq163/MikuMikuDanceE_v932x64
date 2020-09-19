////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WorkingRay.fx ver0.0.2 仕事をする光(マスク用途)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float WaveLength = 1.5;  // 光のゆらぎ波長
float WaveFreq = 1.0;    // 光のゆらぎ周波数

// ボーンの鈍化追従パラメータ
bool flagMildFollow <        // 鈍化追従on/off
   string UIName = "鈍化追従on/off";
   bool UIVisible =  true;
> = true;

float ElasticFactor = 50.0;  // ボーン追従の弾性度
float ResistFactor = 20.0;   // ボーン追従の抵抗度
float MaxDistance = 5.0;     // ボーン追従の最大ぶれ幅


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define TexFile1  "ray1.png"
#define TexFile2  "ray2.png"
#define MaskFile  "mask.png"

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsRz  : CONTROLOBJECT < string name = "(self)"; string item = "Rz"; >;

float time : TIME;

// 座標変換行列
float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix             : VIEW;
float4x4 ProjMatrix             : PROJECTION;
float4x4 ViewProjMatrix         : VIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

//カメラ位置
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

bool opadd;   // 加算合成フラグ

// 光テクスチャ1
texture2D RayTex1 <
    string ResourceName = TexFile1;
>;
sampler TexSamp1 = sampler_state {
    texture = <RayTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 光テクスチャ2
texture2D RayTex2 <
    string ResourceName = TexFile2;
>;
sampler TexSamp2 = sampler_state {
    texture = <RayTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// マスクテクスチャ
texture2D MaskTex <
    string ResourceName = MaskFile;
>;
sampler MaskSamp = sampler_state {
    texture = <MaskTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// オブジェクトの座標・速度記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=2;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp = sampler_state
{
   Texture = <CoordTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=2;
   int Height=1;
    string Format = "D24S8";
>;
float4 CoordTexArray[2] : TEXTUREVALUE <
   string TextureName = "CoordTex";
>;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトの座標・速度計算
struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 共通の頂点シェーダ
VS_OUTPUT Coord_VS(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.25f, 0.5f);

    return Out;
}

// 0フレーム再生でリセット
float4 InitCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float4 Pos = tex2D(CoordSmp, Tex);
   if( time < 0.001f ){
      Pos = Tex.x<0.5f ? float4(WorldMatrix._41_42_43, 0.0f) : float4(0.0f, 0.0f, 0.0f, 1.0f);
   }
   return Pos;
}

// 座標・速度更新
float4 Coord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float4 Pos0 = tex2D(CoordSmp, float2(0.25f, 0.5f));

   // オブジェクトの速度
   float3 Vel = tex2D(CoordSmp, float2(0.75f, 0.5f)).xyz;

   // 1フレームの時間間隔
   float Dt = clamp(time - Pos0.w, 0.001f, 0.05f);

   // ワールド座標
   float3 WPos = WorldMatrix._41_42_43;

   // 加速度計算(弾性力+速度抵抗力)
   float3 Accel = (WPos - Pos0.xyz) * ElasticFactor - Vel * ResistFactor;

   // 新しい座標に更新
   float3 Pos1 = Pos0.xyz + Dt * (Vel + Dt * Accel);

   // 速度計算
   Vel = ( Pos1 - Pos0.xyz ) / Dt;

   // オブジェクトがワールド座標から一定距離以上離れないようにする
   if( length( WPos - Pos1 ) > MaxDistance ){
      Pos1 = WPos + normalize( Pos1 - WPos ) * MaxDistance;
   }

   // 座標・速度記録
   float4 Pos = Tex.x<0.5f ? float4(Pos1, time) : float4(Vel, 1.0f);

   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 光線の描画

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // オブジェクト回転
    Pos.xy = Rotation2D(Pos.xy, AcsRz);

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    // ワールド座標変換
    Pos.xyz = mul( Pos.xyz, (float3x3)WorldMatrix );
    if( flagMildFollow ){
       Pos.xyz += CoordTexArray[0].xyz;
    }else{
       Pos.xyz += WorldMatrix._41_42_43;
    }

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    // テクスチャ座標
    float x = Tex.x * 1.5f * ( ( 1.0f - cos( 1.57f*(2.0f*Tex.y-1.0f) ) ) + 0.6f );
    float y = 0.2f * sin( 13.0f*WaveLength*Tex.y + 1.3f*WaveFreq*time + 2.5f )
            + 0.11f * cos( 7.0f*WaveLength*Tex.y - 1.7f*WaveFreq*time + 3.1f );
    float3 normal = normalize( float3( x, y, -1.0f ) );
    float2 texCoord = float2( normal.x,  normal.y * 0.5f + 0.5f);

    // テクスチャの色
    float4 Color = tex2D( TexSamp1, texCoord );
    Color *= tex2D( TexSamp2, Tex );
    if(opadd){
       Color.xyz += 0.5f * tex2D( MaskSamp, Tex ).xyz;
    }else{
       Color.xyz += 0.3f * tex2D( MaskSamp, Tex ).xyz;
    }
    Color.a *= AcsTr;

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=PosInit;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Coord_VS();
        PixelShader  = compile ps_2_0 InitCoord_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Coord_VS();
        PixelShader  = compile ps_2_0 Coord_PS();
    }
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Mask_VS();
        PixelShader  = compile ps_2_0 Mask_PS();
    }
}

