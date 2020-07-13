


//再生中は隠すようにする
bool HideInPlaying = true;
//bool HideInPlaying = false;

////////////////////////////////////////////////////////////////////////////////////////////////

//フレーム時間とシステム時間が一致したら再生中とみなす
float elapsed_time1 : ELAPSEDTIME<bool SyncInEditMode=true;>;
float elapsed_time2 : ELAPSEDTIME<bool SyncInEditMode=false;>;
static bool IsPlaying = (abs(elapsed_time1 - elapsed_time2) < 0.01) && HideInPlaying;


//ビュー射影行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 InvViewProjMatrix : VIEWPROJECTIONINVERSE;

//アルファ値取得
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//マウス
float4 LeftButton : LEFTMOUSEDOWN;
float4 RightButton : RIGHTMOUSEDOWN;

//バッファの幅
#define INFOBUFSIZE 4

//行列の記録
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

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Color      : COLOR0;
    
};

VS_OUTPUT Object_VS(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT Out;
    
    //記録したビュー射影逆行列をロード
    float4x4 savedMatrix = float4x4(MatrixBufArray[0], MatrixBufArray[1], MatrixBufArray[2], MatrixBufArray[3]);
    
    //Out.Pos = mul( Pos, InvViewProjMatrix );
    Out.Pos = mul( Pos, savedMatrix );
    Out.Pos = mul( Out.Pos, ViewProjMatrix );
    
    Out.Color = float4(abs(Normal), 0.16 * alpha1);
    
    if(IsPlaying) Out.Pos.z = -1; //再生中は隠す
    
    return Out;
}


float4 Object_PS( VS_OUTPUT IN , uniform bool wire) : COLOR0
{
    float4 Color;
    
    if(wire){
        Color = float4(0, 0, 0, 0.4 * alpha1);
    }else{
        Color = IN.Color;
    }
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT2 {
    float4 Pos: POSITION;
    float2 Tex: TEXCOORD0;
};


VS_OUTPUT2 DrawMatrixBuf_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
    VS_OUTPUT2 Out;
    
    Out.Tex = Tex;
    Out.Pos = Pos;
    
    //ボタン同時押し以外は画面外に吹っ飛ばして情報更新しない
    Out.Pos.y += 100 * (LeftButton.z == 0 || RightButton.z == 0); 
    
    return Out;
}

float4 DrawMatrixBuf_PS(float2 Tex: TEXCOORD0) : COLOR {
    int dindex = (int)(Tex * INFOBUFSIZE); //テクセル番号
    
    //ビュー射影逆行列を記録
    float4 Color = InvViewProjMatrix[min(dindex, 3)];
    
    return Color;
}


/////////////////////////////////////////////////////////////////////////////////////

// オブジェクト描画用テクニック

stateblock objectState = stateblock_state
{
    CullMode = NONE;
    ZWriteEnable = false;
    VertexShader = compile vs_2_0 Object_VS();
    PixelShader  = compile ps_2_0 Object_PS(false);
};
stateblock objectState2 = stateblock_state
{
    CullMode = NONE;
    ZWriteEnable = false;
    FillMode = WIREFRAME;
    VertexShader = compile vs_2_0 Object_VS();
    PixelShader  = compile ps_2_0 Object_PS(true);
};

stateblock makeMatrixBufState = stateblock_state
{
    AlphaBlendEnable = false;
    AlphaTestEnable = false;
    VertexShader = compile vs_2_0 DrawMatrixBuf_VS();
    PixelShader  = compile ps_2_0 DrawMatrixBuf_PS();
};

technique MainTec1 < 
    string MMDPass = "object"; 
    string Script =
        
        "RenderColorTarget=MatrixBufTex;"
        "RenderDepthStencilTarget=DepthBufferMB;"
        "Pass=DrawMatrixBuf;"
        
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "Pass=DrawObject;"
        "Pass=DrawObjectWire;"
        
    ;
> {
    
    pass DrawMatrixBuf  < string Script = "Draw=Buffer;";>   { StateBlock = (makeMatrixBufState); }
    pass DrawObject     < string Script = "Draw=Geometry;";> { StateBlock = (objectState);  }
    pass DrawObjectWire < string Script = "Draw=Geometry;";> { StateBlock = (objectState2);  }
    
}

