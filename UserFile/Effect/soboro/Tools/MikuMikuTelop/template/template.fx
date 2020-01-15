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


<<Texture>>
texture2D tex_text{0} < 
    string ResourceName = "{1}";
    int MipLevels = 0;
>;
sampler samp_text{0} = sampler_state {{ 
    texture = <tex_text{0}>; 
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
}};
sampler samp_at_text{0} = sampler_state {{ 
    texture = <tex_text{0}>; 
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
}};
<<TextureEnd>>

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


<<Technique>>
technique Align<<Align>> < string MMDPass = "object"; string Subset = "<<Align>>"; > {
    <<Pass>>
    pass Text{0} {{ 
        ZEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(false, float3({2}, {3}, {4}), {5}, {6}, {7}, {8}, {9}, false);
        PixelShader  = compile ps_2_0 PS_Text(samp_text{0}, {10});
    }}
    <<PassEnd>>
}

technique Align<<Align>>SS < string MMDPass = "object_ss"; string Subset = "<<Align>>"; > {
    <<PassSS>>
    pass Text{0} {{
        ZWriteEnable = false;
        CullMode = None;
        VertexShader = compile vs_2_0 VS_Text(true, float3({2}, {3}, {4}), {5}, {6}, {7}, {8}, {9}, {11});
        PixelShader  = compile ps_2_0 PS_Text(samp_at_text{0}, {10});
    }}
    <<PassSSEnd>>
}
<<TechniqueEnd>>

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

