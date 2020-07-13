////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//粒子表示数
int count
<
   string UIName = "count";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 15000;
> = 15000;

//表示領域
float Height
<
   string UIName = "Height";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 80;

float WidthX
<
   string UIName = "WidthX";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 100;

float WidthZ
<
   string UIName = "WidthZ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = 100;


//落下速度
float Speed
<
   string UIName = "Speed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 40.0;
> = -12;

//パーティクルサイズ
float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.5;
> = 2;

//落下軌道の傾き
float SlopeLevel
<
   string UIName = "SlopeLevel";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.3;

//落下軌道のゆらぎ
float NoizeLevel
<
   string UIName = "NoizeLevel";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 2;

//テクスチャの回転速度
float RotationSpeed
<
   string UIName = "RotationSpeed";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = 3;

//遠方でフェードアウトする距離
float FadeLength
<
   string UIName = "FadeLength";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1000.0;
> = 200;





float3 ControllerPos : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "センター"; >;
float morph_spd : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "速度調節"; >;
float morph_width_x : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲X"; >;
float morph_width_z : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Z"; >;
float morph_height : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Y"; >;
float morph_width_x_down : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲X縮小"; >;
float morph_width_z_down : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Z縮小"; >;
float morph_height_down : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Y縮小"; >;
float morph_num : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "個数調節"; >;
float morph_lamp : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "点滅速度"; >;
float morph_patscale : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "ﾊﾟｰﾃｨｸﾙSi"; >;
float morph_rand : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "ゆらぎ"; >;







//パーティクルテクスチャ
texture2D Tex1 <
    string ResourceName = "particle.png";
    int MipLevels = 0;
>;

sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
    Filter = LINEAR;
};

//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//点滅用テクスチャ
texture2D Lamp <
    string ResourceName = "lamp.png";
    int MipLevels = 0;
>;

sampler LampSamp = sampler_state {
    texture = <Lamp>;
    Filter = LINEAR;
};


float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float ftime : TIME;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;



// 座法変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float  Alpha      : COLOR0;
};

//乱数取得
float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float index = Pos.z;
    Pos.z = 0;
    
    float rot_x = ftime * RotationSpeed + index * 6;
    float rot_y = ftime * RotationSpeed + index * 11;
    float rot_z = ftime * RotationSpeed + index * 33;
	static float3x3 RotationX = {
	    {1,	0,	0},
	    {0, cos(rot_x), sin(rot_x)},
	    {0, -sin(rot_x), cos(rot_x)},
	};
	static float3x3 RotationY = {
	    {cos(rot_y), 0, -sin(rot_y)},
	    {0, 1, 0},
		{sin(rot_y), 0,cos(rot_y)},
	    };
	static float3x3 RotationZ = {
	    {cos(rot_z), sin(rot_z), 0},
	    {-sin(rot_z), cos(rot_z), 0},
	    {0, 0, 1},
	};
	
    // ランダム配置
    float4 base_pos = getRandom(index);
    
    //回転・サイズ変更
    //Pos.xyz = mul( Pos.xyz, RotationX );
    //Pos.xyz = mul( Pos.xyz, RotationY );
    Pos.xyz = mul( Pos.xyz, RotationZ );
    Pos.xy *= ParticleSize + morph_patscale*5.0;
    
    
    float L = ftime * (1-morph_lamp) + (index/count)*128;
    float lamp = tex2Dlod( LampSamp,float4(frac(L),index/count,0,1));
    
    Pos.xy *= lamp;
    

    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    
    base_pos.xz -= 0.5;
    base_pos.y = frac(base_pos.y - ((Speed * (1-morph_spd)) * ftime / Height));
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    WidthX *= 1.0*(1-morph_width_x_down)+morph_width_x*10.0;
    WidthZ *= 1.0*(1-morph_width_z_down)+morph_width_z*10.0;
    Height *= 1.0*(1-morph_height_down)+morph_height*10.0;
    
    //領域変更
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    float2 vec = ControllerPos.xz*0.1;
    vec *= base_pos.y;
    base_pos.xz += vec;
    
    //ノイズ付加
    base_pos.xz += (sin(ftime * 0.2 + index) + cos(ftime * 0.5 + index) * 0.5)  * (NoizeLevel*morph_rand);
    
    Pos.xyz += base_pos;
    
    //表示上限より上のパーティクルは彼方へスッ飛ばす
    Pos.z -= (index >= count*(1-morph_num)) * 100000;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標
    Out.Tex = Tex;
   
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
    float4 color = tex2D( Tex1Samp, input.Tex );
    color.a *= input.Alpha;
    
    return color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec <string MMDPass = "object";>{
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        
      	SRCBLEND = SRCALPHA;
        DESTBLEND=ONE;
        CULLMODE = NONE;
        
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}
technique MainTec <string MMDPass = "object_ss";>{
    pass DrawObject {
        ZWRITEENABLE = false; //Zバッファを更新しない
        
      	SRCBLEND = SRCALPHA;
        DESTBLEND=ONE;
        CULLMODE = NONE;
        
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}
// Z値プロット用テクニック
technique ZplotTec <string MMDPass = "zplot";> {

}

