////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Numbers_Float2.fx ver0.0.4 数値データの表示(float2型)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float3 CameraPos : POSITION  < string Object = "Camera"; >;

// ここに表示させる数値､または変数,式を代入(正確に読めるのは全7桁程度)
static float2 Value = CameraPos.xy;

int FractCount = 3;  // 少数以下桁数

//#define PLUS  // ＋表記する場合はコメントアウトを外す


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

int Count = 2;
int ObjIndex;  // 複製モデルカウンタ

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float3 AcsPos : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;

static int iValue = round(Value[ObjIndex] * pow(10.0f, FractCount));

int TexCount = 15;  // テクスチャ文字種類数

// 画面サイズ
float2 ScreenSize : VIEWPORTPIXELSIZE;

// 数字テクスチャ
texture2D NumberTex <
    string ResourceName = "numbers.png";
>;
sampler NumberSamp = sampler_state {
    texture = <NumberTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
// 整数除算
int div(int a, int b) {
    return floor((a+0.1f)/b);
}

// 整数剰余算
int mod(int a, int b) {
    return (a - div(a,b)*b);
};

///////////////////////////////////////////////////////////////////////////////////////
// 数字テクスチャの選別

int PickupNumber(int index)
{
   int texIndex = 14;
   int absVal = abs(iValue);

   if(index == FractCount) return 10;
   if(index > FractCount) index--;

   bool endFlag = false;
   for(int i=0; i<=index; i++){
      if(absVal>0){
         texIndex = mod(absVal, 10);
         absVal =   div(absVal, 10);
      }else{
         if(endFlag){
            if(index > FractCount+1) texIndex = 14;
         }else{
            if(index > FractCount){
               #ifdef PLUS
               if(iValue > 0) texIndex = 11;
               #else
               if(iValue > 0) texIndex = 14;
               #endif
               else if(iValue < 0) texIndex = 12;
               else texIndex = 14;
               endFlag = true;
            }else{
               texIndex = 0;
            }
         }
      }
   }

   return texIndex;
}


///////////////////////////////////////////////////////////////////////////////////////
// 数字描画

struct VS_OUTPUT
{
    float4 Pos : POSITION;    // 射影変換座標
    float2 Tex : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Obj_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // ボードのインデックス
    int Index = round( Pos.z * 100.0f );

    // ボード配置
    Pos.x *= 0.5f;
    Pos.x -= 0.1f * Index;
    Pos.y -= ObjIndex * 0.2f - 0.1f;

    // 座標変換
    Pos.xy *= AcsSi * 0.07f;
    Pos.x *= ScreenSize.y/ScreenSize.x;
    Pos.xy += AcsPos.xy;
    Pos.zw = float2(0.0f, 1.0f);
    Out.Pos = Pos;

    // テクスチャ座標
    int texIndex = PickupNumber(Index);
    Tex.x = (Tex.x + (float)texIndex ) / (float)TexCount;
    Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 Obj_PS( VS_OUTPUT IN ) : COLOR0
{
   // テクスチャの色
   float4 Color = tex2D( NumberSamp, IN.Tex );
   Color.a *= AcsTr;
   return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec0 < string MMDPass = "object";
    string Script = "LoopByCount=Count;"
                       "LoopGetIndex=ObjIndex;"
                       "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
   pass DrawObject {
       ZENABLE = false;
       VertexShader = compile vs_3_0 Obj_VS();
       PixelShader  = compile ps_3_0 Obj_PS();
   }
}

// エッジ,地面影は非表示
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

