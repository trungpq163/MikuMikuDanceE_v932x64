#define ALBEDO_MAP_FROM 1
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 0
#define ALBEDO_MAP_APPLY_DIFFUSE 1
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_COLOR.jpg"

const float3 albedo = 1.0;
const float2 albedoMapLoopNum = 1;

#define ALBEDO_SUB_ENABLE 0
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 0
#define ALBEDO_SUB_MAP_FILE "albedo.png"

const float3 albedoSub = 1.0;
const float2 albedoSubMapLoopNum = 1;

#define ALPHA_MAP_FROM 0
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 0
#define ALPHA_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_MASK.jpg"

const float alpha = 1.0;
const float alphaMapLoopNum = 24.09;

#define NORMAL_MAP_FROM 1
#define NORMAL_MAP_TYPE 3
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_DISP2.png"

const float normalMapScale = -1;
const float normalMapLoopNum = 1.0;

#define NORMAL_SUB_MAP_FROM 1
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_NORM.jpg"

const float normalSubMapScale = 1.0;
const float normalSubMapLoopNum = 1.0;

#define SMOOTHNESS_MAP_FROM 1
#define SMOOTHNESS_MAP_TYPE 0
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 0
#define SMOOTHNESS_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_ROUGH.jpg"

const float smoothness = 1;
const float smoothnessMapLoopNum = 1.0;

#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 0
#define METALNESS_MAP_FILE "metalness.png"

const float metalness = 0.0;
const float metalnessMapLoopNum = 1.0;

#define SPECULAR_MAP_FROM 0
#define SPECULAR_MAP_TYPE 0
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 0
#define SPECULAR_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_MASK2.jpg"

const float3 specular = 0.5;
const float2 specularMapLoopNum = 1;

#define OCCLUSION_MAP_FROM 1
#define OCCLUSION_MAP_TYPE 0
#define OCCLUSION_MAP_UV_FLIP 0
#define OCCLUSION_MAP_SWIZZLE 0
#define OCCLUSION_MAP_APPLY_SCALE 0 
#define OCCLUSION_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_OCC.jpg"

const float occlusion = 1;
const float occlusionMapLoopNum = 1;

#define PARALLAX_MAP_FROM 1
#define PARALLAX_MAP_TYPE 0
#define PARALLAX_MAP_UV_FLIP 0
#define PARALLAX_MAP_SWIZZLE 0
#define PARALLAX_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_DISP2.png"

const float parallaxMapScale = -0.6;
const float parallaxMapLoopNum = 1;

#define EMISSIVE_ENABLE 0
#define EMISSIVE_MAP_FROM 1
#define EMISSIVE_MAP_UV_FLIP 0
#define EMISSIVE_MAP_APPLY_SCALE 0
#define EMISSIVE_MAP_APPLY_MORPH_COLOR 0
#define EMISSIVE_MAP_APPLY_MORPH_INTENSITY 0
#define EMISSIVE_MAP_APPLY_BLINK 0
#define EMISSIVE_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_Light.png"

const float3 emissive = float3(83,182,255)/255;
const float3 emissiveBlink = 1;
const float  emissiveIntensity = 0.7;
const float2 emissiveMapLoopNum = 1;

#define CUSTOM_ENABLE 1

#define CUSTOM_A_MAP_FROM 1
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 1
#define CUSTOM_A_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_DISP2.png"

const float customA = 1;
const float customAMapLoopNum = 1.0;

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 0
#define CUSTOM_B_MAP_FILE "Encrusted_Gems_002_SD/Encrusted_Gems_002_DISP2.png"
#define SSS_SKIN_TRANSMITTANCE(x) exp((1 - saturate(x)) * float3(-64,-0,-3))

const float3 customB = SSS_SKIN_TRANSMITTANCE(0.9);
const float customBMapLoopNum = 1.0;

#include "material_common_2.0.fxsub"
