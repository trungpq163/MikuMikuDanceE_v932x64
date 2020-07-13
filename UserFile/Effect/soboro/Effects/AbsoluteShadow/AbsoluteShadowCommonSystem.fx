

#define ABSOLUTE_SHADOW



//独自セルフシャドウZバッファのサイズ
#define SHADOWBUFSIZE   2048

//ミップマップ使用可能か
#define MIPMAP_ENABLE  1




float4 VecToQuaternion(float3 vec1, float3 vec2){
    float4 val;
    
    float3 axis = normalize(cross(vec1, vec2));
    float rad = acos(dot(vec1, vec2));
    
    val.w = cos(rad / 2);
    
    val.x = axis.x * sin(rad / 2);
    val.y = axis.y * sin(rad / 2);
    val.z = axis.z * sin(rad / 2);
    
    return val;
}

float4x4 QuaternionToMatrix(float4 qt){
    float4x4 val = {
        {1-2*qt.y*qt.y-2*qt.z*qt.z, 2*qt.x*qt.y+2*qt.w*qt.z,   2*qt.x+qt.z-2*qt.w*qt.y  , 0},
        {2*qt.x*qt.y-2*qt.w*qt.z,   1-2*qt.x*qt.x-2*qt.z*qt.z, 2*qt.y+qt.z+2*qt.w*qt.x  , 0},
        {2*qt.x*qt.z+2*qt.w*qt.y,   2*qt.y*qt.z-2*qt.w*qt.x,   1-2*qt.x*qt.x-2*qt.y*qt.y, 0},
        {0,0,0,1}
    };
    
    return val;
}

float4x4 VecToMatrix(float3 vec1, float3 vec2){
    
    float3 axis = normalize(cross(vec1, vec2));
    
    float nx = axis.x;
    float ny = axis.y;
    float nz = axis.z;
    
    float c = dot(vec1, vec2);
    float rad = acos(c);
    float nc = 1 - c;
    float s = sin(rad);
    
    float4x4 val = {
        {nx*nx*nc+c,    nx*ny*nc-nz*s, nz*nx*nc+ny*s, 0},
        {nx*ny*nc+nz*s, ny*ny*nc+c,    ny*nz*nc-nx*s, 0},
        {nz*nx*nc-ny*s, ny*nz*nc+nx*s, nz*nz*nc+c,    0},
        {0,0,0,1}
    };
    
    float4x4 val2 = {
        {1,0,0,0},
        {0,1,0,0},
        {0,0,1,0},
        {0,0,0,1}
    };
    
    //val = (abs(abs(c) - 1) > 0.001) ? val : val2;
    
    return val;
    
    //return QuaternionToMatrix(VecToQuaternion(vec1, vec2));
}



float3   LightDirVec    : DIRECTION < string Object = "Light"; >;
float4x4 WorldMatrixX : WORLD;

float size1 : CONTROLOBJECT < string name = "AbsoluteShadow.x"; string item = "Si"; >;
static float size = size1 * 15;
float3 move1 : CONTROLOBJECT < string name = "AbsoluteShadow.x"; >;

static float4x4 LightWorldMatrix = {
    {1/size, 0, 0, 0},
    {0, 1/size, 0, 0},
    {0, 0, 1/size, 0},
    {-move1.x/size, -move1.y/size, -move1.z/size, 1}
};

static float4x4 LightViewMatrix = VecToMatrix(float3(0,0,1), normalize(LightDirVec));

static float ZFar = size1 * 30;

static float4x4 LightProjMatrix = {
    {1, 0, 0, 0},
    {0, 1, 0, 0},
    {0, 0, 1/ZFar, 0},
    {0, 0, 0.5, 1}
};

static float4x4 LightWorldViewProjMatrix = mul(WorldMatrixX, mul(mul(LightWorldMatrix, LightViewMatrix), LightProjMatrix));



float ShadowRate : CONTROLOBJECT < string name = "AbsoluteShadow.x"; string item = "Tr"; >;

static const float sampstep = 1.0 / SHADOWBUFSIZE;

