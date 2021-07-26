/////////////////////////////
//ノーマルマップ事前計算 Ver1.00
//引用元:ビームマンP
/////////////////////////////
#ifdef INVERSE_X
    #define IMAGE_DIRECTION_X -1
#else
    #define IMAGE_DIRECTION_X 1
#endif
#ifdef INVERSE_Y
    #define IMAGE_DIRECTION_Y -1
#else
    #define IMAGE_DIRECTION_Y 1
#endif

#define ShaderVer(x) x##_3_0

#ifdef USE_NORMAL_MAP
    #define USE_CALC_NORMAL
#else
    #ifdef USE_NORMAL_MAP_SKIN
        #define USE_CALC_NORMAL
    #endif
#endif
#ifdef USE_CALC_NORMAL
    // 法線マップの為、Tangent と Binormal を計算する関数
    // MMDから Tangent と Binormal の値は渡されない為、ピクセルシェーダでこれらを計算している
    // ※プログラム側で計算できるならその方が高速
    float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV) {
        float3 dp1 = ddx(View);
        float3 dp2 = ddy(View);
        float2 duv1 = ddx(UV);
        float2 duv2 = ddy(UV);
        float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
        float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
        float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
        float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);
        return float3x3(normalize(Tangent), normalize(Binormal), Normal);
    }
#endif
/////////////////////////////
/*ピクセルシェーダー内の計算
#ifdef USE_NORMAL_MAP//ノーマルマップ
    float3x3 tf = compute_tangent_frame(IN.Normal, IN.Eye, IN.Tex);
    float3x3 tfa = {
        {tf[0] * IMAGE_DIRECTION_X}, // Tangent
        {tf[1] * IMAGE_DIRECTION_Y}, // Binormal
        tf[2]}; // Normal
    IN.Normal = normalize(mul(tex2D( NormalMapSampler, IN.Tex) * 2 - 1, tfa));
#endif
*/