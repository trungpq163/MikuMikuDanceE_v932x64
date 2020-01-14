#define ALBEDO_MAP_FROM 1
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 0
#define ALBEDO_MAP_APPLY_DIFFUSE 1
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_COLOR.jpg"

const float3 albedo = 1.0;
const float2 albedoMapLoopNum = 1;

#define ALBEDO_SUB_ENABLE 0
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 0
#define ALBEDO_SUB_MAP_FILE "albedo.png"

const float3 albedoSub = 1.0;
const float2 albedoSubMapLoopNum = 1;

#define ALPHA_MAP_FROM 3
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 3
#define ALPHA_MAP_FILE "alpha.png"

const float alpha = 1.0;
const float alphaMapLoopNum = 1;

#define NORMAL_MAP_FROM 1
#define NORMAL_MAP_TYPE 1
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_NORM.jpg"

const float normalMapScale = 6;
const float normalMapLoopNum = 1.0;

#define NORMAL_SUB_MAP_FROM 0
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "Nstreet.jpg"

const float normalSubMapScale = 0.2;
const float normalSubMapLoopNum = 10;

#define SMOOTHNESS_MAP_FROM 1
#define SMOOTHNESS_MAP_TYPE 1
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 1
#define SMOOTHNESS_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_ROUGH.jpg"

const float smoothness = 0.65;
const float smoothnessMapLoopNum = 1.0;

#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 0
#define METALNESS_MAP_FILE "metalness.png"

const float metalness = 0.0;
const float metalnessMapLoopNum = 1.0;

#define SPECULAR_MAP_FROM 1
#define SPECULAR_MAP_TYPE 0
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 0
#define SPECULAR_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_ROUGH.jpg"

const float3 specular = 0.5;
const float2 specularMapLoopNum = 1;

#define OCCLUSION_MAP_FROM 1
#define OCCLUSION_MAP_TYPE 1
#define OCCLUSION_MAP_UV_FLIP 0
#define OCCLUSION_MAP_SWIZZLE 0
#define OCCLUSION_MAP_APPLY_SCALE 2 
#define OCCLUSION_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_DISP.png"

const float occlusion = 0.32;
const float occlusionMapLoopNum = 1;

#define PARALLAX_MAP_FROM 1
#define PARALLAX_MAP_TYPE 1
#define PARALLAX_MAP_UV_FLIP 0
#define PARALLAX_MAP_SWIZZLE 0
#define PARALLAX_MAP_FILE "Stone_Tiles_003_SD/Stone_Tiles_003_DISP.png"

const float parallaxMapScale = 0.1;
const float parallaxMapLoopNum = 1;

#define EMISSIVE_ENABLE 0
#define EMISSIVE_MAP_FROM 0
#define EMISSIVE_MAP_UV_FLIP 0
#define EMISSIVE_MAP_APPLY_SCALE 0
#define EMISSIVE_MAP_APPLY_MORPH_COLOR 0
#define EMISSIVE_MAP_APPLY_MORPH_INTENSITY 0
#define EMISSIVE_MAP_APPLY_BLINK 0
#define EMISSIVE_MAP_FILE "emissive.png"

const float3 emissive = 1;
const float3 emissiveBlink = 1;
const float  emissiveIntensity = 1;
const float2 emissiveMapLoopNum = 1;

#define CUSTOM_ENABLE 0

#define CUSTOM_A_MAP_FROM 0
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 0
#define CUSTOM_A_MAP_FILE "custom.png"

const float customA = 0.0;
const float customAMapLoopNum = 1.0;

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 0
#define CUSTOM_B_MAP_FILE "custom.png"

const float3 customB = 0.0;
const float2 customBMapLoopNum = 1.0;

#include "material_common_2.0.fxsub"
