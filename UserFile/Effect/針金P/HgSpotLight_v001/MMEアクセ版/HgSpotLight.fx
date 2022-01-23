////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgSpotLight.fx ver0.0.1  スポットライト光源エフェクト(アクセ版,セルフシャドウあり)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

// ソフトシャドウの有無
#define UseSoftShadow  1  // 0:なし, 1:有り

// シャドウマップバッファサイズ
#define ShadowMapSize  1024

// ソフトシャドウのぼかし強度
float ShadowBulrPower = 1.0;  // 0.5～3.0程度で調整

// セルフ影の濃度
float ShadowDensity = 0.0;  // 大きくするほど影が薄くなる(0.0～1.0で調整)

// 光軸から照明縁までの角度(deg)(HgSL_Object.fxsub,HgSL_ShadowMap.fxsubも同じ値を設定する必要あり)
float LightShieldDirection = 20.0;


// アンチエイリアスによる輪郭部の遮蔽誤判定対策
#define UseAAShadow  0   // 0:しない, 1:する
// (輪郭部のちらつきが目立つ場合はここを1にすると消える,ただしジャギーが出る)

// 輪郭抽出(深度)閾値設定
#define DepthThreshold  2.0


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 光源ワールド変換行列
float4x4 LightWorldMatrix : WORLD;
// 光源位置
static float3 LightPosition = LightWorldMatrix._41_42_43;
// 光軸方向
static float3 LightDirecCenter = normalize(LightWorldMatrix._31_32_33);

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5) / ViewportSize;
static float2 SampStep = float2(1,1) / ViewportSize;

// オフスクリーンスポットライト光源ライティングバッファ
texture HgSL_Draw: OFFSCREENRENDERTARGET <
    string Description = "HgSpotLight.fxのモデルのスポットライト光源オブジェクト描画";
    float2 ViewPortRatio = {1.0, 2.0};
    float4 ClearColor = {0, 0, 0, 1};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A8R8G8B8" ;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = HgSL_Object.fxsub;";
>;
sampler ObjDrawSamp = sampler_state {
    texture = <HgSL_Draw>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// シャドウマップバッファサイズ
#define SMAPSIZE_WIDTH   ShadowMapSize
#define SMAPSIZE_HEIGHT  ShadowMapSize

// オフスクリーンシャドウマップバッファ
texture HgSL_SMap : OFFSCREENRENDERTARGET <
    string Description = "HgSpotLight.fxのシャドウマップ";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_G32R32F" ;
    bool AntiAlias = false;
    int Miplevels = 0;
    string DefaultEffect = 
        "self = hide;"
        "* = HgSL_ShadowMap.fxsub;";
>;
sampler ShadowMapSamp = sampler_state {
    texture = <HgSL_SMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// オフスクリーンワールド座標バッファ
texture2D HgSL_WPos : OFFSCREENRENDERTARGET <
    string Description = "HgSpotLight.fxのモデル座標バッファ";
    float2 ViewPortRatio = {1.0, 1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A32B32G32R32F";
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = HgSL_WPosMap.fxsub;";
>;
sampler2D WPosSamp = sampler_state {
    texture = <HgSL_WPos>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウマップ関連の処理

// ライト方向のビュー変換行列
float4x4 GetLightViewMatrix()
{
   // x軸方向ベクトル(LightDirecCenterがz軸方向ベクトル)
   float3 ltViewX = cross( float3(0.0f, 1.0f, 0.0f), LightDirecCenter ); 
   float3 ltViewY;

   if( any(ltViewX) ){
       // x軸方向ベクトルの正規化
       ltViewX = normalize(ltViewX);
       // y軸方向ベクトル
       ltViewY = cross( LightDirecCenter, ltViewX );
   }else{
       // 真上/真下とLightDirecCenterの方向が一致する場合は特異値となる
       ltViewX = float3(1.0f, 0.0f, 0.0f);
       ltViewY = float3(0.0f, 0.0f, -sign(LightDirecCenter.y));
   }

   // ビュー座標変換の回転行列
   float3x3 ltViewRot = { ltViewX.x, ltViewY.x, LightDirecCenter.x,
                          ltViewX.y, ltViewY.y, LightDirecCenter.y,
                          ltViewX.z, ltViewY.z, LightDirecCenter.z };

   return float4x4( ltViewRot[0],  0,
                    ltViewRot[1],  0,
                    ltViewRot[2],  0,
                   -mul( LightPosition, ltViewRot ), 1 );
};

#define Z_NEAR  1.0     // 最近値
#define Z_FAR   1000.0  // 最遠値
#define MSC     0.98    // マップ縮小率

// ライト方向の射影変換
float4 CalcLightProjPos(float4 VPos)
{
    float vL = MSC / tan(radians(LightShieldDirection));
    float zp = Z_FAR * ( VPos.z - Z_NEAR ) / ( Z_FAR - Z_NEAR );
    return float4(vL*VPos.x, vL*VPos.y, zp, VPos.z);
}

#if UseSoftShadow==1
// シャドウマップのサンプリング間隔
static float2 SMapSampStep = float2(ShadowBulrPower/1024.0f, ShadowBulrPower/1024.0f);

// シャドウマップの周辺サンプリング1
float4 GetZPlotSampleBase1(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv));
    return (Color / 6.0f);
}

// シャドウマップの周辺サンプリング2
float4 GetZPlotSampleBase2(float2 Tex, float smpScale)
{
    float2 smpStep = SMapSampStep * smpScale;
    float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, mipLv)) * 2.0f;
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv));
    Color += tex2Dlod(ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv));
    return (Color / 6.0f);
}
#endif

// シャドウマップからZプロット読み取り
float2 GetZPlot(float2 Tex)
{
    #if UseSoftShadow==1
    float4 Color;
    Color  = GetZPlotSampleBase1(Tex, 1.0f) * 0.508f;
    Color += GetZPlotSampleBase2(Tex, 2.0f) * 0.254f;
    Color += GetZPlotSampleBase1(Tex, 3.0f) * 0.127f;
    Color += GetZPlotSampleBase2(Tex, 4.0f) * 0.063f;
    Color += GetZPlotSampleBase1(Tex, 5.0f) * 0.032f;
    Color += GetZPlotSampleBase2(Tex, 6.0f) * 0.016f;
    #else
    float4 Color = tex2Dlod(ShadowMapSamp, float4(Tex, 0, 0));
    #endif

    return Color.xy;
}

#if UseAAShadow==1
// アンチエイリアスブレンド位置では奥側の隣接ピクセルをサンプリング
float2 GetTexCoordAA(float2 Tex0)
{
    // 周辺のワールド座標と深度
    float Depth0 = tex2D( WPosSamp, Tex0 ).w;
    float DepthL = tex2D( WPosSamp, Tex0+SampStep*float2(-1, 0) ).w;
    float DepthR = tex2D( WPosSamp, Tex0+SampStep*float2( 1, 0) ).w;
    float DepthT = tex2D( WPosSamp, Tex0+SampStep*float2( 0,-1) ).w;
    float DepthB = tex2D( WPosSamp, Tex0+SampStep*float2( 0, 1) ).w;

    // 輪郭部では奥側のTex座標に補正
    float DepthMax = Depth0;
    float2 Tex = Tex0;
    if(DepthL - Depth0 > DepthThreshold){
       if( DepthMax < DepthL ){
           DepthMax = DepthL;
           Tex = Tex0 + SampStep * float2(-1, 0);
       }
    }
    if(DepthR - Depth0 > DepthThreshold){
       if( DepthMax < DepthR ){
           DepthMax = DepthR;
           Tex = Tex0 + SampStep * float2( 1, 0);
       }
    }
    if(DepthT - Depth0 > DepthThreshold){
       if( DepthMax < DepthT ){
           DepthMax = DepthT;
           Tex = Tex0 + SampStep * float2( 0,-1);
       }
    }
    if(DepthB - Depth0 > DepthThreshold){
       if( DepthMax < DepthB ){
           DepthMax = DepthB;
           Tex = Tex0 + SampStep * float2( 0, 1);
       }
    }

    return Tex;
}
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// ライティング描画の加算合成

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float2 Tex  : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT VS_Draw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

// ピクセルシェーダ
float4 PS_Draw( float2 Tex: TEXCOORD0 ) : COLOR
{
    // 上下2画面のTex座標
    float2 TexUpper = float2(Tex.x, 0.5f*Tex.y);
    float2 TexUnder = float2(Tex.x, 0.5f*(Tex.y+1.0f));

    // ライティング処理の色
    float4 Color = tex2D( ObjDrawSamp, TexUpper );

    // 影の色
    float4 ShadowColor0 = float4(Color.rgb*ShadowDensity, Color.a);
    float4 ShadowColor = tex2D( ObjDrawSamp, TexUnder );
    ShadowColor = max(ShadowColor, ShadowColor0);

    // AAブレンド位置を考慮してTex座標を補正
    #if UseAAShadow==1
    Tex = GetTexCoordAA(Tex);
    #endif

    // ライト方向の座標変換,Z値計算
    float3 WPos = tex2D( WPosSamp, Tex ).xyz;
    float4 VPos = mul(float4(WPos,1), GetLightViewMatrix());
    float4 PPos = CalcLightProjPos(VPos);
    float z = PPos.z/PPos.w;

    // シャドウマップテクスチャ座標に変換
    float2 SMapTex = PPos.xy / PPos.w;
    SMapTex.y = -SMapTex.y;
    SMapTex = (SMapTex + 1.0f) * 0.5f;

    // セルフシャドウ描画
    if( !any( saturate(SMapTex) - SMapTex ) ) {
        // シャドウマップZプロット
        float2 zplot = GetZPlot( SMapTex );

        #if UseSoftShadow==1
        // 影部判定(ソフトシャドウ有り VSM:Variance Shadow Maps法)
        float variance = max( zplot.y - zplot.x * zplot.x, 0.0002f );
        float Comp = variance / (variance + max(z - zplot.x, 0.0f));
        #else
        //  影部判定(ソフトシャドウ無し)
        float Comp = 1.0 - saturate( max(z - zplot.x, 0.0f)*1500.0f - 0.3f );
        #endif

        // 影の合成
        Color = lerp(ShadowColor, Color, Comp);
    }

    Color.rgb *= AcsTr;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech <
    string Script = 
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ScriptExternal=Color;"
            "Pass=PostDraw;"
    ;
> {
    pass PostDraw < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_3_0 VS_Draw();
        PixelShader  = compile ps_3_0 PS_Draw();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
