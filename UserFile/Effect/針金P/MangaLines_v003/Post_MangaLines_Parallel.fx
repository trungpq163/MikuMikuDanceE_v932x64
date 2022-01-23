////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Post_MangaLines_Parallel.fx ver0.0.3  漫画･アニメの効果線エフェクト(平行線,ポストフェクト版)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int LineCount = 87;       // 効果線の本数
float LineThick = 0.5;    // 効果線の基準太さ
float LineAlpha = 0.7;    // 効果線の最大透過値
float PosParam = 0.65;     // より分けパラメータ(0で均等,1に近づくほど外側により分けられる)
float AreaScale = 1.0;    // 効果線が描画される範囲(中心位置変更で効果線外端が見える時はここを大きくする)
float3 LineColor = {0.0, 0.0, 0.0}; // 効果線色(RBG)

int SeedThick = 9;     // 太さに関する乱数シード
int SeedPos = 14;      // 配置に関する乱数シード
int SeedAnime = 108;   // アニメーションに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define PAI 3.14159265f   // π

bool flagCenterControl   : CONTROLOBJECT < string name = "CentetControl.pmx"; >;
float4x4 CenterControlMat  : CONTROLOBJECT < string name = "CentetControl.pmx"; string item = "センター"; >;
static float2 CenterCtrlRzVec = flagCenterControl ? normalize(CenterControlMat._11_12) : float2(1,0); // Z軸回転ベクトル

float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsZ  : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;
float AcsRx : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;
float AcsRz : CONTROLOBJECT < string name = "(self)"; string item = "Rz"; >;
float AcsRy : CONTROLOBJECT < string name = "(self)"; string item = "Ry"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float xAlpha = saturate( 1.0f - degrees(AcsRx) );

float time : Time;

int Index;

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float R = length( float2( ViewportSize.x/ViewportSize.y, 1.0f) )*AreaScale;  // 画面対角線長さと高さの比

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x1 = pos.x * cos(rot) - pos.y * sin(rot);
    float y1 = pos.x * sin(rot) + pos.y * cos(rot);
    float x2 = x1 * CenterCtrlRzVec.x - y1 * CenterCtrlRzVec.y;
    float y2 = x1 * CenterCtrlRzVec.y + y1 * CenterCtrlRzVec.x;

    return float2(x2, y2);
}

///////////////////////////////////////////////////////////////////////////////////////
// 効果線描画

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 VPos       : TEXCOORD0;   // ローカル･アニメーション座標
    float2 Tex        : TEXCOORD1;   // テクスチャ座標
};

// 頂点シェーダ
VS_OUTPUT Line_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 乱数設定
    float rand1 = 0.5f * (0.66f * sin(22.1f * SeedThick * Index) + 0.33f * cos(33.6f * SeedThick * Index) + 1.0f);
    float rand2 = 0.5f * (0.31f * sin(45.3f * SeedPos * Index) + 0.69f * cos(73.4f * SeedPos * Index) + 1.0f);
    float rand3 = 0.5f * (0.38f * sin(55.1f * SeedAnime * Index) + 0.62f * cos(44.4f * SeedAnime * Index) + 1.0f);

    // ローカル･アニメーション座標
    Out.VPos.x = Pos.x;
    Out.VPos.y = step(0.0, AcsZ)*(2.0f*R+abs(AcsZ))
               - sign(AcsZ)*fmod(lerp(0.0f, 2.0f*(R+abs(AcsZ)), rand3)+time*AcsSi, 2.0f*(R+abs(AcsZ)));

    // 線の太さ
    Pos.y *= max((LineThick+degrees(AcsRy)*0.2f)*(0.5+rand1)*(1.0f+Pos.x)*0.1f, 0.3f);

    // 平行線配置
    float2 Pos0 = float2(-R-0.4*rand2, lerp(-R, R, (float)Index/(float)LineCount) + ((rand2-0.5f) * 1.5f * R / LineCount));
    Pos0.y = sign(Pos0.y)*R*pow(abs(Pos0.y/R), max(1.0f-PosParam, 0.0f));
    Pos.xy += Pos0;

    // 座標回転
    Pos.xy = Rotation2D(Pos.xy, AcsRz);

    // 配置移動
    if ( flagCenterControl ){
       float4 centerPos = mul(CenterControlMat[3], ViewProjMatrix);
       Pos.x += centerPos.x / centerPos.w * ViewportSize.x/ViewportSize.y;
       Pos.y += centerPos.y / centerPos.w;
    } else {
       Pos.x += AcsX*ViewportSize.x/ViewportSize.y;
       Pos.y += AcsY;
    }

    // スクリーン座標に変換
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Out.Pos = Pos;

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Line_PS( VS_OUTPUT IN ) : COLOR0
{
    // 線先端透過値設定
    float alpha1 = smoothstep((1.0f-AcsTr)*(1.0f+R), 1.0f+(1.0f-AcsTr)*5.0f, IN.VPos.x)*AcsTr;
    // アニメーション透過値設定
    float alpha2 = smoothstep(-max(abs(AcsZ),0.0001f), 0.0f, -abs(IN.VPos.x-IN.VPos.y));
    if( abs(AcsZ) < 0.0001f ) alpha2 = 1.0f;
    // 線側境界透過値設定
    float alpha3 = 1.0f - smoothstep(0.0f, 0.5f, abs(IN.Tex.y-0.5f));

    // 効果線の色
    float4 Color = float4( LineColor, alpha1*alpha2*alpha3*LineAlpha*xAlpha );

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
            "LoopByCount=LineCount;"
               "LoopGetIndex=Index;"
               "Pass=DrawObject;"
            "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_1_1 Line_VS();
        PixelShader  = compile ps_2_0 Line_PS();
    }
}

