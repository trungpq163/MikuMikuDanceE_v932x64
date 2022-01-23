////////////////////////////////////////////////////////////////////////////////////////////////
//
//  TexFire.fx ver0.0.2 ビルボード＋テクスチャアニメの炎エフェクト(Candle Ver)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define FireSourceTexFile  "FireSource.png" // 炎の種となるテクスチャファイル名
#define FireColorTexFile   "palette1.png"   // 炎色palletテクスチャファイル名

//メラメラ感を決めるパラメータ,ここを弄れば見た目が結構代わる。
float fireDisFactor = 0.05; 
float fireSizeFactor = 0.5;
float fireShakeFactor = 0.01;

float fireRiseFactor = 6.0;     // 炎の上昇度
float fireRadiateFactor = 1.0;  // 炎の拡がり度
float fireWvAmpFactor = 1.0;    // 炎の左右の揺らぎ振幅
float fireWvFreqFactor = 0.33;  // 炎の左右の揺らぎ周波数
float firePowAmpFactor = 0.12;  // 炎の明るさ揺らぎ振幅
float firePowFreqFactor = 10;   // 炎の明るさ揺らぎ周波数
float fireTexMoveLimit = 0.05;  // オブジェクト移動に伴う炎の揺らぎ限界値(移動が大きく炎がボードからはみ出る場合はここを小さくする)

int FrameCount = 1; // 1フレームの炎テクスチャ更新数(60fpsで1, 30fpsで2ぐらいが多分ベスト)

float fireInitScaling = 0.25;  // 炎の初期スケール
float fireAveScaling = 1.0;    // モデル平均スケール(モデル側で複数のスケール設定した場合の平均値)

float ElasticFactor = 1000.0; // ボーン追従の弾性度(ここを1000以上にすると完全追従になる)
float ResistFactor = 2.0;     // ボーン追従の抵抗度

#define ADD_FLG  1   // 0:半透明合成, 1:加算合成
#define TEX_WORK_SIZE  512 // 炎アニメーションの作業レイヤサイズ


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float4x4 WorldMatrix         : WORLD;
float4x4 ViewMatrix          : VIEW;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;
static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

// カメラZ軸回転行列
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float4 WPos = float4(WorldMatrix._41_42_43, 1);
static float4 pos0 = mul( WPos, ViewProjMatrix);
static float4 posY = mul( float4(WPos.x, WPos.y+1, WPos.z, 1), ViewProjMatrix);
static float2 rotVec0 = posY.xy/posY.w - pos0.xy/pos0.w;
static float2 rotVec = normalize( float2(rotVec0.x*ViewportSize.x/ViewportSize.y, rotVec0.y) );
static float3x3 RotMatrix = float3x3( rotVec.y, -rotVec.x, 0,
                                      rotVec.x,  rotVec.y, 0,
                                             0,         0, 1 );
static float3x3 RotMatrixInv = transpose( RotMatrix );
static float3x3 BillboardZRotMatrix = mul( RotMatrix, BillboardMatrix);

// 上下カメラアングルによる縮尺(適当)
float3 CameraDirection : DIRECTION < string Object = "Camera"; >;
static float absCosD = abs( dot(float3(0,1,0), -CameraDirection) );
static float yScale = 1.0f - 0.7f*smoothstep(0.7f, 1.0f, absCosD);

float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
float  SpecularPower   : SPECULARPOWER < string Object = "Geometry"; >; // Shininess   0.1

float time : TIME;
float elapsed_time : ELAPSEDTIME;
static float Dt = clamp(elapsed_time, 0.001f, 0.1f);
static float fireShake = fireShakeFactor * FrameCount / (Dt * 60.0f);

int RepertIndex;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float Scaling = AcsSi * 0.1f;

// 作業レイヤサイズ
#define TEX_WORK_WIDTH  TEX_WORK_SIZE
#define TEX_WORK_HEIGHT TEX_WORK_SIZE

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

// 1フレーム前の作業レイヤ
texture2D OldWorkLayer : RENDERCOLORTARGET <
    int Width = TEX_WORK_WIDTH;
    int Height = TEX_WORK_HEIGHT;
    int Miplevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D OldWorkLayerSamp = sampler_state {
    texture = <OldWorkLayer>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// オブジェクトの座標記録用
texture WorldCoordTex : RENDERCOLORTARGET
<
   int Width=2;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp = sampler_state
{
   Texture = <WorldCoordTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture WorldCoordDepthBuffer : RenderDepthStencilTarget <
   int Width=2;
   int Height=1;
    string Format = "D24S8";
>;
float4 WorldCoordTexArray[2] : TEXTUREVALUE <
   string TextureName = "WorldCoordTex";
>;


///////////////////////////////////////////////////////////////////////////////////////
// 炎アニメーションの描画

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_FireAnimation( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out;

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.5f/TEX_WORK_WIDTH, 0.5f/TEX_WORK_HEIGHT);

    return Out;
}

// ピクセルシェーダ(作業レイヤのコピー)
float4 PS_CopyWorkLayer(float2 Tex: TEXCOORD0) : COLOR0
{
    return tex2D(WorkLayerSamp, Tex);
}


// ピクセルシェーダ
float4 PS_FireAnimation(float2 Tex: TEXCOORD0, uniform bool flag) : COLOR0
{
    float2 oldTex = Tex;

    // オブジェクト移動に伴うずらし
    float3 wPosNew = WorldCoordTexArray[1].xyz;
    float3 wPosOld = WorldCoordTexArray[0].xyz;
    wPosNew = mul( wPosNew, (float3x3)ViewMatrix );
    wPosOld = mul( wPosOld, (float3x3)ViewMatrix );
    wPosNew = mul( wPosNew, RotMatrixInv );
    wPosOld = mul( wPosOld, RotMatrixInv );
    float2 moveVec = (wPosNew.xy - wPosOld.xy) / (20.0f * fireInitScaling * fireAveScaling * FrameCount * Scaling * Scaling);
    moveVec.y = -moveVec.y;
    if(moveVec.y < 0) moveVec.y *= 0.5f;
    moveVec = clamp(moveVec, -fireTexMoveLimit, fireTexMoveLimit);
    oldTex += moveVec;

    // 放射状に炎をずらす
    moveVec = float2(0.5f, 0.75f) - Tex;
    float radLen = length(moveVec) * 10000.0f;
    moveVec = normalize(moveVec) * fireRadiateFactor / max(radLen, 750.0f);
    oldTex += moveVec;

    // 上に炎をずらす ※参照位置を下にずらすと絵は上にずれる
    moveVec = float2( 0.5f/TEX_WORK_WIDTH * fireWvAmpFactor * (abs(frac(fireWvFreqFactor*time)*2.0f - 1.0f) - 0.5f),
                      0.5f/TEX_WORK_HEIGHT * fireRiseFactor * yScale );
    oldTex += moveVec;

    float4 oldCol = tex2D(OldWorkLayerSamp, oldTex);

    float4 tmp = oldCol;
    if( flag ){
        // 作業レイヤに燃焼物を描画 ※前回の炎をずらした後に描画する事で燃焼物自体は、同じ位置に描画できる。
        tmp = max(oldCol, tex2D(ParticleSamp, Tex));
        tmp *= smoothstep(0.0f, 0.7f, WorldCoordTexArray[1].w);
    }

    // ノイズの追加
    float2 noiseTex;
    noiseTex = Tex;
    noiseTex.y += time * fireShake;
    tmp = saturate(tmp - fireDisFactor * tex2D(NoiseOneSamp, noiseTex * fireSizeFactor));

    noiseTex = Tex;
    noiseTex.x += time * fireShake;
    tmp = saturate(tmp - fireDisFactor * 0.5f * tex2D(NoiseTwoSamp, noiseTex * fireSizeFactor));

    return float4(tmp.rgb, 1.0f);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトの座標計算

// 共通の頂点シェーダ
VS_OUTPUT WorldCoord_VS(float4 Pos : POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.25f, 0.5f);

    return Out;
}

// 0フレーム再生でリセット
float4 InitWorldCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float4 Pos = tex2D(WorldCoordSmp, Tex);
   if( time < 0.001f ){
      Pos = float4(WorldMatrix._41_42_43, 0.0f);
   }
   return Pos;
}

// 座標更新
float4 WorldCoord1_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトの座標
   float4 Pos0 = WorldCoordTexArray[0];
   float4 Pos1 = WorldCoordTexArray[1];

   // オブジェクトの速度
   float3 Vel = ( Pos1.xyz  - Pos0.xyz ) / Dt;

   // ワールド座標
   float3 WPos = WorldMatrix._41_42_43;

   // 加速度計算(弾性力+速度抵抗力)
   float3 Accel = (WPos - Pos1.xyz) * ElasticFactor - Vel * ResistFactor;

   // 新しい座標に更新
   float3 Pos2 = Pos1.xyz + Dt * (Vel + Dt * Accel);

   // 経過時間
   float timer = max(Pos1.w, 0.0f) + Dt;

   // 座標記録
   float4 Pos;
   if( ElasticFactor < 999.9f ){
       Pos = Tex.x<0.5f ? Pos1 : float4(Pos2, timer);
   }else{
       Pos = Tex.x<0.5f ? Pos1 : float4(WorldMatrix._41_42_43, timer);
   }

   return Pos;
}

// 座標更新
float4 WorldCoord2_PS(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Pos = float4(WorldMatrix._41_42_43, 0.0f);
   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
VS_OUTPUT VS_Object( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out;

    // オブジェクト位置・スケール
    float3 Pos0 = MaterialDiffuse.rgb * 0.1f;
    float scale = SpecularPower;

    // オブジェクト座標
    Pos.x = 2.0f * (Tex.x - 0.5f);
    Pos.y = 2.0f * (0.5f - Tex.y) + 0.5f;
    Pos.z = 0.0f;

    // オブジェクトスケール
    Pos.xy *= fireInitScaling * scale;

    // ビルボード+z軸回転
    Pos.xyz = mul( Pos.xyz, BillboardZRotMatrix );

    // ワールド座標変換
    Pos.xyz += Pos0;
    Pos.xyz = mul( Pos, (float3x3)WorldMatrix );
    Pos.xyz += WorldCoordTexArray[1].xyz;

    // ビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // テクスチャ座標
    Out.Tex = Tex + float2(0.5f/TEX_WORK_WIDTH, 0.5f/TEX_WORK_HEIGHT);

    return Out;
}

// ピクセルシェーダ
float4  PS_Object(float2 Tex: TEXCOORD0) : COLOR0
{
    // 炎の色
    float tmp = tex2D(WorkLayerSamp, Tex).r;
    float4 FireCol = tex2D(FireColorSamp, saturate(float2(tmp, 0.5f)));

    // 炎の明るさの揺らぎ
    float s = 1.0f + firePowAmpFactor * (0.66f * sin(2.2f * time * firePowFreqFactor)
                                       + 0.33f * cos(3.3f * time * firePowFreqFactor) );
    // 透過設定
    #if ADD_FLG == 1
        FireCol.rgb *= 0.8f * s * AcsTr;
    #else
        FireCol.a *= tmp * 0.8f * s * AcsTr;
    #endif

    return FireCol;
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec0 < string MMDPass = "object"; string Subset = "0";
    string Script = 
        "RenderColorTarget0=OldWorkLayer;"
            "RenderDepthStencilTarget=WorkLayerDepthBuffer;"
            "Pass=CopyWorkLayer;"
        "RenderColorTarget0=WorkLayer;"
            "RenderDepthStencilTarget=WorkLayerDepthBuffer;"
            "LoopByCount=FrameCount;"
                "LoopGetIndex=RepertIndex;"
                "Pass=FireAnimation;"
            "LoopEnd=;"
        "RenderColorTarget0=WorldCoordTex;"
	    "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
	    "Pass=PosInit;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
    ;
> {
    pass CopyWorkLayer < string Script= "Draw=Buffer;"; > {
        ZWriteEnable = FALSE;
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_2_0 VS_FireAnimation();
        PixelShader  = compile ps_2_0 PS_CopyWorkLayer();
    }
    pass FireAnimation < string Script= "Draw=Buffer;"; > {
        ZWriteEnable = FALSE;
        VertexShader = compile vs_2_0 VS_FireAnimation();
        PixelShader  = compile ps_2_0 PS_FireAnimation(true);
    }
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 WorldCoord_VS();
        PixelShader  = compile ps_2_0 InitWorldCoord_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 WorldCoord_VS();
        PixelShader  = compile ps_2_0 WorldCoord1_PS();
    }
    pass DrawObject {
        ZEnable = TRUE;
        ZWriteEnable = FALSE;
        ALPHABLENDENABLE = TRUE;
        CullMode = NONE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTec1 < string MMDPass = "object"; >
{
    pass DrawObject {
        ZEnable = TRUE;
        ZWriteEnable = FALSE;
        ALPHABLENDENABLE = TRUE;
        CullMode = NONE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTecSS0 < string MMDPass = "object_ss"; string Subset = "0";
    string Script = 
        "RenderColorTarget0=WorkLayer;"
            "RenderDepthStencilTarget=WorkLayerDepthBuffer;"
            "LoopByCount=FrameCount;"
                "LoopGetIndex=RepertIndex;"
                "Pass=FireAnimation;"
            "LoopEnd=;"
        "RenderColorTarget0=WorldCoordTex;"
	    "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
	    "Pass=PosInit;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
    ;
> {
    pass FireAnimation < string Script= "Draw=Buffer;"; > {
        ZWriteEnable = FALSE;
        VertexShader = compile vs_2_0 VS_FireAnimation();
        PixelShader  = compile ps_2_0 PS_FireAnimation(false);
    }
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 WorldCoord_VS();
        PixelShader  = compile ps_2_0 InitWorldCoord_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE=FALSE;
        VertexShader = compile vs_1_1 WorldCoord_VS();
        PixelShader  = compile ps_2_0 WorldCoord2_PS();
    }
    pass DrawObject {
        ZEnable = TRUE;
        ZWriteEnable = FALSE;
        ALPHABLENDENABLE = TRUE;
        CullMode = NONE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTecSS1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        ZEnable = TRUE;
        ZWriteEnable = FALSE;
        ALPHABLENDENABLE = TRUE;
        CullMode = NONE;
        #if ADD_FLG == 1
          DestBlend = ONE;
          SrcBlend = ONE;
        #else
          DestBlend = INVSRCALPHA;
          SrcBlend = SRCALPHA;
        #endif
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

// エッジは描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }

