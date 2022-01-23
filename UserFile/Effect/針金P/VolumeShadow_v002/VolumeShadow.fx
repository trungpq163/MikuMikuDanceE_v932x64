////////////////////////////////////////////////////////////////////////////////////////////////
//
//  VolumeShadow.fx ver0.0.1  シャドウボリューム法によるセルフシャドウ描画
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define UseMLAA  1   // MLAA法による影境界のアンチエイリアシング処理
// 0 : 処理しない、描画速度優先、影境界にジャギーが残る。
// 1 : 処理する、影境界のジャギーは緩和される。
// ※32bit版MMEではエラーになるので0にしてください


#define MLAA_SampNum   8   // MLAA処理の一方向のサンプリング数


#define MODE_HQ  0   // シャドウボリューム計算結果を記録するバッファサイズ
// 0 : スクリーン等倍サイズ
// 1 : スクリーンの2倍サイズ,影境界がきれいでなめらかになる(かなり重いです)


/* テスト用シャドウボリュームの可視化 */
//#define TestDrawShadowVolume  /* ←行先頭の // を除くをシャドウボリュームが描画されます */


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0f;

#if MODE_HQ==1
    #define BUFFRATIO  2.0
#else
    #define BUFFRATIO  1.0
#endif

// シャドウボリュームの描画結果を記録するためのレンダーターゲット
shared texture2D VolumeShadow_VolumeMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {BUFFRATIO, BUFFRATIO};
    int MipLevels = 0;
    string Format = "D3DFMT_A8R8G8B8";
>;
sampler2D VolumeMapSamp = sampler_state {
    texture = <VolumeShadow_VolumeMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// シャドウボリュームの計算に用いる深度ステンシルバッファ
shared texture2D VolumeShadow_DepthStencilBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {BUFFRATIO, BUFFRATIO};
    string Format = "D3DFMT_D24S8";
>;

// シャドウボリュームのステンシル処理を行うオフスクリーンバッファ
// (深度ステンシルバッファの更新だけでオフスクリーンバッファはダミー,シャドウボリュームのテスト描画あり)
texture VS_StencilRT : OFFSCREENRENDERTARGET <
    string Description = "VolumeShadow.fxのオフスクリーンバッファ";
    int Width  = 1;
    int Height = 1;
    int Miplevels = 1;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* = VolumeShadow_Stencil.fxsub;";
>;

// 深度バッファを更新するためのオフスクリーンバッファ
// (深度ステンシルバッファの更新だけでオフスクリーンバッファはダミー)
texture VS_DepthRT : OFFSCREENRENDERTARGET <
    string Description = "VolumeShadow.fxのオフスクリーンバッファ";
    int Width  = 1;
    int Height = 1;
    int Miplevels = 1;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* = VolumeShadow_Depth.fxsub;"
    ;
>;

#ifdef TestDrawShadowVolume
// シャドウボリュームの描画結果を記録するためのレンダーターゲット
texture2D TestVolumeDrawMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D TestVolumeDrawSamp = sampler_state {
    texture = <TestVolumeDrawMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
#endif

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize/BUFFRATIO);
static float2 SampStep = (float2(1,1)/ViewportSize/BUFFRATIO);


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Common( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ステンシルバッファより影部を書き出す

float4 PS_ShadowDraw() : COLOR
{
    return float4(1,1,1,1);
//    return float4(0,0,1,1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 影境界の補正
// (深度バッファ更新時に頂点を押し出したことでオブジェクト境界の影に隙間が出来てしまうへの対処)

float4 PS_ShadowEdgeDraw( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 色データ
    float color0 = tex2D( VolumeMapSamp, Tex ).b;
    float colorL = tex2D( VolumeMapSamp, Tex-float2(SampStep.x,0) ).b;
    float colorR = tex2D( VolumeMapSamp, Tex+float2(SampStep.x,0) ).b;
    float colorB = tex2D( VolumeMapSamp, Tex+float2(0,SampStep.y) ).b;
    float colorT = tex2D( VolumeMapSamp, Tex-float2(0,SampStep.y) ).b;
    float color = color0;

    // 非影ピクセルの隣接部が2ピクセル以上影の場合は影にする
    if(color0 < 0.5){
        color = step(1.5f, colorL+colorR+colorB+colorT);
    }
    // 影ピクセルの隣接部が全て非影の場合は非影にする(計算誤差によるゴミ点の除去)
    if(color0 > 0.5){
        color = step(0.5f, colorL+colorR+colorB+colorT);
    }

    return float4(color, color, color0, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////
// MLAA法による影境界のアンチエイリアシング処理

#if UseMLAA==1

// 輪郭抽出結果を記録するためのレンダーターゲット
texture2D OutlineMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {BUFFRATIO, BUFFRATIO};
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8";
>;
sampler2D OutlineMapSamp = sampler_state {
    texture = <OutlineMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// 輪郭抽出
float4 PS_PickupOutline( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 色データ
    float color0 = tex2D( VolumeMapSamp, Tex ).r;
    float colorL = tex2D( VolumeMapSamp, Tex-float2(SampStep.x,0) ).r;
    float colorR = tex2D( VolumeMapSamp, Tex+float2(SampStep.x,0) ).r;
    float colorB = tex2D( VolumeMapSamp, Tex+float2(0,SampStep.y) ).r;
    float colorT = tex2D( VolumeMapSamp, Tex-float2(0,SampStep.y) ).r;

    // 輪郭フラグ
    float bflagL = step(0.5f, abs(color0 - colorL));
    float bflagR = step(0.5f, abs(color0 - colorR));
    float bflagB = step(0.5f, abs(color0 - colorB));
    float bflagT = step(0.5f, abs(color0 - colorT));

    return float4(bflagL, bflagR, bflagB, bflagT);
}


// 境界色のブレンド
float AAColorBlend(float color0, float color1, float2 linePt1, float2 linePt2)
{
    float Color = color0;

    if(linePt1.y * linePt2.y == 0.0f){
        // L型境界の処理
        float x1 = (linePt1.y == 0.0f) ? max(linePt1.x, linePt2.x-MLAA_SampNum-1) : linePt1.x;
        float x2 = (linePt2.y == 0.0f) ? min(linePt2.x, linePt1.x+MLAA_SampNum+1) : linePt2.x;
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-x1)/(x2-x1));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-x1)/(x2-x1));
        if(h1 >= 0.0f && h2 >= 0.0f){
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(h1 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h1);
        }else if(h2 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h2);
        }
    }else if(linePt1.y * linePt2.y < 0.0f){
        // Z型境界の処理
        float h1 = lerp(linePt1.y, linePt2.y, (-0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        float h2 = lerp(linePt1.y, linePt2.y, ( 0.5f-linePt1.x)/(linePt2.x-linePt1.x));
        if(h1 >= 0.0f && h2 >= 0.0f){
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(h1 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h1);
        }else if(h2 > 0.0f){
            Color = lerp(color0, color1, 0.25f*h2);
        }
    }else if(linePt1.y > 0.0f && linePt2.y > 0.0f){
        // U型境界の処理
        float h1, h2;
        float x0 = (linePt1.x + linePt2.x) * 0.5f;
        if(x0 >= 0.5f){
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(x0-linePt1.x));
            h2 = lerp(linePt1.y, 0.0f, ( 0.5f-linePt1.x)/(x0-linePt1.x));
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else if(x0 <= -0.5f){
            h1 = lerp(0.0f, linePt2.y, (-0.5f-x0)/(linePt2.x-x0));
            h2 = lerp(0.0f, linePt2.y, ( 0.5f-x0)/(linePt2.x-x0));
            Color = lerp(color0, color1, 0.5f*(h1+h2));
        }else{
            h1 = lerp(linePt1.y, 0.0f, (-0.5f-linePt1.x)/(-linePt1.x));
            h2 = lerp(0.0f, linePt2.y,   0.5f           /( linePt2.x));
            Color = lerp(color0, color1, 0.25f*(h1+h2));
        }
    }

    return Color;
}


// LeftRight境界のAA処理
float4 PS_MLAA_LeftRight(float2 Tex: TEXCOORD0) : COLOR
{
    float Color  = tex2D( VolumeMapSamp, Tex ).r;
    float colorL = tex2D( VolumeMapSamp, Tex-float2(SampStep.x,0) ).r;
    float colorR = tex2D( VolumeMapSamp, Tex+float2(SampStep.x,0) ).r;
    float Color1 = Color;

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Left境界のAA処理
    if(bflag.x > 0.5f){
        // Left境界のジャギー形状解析
        float4 bflag0, bflagL;
        float2 linePt1 = float2(-0.5f-MLAA_SampNum, 0.0f);
        float2 linePt2 = float2( 0.5f+MLAA_SampNum, 0.0f);
        [unroll] //ループ展開
        for(int i=MLAA_SampNum; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         , SampStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x, SampStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagL.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         ,-SampStep.y*i) );
            bflagL = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x,-SampStep.y*i) );
            if(bflag0.x < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagL.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Left境界色ブレンド
        Color1 = AAColorBlend(Color, colorL, linePt1, linePt2);
    }

    // Right境界のAA処理
    if(bflag.y > 0.5f){
        // Right境界のジャギー形状解析
        float4 bflag0, bflagR;
        float2 linePt1 = float2(-0.5f-MLAA_SampNum, 0.0f);
        float2 linePt2 = float2( 0.5f+MLAA_SampNum, 0.0f);
        [unroll] //ループ展開
        for(int i=MLAA_SampNum; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         , SampStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( SampStep.x, SampStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.z > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagR.z > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( 0         ,-SampStep.y*i) );
            bflagR = tex2D( OutlineMapSamp, Tex+float2( SampStep.x,-SampStep.y*i) );
            if(bflag0.y < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.w > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagR.w > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Right境界色ブレンド
        Color1 = AAColorBlend(Color, colorR, linePt1, linePt2);
    }

    return float4(Color, Color1, 0, 1);
}


// BottomTop境界のAA処理
float4 PS_MLAA_BottomTop(float2 Tex: TEXCOORD0) : COLOR
{
    float Color  = tex2D( VolumeMapSamp, Tex ).g;
    float colorB = tex2D( VolumeMapSamp, Tex+float2(0,SampStep.y) ).g;
    float colorT = tex2D( VolumeMapSamp, Tex-float2(0,SampStep.y) ).g;
    float Color1 = Color;

    float4 bflag = tex2D( OutlineMapSamp, Tex ); // 輪郭フラグ

    // Bottom境界のAA処理
    if(bflag.z > 0.5f){
        // Bottom境界のジャギー形状解析
        float4 bflag0, bflagB;
        float2 linePt1 = float2(-0.5f-MLAA_SampNum, 0.0f);
        float2 linePt2 = float2( 0.5f+MLAA_SampNum, 0.0f);
        [unroll] //ループ展開
        for(int i=MLAA_SampNum; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, 0         ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, SampStep.y) );
            if(bflag0.z < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagB.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, 0         ) );
            bflagB = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, SampStep.y) );
            if(bflag0.z < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagB.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Bottom境界色ブレンド
        Color1 = AAColorBlend(Color, colorB, linePt1, linePt2);
    }

    // Top境界のAA処理
    if(bflag.w > 0.5f){
        // Top境界のジャギー形状解析
        float4 bflag0, bflagT;
        float2 linePt1 = float2(-0.5f-MLAA_SampNum, 0.0f);
        float2 linePt2 = float2( 0.5f+MLAA_SampNum, 0.0f);
        [unroll] //ループ展開
        for(int i=MLAA_SampNum; i>=0; i--){
            bflag0 = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, 0         ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2(-SampStep.x*i, SampStep.y) );
            if(bflag0.w < 0.5f){
                linePt1 = float2( 0.5f-i, 0.0f);
            }else if(bflag0.x > 0.5f){
                linePt1 = float2(-0.5f-i, 0.5f);
            }else if(bflagT.x > 0.5f){
                linePt1 = float2(-0.5f-i,-0.5f);
            }

            bflag0 = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, 0         ) );
            bflagT = tex2D( OutlineMapSamp, Tex+float2( SampStep.x*i, SampStep.y) );
            if(bflag0.w < 0.5f){
                linePt2 = float2(-0.5f+i, 0.0f);
            }else if(bflag0.y > 0.5f){
                linePt2 = float2( 0.5f+i, 0.5f);
            }else if(bflagT.y > 0.5f){
                linePt2 = float2( 0.5f+i,-0.5f);
            }
        }
        // Top境界色ブレンド
        Color1 = AAColorBlend(Color, colorT, linePt1, linePt2);
    }

    return float4(Color1, Color, 0, 1);
}

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// テスト用シャドウボリュームの描画

#ifdef TestDrawShadowVolume

// シャドウボリュームの描画結果をバックアップ
float4 PS_CopyDraw( float2 Tex: TEXCOORD0 ) : COLOR
{
    return tex2D( VolumeMapSamp, Tex );
}

// シャドウボリュームを描画
float4 PS_TestDraw( float2 Tex: TEXCOORD0 ) : COLOR
{
    //float4 Color = tex2D( VolumeMapSamp, Tex );
    float4 Color = float4(0.8f, 1.0f, 0.0f, 0.7f*tex2D( TestVolumeDrawSamp, Tex ).r);
    return Color;
}

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        #ifdef TestDrawShadowVolume
        // シャドウボリュームの描画結果をバックアップ(テスト用)
        "RenderColorTarget0=TestVolumeDrawMap;"
            "RenderDepthStencilTarget=VolumeShadow_DepthStencilBuffer;"
            "ClearSetColor=ClearColor;"
            "Clear=Color;"
            "Pass=CopyDraw;"
        #endif

        // ステンシルバッファの結果を書き出す(遮蔽マップ作成)
        "RenderColorTarget0=VolumeShadow_VolumeMap;"
            "RenderDepthStencilTarget=VolumeShadow_DepthStencilBuffer;"
            "ClearSetColor=ClearColor;"
            "Clear=Color;"
            "Pass=DrawShadowVolume;"
            "Pass=ShadowEdgeDraw;"

        #if UseMLAA==1
        // 影境界のアンチエイリアシング処理
        "RenderColorTarget0=OutlineMap;"
        "RenderDepthStencilTarget=VolumeShadow_DepthStencilBuffer;"
            "ClearSetColor=ClearColor;"
            "Clear=Color;"
            "Pass=PickupOutline;"
        "RenderColorTarget0=VolumeShadow_VolumeMap;"
        "RenderDepthStencilTarget=VolumeShadow_DepthStencilBuffer;"
            "Pass=MLAA_LeftRight;"
            "Pass=MLAA_BottomTop;"
        #endif

        // オリジナルの描画
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ScriptExternal=Color;"
            #ifdef TestDrawShadowVolume
            // シャドウボリュームを描画(テスト用)
            "Pass=TestDraw;"
            #endif

        // 次フレームのため深度ステンシルバッファをクリア
        "RenderColorTarget0=VolumeShadow_VolumeMap;"
            "RenderDepthStencilTarget=VolumeShadow_DepthStencilBuffer;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Depth;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
        ; >
{
    pass DrawShadowVolume < string Script= "Draw=Buffer;"; > {
        // ステンシルバッファの結果を書き出す
        ZEnable = FALSE;
        StencilEnable = TRUE;
        StencilRef = 0x1;
        StencilMask = 0xffffffff;
        StencilWriteMask = 0xffffffff;
        StencilFunc = LESS;
        StencilFail = KEEP;
        StencilZFail = KEEP;
        StencilPass = KEEP;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_ShadowDraw();
    }
    pass ShadowEdgeDraw < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_ShadowEdgeDraw();
    }

    #if UseMLAA==1
    pass PickupOutline < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_PickupOutline();
    }
    pass MLAA_LeftRight < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_MLAA_LeftRight();
    }
    pass MLAA_BottomTop < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Common();
        PixelShader  = compile ps_3_0 PS_MLAA_BottomTop();
    }
    #endif

    #ifdef TestDrawShadowVolume
    pass CopyDraw < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        ZWriteEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_CopyDraw();
    }
    pass TestDraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_Common();
        PixelShader  = compile ps_2_0 PS_TestDraw();
    }
    #endif
}

////////////////////////////////////////////////////////////////////////////////////////////////
