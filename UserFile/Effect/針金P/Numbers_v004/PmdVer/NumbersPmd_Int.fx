////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Numbers_Int.fx ver0.0.4 数値データの表示(int型)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float time : Time;

// ここに表示させる数値､または変数,式を代入(正確に読めるのは全7桁程度)
static int Value = floor(time);

//#define PLUS  // ＋表記する場合はコメントアウトを外す


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float PmdSi : CONTROLOBJECT < string name = "(self)"; string item = "スケール"; >;
float PmdTr : CONTROLOBJECT < string name = "(self)"; string item = "透過"; >;
float3 PmdPos : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;

int TexCount = 15;  // テクスチャ種類数

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
   int absVal = abs(Value);

   bool endFlag = false;
   for(int i=0; i<=index; i++){
      if(absVal>0){
         texIndex = mod(absVal, 10);
         absVal =   div(absVal, 10);
      }else{
         if(absVal == 0){
            if(endFlag){
               texIndex = 14;
            }else{
               #ifdef PLUS
               if(Value > 0) texIndex = 11;
               #else
               if(Value > 0) texIndex = 14;
               #endif
               else if(Value < 0) texIndex = 12;
               else texIndex = 0;
               endFlag = true;
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
VS_OUTPUT Obj_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, int index: _INDEX)
{
    VS_OUTPUT Out;

    // インデックスよりボードのローカル座標決定(pmdデータ配列に由来)
    int Index = index % 4;
    if(Index == 0){
       Pos = float4(1.0f, 1.0f, 0.0f, 1.0f);
    }else if(Index == 1){
       Pos = float4(1.0f, -1.0f, 0.0f, 1.0f);
    }else if(Index == 2){
       Pos = float4(-1.0f, -1.0f, 0.0f, 1.0f);
    }else{
       Pos = float4(-1.0f, 1.0f, 0.0f, 1.0f);
    }
    Index = index / 4;

    // ボード配置
    Pos.x *= 0.5f;
    Pos.x -= float(Index);

    // ワールド座標変換
    Pos.xy *= (1.0f - PmdSi)*0.07f;
    Pos.x *= ScreenSize.y/ScreenSize.x;
    Pos.xy += PmdPos.xy * 0.1f;
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
   Color.a *= (1.0f - PmdTr);
   return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object"; >{
   pass DrawObject {
       ZENABLE = false;
       VertexShader = compile vs_3_0 Obj_VS();
       PixelShader  = compile ps_3_0 Obj_PS();
   }
}

technique MainTec2 < string MMDPass = "object_ss"; >{
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

