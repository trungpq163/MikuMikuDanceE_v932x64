// パラメータ宣言
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
// 普通のビュー行列
float4x4 calcViewMatrixInUp(float4x4 matWorld) {

    float3 eye = float3(0,0,0);
    float3 at = float3(0,1,0);
    float3 up = float3(0,0,1);
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
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;
float4x4 calcPerspectiveMatrixOffCenterLH(float l, float r, float b, float t, float zn, float zf) {
     
     float s = (length(MirrorWorldMatrix[1])*0.1)*2;
    return float4x4(
        2/-s, 0, 0, 0,
        0, 2/s, 0, 0,
        0, 0, 1/(zf-zn), 0,
        0, 0, zn/(zn-zf), 1
    );
    /*
    return float4x4(
        2*zn/(r-l) , 0          , 0         ,    0,
        0          , 2*zn/(t-b) , 0         ,    0,
        (l+r)/(l-r), (t+b)/(b-t), zf/(zf-zn),    1,
        0          , 0          , zn*zf/(zn-zf), 0
    );
    */
}
// 鏡面を描画する場合の射影変換行列を計算する。
// - 鏡の長方形を、視錐台の前方クリップ面とするような、射影行列を計算する。
float4x4 calcProjMatrixInUp(float4x4 matWorld, float4x4 matView, float2 mirror_size) {
    // 射影行列を計算する
    float size = 30;
    float4x4 ProjInMirror = calcPerspectiveMatrixOffCenterLH( -size/2, size/2, -size/2, size/2, matWorld[3].y, matWorld[3].y+1 );
    return ProjInMirror;
}
// 座法変換行列
float4x4 WorldMatrix  : WORLD;

static float4x4 ViewMatrix = calcViewMatrixInUp(MirrorWorldMatrix); 
//float4x4 ProjMatrix : PROJECTION;//calcProjMatrixInUp(MirrorWorldMatrix, ViewMatrix, MirrorSize );
static float4x4 ProjMatrix = calcProjMatrixInUp(MirrorWorldMatrix, ViewMatrix, 1 );
static float4x4 matWVP = mul( mul(WorldMatrix, ViewMatrix), ProjMatrix) ;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float4 TexCoord   : TEXCOORD0;
    float2 ObjTex	  : TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL,float2 Tex: TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = mul( Pos, matWVP );
    //Out.Pos.y *= -1;
    Out.Pos.xy *= 0.1;
    //Out.Pos.xy -= 1;
    Out.TexCoord = Out.Pos;
    Out.ObjTex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	float z = 1-IN.TexCoord.z/IN.TexCoord.w;
	
	return float4(z,1,1,1);
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
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
    
}

///////////////////////////////////////////////////////////////////////////////////////////////
