//水面当たり判定用エフェクト

//水面に与える力
float HitPow = 1.0;

//--ここから触らない

//モーフから取得
float morph : CONTROLOBJECT < string name = "(self)"; string item = "水面力"; >;

//最終値
static float wHitPow = HitPow * (1-morph);

float2 MirrorSize = { 1, 1 };

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
// 普通のビュー行列
float4x4 calcViewMatrixInUp(float4x4 matWorld) {

    float3 eye = -(matWorld[3] + normalize(matWorld[2])*65535);
    float3 at = 0;
    float3 up = normalize(matWorld[0]);
    float3 zaxis;
    float3 xaxis;
    float3 yaxis;
    float3 w;

    zaxis = normalize(at - eye);
    xaxis = normalize(cross(up, zaxis));
    yaxis = cross(zaxis, xaxis);
    
    w.x = -dot(xaxis, eye);
    w.y = -dot(yaxis, eye);
    w.z = -dot(zaxis, eye);
    
 	
    return float4x4(
        xaxis.x,           yaxis.x,           zaxis.x,          0,
        xaxis.y,           yaxis.y,           zaxis.y,          0,
        xaxis.z,           yaxis.z,           zaxis.z,          0,
       	w.x,			   w.y,				  w.z, 1
    );
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
float4x4 calcProjMatrixInUp(float4x4 matWorld, float4x4 matView, float2 mirror_size) {
    float4x4 matWVinMirror = mul( matWorld, matView );
    
    // 始点から見えるのは鏡の表か裏か
    bool face = false;//dot(matWVinMirror[2].xyz,matWVinMirror[3].xyz) < 0;
    
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
    float4x4 ProjInMirror = calcPerspectiveMatrixOffCenterLH( mirror_lb.x, mirror_rt.x, mirror_lb.y, mirror_rt.y, mirror_lb.z, mirror_lb.z+1000 );
    return mul( mirrorVerticalView, ProjInMirror);
}
// 座法変換行列
float4x4 WorldMatrix  : WORLD;
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;

static float4x4 ViewMatrix = calcViewMatrixInUp(MirrorWorldMatrix); 
static float4x4 ProjMatrix = calcProjMatrixInUp(MirrorWorldMatrix, ViewMatrix, MirrorSize );
static float4x4 WorldViewProjMatrix = mul( mul(WorldMatrix, ViewMatrix), ProjMatrix) ;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2); 

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos      : POSITION;     // 射影変換座標
    float4 Color    : COLOR0;      // ディフューズ色
};

//頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    float3 wpos = mul(Pos,WorldMatrix).xyz;
        
    float len = length(wpos - MirrorWorldMatrix[3]);
	
	float3 P0 = MirrorWorldMatrix[3].xyz;
	float3 N = normalize(MirrorWorldMatrix[2].xyz);
	float3 V1 = P0 - wpos;
	
	len = dot(N,V1);
	
	/*
    if(len > 0.1)
    {
    	len = 0;
    }
    */
    
    Out.Color.rgb = len*wHitPow;
    Out.Color.a = 1;
    
    return Out;
}
// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
	return IN.Color;
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
