#define CONTROLLER_NAME "material_skin_bg.pmx"
#include "../Editor/Skin/material_editor.fxsub"

#define ALBEDO_MAP_FROM 3
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 1
#define ALBEDO_MAP_APPLY_DIFFUSE 1
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "albedo.png"

static const float3 albedo = mAlbedoColor +  float3(0.2,0,0);
static const float2 albedoMapLoopNum = mAlbedoLoops;

#define ALBEDO_SUB_ENABLE 4
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 0
#define ALBEDO_SUB_MAP_FILE "albedo.png"

static const float3 albedoSub = mMelanin * 2;
static const float2 albedoSubMapLoopNum = mMelaninLoops;

#define ALPHA_MAP_FROM 3
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 3
#define ALPHA_MAP_FILE "alpha.png"

const float alpha = 1.0;
const float alphaMapLoopNum = 1.0;

#define NORMAL_MAP_FROM 1
#define NORMAL_MAP_TYPE 0
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "../_MaterialMap/skin.png"

static const float normalMapScale = 0.08 + (mNormalScale - 1) / 5;;
static const float normalMapLoopNum = 40 + 10 * mNormalLoops;

#define NORMAL_SUB_MAP_FROM 4
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "../_MaterialMap/skin.png"

static const float normalSubMapScale = -2 * (mNormalSubScale - 1);
static const float normalSubMapLoopNum = mNormalSubLoops;

#define SMOOTHNESS_MAP_FROM 0
#define SMOOTHNESS_MAP_TYPE 0
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 0
#define SMOOTHNESS_MAP_FILE "smoothness.png"

static const float smoothness = mSmoothness;
static const float smoothnessMapLoopNum = mSmoothnessLoops;

#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 0
#define METALNESS_MAP_FILE "metalness.png"

static const float metalness = mMetalness * 2.0;
static const float metalnessMapLoopNum = mMetalnessLoops;

#define SPECULAR_MAP_FROM 0
#define SPECULAR_MAP_TYPE 0
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 0
#define SPECULAR_MAP_FILE "specular.png"

static const float3 specular = mSpecularColor;
static const float2 specularMapLoopNum = mSpecularLoops;

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

static const float3 emissive = mEmissiveColor +  float3(0.18,0,0);
static const float emissiveBlink = mEmissiveBlink; 
static const float emissiveIntensity = mEmissiveIntensity;
static const float emissiveMapLoopNum = mEmissiveLoops;

#define CUSTOM_ENABLE 1

#define CUSTOM_A_MAP_FROM 0
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 0
#define CUSTOM_A_MAP_FILE "custom.png"

static const float customA = 0.2 + mCustomA * 2;
static const float customAMapLoopNum = mCustomALoops;

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 0
#define CUSTOM_B_MAP_FILE "custom.png"

static const float3 customB = mCustomBColor +  float3(0.5,1,0);
static const float2 customBMapLoopNum = mCustomBLoops;

#include "../material_common_2.0.fxsub"