/////////////////////////////
// 回転行列の計算 Ver1.01
// 作成: Caeru.exeile
/////////////////////////////

float4x4 AxisRotation()
{
    float3 TopP = {0,-1,0};
    float3 vAxis = normalize(cross(LightDirection,TopP)); //頂点とライトの交差ベクトルの計算
    float fAngle = acos(dot(LightDirection,TopP)); //頂点とライトの角度の計算

    if( dot( abs( vAxis ), 1 ) <= 0.01 ) {
        return  float4x4(   float4( 1, 0, 0, 0 ),
                            float4( 0, 1, 0, 0 ),
                            float4( 0, 0, 1, 0 ),
                            float4( 0, 0, 0, 1 ) );
    }
    else {
        float3      a   = normalize( vAxis );
        float3      sq  = a * a;
        float       s, c;

        sincos( fAngle, s, c );

        float4x4    r;
        r._11_21_31_41  = float4( sq.x + (sq.y + sq.z) * c,     a.x * a.y * (1-c) - a.z * s,    a.x * a.z * (1-c) + a.y * s,    0.0 );
        r._12_22_32_42  = float4( a.x * a.y * (1-c) + a.z * s,  sq.y + (sq.x + sq.z) * c,       a.y * a.z * (1-c) - a.x * s,    0.0 );
        r._13_23_33_43  = float4( a.x * a.z * (1-c) - a.y * s,  a.y * a.z * (1-c) + a.x * s,    sq.z + (sq.x + sq.y) * c,       0.0 );
        r._14_24_34_44  = float4( 0.0.xxx, 1.0 );
        return r;
    }
}
