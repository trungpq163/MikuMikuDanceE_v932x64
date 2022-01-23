////////////////////////////////////////////////////////////////////////////////////////////////
//
//  TakenFrame.fx ver0.0.1  コマ撮りエフェクト
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float Dt = AcsSi * 0.1f;
static float Fade = AcsTr;

float time : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1, 1};
    string Format = "D24S8";
>;

// フレームを保持するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// フレームを保持するためのレンダーターゲット(バックアップ)
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 更新時刻記録用
shared texture UpdateTime : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_R32F" ;
>;
sampler UpdateTimeSmp = sampler_state
{
   Texture = <UpdateTime>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 画面更新時刻の計算
VS_OUTPUT VS_UpdateTime(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = float2(0.5f, 0.5f);

    return Out;
}

float4 PS_UpdateTime(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Color = tex2D(UpdateTimeSmp, Tex);
   float updateTime = Color.r;

   if( time < 0.01f){
      // 0フレーム再生でリセット
      Color = float4(Dt, 0, 0, 0);
      updateTime = Dt;
   }
   if( time >= updateTime ){
      // 次の更新時刻
      if( (time-updateTime) < Dt ){
         Color += float4(Dt, 0, 0, 0);
      }else{
         Color = float4(time+Dt, 0, 0, 0);
      }
   }

   return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// コマ撮り共通頂点シェーダ
VS_OUTPUT VS_TakenFrame(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// フレームを保持
float4 PS_BackupFrame(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Color = tex2D(ScnSamp2, Tex);
   float updateTime = tex2D(UpdateTimeSmp, float2(0.5f, 0.5f)).r;

   // 更新時刻を過ぎた場合は書き換える
   if( time < 0.01f || time >= updateTime ){
      Color = tex2D(ScnSamp, Tex);
   }

   return Color;
}

// 保持したフレームのバックアップ
float4 PS_BackupFrame2(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Color = tex2D(ScnSamp3, Tex);
   float updateTime = tex2D(UpdateTimeSmp, float2(0.5f, 0.5f)).r;

   // 更新時刻を過ぎた場合は書き換える
   if( time < 0.01f || time >= updateTime ){
      Color = tex2D(ScnSamp2, Tex);
   }

   return Color;
}

// 画面の更新
float4 PS_TakenFrame(float2 Tex: TEXCOORD0) : COLOR
{
   float4 Color1 = tex2D(ScnSamp2, Tex);
   float4 Color2 = tex2D(ScnSamp3, Tex);

   float updateTime = tex2D(UpdateTimeSmp, float2(0.5f, 0.5f)).r;

   // クロスフェードで更新
   float4 Color = lerp(Color1, Color2, saturate( (updateTime-time)/(Dt*Fade) ) );

   return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec <
    string Script = 
        "RenderColorTarget0=ScnMap;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
        "RenderColorTarget0=ScnMap3;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "Pass=BackupFrame2;"
        "RenderColorTarget0=ScnMap2;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "Pass=BackupFrame1;"
        "RenderColorTarget0=UpdateTime;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTimeCalc;"
    ;>
{
    pass BackupFrame1 < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_TakenFrame();
        PixelShader  = compile ps_2_0 PS_BackupFrame();
    }
    pass BackupFrame2 < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_TakenFrame();
        PixelShader  = compile ps_2_0 PS_BackupFrame2();
    }
    pass UpdateTimeCalc < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_2_0 VS_UpdateTime();
        PixelShader  = compile ps_2_0 PS_UpdateTime();
    }
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_TakenFrame();
        PixelShader  = compile ps_2_0 PS_TakenFrame();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////



