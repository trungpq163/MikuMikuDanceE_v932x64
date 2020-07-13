//当たり判定用エフェクト

//--ここから触らない

static float2 MirrorSize = { 250, 250 };

float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
// 普通のビュー行列
float4x4 calcViewMatrixInUp(float4x4 matWorld) {

    float3 eye = matWorld[3]+normalize(matWorld[1].xyz)*100;
    float3 at = matWorld[3];
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
    float4x4 Proj = calcPerspectiveLH(MirrorSize.x,MirrorSize.y,1, 100 );
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
    float3 eye = MirrorWorldMatrix[3]+normalize(MirrorWorldMatrix[1].xyz);
    float3 pos = WorldMatrix[3];
    
    float work = length(eye-pos);
    
    // カメラ視点のワールドビュー変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    float3 wpos = Pos.xyz;
    
    float4 VPos = mul( Pos,mul(WorldMatrix, ViewMatrix));
    float len = VPos.z*0.01;//(Out.Pos.z/Out.Pos.w);

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
    	CULLMODE = NONE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
    	CULLMODE = NONE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
