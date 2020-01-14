////////////////////////////////////////////////////////////////////////////////////////////////
//
//  被写界深度エフェクト・深度マップメイカー Ver.2
//  作成: そぼろ
//
//　DOFに特化しているので汎用性はありません
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 背景まで透過させる閾値を設定します
float TransparentThreshold = 0.5;

// 透過判定にテクスチャの透過度を使用します。1で有効、0で無効
#define TRANS_TEXTURE  0


////////////////////////////////////////////////////////////////////////////////////////////////

float DepthLimit = 20;

#define SCALE_VALUE 4

//バッファ拡大率
float fmRange = 0.75f;


// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 WorldViewMatrix          : WORLDVIEW;
float4x4 ProjectionMatrix         : PROJECTION;

bool use_texture;  //テクスチャの有無

//マニュアルフォーカスの使用
bool UseMF : CONTROLOBJECT < string name = "ManualFocus.x"; >;
float MFScale : CONTROLOBJECT < string name = "ManualFocus.x"; >;

//親モデルのTr値
float alpha1 : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Tr"; >;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

//合焦距離の取得
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;
float3 ControlerPos  : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
static float3 FocusVec = ControlerPos - CameraPosition;
static float FocusLength = UseMF ? (3.5 * MFScale) : (length(FocusVec) * alpha1);

//焦点がカメラの背面にあるかどうか
float3 CameraDirection : DIRECTION < string Object = "Camera"; >;
static bool BackOut = (dot(CameraDirection, normalize(FocusVec)) < 0) && !UseMF;


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


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // UV
    float3 WorldPos   : TEXCOORD1;   // ワールド座標
};

// 頂点シェーダ
VS_OUTPUT objw_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //ProjectionMatrix._11 *= fmRange;
    //ProjectionMatrix._22 *= fmRange;
    
    //Out.Pos = mul( Pos, mul(WorldViewMatrix, ProjectionMatrix) );
    
    //ワールド座標
    Out.WorldPos = mul( Pos, WorldMatrix );
    
    #if TRANS_TEXTURE
        Out.Tex = Tex; //テクスチャUV
    #endif
    
    return Out;
}

// ピクセルシェーダ
float4 objw_PS( VS_OUTPUT IN ) : COLOR0
{
    //カメラとの距離
    float depth = length(CameraPosition - IN.WorldPos);
    float alpha = MaterialDiffuse.a;
    
    #if TRANS_TEXTURE
        if(use_texture){
            alpha *= tex2D(ObjTexSampler,IN.Tex).a;
        }
    #endif
    
    //合焦距離で正規化
    depth /= (FocusLength * SCALE_VALUE);
    
    //深度が上限を超えているか、焦点がカメラの背面にあるならリミット設定
    depth = (depth > DepthLimit || BackOut) ? DepthLimit : depth;
    
    return float4(depth, 0, 0, (alpha >= TransparentThreshold));
    
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 objw_VS();
        PixelShader  = compile ps_2_0 objw_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 objw_VS();
        PixelShader  = compile ps_2_0 objw_PS();
    }
}

// エッジ描画
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawObject {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 objw_VS();
        PixelShader  = compile ps_2_0 objw_PS();
    }
}

// 地面影は表示しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// セルフシャドウは表示しない
technique ZplotTec < string MMDPass = "zplot"; > { }


///////////////////////////////////////////////////////////////////////////////////////////////
