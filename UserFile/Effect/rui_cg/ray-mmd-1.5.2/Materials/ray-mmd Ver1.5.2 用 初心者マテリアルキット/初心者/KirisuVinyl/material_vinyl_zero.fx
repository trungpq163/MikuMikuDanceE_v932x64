#define CONTROLLER_NAME "material_vinyl_zero.pmx"
#include "material_vinyl_editor.fxsub"


static const float transparent_factor = mTransFactor;	////透明度の係数　0～1
static const float transparent_level = mTransLevel;  //透明度をかさ上げ　0～1（通常0）
static const float transparent_reverse = mTransReverse; //法線に従って色が濃くなる範囲の指定　-1～1(通常0)　メッシュ形状に合わせて都合が良い値にする

static const float specular_boost_factor = mSpecBoost; //スペキュラをかさ上げする係数　0～1　見た目の透明度は下がる
static const float reflection_boost_factor = mRefBoost; //反射をかさ上げする係数　0～1 見た目の透明度は下がる
static const float revese_surface_factor = mRevFactor;

//独自パラメータ設定　ここから
// const float transparent_factor = 0.90;	//透明度の係数　0～1
// const float transparent_level = 0.4;  //透明度をかさ上げする係数　0～1（通常0）
// const float transparent_reverse = 0.3; //法線に従って色が濃くなる範囲の指定
// const float specular_boost_factor = 0.5; //スペキュラをかさ上げする係数　0～1　見た目の透明度は下がる
// const float reflection_boost_factor = 0.8; //反射をかさ上げする係数　0～1 見た目の透明度は下がる
// const float revese_surface_factor = 1; //裏面の影響度　0～1　横も色が濃くなります。　チラつく時は0にして切る
//ここまで

#define ALBEDO_MAP_FROM 3
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 0
#define ALBEDO_MAP_APPLY_DIFFUSE 1
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "albedo.png"

static const float3 albedo = mAlbedoColor;
static const float2 albedoMapLoopNum = mAlbedoLoops;

#define ALBEDO_SUB_ENABLE 4
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 0
#define ALBEDO_SUB_MAP_FILE "albedo.png"

static const float3 albedoSub = mMelanin;
static const float2 albedoSubMapLoopNum = mMelaninLoops;

#define ALPHA_MAP_FROM 0
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 3
#define ALPHA_MAP_FILE "alpha.png"

static const float alpha = 0.1;
const float alphaMapLoopNum = 1.0;

#define NORMAL_MAP_FROM 0
#define NORMAL_MAP_TYPE 0
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "normal.png"

static const float normalMapScale = mNormalScale;
static const float normalMapLoopNum = mNormalLoops;

#define NORMAL_SUB_MAP_FROM 4
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "normal.png"

static const float normalSubMapScale = -1 * (mNormalSubScale - 1) - 1.3;
static const float normalSubMapLoopNum = mNormalSubLoops;

#define SMOOTHNESS_MAP_FROM 0
#define SMOOTHNESS_MAP_TYPE 0
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 0
#define SMOOTHNESS_MAP_FILE "smoothness.png"

static const float smoothness = mSmoothness + 0.6; 
static const float smoothnessMapLoopNum = mSmoothnessLoops;

#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 0
#define METALNESS_MAP_FILE "metalness.png"

static const float metalness = mMetalness;
static const float metalnessMapLoopNum = mMetalnessLoops;

#define SPECULAR_MAP_FROM 0
#define SPECULAR_MAP_TYPE 0
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 0
#define SPECULAR_MAP_FILE "specular.png"

static const float3 specular = mSpecularColor;
static const float2 specularMapLoopNum = 1.0;

#define OCCLUSION_MAP_FROM 0
#define OCCLUSION_MAP_TYPE 0
#define OCCLUSION_MAP_UV_FLIP 0
#define OCCLUSION_MAP_SWIZZLE 0
#define OCCLUSION_MAP_APPLY_SCALE 0 
#define OCCLUSION_MAP_FILE "occlusion.png"

const float occlusion = 1.0;
const float occlusionMapLoopNum = 1.0;

#define PARALLAX_MAP_FROM 0
#define PARALLAX_MAP_TYPE 0
#define PARALLAX_MAP_UV_FLIP 0
#define PARALLAX_MAP_SWIZZLE 0
#define PARALLAX_MAP_FILE "height.png"

const float parallaxMapScale = 1.0;
const float parallaxMapLoopNum = 1.0;

#define EMISSIVE_ENABLE 1
#define EMISSIVE_MAP_FROM 0
#define EMISSIVE_MAP_UV_FLIP 0
#define EMISSIVE_MAP_APPLY_SCALE 0
#define EMISSIVE_MAP_APPLY_MORPH_COLOR 0
#define EMISSIVE_MAP_APPLY_MORPH_INTENSITY 0
#define EMISSIVE_MAP_APPLY_BLINK 0
#define EMISSIVE_MAP_FILE "emissive.png"

static const float3 emissive = mEmissiveColor;
static const float emissiveBlink = mEmissiveBlink; 
static const float emissiveIntensity = mEmissiveIntensity;
static const float emissiveMapLoopNum = mEmissiveLoops;

#define CUSTOM_ENABLE 4

#define CUSTOM_A_MAP_FROM 0
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 0
#define CUSTOM_A_MAP_FILE "custom.png"

static const float customA = 0.1 + mCustomA;
static const float customAMapLoopNum = mCustomALoops;

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 0
#define CUSTOM_B_MAP_FILE "custom.png"

static const float3 customB = mCustomBColor;
static const float2 customBMapLoopNum = mCustomBLoops;

#include "material_vinyl.fxsub"