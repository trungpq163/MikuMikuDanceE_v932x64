////////////////////////////////////////////////////////////////////////////////////////////////
// 編集禁止

#define ALIGN_LEFT_TOP      "0"
#define ALIGN_LEFT_CENTER   "1"
#define ALIGN_LEFT_BOTTOM   "2"
#define ALIGN_CENTER_TOP    "3"
#define ALIGN_CENTER_CENTER "4"
#define ALIGN_CENTER_BOTTOM "5"
#define ALIGN_RIGHT_TOP     "6"
#define ALIGN_RIGHT_CENTER  "7"
#define ALIGN_RIGHT_BOTTOM  "8"

// アルファ
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 WorldViewMatrixInverse        : WORLDVIEWINVERSE;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float screen_aspect = ViewportSize.x / ViewportSize.y;

float ftime : TIME <bool SyncInEditMode = true;>;


//フレーム時間とシステム時間が一致したら再生中とみなす
float elapsed_time1 : ELAPSEDTIME<bool SyncInEditMode=true;>;
float elapsed_time2 : ELAPSEDTIME<bool SyncInEditMode=false;>;
static bool IsPlaying = (abs(elapsed_time1 - elapsed_time2) < 0.01);


bool flag1 : CONTROLOBJECT < string name = "PostTelop.x"; >;
bool flag2 : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
static bool hide_by_post = flag1 && !flag2;



texture2D tex_text0 < 
    string ResourceName = "0.png";
    int MipLevels = 0;
>;
sampler samp_text0 = sampler_state { 
    texture = <tex_text0>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text0 = sampler_state { 
    texture = <tex_text0>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text1 < 
    string ResourceName = "1.png";
    int MipLevels = 0;
>;
sampler samp_text1 = sampler_state { 
    texture = <tex_text1>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text1 = sampler_state { 
    texture = <tex_text1>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text2 < 
    string ResourceName = "2.png";
    int MipLevels = 0;
>;
sampler samp_text2 = sampler_state { 
    texture = <tex_text2>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text2 = sampler_state { 
    texture = <tex_text2>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text3 < 
    string ResourceName = "3.png";
    int MipLevels = 0;
>;
sampler samp_text3 = sampler_state { 
    texture = <tex_text3>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text3 = sampler_state { 
    texture = <tex_text3>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text4 < 
    string ResourceName = "4.png";
    int MipLevels = 0;
>;
sampler samp_text4 = sampler_state { 
    texture = <tex_text4>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text4 = sampler_state { 
    texture = <tex_text4>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text5 < 
    string ResourceName = "5.png";
    int MipLevels = 0;
>;
sampler samp_text5 = sampler_state { 
    texture = <tex_text5>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text5 = sampler_state { 
    texture = <tex_text5>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text6 < 
    string ResourceName = "6.png";
    int MipLevels = 0;
>;
sampler samp_text6 = sampler_state { 
    texture = <tex_text6>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text6 = sampler_state { 
    texture = <tex_text6>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text7 < 
    string ResourceName = "7.png";
    int MipLevels = 0;
>;
sampler samp_text7 = sampler_state { 
    texture = <tex_text7>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text7 = sampler_state { 
    texture = <tex_text7>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text8 < 
    string ResourceName = "8.png";
    int MipLevels = 0;
>;
sampler samp_text8 = sampler_state { 
    texture = <tex_text8>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text8 = sampler_state { 
    texture = <tex_text8>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text9 < 
    string ResourceName = "9.png";
    int MipLevels = 0;
>;
sampler samp_text9 = sampler_state { 
    texture = <tex_text9>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text9 = sampler_state { 
    texture = <tex_text9>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text10 < 
    string ResourceName = "10.png";
    int MipLevels = 0;
>;
sampler samp_text10 = sampler_state { 
    texture = <tex_text10>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text10 = sampler_state { 
    texture = <tex_text10>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text11 < 
    string ResourceName = "11.png";
    int MipLevels = 0;
>;
sampler samp_text11 = sampler_state { 
    texture = <tex_text11>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text11 = sampler_state { 
    texture = <tex_text11>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text12 < 
    string ResourceName = "12.png";
    int MipLevels = 0;
>;
sampler samp_text12 = sampler_state { 
    texture = <tex_text12>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text12 = sampler_state { 
    texture = <tex_text12>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text13 < 
    string ResourceName = "13.png";
    int MipLevels = 0;
>;
sampler samp_text13 = sampler_state { 
    texture = <tex_text13>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text13 = sampler_state { 
    texture = <tex_text13>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text14 < 
    string ResourceName = "14.png";
    int MipLevels = 0;
>;
sampler samp_text14 = sampler_state { 
    texture = <tex_text14>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text14 = sampler_state { 
    texture = <tex_text14>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text15 < 
    string ResourceName = "15.png";
    int MipLevels = 0;
>;
sampler samp_text15 = sampler_state { 
    texture = <tex_text15>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text15 = sampler_state { 
    texture = <tex_text15>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text16 < 
    string ResourceName = "16.png";
    int MipLevels = 0;
>;
sampler samp_text16 = sampler_state { 
    texture = <tex_text16>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text16 = sampler_state { 
    texture = <tex_text16>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text17 < 
    string ResourceName = "17.png";
    int MipLevels = 0;
>;
sampler samp_text17 = sampler_state { 
    texture = <tex_text17>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text17 = sampler_state { 
    texture = <tex_text17>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text18 < 
    string ResourceName = "18.png";
    int MipLevels = 0;
>;
sampler samp_text18 = sampler_state { 
    texture = <tex_text18>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text18 = sampler_state { 
    texture = <tex_text18>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text19 < 
    string ResourceName = "19.png";
    int MipLevels = 0;
>;
sampler samp_text19 = sampler_state { 
    texture = <tex_text19>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text19 = sampler_state { 
    texture = <tex_text19>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text20 < 
    string ResourceName = "20.png";
    int MipLevels = 0;
>;
sampler samp_text20 = sampler_state { 
    texture = <tex_text20>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text20 = sampler_state { 
    texture = <tex_text20>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text21 < 
    string ResourceName = "21.png";
    int MipLevels = 0;
>;
sampler samp_text21 = sampler_state { 
    texture = <tex_text21>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text21 = sampler_state { 
    texture = <tex_text21>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text22 < 
    string ResourceName = "22.png";
    int MipLevels = 0;
>;
sampler samp_text22 = sampler_state { 
    texture = <tex_text22>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text22 = sampler_state { 
    texture = <tex_text22>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text23 < 
    string ResourceName = "23.png";
    int MipLevels = 0;
>;
sampler samp_text23 = sampler_state { 
    texture = <tex_text23>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text23 = sampler_state { 
    texture = <tex_text23>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text24 < 
    string ResourceName = "24.png";
    int MipLevels = 0;
>;
sampler samp_text24 = sampler_state { 
    texture = <tex_text24>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text24 = sampler_state { 
    texture = <tex_text24>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text25 < 
    string ResourceName = "25.png";
    int MipLevels = 0;
>;
sampler samp_text25 = sampler_state { 
    texture = <tex_text25>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text25 = sampler_state { 
    texture = <tex_text25>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text26 < 
    string ResourceName = "26.png";
    int MipLevels = 0;
>;
sampler samp_text26 = sampler_state { 
    texture = <tex_text26>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text26 = sampler_state { 
    texture = <tex_text26>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text27 < 
    string ResourceName = "27.png";
    int MipLevels = 0;
>;
sampler samp_text27 = sampler_state { 
    texture = <tex_text27>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text27 = sampler_state { 
    texture = <tex_text27>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text28 < 
    string ResourceName = "28.png";
    int MipLevels = 0;
>;
sampler samp_text28 = sampler_state { 
    texture = <tex_text28>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text28 = sampler_state { 
    texture = <tex_text28>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text29 < 
    string ResourceName = "29.png";
    int MipLevels = 0;
>;
sampler samp_text29 = sampler_state { 
    texture = <tex_text29>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text29 = sampler_state { 
    texture = <tex_text29>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D tex_text30 < 
    string ResourceName = "30.png";
    int MipLevels = 0;
>;
sampler samp_text30 = sampler_state { 
    texture = <tex_text30>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler samp_at_text30 = sampler_state { 
    texture = <tex_text30>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Tex        : TEXCOORD0;
    float4 Color      : COLOR0;
};

// 頂点シェーダ
VS_OUTPUT VS_Text(float4 Pos : POSITION, float4 Tex : TEXCOORD0, 
    uniform bool PanelMode, uniform float3 ViewPos, uniform float size, uniform float aspect, 
    uniform float starttime, uniform float endtime, uniform float fade, uniform bool billboard)
{
    VS_OUTPUT Out;
    
    Out.Pos = Pos;
    Out.Pos.x *= size * aspect / screen_aspect;
    Out.Pos.y *= size;
    Out.Pos.zw = float2(0, 1);
    
    if(PanelMode) Out.Pos.x *= screen_aspect;
    if(billboard) Out.Pos.xyz = mul( Out.Pos.xyz, BillboardMatrix );
    
    Out.Pos.xyz += ViewPos;
    
    if(PanelMode) Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
    
    bool visivle = (starttime <= ftime && ftime < endtime) && !hide_by_post;
    Out.Pos.y += !visivle * 1000;
    
    float alpha = saturate(min(((ftime - starttime) / fade), ((endtime - ftime) / fade)));
    alpha = (fade == 0) ? 1 : alpha;
    
    Out.Tex = Tex;
    Out.Color = float4(1,1,1,alpha);
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Text( VS_OUTPUT IN, uniform sampler samp_text , uniform float malpha) : COLOR0
{
    float4 color;
    color = tex2D(samp_text, IN.Tex);
    color *= IN.Color * alpha1 * malpha;
    return color;
}


///////////////////////////////////////////////////////////////////////////////////////////////



technique Align0 < string MMDPass = "object"; string Subset = "0"; > {
    
}

technique Align0SS < string MMDPass = "object_ss"; string Subset = "0"; > {
    
}

technique Align1 < string MMDPass = "object"; string Subset = "1"; > {
    
}

technique Align1SS < string MMDPass = "object_ss"; string Subset = "1"; > {
    
}

technique Align2 < string MMDPass = "object"; string Subset = "2"; > {
    
    pass Text0 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.978903, 3.333333, 13.33333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text0, 1);
    }
    
    pass Text1 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 3.898734, 13.33333, 23.33333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text1, 1);
    }
    
    pass Text2 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.49697, 26.66667, 37.2, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text2, 1);
    }
    
    pass Text3 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 4.898734, 37.23333, 43.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text3, 1);
    }
    
    pass Text4 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 7.350211, 43.13334, 48.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text4, 1);
    }
    
    pass Text5 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 3.379798, 49.4, 59.6, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text5, 1);
    }
    
    pass Text6 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.978903, 59.63334, 65.46667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text6, 1);
    }
    
    pass Text7 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 7.962025, 65.5, 70.7, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text7, 1);
    }
    
    pass Text8 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 1.39798, 70.96667, 76.23333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text8, 1);
    }
    
    pass Text9 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.692929, 76.26667, 82.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text9, 1);
    }
    
    pass Text10 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.759494, 82.13333, 87.7, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text10, 1);
    }
    
    pass Text11 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 6.35443, 87.76667, 93, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text11, 1);
    }
    
    pass Text12 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 6.451477, 93.1, 98.63333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text12, 1);
    }
    
    pass Text13 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 6.156118, 98.66666, 104.1667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text13, 1);
    }
    
    pass Text14 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 6.156118, 104.2, 109.9, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text14, 1);
    }
    
    pass Text15 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 1.987879, 109.9333, 116.1333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text15, 1);
    }
    
    pass Text16 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.232323, 138.7667, 149, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text16, 1);
    }
    
    pass Text17 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.523232, 149.0333, 154.3667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text17, 1);
    }
    
    pass Text18 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.130802, 154.4, 160.1333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text18, 1);
    }
    
    pass Text19 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.577778, 160.3, 165.5667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text19, 1);
    }
    
    pass Text20 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 3.719192, 165.6, 171.3, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text20, 1);
    }
    
    pass Text21 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 3.577778, 171.3333, 176.8667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text21, 1);
    }
    
    pass Text22 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 7.341772, 176.9, 182.2667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text22, 1);
    }
    
    pass Text23 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.506329, 182.3, 187.8333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text23, 1);
    }
    
    pass Text24 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 8.843882, 187.8667, 193.3667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text24, 1);
    }
    
    pass Text25 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.026263, 193.4, 199.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text25, 1);
    }
    
    pass Text26 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.789899, 199.1333, 205.3333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text26, 1);
    }
    
    pass Text27 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 5.506329, 205.3667, 210.3333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text27, 1);
    }
    
    pass Text28 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.3291667, 8.843882, 210.3667, 215.8667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text28, 1);
    }
    
    pass Text29 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 1.949495, 215.9, 221.5, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text29, 1);
    }
    
    pass Text30 { 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3(-0.99, -0.962, 0), 0.6875, 2.789899, 221.5333, 228.7667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text30, 1);
    }
    
}

technique Align2SS < string MMDPass = "object_ss"; string Subset = "2"; > {
    
    pass Text0 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.978903, 3.333333, 13.33333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text0, 1);
    }
    
    pass Text1 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 3.898734, 13.33333, 23.33333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text1, 1);
    }
    
    pass Text2 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.49697, 26.66667, 37.2, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text2, 1);
    }
    
    pass Text3 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 4.898734, 37.23333, 43.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text3, 1);
    }
    
    pass Text4 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 7.350211, 43.13334, 48.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text4, 1);
    }
    
    pass Text5 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 3.379798, 49.4, 59.6, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text5, 1);
    }
    
    pass Text6 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.978903, 59.63334, 65.46667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text6, 1);
    }
    
    pass Text7 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 7.962025, 65.5, 70.7, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text7, 1);
    }
    
    pass Text8 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 1.39798, 70.96667, 76.23333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text8, 1);
    }
    
    pass Text9 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.692929, 76.26667, 82.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text9, 1);
    }
    
    pass Text10 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.759494, 82.13333, 87.7, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text10, 1);
    }
    
    pass Text11 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 6.35443, 87.76667, 93, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text11, 1);
    }
    
    pass Text12 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 6.451477, 93.1, 98.63333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text12, 1);
    }
    
    pass Text13 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 6.156118, 98.66666, 104.1667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text13, 1);
    }
    
    pass Text14 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 6.156118, 104.2, 109.9, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text14, 1);
    }
    
    pass Text15 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 1.987879, 109.9333, 116.1333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text15, 1);
    }
    
    pass Text16 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.232323, 138.7667, 149, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text16, 1);
    }
    
    pass Text17 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.523232, 149.0333, 154.3667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text17, 1);
    }
    
    pass Text18 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.130802, 154.4, 160.1333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text18, 1);
    }
    
    pass Text19 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.577778, 160.3, 165.5667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text19, 1);
    }
    
    pass Text20 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 3.719192, 165.6, 171.3, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text20, 1);
    }
    
    pass Text21 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 3.577778, 171.3333, 176.8667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text21, 1);
    }
    
    pass Text22 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 7.341772, 176.9, 182.2667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text22, 1);
    }
    
    pass Text23 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.506329, 182.3, 187.8333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text23, 1);
    }
    
    pass Text24 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 8.843882, 187.8667, 193.3667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text24, 1);
    }
    
    pass Text25 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.026263, 193.4, 199.1, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text25, 1);
    }
    
    pass Text26 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.789899, 199.1333, 205.3333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text26, 1);
    }
    
    pass Text27 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 5.506329, 205.3667, 210.3333, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text27, 1);
    }
    
    pass Text28 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.3291667, 8.843882, 210.3667, 215.8667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text28, 1);
    }
    
    pass Text29 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 1.949495, 215.9, 221.5, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text29, 1);
    }
    
    pass Text30 {
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3(-0.99, -0.962, 0), 0.6875, 2.789899, 221.5333, 228.7667, 0.15, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text30, 1);
    }
    
}

technique Align3 < string MMDPass = "object"; string Subset = "3"; > {
    
}

technique Align3SS < string MMDPass = "object_ss"; string Subset = "3"; > {
    
}

technique Align4 < string MMDPass = "object"; string Subset = "4"; > {
    
}

technique Align4SS < string MMDPass = "object_ss"; string Subset = "4"; > {
    
}

technique Align5 < string MMDPass = "object"; string Subset = "5"; > {
    
}

technique Align5SS < string MMDPass = "object_ss"; string Subset = "5"; > {
    
}

technique Align6 < string MMDPass = "object"; string Subset = "6"; > {
    
}

technique Align6SS < string MMDPass = "object_ss"; string Subset = "6"; > {
    
}

technique Align7 < string MMDPass = "object"; string Subset = "7"; > {
    
}

technique Align7SS < string MMDPass = "object_ss"; string Subset = "7"; > {
    
}

technique Align8 < string MMDPass = "object"; string Subset = "8"; > {
    
}

technique Align8SS < string MMDPass = "object_ss"; string Subset = "8"; > {
    
}


////////////////////////////////////////////////////////////////////////////////////
// パネルモードにおける背景

// 頂点シェーダ
VS_OUTPUT VS_BackScreen(float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Out.Pos = Pos;
    Out.Pos.x *= screen_aspect;
    
    Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
    
    return Out;
}

// ピクセルシェーダ
float4 PS_BackScreen( VS_OUTPUT IN ) : COLOR0
{
    float4 color;
    color = float4(0, 0, 1, 0.07 * !IsPlaying * !hide_by_post);
    return color;
}

technique BackScreen < string MMDPass = "object"; string Subset = "9"; > { }

technique BackScreenSS < string MMDPass = "object_ss"; string Subset = "9"; > {
    
    pass BackScreenPass {
        ZWRITEENABLE = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_BackScreen();
        PixelShader  = compile ps_2_0 PS_BackScreen();
    }
    
}


//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

