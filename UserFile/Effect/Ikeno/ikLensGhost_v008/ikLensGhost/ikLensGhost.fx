//--------------------------------------------------------------//
// ikLensGhost
//--------------------------------------------------------------//

const bool UseCustomLightColor <
   string UIName = "UseCustomLightColor";
   string UIWidget = "Numeric";
   string UIHelp = "独自のライト色を使用するか";
   bool UIVisible =  true;
> = false;

const float3 CustomLightColor <
   string UIName = "CustomLightColor";
   string UIWidget = "Color";
   string UIHelp = "ライト色";
   bool UIVisible =  true;
> = float3( 154.0/255.0, 154.0/255.0, 154.0/255.0);

const float FlareIntensity
<
   string UIName = "FlareIntensity";
   string UIWidget = "Slider";
   string UIHelp = "ライトの強度";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.0;
> = float( 1.0 );
const float GhostIntensity
<
   string UIName = "GhostIntensity";
   string UIWidget = "Slider";
   string UIHelp = "ゴーストの強度";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.0;
> = float( 0.5 );
const float DirtIntensity
<
   string UIName = "DirtIntensity";
   string UIWidget = "Slider";
   string UIHelp = "レンズダートの強度";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.0;
> = float( 1.0 );

// +だと赤っぽく、-だと青っぽくなる
const float ColorShiftRate
<
   string UIName = "ColorShiftRate";
   string UIWidget = "Slider";
   string UIHelp = "色ズレする度合い";
   bool UIVisible =  true;
   float UIMin = -0.2;
   float UIMax = 0.2;
> = float( 0.2 );

const float ColorEmphasizeRate
<
   string UIName = "ColorEmphasizeRate";
   string UIWidget = "Slider";
   string UIHelp = "色ズレのコントラストを強調する度合い";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.5 );

const float GhostBrightness <
   string UIName = "GhostBrightness";
   string UIWidget = "Numeric";
   string UIHelp = "ゴーストの明るさ";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.75 );

const float GhostBulriness <
   string UIName = "GhostBlurriness";
   string UIWidget = "Numeric";
   string UIHelp = "ゴーストのボケ度合";
   bool UIVisible =  true;
   float UIMin = 1.0;
   float UIMax = 4.0;
> = float( 2.0 );

const float GhostDistortion <
   string UIName = "GhostDistortion";
   string UIWidget = "Numeric";
   string UIHelp = "ゴーストの歪み度合";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.75 );

// レンズフレアの一部を小さくする
// 全体のサイズはSiで調整
#define		MiniSizeFlare		0

// ライト部分に出るゴースト
#define		FlareMainTexName	"LensFlareMain.png"
// ライトの周囲に出るゴースト
#define		FlareSubTexName		"LensFlareSub.png"

// カメラ表面の汚れ
// 使用しない場合は、#defineの前に//をつける。
#define		DirtTexName			"LensDirt.png"


// ライト方向を基準にレンズフレアを出す
// 0の場合、アクセサリの位置を基準にレンズフレアを出す
#define USE_LIGHT_POSITION		0


//--------------------------------------------------------------//

#include "lensGhost_common.fxsub"

//--------------------------------------------------------------//
