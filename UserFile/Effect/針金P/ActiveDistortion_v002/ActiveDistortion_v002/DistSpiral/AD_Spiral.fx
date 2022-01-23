////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AD_Spiral.fx 空間歪みエフェクト(スクリュー衝撃波っぽいエフェクト,法線・深度マップ作成)
//  ( ActiveDistortion.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

float SpiralThick = 0.1;        // 螺旋発生時の太さ
float SpiralScaleUp = 0.2;      // 螺旋発の太さ拡大度
float SpiralPos = 0.2;          // 螺旋発生位置の中心距離
float SpiralRotSpeed = 2.0;     // 螺旋回転スピード
float SpiralDiffuseSpeed = 1.0; // 螺旋拡散スピード
float SpiralDiffuseExp = 2.0;   // 螺旋拡散スピード(指数係数)

float SpiralLife = 1.5;         // 螺旋の寿命(秒)
float SpiralDecrement = 0.3;    // 螺旋が消失を開始する時間(0.0～1.0:SpiralLifeとの比)

float SpiralLenParRot = 10.0;   // 螺旋一回転当たりの進行距離
float SpiralDirMax = 15.0;      // 螺旋1ステップの最大回転角

int SpiralCount = 4;            // 螺旋配置個数

// オプションのコントロールファイル名
#define BackgroundCtrlFileName  "BackgroundControl.x" // 背景座標コントロールファイル名
#define TimrCtrlFileName        "TimeControl.x"       // 時間制御コントロールファイル名

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define TEX_WIDTH     4   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT  512   // 配置･乱数情報テクスチャピクセル高さ

#define DEPTH_FAR  5000.0f   // 深度最遠値

#define PAI 3.14159265f   // π

int SpiralIndex;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float Scaling = AcsSi * 0.1f;

////////////////////////////////////////////////////////////////////////////////////////////////

// オプションのコントロールパラメータ
bool IsBack : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;
float4x4 BackMat : CONTROLOBJECT < string name = BackgroundCtrlFileName; >;

// MMDワールド座標→背景アクセ基準のワールド座標
float3 BackWorldCoord(float3 pos)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        float3x3 mat3x3_inv = transpose((float3x3)BackMat) * scaling;
        pos = mul( float4(pos, 1), float4x4( mat3x3_inv[0], 0, 
                                             mat3x3_inv[1], 0, 
                                             mat3x3_inv[2], 0, 
                                            -mul(BackMat._41_42_43,mat3x3_inv), 1 ) ).xyz;
    }
    return pos;
}

// 背景アクセ基準の変換行列→MMDワールド変換行列
float4x4 InvBackWorldMatrix(float4x4 mat)
{
    if( IsBack ){
        float scaling = 1.0f / length(BackMat._11_12_13);
        mat = mul( mat, float4x4( BackMat[0]*scaling,
                                  BackMat[1]*scaling,
                                  BackMat[2]*scaling,
                                  BackMat[3] )      );
    }
    return mat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 時間設定

// 時間制御コントロールパラメータ
bool IsTimeCtrl : CONTROLOBJECT < string name = TimrCtrlFileName; >;
float TimeSi : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Si"; >;
float TimeTr : CONTROLOBJECT < string name = TimrCtrlFileName; string item = "Tr"; >;
static bool TimeSync = IsTimeCtrl ? ((TimeSi>0.001f) ? true : false) : true;
static float TimeRate = IsTimeCtrl ? TimeTr : 1.0f;

float time1 : Time;
float time2 : Time < bool SyncInEditMode = true; >;
static float time0 = TimeSync ? time1 : time2;

// 更新時刻記録用
texture TimeTex : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format = "D3DFMT_A32B32G32R32F" ;
>;
sampler TimeTexSmp : register(s0) = sampler_state
{
   Texture = <TimeTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture TimeDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D3DFMT_D24S8";
>;
#ifndef MIKUMIKUMOVING
float4 TimeBufArray[1] : TEXTUREVALUE <
    string TextureName = "TimeTex";
>;
static float time = TimeBufArray[0].y;
static float Dt = TimeBufArray[0].z;
#else
static float4 TimeBuf = tex2Dlod(TimeTexSmp, float4(0.5f,0.5f,0,0));
static float time = TimeBuf.y;
static float Dt = TimeBuf.z;
#endif

float4 UpdateTime_VS(float4 Pos : POSITION) : POSITION
{
    return Pos;
}

float4 UpdateTime_PS() : COLOR
{
   float2 timeDat = tex2D(TimeTexSmp, float2(0.5f,0.5f)).xy;
   float dt = clamp(time0 - timeDat.x, 0.0f, 0.1f) * TimeRate;
   float etime = timeDat.y + dt;
   if(time0 < 0.001f) etime = 0.0;
   return float4(time0, etime, dt, 1);
}


////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix      : WORLD;
float4x4 ViewMatrix       : VIEW;
float4x4 ProjMatrix       : PROJECTION;
float4x4 ViewProjMatrix   : VIEWPROJECTION;

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 螺旋ワールド変換行列記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s1) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = CLAMP;
    AddressV  = WRAP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;


// オブジェクトのワールド変換行列記録用
texture WorldMatrixTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldMatrixSmp = sampler_state
{
   Texture = <WorldMatrixTex>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture WorldMatrixDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=1;
    string Format = "D24S8";
>;
float4 MatrixBufArray[TEX_WIDTH] : TEXTUREVALUE <
    string TextureName = "WorldMatrixTex";
>;

//前フレームのワールド行列
static float4x4 prevWorldMatrix = float4x4( MatrixBufArray[0].xyz, 0.0f,
                                            MatrixBufArray[1].xyz, 0.0f,
                                            MatrixBufArray[2].xyz, 0.0f,
                                            MatrixBufArray[3].xyz, 1.0f );

static float prevCount = MatrixBufArray[0].w;
static float prevRot   = MatrixBufArray[1].w;
static float prevTime  = MatrixBufArray[2].w;


////////////////////////////////////////////////////////////////////////////////////////////////

// 螺旋発生位置のワールド変換行列
float4x4 GetWorldMatrix(int index)
{
    float y = (0.5f+index)/TEX_HEIGHT;
    return InvBackWorldMatrix(
           float4x4( tex2Dlod(CoordSmp, float4(0.5f/TEX_WIDTH, y, 0, 0)).xyz, 0.0f,
                     tex2Dlod(CoordSmp, float4(1.5f/TEX_WIDTH, y, 0, 0)).xyz, 0.0f,
                     tex2Dlod(CoordSmp, float4(2.5f/TEX_WIDTH, y, 0, 0)).xyz, 0.0f,
                     tex2Dlod(CoordSmp, float4(3.5f/TEX_WIDTH, y, 0, 0)).xyz, 1.0f ) );
}

// 螺旋発生からの時間
float GetTime(int index)
{
    return tex2Dlod(CoordSmp, float4(0.5f/TEX_WIDTH, (0.5f+index)/TEX_HEIGHT, 0, 0)).w - 1.0f;
}

// 螺旋ライン自体の進行方向(ローカル座標)
float3 GetVec(int index, float s0, float s1)
{
    float len = tex2Dlod(CoordSmp, float4(1.5f/TEX_WIDTH, (0.5f+index)/TEX_HEIGHT, 0, 0)).w; // 1ステップの進行距離
    float rot = tex2Dlod(CoordSmp, float4(2.5f/TEX_WIDTH, (0.5f+index)/TEX_HEIGHT, 0, 0)).w; // 1ステップの進行角度
    float3 vec = float3(s1*cos(rot)-s0, s1*sin(rot), -len);
    return (len > 0.001f) ? normalize(vec) : float3(0,0,-1);
}

// 1フレーム間のステップ数
int GetCount(int index)
{
    return (int)tex2Dlod(CoordSmp, float4(0.5f/TEX_WIDTH, (3.5f+index)/TEX_HEIGHT, 0, 0)).w;
}

// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

////////////////////////////////////////////////////////////////////////////////////////////////

// クォータニオンの積算
float4 MulQuat(float4 q1, float4 q2)
{
    return float4(cross(q1.xyz, q2.xyz)+q1.xyz*q2.w+q2.xyz*q1.w, q1.w*q2.w-dot(q1.xyz, q2.xyz));
}

// クォータニオンの回転(v1,v2は正規ベクトル)
float3 RotQuat(float3 v1, float3 v2, float3 pos, float slerp)
{
    float4 p =  float4(pos, 0.0f);

    if(dot(v1, v2) > -0.9999f){
        if(distance(v1,v2) > 0.0001f){
            float3 v = normalize( cross(v1, v2) );
            float rot = acos( dot(v1, v2) ) * slerp;
            float sinHD = sin(0.5f * rot);
            float cosHD = cos(0.5f * rot);
            float4 q1 = float4(v*sinHD, cosHD);
            float4 q2 = float4(-v*sinHD, cosHD);
            p = MulQuat( MulQuat(q2, p), q1);
        }
    }else{
       p.x = -p.x;
    }
    return p.xyz;
}

// vを回転軸としてrot回転させる回転行列(vは正規ベクトル)
float3x3 RotMat1(float3 v, float rot)
{
    float3x3 m = float3x3(1,0,0, 0,1,0, 0,0,1);

    if(abs(rot) > 0.0001f){
        float sinHD = sin(0.5f * rot);
        float cosHD = cos(0.5f * rot);
        float4 q = float4(v*sinHD, cosHD);
        m = float3x3( 1-2*q.y*q.y-2*q.z*q.z,   2*q.x*q.y+2*q.w*q.z,   2*q.x*q.z-2*q.w*q.y,
                        2*q.x*q.y-2*q.w*q.z, 1-2*q.x*q.x-2*q.z*q.z,   2*q.y*q.z+2*q.w*q.x,
                        2*q.x*q.z+2*q.w*q.y,   2*q.y*q.z-2*q.w*q.x, 1-2*q.x*q.x-2*q.y*q.y );
    }

    return m;
}

// v1→v2ベクトル間の回転行列(v1,v2は正規ベクトル)
float3x3 RotMat2(float3 v1, float3 v2)
{
    float3x3 m = float3x3(1,0,0, 0,1,0, 0,0,1);

    if(distance(v1,v2) > 0.0001f){
        float3 v = normalize( cross(v1, v2) );
        float rot = acos( dot(v1, v2) );
        float sinHD = sin(0.5f * rot);
        float cosHD = cos(0.5f * rot);
        float4 q = float4(v*sinHD, cosHD);
        m = float3x3( 1-2*q.y*q.y-2*q.z*q.z,   2*q.x*q.y+2*q.w*q.z,   2*q.x*q.z-2*q.w*q.y,
                        2*q.x*q.y-2*q.w*q.z, 1-2*q.x*q.x-2*q.z*q.z,   2*q.y*q.z+2*q.w*q.x,
                        2*q.x*q.z+2*q.w*q.y,   2*q.y*q.z-2*q.w*q.x, 1-2*q.x*q.x-2*q.y*q.y );
    }

    return m;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 螺旋の発生・変換行列更新計算

struct VS_OUTPUT {
   float4 Pos : POSITION;
   float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT UpdatePos_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

// ピクセルシェーダ
float4 UpdatePos_PS(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Pos;
    int i = floor( Tex.x*TEX_WIDTH );

    // 螺旋の座標
    float w = tex2D(CoordSmp, float2(0.5f/TEX_WIDTH, Tex.y)).w;

    if(w < 1.001f){
    // 未発生螺旋の中から移動距離に応じて新たに螺旋を発生させる
        float4x4 Mat = prevWorldMatrix;
        Mat._44 = 0.0f;
        // オブジェクトのワールド座標
        float3 WPos0 = prevWorldMatrix._41_42_43;
        float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);

        float len = length( WPos1 - WPos0 );
        if(len>0.0001f){
            // 1フレーム間の回転角度
            float p_rot = 2.0f * PAI * len / (SpiralLenParRot * Scaling);
            // 1フレーム間の螺旋発生ステップ数
            int p_count = ceil((p_rot-0.0001f) / radians(SpiralDirMax));
            if(prevTime > time || AcsTr < 0.0001f) p_count = min(p_count, 1);

            // 螺旋インデックス
            int p_index = floor( Tex.y*TEX_HEIGHT );

            // 新たに螺旋を発生させるかどうかの判定
            if(p_index < round(prevCount)) p_index += TEX_HEIGHT;
            if(p_index < round(prevCount)+p_count && prevTime < time && AcsTr > 0.0001f){
                // 螺旋発生変換行列
                float s = float(p_index - prevCount) / float(p_count);
                float3 Pos1 = lerp(WPos0, WPos1, s);
                float3 wVec = normalize(WPos1 - WPos0);
                float3x3 dirRotMat = RotMat1(wVec, prevRot+p_rot*s);
                float4x4 newRotMat = float4x4(dirRotMat[0], 0.0f,
                                              dirRotMat[1], 0.0f,
                                              dirRotMat[2], 0.0f,
                                              Pos1 - mul(WPos0, dirRotMat), 1.0f );
                Mat = mul(prevWorldMatrix, newRotMat);
                Mat._14 = 1.0011f + Dt * s;       // w>1.001で螺旋発生
                Mat._24 = len / float(p_count);   // 1ステップの進行距離
                Mat._34 = p_rot / float(p_count); // 1ステップの進行角度
                Mat._44 = p_count;                // 1フレーム間のステップ数
            }
        }
        Pos = Mat[i % TEX_WIDTH];
    }else{
    // 発生中螺旋の座標
        Pos = tex2D(CoordSmp, Tex);

        if(i == 0){
            // すでに発生している螺旋は経過時間を進める
            Pos.w += Dt;
            Pos.w *= step(Pos.w-1.0f, SpiralLife); // 指定時間を超えると0(螺旋消失)
        }
    }

    if(time < 0.001f){
        float4x4 initWldMat = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, BackWorldCoord(WorldMatrix._41_42_43),0);
        Pos = initWldMat[i % TEX_WIDTH];
    }

    return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトのワールド座標記録

// 頂点シェーダ
VS_OUTPUT WorldMatrix_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.5f/TEX_WIDTH, 0.5f);

    return Out;
}

// ピクセルシェーダ
float4 WorldMatrix_PS(float2 Tex: TEXCOORD0) : COLOR
{
    // オブジェクトのワールド座標
    float3 WPos0 = prevWorldMatrix._41_42_43;
    float3 WPos1 = BackWorldCoord(WorldMatrix._41_42_43);

    float3 dirVec0 = any(prevWorldMatrix._31_32_33) ? normalize(-prevWorldMatrix._31_32_33) : float3(0,0,-1);
    float3 dirVec1 = (distance(WPos1, WPos0) > 0.001f) ? normalize(WPos1 - WPos0) : dirVec0;

    float3x3 dirRotMat = RotMat2(dirVec0, dirVec1);
    float4x4 newRotMat = float4x4(dirRotMat[0], 0.0f,
                                  dirRotMat[1], 0.0f,
                                  dirRotMat[2], 0.0f,
                                  WPos1 - mul(WPos0, dirRotMat), 1.0f );
    float4x4 newWldMat = mul(prevWorldMatrix, newRotMat);

    // 1フレーム間の回転角度
    float p_rot = 2.0f * PAI * distance(WPos1, WPos0) / (SpiralLenParRot * Scaling);
    // 1フレーム間の発生螺旋数
    int p_count = ceil((p_rot-0.0001f) / radians(SpiralDirMax));
    if(prevTime > time || AcsTr < 0.0001f) p_count = min(p_count, 1);

    float rot = prevRot + p_rot;
    float w = prevCount + p_count;
    if(w >= float(TEX_HEIGHT)) w -= float(TEX_HEIGHT);

    newWldMat._14 = w;
    newWldMat._24 = rot;
    newWldMat._34 = time;

    if(time < 0.001f || !any(newWldMat._11_22_33)){
        newWldMat = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, WPos1,0);
    }

    int i = floor( Tex.x * TEX_WIDTH );

    return newWldMat[i % TEX_WIDTH];
}


///////////////////////////////////////////////////////////////////////////////////////////////
//MMM対応
#ifndef MIKUMIKUMOVING
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


///////////////////////////////////////////////////////////////////////////////////////
// 螺旋描画

struct VS_OUTPUT2
{
    float4 Pos    : POSITION;    // 射影変換座標
    float3 Normal : TEXCOORD1;   // 法線
    float4 VPos   : TEXCOORD2;   // ビュー座標
    float  Alpha  : COLOR0;      // 螺旋の透過度
};

// 頂点シェーダ
VS_OUTPUT2 Spiral_VS(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

    int Index = round( Pos.z * 100.0f );
    Pos.z = 0.0f;
    float4x4 wldMat = GetWorldMatrix(Index);  // 螺旋先端のワールド変換行列

    float sgn = (dot(Pos.xy, Normal.xy) > 0.0f) ? 1.0f : -1.0f; // 法線が 1:外向き, -1:内向き

    // 経過時間
    float etime = GetTime(Index);
    float etimePrev2 = GetTime(Index-GetCount(Index)-2);
    float etimePrev  = GetTime(Index-1);
    float etimeNext  = GetTime(Index+1);
    float etimeNext2 = GetTime(Index+2);

    // 進行による減衰度
    float alpha = smoothstep(-SpiralLife, -SpiralLife*SpiralDecrement, -etime);

    // 経過時間に対する螺旋太さ拡大度
    float scale = SpiralScaleUp * etime + SpiralThick;
//    scale *= alpha;
    Pos.xyz *= scale * Scaling;

    // 螺旋の位置・回転
    float s0 = SpiralPos + SpiralDiffuseSpeed * pow(abs(etime), SpiralDiffuseExp);
    float s1 = SpiralPos + SpiralDiffuseSpeed * pow(abs(etimeNext), SpiralDiffuseExp);
    float3 vec = GetVec(Index, s0, s1);
    Pos.xyz = RotQuat(float3(0,0,-1), vec, Pos.xyz, 1.0f);
    Pos.x += s0 * Scaling;
    Pos.xy = Rotation2D(Pos.xy, 2.0f*PAI*float(SpiralIndex)/float(SpiralCount));

    // 螺旋の移動軸周りの時間変化に対する回転
    float3 rotVec = normalize(wldMat._31_32_33);
    float3x3 dirRotMat = RotMat1(rotVec, -SpiralRotSpeed*time);
    float4x4 newRotMat = float4x4(dirRotMat[0], 0.0f,
                                  dirRotMat[1], 0.0f,
                                  dirRotMat[2], 0.0f,
                                  wldMat._41_42_43 - mul(wldMat._41_42_43, dirRotMat), 1.0f );
    wldMat = mul(wldMat, newRotMat);

    // 螺旋のワールド座標
    Pos = mul(Pos, wldMat);
    if(etime < 0.001f) Pos.xyz *= wldMat._41_42_43;
    Pos.w = 1.0f;

    // 法線回転
    Normal = RotQuat(float3(0,0,-1), vec, Normal, 1.0f);
    Normal.xy = Rotation2D(Normal.xy, 2.0f*PAI*float(SpiralIndex)/float(SpiralCount));
    Normal = mul(Normal, (float3x3)wldMat) * sgn;
    //Out.Normal = Normal;
    Out.Normal = mul(Normal, (float3x3)ViewMatrix);

    // カメラ視点のビュー変換
    Out.VPos = mul( Pos, ViewMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 非表示にする螺旋のチェック
    alpha *= step(0.001, etime);
    alpha *= step(0.001, etimePrev2);
    alpha *= step(0.001, etimePrev);
    alpha *= step(0.001, etimeNext);
    alpha *= step(0.001, etimeNext2);

    Out.Alpha = alpha*alpha;
    Out.Alpha = saturate( Out.Alpha );

    return Out;
}

// ピクセルシェーダ
float4 Spiral_PS( VS_OUTPUT2 IN ) : COLOR0
{
    // 未発生部位は描画しない
    clip( IN.Alpha - 0.001f );

    // 法線(0～1になるよう補正)
    float3 Normal = normalize(IN.Normal);
    //Normal = RotQuat(Normal, float3(0,0,-1), Normal, 1-IN.Alpha); // これでやりたいけど何故かうまくいかない
    Normal = (Normal + 1.0f) / 2.0f;
    Normal = lerp(float3(0.5, 0.5, 0.0f), Normal, IN.Alpha * AcsTr);

    // 深度(0～DEPTH_FARを0.5～1.0に正規化)
    float dep = length(IN.VPos.xyz / IN.VPos.w);
    dep = (saturate(dep / DEPTH_FAR) + 1.0f) * 0.5f;

    return float4(Normal, dep);
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=TimeTex;"
            "RenderDepthStencilTarget=TimeDepthBuffer;"
            "Pass=UpdateTime;"
        "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateCoord;"
        "RenderColorTarget0=WorldMatrixTex;"
	    "RenderDepthStencilTarget=WorldMatrixDepthBuffer;"
	    "Pass=UpdateWorldMatrix;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
             "LoopByCount=SpiralCount;"
             "LoopGetIndex=SpiralIndex;"
                 "Pass=DrawObject;"
             "LoopEnd=;";
>{
    pass UpdateTime < string Script= "Draw=Buffer;"; > {
        ZEnable = FALSE;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_1_1 UpdateTime_VS();
        PixelShader  = compile ps_2_0 UpdateTime_PS();
    }
    pass UpdateCoord < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 UpdatePos_VS();
        PixelShader  = compile ps_3_0 UpdatePos_PS();
    }
    pass UpdateWorldMatrix < string Script= "Draw=Buffer;"; > {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 WorldMatrix_VS();
        PixelShader  = compile ps_3_0 WorldMatrix_PS();
    }
    pass DrawObject {
        ALPHABLENDENABLE = FALSE;
        VertexShader = compile vs_3_0 Spiral_VS();
        PixelShader  = compile ps_3_0 Spiral_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }

