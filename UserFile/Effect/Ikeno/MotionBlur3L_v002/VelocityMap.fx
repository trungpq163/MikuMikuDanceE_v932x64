////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ベロシティマップ 出力エフェクト
//  製作：そぼろ
//  MME 0.27が必要です
//  改造・流用とも自由です
//
////////////////////////////////////////////////////////////////////////////////////////////////


// 背景まで透過させる閾値を設定します
float TransparentThreshold = 0.5;

// 透過判定にテクスチャの透過度を使用します。1で有効、0で無効
#define TRANS_TEXTURE  1

//シーン切り替え閾値
float SceneChangeThreshold
<
   string UIName = "SceneChangeThreshold";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100;
> = float( 20 );

//シーン切り替え角度閾値
float SceneChangeAngleThreshold
<
   string UIName = "SceneChangeAngleThreshold";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 100;
> = float( 25 );


////////////////////////////////////////////////////////////////////////////////////////////////
//Clone連携機能

//Cloneのパラメータ読み込み指定
#define CLONE_PARAMINCLUDE

//以下のコメントアウトを外し、クローンエフェクトファイル名を指定
//include "Clone.fx"


//ダミー変数・関数宣言
#ifndef CLONE_MIPMAPTEX_SIZE
int CloneIndex = 0; //ループ変数
int CloneCount = 1; //複製数
float4 ClonePos(float4 Pos) { return Pos; }
#endif

////////////////////////////////////////////////////////////////////////////////////////////////


// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 WorldViewMatrix          : WORLDVIEW;
float4x4 ProjectionMatrix         : PROJECTION;
float4x4 ViewProjMatrix           : VIEWPROJECTION;
float4x4 ViewMatrix               : VIEW;


bool use_texture;  //テクスチャの有無

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;


#if TRANS_TEXTURE!=0
    // オブジェクトのテクスチャ
    texture ObjectTexture: MATERIALTEXTURE;
    sampler ObjTexSampler = sampler_state
    {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };
    
    
    // MMD本来のsamplerを上書きしないための記述です。削除不可。
    sampler MMDSamp0 : register(s0);
    sampler MMDSamp1 : register(s1);
    sampler MMDSamp2 : register(s2);
    
#endif



//26万頂点まで対応
//→ 52万に拡張
//#define VPBUF_WIDTH  512
#define VPBUF_WIDTH  1024
#define VPBUF_HEIGHT 512

//頂点座標バッファサイズ
static float2 VPBufSize = float2(VPBUF_WIDTH, VPBUF_HEIGHT);

static float2 VPBufOffset = float2(0.5 / VPBUF_WIDTH, 0.5 / VPBUF_HEIGHT);


//頂点ごとのワールド座標を記録
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=VPBUF_WIDTH;
   int Height=VPBUF_HEIGHT;
    string Format = "D24S8";
>;
texture VertexPosBufTex : RenderColorTarget
<
    int Width=VPBUF_WIDTH;
    int Height=VPBUF_HEIGHT;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;
sampler VertexPosBuf = sampler_state
{
   Texture = (VertexPosBufTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
texture VertexPosBufTex2 : RenderColorTarget
<
    int Width=VPBUF_WIDTH;
    int Height=VPBUF_HEIGHT;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;
sampler VertexPosBuf2 = sampler_state
{
   Texture = (VertexPosBufTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};


//ワールドビュー射影行列などの記録

#define INFOBUFSIZE 16

texture DepthBufferMB : RenderDepthStencilTarget <
   int Width=INFOBUFSIZE;
   int Height=1;
    string Format = "D24S8";
>;
texture MatrixBufTex : RenderColorTarget
<
    int Width=INFOBUFSIZE;
    int Height=1;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;

float4 MatrixBufArray[INFOBUFSIZE] : TEXTUREVALUE <
    string TextureName = "MatrixBufTex";
>;

//前フレームのワールド行列
static float4x4 lastWorldMatrix = float4x4(MatrixBufArray[0], MatrixBufArray[1], MatrixBufArray[2], MatrixBufArray[3]);

//前フレームのビュー射影行列
static float4x4 lastViewMatrix = float4x4(MatrixBufArray[4], MatrixBufArray[5], MatrixBufArray[6], MatrixBufArray[7]);



//フレームの記録をブロックするかどうか
bool MotionBlockerEnable  : CONTROLOBJECT < string name = "LockMotion.x"; >;
bool CameraBlockerEnable  : CONTROLOBJECT < string name = "LockCamera.x"; >;


#ifdef MIKUMIKUMOVING
    static float4x4 lastMatrix = mul(WorldMatrix, lastViewMatrix);
#else
    static float4x4 lastMatrix = mul(lastWorldMatrix, lastViewMatrix);
#endif

//時間
float ftime : TIME<bool SyncInEditMode=true;>;
float stime : TIME<bool SyncInEditMode=false;>;

//出現フレームかどうか
//前回呼び出しから0.5s以上経過していたら非表示だったと判断
static float last_ftime = MatrixBufArray[8].y;
static float last_stime = MatrixBufArray[8].x;
static bool Appear = (abs(last_stime - stime) > 0.5);


////////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応

#ifdef MIKUMIKUMOVING
    
    #define GETPOS MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
    
    int voffset : VERTEXINDEXOFFSET;
    
#else
    
    struct MMM_SKINNING_INPUT{
        float4 Pos : POSITION;
        float2 Tex : TEXCOORD0;
        float4 AddUV1 : TEXCOORD1;
        float4 AddUV2 : TEXCOORD2;
        float4 AddUV3 : TEXCOORD3;
        int Index     : _INDEX;
    };
    
    #define GETPOS (IN.Pos)
    
    const int voffset = 0;
    
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
//汎用関数

//W付きスクリーン座標を単純スクリーン座標に
float2 ScreenPosRasterize(float4 ScreenPos){
    return ScreenPos.xy / ScreenPos.w;
    
}

//頂点座標バッファ取得
float4 getVertexPosBuf(float index)
{
    float4 Color;
    float2 tpos = float2(index % VPBUF_WIDTH, trunc(index / VPBUF_WIDTH));
    tpos += float2(0.5, 0.5);
    tpos /= float2(VPBUF_WIDTH, VPBUF_HEIGHT);
    Color = tex2Dlod(VertexPosBuf2, float4(tpos,0,0));
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // UV
    float4 LastPos    : TEXCOORD1;
    float4 CurrentPos : TEXCOORD2;
    
};

VS_OUTPUT Velocity_VS(MMM_SKINNING_INPUT IN , uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    if(useToon){
        Out.LastPos = ClonePos(getVertexPosBuf((float)(IN.Index + voffset)));
    }
    
    float4 pos = GETPOS;
    pos = ClonePos(pos);
    
    Out.CurrentPos = pos;
    
    Out.Pos = mul( pos, WorldViewProjMatrix );
    
    #if TRANS_TEXTURE!=0
        Out.Tex = IN.Tex; //テクスチャUV
    #endif
    
    return Out;
}


//-----------------------------------------------------------------
// *** カメラの切り替わりでもブラーを止めない ***
// 外部アクセサリで強制的にカメラが変わったことを知らせる。
bool ChangeCamera  : CONTROLOBJECT < string name = "ChangeCamera.x"; >;
static float SceneChangeDirThreshold = cos(SceneChangeAngleThreshold * 3.14 / 180);
static float3 CameraPos = ViewMatrix[3].xyz;
static float3 CameraDir = ViewMatrix[2].xyz;
static float3 LastCameraPos = lastViewMatrix[3].xyz;
static float3 LastCameraDir = lastViewMatrix[2].xyz;
static bool IsSceneChange = 
#if 0
	false;
#else
	(length(CameraPos - LastCameraPos) > SceneChangeThreshold) ||
	(dot(CameraDir, LastCameraDir) < SceneChangeDirThreshold) ||
	ChangeCamera;
#endif
static float4x4 LastMatrix = IsSceneChange ? WorldViewProjMatrix : lastMatrix;
//-----------------------------------------------------------------


float4 Velocity_PS( VS_OUTPUT IN , uniform bool useToon , uniform bool isEdge) : COLOR0
{
    float4 lastPos, ViewPos;
    
    if(useToon){
        lastPos = mul( IN.LastPos, LastMatrix );
        ViewPos = mul( IN.CurrentPos, WorldViewProjMatrix );
    }else{
        lastPos = mul( IN.CurrentPos, LastMatrix );
        ViewPos = mul( IN.CurrentPos, WorldViewProjMatrix );
    }
    
    float alpha = MaterialDiffuse.a;
    
    //深度
    float mb_depth = ViewPos.z;
    //float mb_depth = ViewPos.z / ViewPos.w;
    
    #if TRANS_TEXTURE!=0
        if(use_texture){
            alpha *= tex2D(ObjTexSampler,IN.Tex).a;
        }
    #endif
    
    //速度算出
    float2 Velocity = ScreenPosRasterize(ViewPos) - ScreenPosRasterize(lastPos);
    Velocity.x *= ViewportAspect;
    
    //出現時、速度キャンセル
    Velocity *= !Appear || MotionBlockerEnable || CameraBlockerEnable;
    
    //速度を色として出力
    Velocity = Velocity * 0.25 + 0.5;
    
    alpha = (alpha >= TransparentThreshold) * (isEdge ? (1.0 / (length(Velocity) * 30)) : 1);
    
    float4 Color = float4(Velocity, mb_depth, alpha);
    
    return Color;
    
}


/////////////////////////////////////////////////////////////////////////////////////
//情報バッファの作成

struct VS_OUTPUT2 {
    float4 Pos: POSITION;
    float2 texCoord: TEXCOORD0;
};


VS_OUTPUT2 DrawMatrixBuf_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
    VS_OUTPUT2 Out;
    
    Out.Pos = Pos;
    Out.texCoord = Tex;
    return Out;
}

float4 DrawMatrixBuf_PS(float2 texCoord: TEXCOORD0) : COLOR {
    
    int dindex = (int)((texCoord.x * INFOBUFSIZE) + 0.2); //テクセル番号
    float4 Color;
    
    if(dindex < 4){
        Color = MotionBlockerEnable ? lastWorldMatrix[(int)dindex] : WorldMatrix[(int)dindex]; //行列を記録
        
    }else if(dindex < 8){
        Color = CameraBlockerEnable ? lastViewMatrix[(int)dindex - 4] : ViewProjMatrix[(int)dindex - 4];
        
    }else{
        Color = float4(stime, ftime, 0.5, 1);
    }
    
    return Color;
}


/////////////////////////////////////////////////////////////////////////////////////
//頂点座標バッファの作成

struct VS_OUTPUT3 {
    float4 Pos: POSITION;
    float4 BasePos: TEXCOORD0;
};

VS_OUTPUT3 DrawVertexBuf_VS(MMM_SKINNING_INPUT IN)
{
    VS_OUTPUT3 Out;
    
    float findex = (float)(IN.Index + voffset);
    float2 tpos = 0;
    tpos.x = modf(findex / VPBUF_WIDTH, tpos.y);
    tpos.y /= VPBUF_HEIGHT;
    
    //バッファ出力
    Out.Pos.xy = (tpos * 2 - 1) * float2(1,-1); //テクスチャ座標→頂点座標変換
    Out.Pos.zw = float2(0, 1);
    
    Out.Pos.x += MotionBlockerEnable * -100; //記録の可否
    
    //ラスタライズなしでピクセルシェーダに渡す
    Out.BasePos = GETPOS;
    
    return Out;
}

float4 DrawVertexBuf_PS( VS_OUTPUT3 IN ) : COLOR0
{
    //座標を色として出力
    return IN.BasePos;
}

/////////////////////////////////////////////////////////////////////////////////////
//頂点座標バッファのコピー

VS_OUTPUT2 CopyVertexBuf_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + VPBufOffset;
   return Out;
}

float4 CopyVertexBuf_PS(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(VertexPosBuf, texCoord);
}

/////////////////////////////////////////////////////////////////////////////////////


float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;


// オブジェクト描画用テクニック

stateblock PMD_State = stateblock_state
{
    
    DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
    AlphaBlendEnable = false;
    AlphaTestEnable = true;
    
    VertexShader = compile vs_3_0 Velocity_VS(true);
    PixelShader  = compile ps_3_0 Velocity_PS(true, false);
};

stateblock Edge_State = stateblock_state
{
    
    DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
    AlphaBlendEnable = false;
    AlphaTestEnable = true;
    
    VertexShader = compile vs_3_0 Velocity_VS(true);
    PixelShader  = compile ps_3_0 Velocity_PS(true, true);
};


stateblock Accessory_State = stateblock_state
{
    
    DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
    AlphaBlendEnable = false;
    AlphaTestEnable = true;
    
    VertexShader = compile vs_3_0 Velocity_VS(false);
    PixelShader  = compile ps_3_0 Velocity_PS(false, false);
};

stateblock makeMatrixBufState = stateblock_state
{
    AlphaBlendEnable = false;
    AlphaTestEnable = false;
    VertexShader = compile vs_3_0 DrawMatrixBuf_VS();
    PixelShader  = compile ps_3_0 DrawMatrixBuf_PS();
};


stateblock makeVertexBufState = stateblock_state
{
    DestBlend = InvSrcAlpha; SrcBlend = SrcAlpha; //加算合成のキャンセル
    FillMode = POINT;
    CullMode = NONE;
    ZEnable = false;
    AlphaBlendEnable = false;
    AlphaTestEnable = false;
    
    VertexShader = compile vs_3_0 DrawVertexBuf_VS();
    PixelShader  = compile ps_3_0 DrawVertexBuf_PS();
};

stateblock copyVertexBufState = stateblock_state
{
    AlphaBlendEnable = false;
    AlphaTestEnable = false;
    VertexShader = compile vs_3_0 CopyVertexBuf_VS();
    PixelShader  = compile ps_3_0 CopyVertexBuf_PS();
};

////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec0_0 < 
    string MMDPass = "object"; 
    bool UseToon = true;
    string Subset = "0"; 
    string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "RenderColorTarget=VertexPosBufTex2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=CopyVertexBuf;"
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
        "RenderColorTarget=VertexPosBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        
    ;
> {
    pass DrawMatrixBuf < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (PMD_State);  }
    pass DrawVertexBuf < string Script = "Draw=Geometry;";> { StateBlock = (makeVertexBufState); }
    pass CopyVertexBuf < string Script = "Draw=Buffer;";>   { StateBlock = (copyVertexBufState); }
    
}


technique MainTec0_1 < 
    string MMDPass = "object"; 
    bool UseToon = true;
    string Script =
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
        "RenderColorTarget=VertexPosBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        
    ;
> {
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (PMD_State);  }
    pass DrawVertexBuf < string Script = "Draw=Geometry;";> { StateBlock = (makeVertexBufState); }
    
}

technique MainTec1 < 
    string MMDPass = "object"; 
    bool UseToon = false;
    string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
    ;
> {
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (Accessory_State);  }
    pass DrawMatrixBuf < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec0_0SS < 
    string MMDPass = "object_ss"; 
    bool UseToon = true;
    string Subset = "0"; 
    string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "RenderColorTarget=VertexPosBufTex2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=CopyVertexBuf;"
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
        "RenderColorTarget=VertexPosBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        
    ;
> {
    pass DrawMatrixBuf < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (PMD_State);  }
    pass DrawVertexBuf < string Script = "Draw=Geometry;";> { StateBlock = (makeVertexBufState); }
    pass CopyVertexBuf < string Script = "Draw=Buffer;";>   { StateBlock = (copyVertexBufState); }
    
}


technique MainTec0_1SS < 
    string MMDPass = "object_ss"; 
    bool UseToon = true;
    string Script =
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
        "RenderColorTarget=VertexPosBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        
    ;
> {
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (PMD_State);  }
    pass DrawVertexBuf < string Script = "Draw=Geometry;";> { StateBlock = (makeVertexBufState); }
    
}

technique MainTec1SS < 
    string MMDPass = "object_ss"; 
    bool UseToon = false;
    string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
    ;
> {
    pass DrawObject    < string Script = "Draw=Geometry;";> { StateBlock = (Accessory_State);  }
    pass DrawMatrixBuf < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

technique EdgeTec < string MMDPass = "edge";
    string Script =
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "LoopByCount=CloneCount;"
        "LoopGetIndex=CloneIndex;"
            "Pass=DrawObject;"
        "LoopEnd=;"
        
    ;
> {
    pass DrawObject < string Script = "Draw=Geometry;";> { StateBlock = (Edge_State);  }
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 影なし
technique ShadowTec < string MMDPass = "shadow"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////

