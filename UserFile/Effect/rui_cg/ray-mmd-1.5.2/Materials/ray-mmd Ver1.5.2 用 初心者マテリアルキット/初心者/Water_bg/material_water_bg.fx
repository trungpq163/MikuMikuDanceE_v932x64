#define CONTROLLER_NAME "material_water_ctrl.pmx"
#include "material_water_editor.fxsub"

static const float smoothness = mWSmoothness;
static const float smoothnessBaseSpecular = mWSmoothnessBaseSpecular;

static const float3 scatteringLow = mScatteringLowColor; //exp(-mScatteringLowColor * 1.0) * 2;
static const float3 scatteringHigh = mScatteringHighColor; //exp(-mScatteringHighColor * 1.25);

#define WAVE_MAP_ENABLE 1
#define WAVE_MAP_FILE "textures/wave.png"

static const float waveHeightLow = mWaveHeightLow;
static const float waveHeightHigh  = mWaveHeightHigh;

static const float waveLoopsLow = mWaveLoopsLow;
static const float waveLoopsHigh = mWaveLoopsHigh;

static const float waveMapScaleLow = mWaveMapScaleL;

static const float2 waveMapLoopNumLow = mWaveMapLoopsL;

const float2 waveMapTranslate = float2(1, 1);

#define WAVE_NOISE_MAP_ENABLE 1
#define WAVE_NOISE_MAP_FILE "textures/noise.png"

#include "material_common.fxsub"