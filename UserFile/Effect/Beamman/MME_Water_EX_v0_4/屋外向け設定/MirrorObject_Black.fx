///////////////////////////////////////////////////////////////////////////////////////////////
// 設定

// 鏡アクセサリのサイズ（横ｘ縦）
//   ※この値を変更した場合、必ずMirror.fxの同名の設定も合わせて変更すること
float2 MirrorSize = { 1, 1 };

////////////////////////////////////////////////////////////////////////////////////////////////
// 鏡関連

// ワールド・ビュー変換行列限定で、逆行列を計算する。
// - 行列が、等倍スケーリング、回転、平行移動しか含まないことを前提条件とする。
float4x4 inverseWorldMatrix(float4x4 mat) {
    float scaling = length(mat[0].xyz);
    float scaling_inv2 = 1.0 / (scaling * scaling);
    
    float3x3 mat3x3_inv = transpose((float3x3)mat) * scaling_inv2;
    return float4x4(
        mat3x3_inv[0], 0, 
        mat3x3_inv[1], 0, 
        mat3x3_inv[2], 0, 
        -mul(mat._41_42_43,mat3x3_inv), 1
    );
}

// 鏡面を描画する場合のビュー変換行列を計算する。
// - 鏡面を対称面として、視点の位置および方向を反転した、ビュー変換行列を計算する。
// - ただし、そのままでは右手系になってしまい、描画に影響が出るので、X軸も反転しておく。
float4x4 calcViewMatrixInMirror(float4x4 matWorld, float4x4 matView) {
    float4x4 res = inverseWorldMatrix(matWorld);
    res._13_23_33_43 *= -1;
    res = mul( res, matWorld );
    res = mul( res, matView );
    res._11_21_31_41 *= -1;
    return res;
}

// D3DXMatrixPerspectiveOffCenterLH関数そのまま
float4x4 calcPerspectiveMatrixOffCenterLH(float l, float r, float b, float t, float zn, float zf) {
    return float4x4(
        2*zn/(r-l) , 0          , 0         ,    0,
        0          , 2*zn/(t-b) , 0         ,    0,
        (l+r)/(l-r), (t+b)/(b-t), zf/(zf-zn),    1,
        0          , 0          , zn*zf/(zn-zf), 0
    );
}

// 鏡面を描画する場合の射影変換行列を計算する。
// - 鏡の長方形を、視錐台の前方クリップ面とするような、射影行列を計算する。
float4x4 calcProjMatrixInMirror(float4x4 matWorld, float4x4 matView, float2 mirror_size) {
    float4x4 matWVinMirror = mul( matWorld, matView );
    
    // 始点から見えるのは鏡の表か裏か
    bool face = dot(matWVinMirror[2].xyz,matWVinMirror[3].xyz) < 0;
    
    // 視線が鏡面に対して垂直になるよう、回転する。
    float4x4 mirrorVerticalView = 0;
    mirrorVerticalView._11_22_33_44 = 1;
    if ( face ) {
        mirrorVerticalView._11_33 = -1;
    }
    mirrorVerticalView = mul(mirrorVerticalView, matWVinMirror);
    mirrorVerticalView = transpose(mirrorVerticalView);
    mirrorVerticalView = float4x4(
        normalize(mirrorVerticalView[0].xyz), 0, 
        normalize(mirrorVerticalView[1].xyz), 0, 
        normalize(mirrorVerticalView[2].xyz), 0, 
        0,0,0, 1
    );
    
    float4x4 mirrorVerticalWV = mul( matWVinMirror, mirrorVerticalView);
    
    float4 mirror_lb = float4( -mirror_size/2, 0, 1);
    float4 mirror_rt = float4( mirror_size/2, 0, 1);
    if ( face ) {
        mirror_lb.x *= -1;
        mirror_rt.x *= -1;
    }
    
    // 回転後の座標上での、鏡の各頂点の座標を求める。
    mirror_lb = mul( mirror_lb, mirrorVerticalWV);
    mirror_rt = mul( mirror_rt, mirrorVerticalWV);
    
    // 射影行列を計算する
    float4x4 ProjInMirror = calcPerspectiveMatrixOffCenterLH( mirror_lb.x, mirror_rt.x, mirror_lb.y, mirror_rt.y, mirror_lb.z, mirror_lb.z+65535 );
    return mul( mirrorVerticalView, ProjInMirror);
}

float4x4 WorldMatrix  : WORLD;
float4x4 OriginalViewMatrix  : VIEW;
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;

static float4x4 ViewMatrix = calcViewMatrixInMirror(MirrorWorldMatrix, OriginalViewMatrix);
static float4x4 ProjMatrix = calcProjMatrixInMirror(MirrorWorldMatrix, ViewMatrix, MirrorSize );
static float4x4 WorldViewProjMatrix = mul( mul(WorldMatrix, ViewMatrix), ProjMatrix) ;

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float  Z 		  : TEXCOORD0;    // Z値
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Z = length(CameraPosition - mul( Pos, WorldMatrix ));
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    return float4(0,0,0,1);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject
    {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
