//水面当たり判定用エフェクト

//水面に与える力
float HitPow = 1.0;

//--ここから触らない

//モーフから取得
float morph : CONTROLOBJECT < string name = "(self)"; string item = "水面力"; >;

float OwnerScale: CONTROLOBJECT < string Name = "(OffscreenOwner)";string item = "Si"; >;

//最終値
static float wHitPow = HitPow * (1-morph);

static float2 MirrorSize = { 1*OwnerScale, 1*OwnerScale };

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
// 普通のビュー行列
float4x4 calcViewMatrixInUp(float4x4 matWorld) {

    float3 eye = matWorld[3]-normalize(matWorld[1].xyz);//(matWorld[3] + normalize(matWorld[1])*65535);
	//eye = float3(0,10,0);
    float3 at = matWorld[3]+normalize(matWorld[1].xyz);
    float3 up = normalize(matWorld[2]);
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
float4x4 calcPerspectiveLH(float w,float h,float zn,float zf) {

    return float4x4(
		2/w,	0,      0,             0,
		0,      2/h,	0,             0,
		0,      0,      1/(zf-zn),     0,
		0,      0,      zn/(zn-zf),    1
		
    );
}
// 鏡面を描画する場合の射影変換行列を計算する。
// - 鏡の長方形を、視錐台の前方クリップ面とするような、射影行列を計算する。
float4x4 calcProjMatrixInUp(float4x4 matWorld, float4x4 matView, float2 mirror_size) {

    // 射影行列を計算する
    float4x4 Proj = calcPerspectiveLH(MirrorSize.x,MirrorSize.y,1, 1000 );
    return Proj;
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
    
    float3 wpos = Pos.xyz;
        
    float len = 1-saturate(Out.Pos.z*1024);//saturate(length(wpos.y - MirrorWorldMatrix[3].y));

    Out.Color.rgb = len;
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
