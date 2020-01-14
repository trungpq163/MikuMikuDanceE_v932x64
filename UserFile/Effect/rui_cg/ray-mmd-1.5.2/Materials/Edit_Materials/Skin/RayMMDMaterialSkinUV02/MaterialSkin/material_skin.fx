#define CONTROLLER_NAME "material_skin.pmx"
#include "material_editor_mod.fxsub"

#define ALBEDO_MAP_FROM 3
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 1
#define ALBEDO_MAP_APPLY_DIFFUSE 1
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "albedo.png"

static const float3 albedo = mAlbedoColor;
static const float2 albedoMapLoopNum = mAlbedoLoops;
static const float2 albedoMapUvOffset = float2(mAlbedoUvX,mAlbedoUvY);

#define ALBEDO_SUB_ENABLE 4
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 1
#define ALBEDO_SUB_MAP_FILE "albedo.png"

static const float3 albedoSub = mMelanin;
static const float2 albedoSubMapLoopNum = mMelaninLoops;
static const float2 albedoSubMapUvOffset = float2(mMelaninUvX,mMelaninUvY);


#define ALPHA_MAP_FROM 3
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 3
#define ALPHA_MAP_FILE "alpha.png"

const float alpha = 1.0;
const float alphaMapLoopNum = 1.0;

#define NORMAL_MAP_FROM 0
#define NORMAL_MAP_TYPE 0
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "normal.png"

static const float normalMapScale = mNormalScale;
static const float normalMapLoopNum = mNormalLoops;
static const float2 normalMapUvOffset = float2(mNormalUvX,mNormalUvY);

#define NORMAL_SUB_MAP_FROM 0
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "normal.png"

static const float normalSubMapScale = mNormalSubScale;
static const float normalSubMapLoopNum = mNormalSubLoops;
static const float2 normalSubMapUvOffset = float2(mNormalSubUvX,mNormalSubUvY);

#define SMOOTHNESS_MAP_FROM 0
#define SMOOTHNESS_MAP_TYPE 0
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 1
#define SMOOTHNESS_MAP_FILE "smoothness.png"

static const float smoothness = mSmoothness;
static const float smoothnessMapLoopNum = mSmoothnessLoops;
static const float2 smoothnessMapUvOffset = float2(mSmoothnessUvX,mSmoothnessUvY);


#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 1
#define METALNESS_MAP_FILE "metalness.png"

static const float metalness = mMetalness;
static const float metalnessMapLoopNum = mMetalnessLoops;
static const float2 metalnessMapUvOffset = float2(mMetalnessUvX,mMetalnessUvY);

#define SPECULAR_MAP_FROM 0
#define SPECULAR_MAP_TYPE 2
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 1
#define SPECULAR_MAP_FILE "specular.png"

static const float3 specular = mSpecularColor;
static const float2 specularMapLoopNum = mSpecularLoops;
static const float2 specularMapUvOffset = float2(mSpecularUvX,mSpecularUvY);


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

#define EMISSIVE_ENABLE 0
#define EMISSIVE_MAP_FROM 0
#define EMISSIVE_MAP_UV_FLIP 0
#define EMISSIVE_MAP_APPLY_SCALE 1
#define EMISSIVE_MAP_APPLY_MORPH_COLOR 0
#define EMISSIVE_MAP_APPLY_MORPH_INTENSITY 0
#define EMISSIVE_MAP_APPLY_BLINK 0
#define EMISSIVE_MAP_FILE "emissive.png"

static const float3 emissive = mEmissiveColor;
static const float emissiveBlink = mEmissiveBlink; 
static const float emissiveIntensity = mEmissiveIntensity;
static const float emissiveMapLoopNum = mEmissiveLoops;
static const float2 emissiveMapUvOffset = float2(mEmissiveUvX,mEmissiveUvY);


#define CUSTOM_ENABLE 1

#define CUSTOM_A_MAP_FROM 0
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 1
#define CUSTOM_A_MAP_FILE "customA.png"

static const float customA = mCustomA;
static const float customAMapLoopNum = mCustomALoops;
static const float2 customAMapUvOffset = float2(mCustomAUvX,mCustomAUvY);

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 1
#define CUSTOM_B_MAP_FILE "customB.png"

static const float3 customB = mCustomBColor;
static const float2 customBMapLoopNum = mCustomBLoops;
static const float2 customBMapUvOffset = float2(mCustomBUvX,mCustomBUvY);

#include "material_for_skin.fxsub"