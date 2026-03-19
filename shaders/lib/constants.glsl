// ===================================================================
// Echelon Nexus Shader Pack - Global Constants & Buffer Semantics
// ===================================================================

#ifndef INCLUDE_CONSTANTS
#define INCLUDE_CONSTANTS

// ===================================================================
// COMPILE-TIME CONFIGURATION
// ===================================================================

// Feature detection flags (set via shaders.properties)
// These allow graceful fallback when features are unsupported

#ifndef FEATURE_COMPUTE_SHADERS
#define FEATURE_COMPUTE_SHADERS 0
#endif

#ifndef FEATURE_SSBO
#define FEATURE_SSBO 0
#endif

#ifndef FEATURE_TESSELLATION
#define FEATURE_TESSELLATION 0
#endif

#ifndef FEATURE_INDIRECT_DISPATCH
#define FEATURE_INDIRECT_DISPATCH 0
#endif

// ===================================================================
// BUFFER OWNERSHIP & SEMANTICS
// ===================================================================

// ColorTex Buffer Allocation (16 buffers total; colortex0-15)
//
// Buffer   Name              Format   Resolution   Usage
// -------  ----------------  -------  -----------  -----------------------------------------------
// 0        colortex0         RGBA8    Screen       Lit scene color / final composite output
// 1        colortex1         RGBA16F  Screen       Material params (R=rough, G=metallic, B=emiss, A=?)
// 2        colortex2         RGBA16F  Screen       Normal (RGB) + depth encoding (A)
// 3        colortex3         RGBA8    Screen       History buffer for TAA / temporal effects
// 4        colortex4         RGBA16F  Screen       SSR intermediate / reflection data
// 5        colortex5         RGBA16F  Half-Res     Bloom prefilter / bright pixels threshold
// 6        colortex6         RGBA8    Available    User-defined or auxiliary pass data
// 7-15     colortex7-15      RGBA8    Available    Available for future effects/passes
//
// Pass Ownership & Data Flow:
//
// GBUFFERS PASSES (terrain, entities, hand, weather, water):
//   OUTPUT: colortex0 (lit scene color or unlit albedo)
//           colortex1 (material parameters)
//           colortex2 (normals + depth)
//   Purpose: Capture per-pixel material data and geometry
//
// SHADOW PASS:
//   OUTPUT: shadowcolor0 (standard shadow map output)
//   Purpose: Render from light perspective; depth stored in depth texture
//
// DEFERRED PASS:
//   INPUT:  colortex0, colortex1, colortex2 (from gbuffers)
//           shadowtex0 (shadow map)
//           Various samplers (albedo, specular, normal maps from Minecraft)
//   OUTPUT: colortex0 (updated lit color with full lighting)
//   Purpose: Per-pixel Cook-Torrance GGX lighting computation
//
// DEFERRED1 PASS (optional, second deferred):
//   INPUT:  colortex0-4 (intermediate results)
//   OUTPUT: colortex0 or auxiliary buffers (additional effects)
//   Purpose: Additional lighting passes, special effects
//
// COMPOSITE PASS:
//   INPUT:  colortex0-4 (all intermediate data)
//           shadowtex0 (shadow map)
//   OUTPUT: colortex0 (updated scene with post-effects)
//   Purpose: Apply SSR, TAA, bloom prefilter, fog
//
// COMPOSITE1 PASS (optional, second composite):
//   INPUT:  colortex0, colortex3-5 (bloom, history, SSR data)
//   OUTPUT: colortex0 (bloom upsampled, SSR integrated)
//   Purpose: Bloom upsampling, reflection integration
//
// FINAL PASS:
//   INPUT:  colortex0 (final composited scene)
//   OUTPUT: Framebuffer (gl_FragColor or layout-specified output)
//   Purpose: Tonemap, color grade, output to screen

// ===================================================================
// MATHEMATICAL CONSTANTS
// ===================================================================

const float PI           = 3.14159265359;
const float TWO_PI       = 6.28318530718;
const float HALF_PI      = 1.57079632679;
const float INV_PI       = 0.31830988618;
const float INV_TWO_PI   = 0.15915494309;
const float SQRT_2       = 1.41421356237;
const float INV_SQRT_2   = 0.70710678118;
const float GOLDEN_RATIO = 1.61803398875;
const float EPSILON      = 1e-6;

// ===================================================================
// COLOR & SPACE CONSTANTS
// ===================================================================

// sRGB to Linear and Linear to sRGB constants
const float SRGB_GAMMA   = 2.2;
const float SRGB_INV_GAMMA = 1.0 / 2.2;

// Luminance weights (ITU-R BT.601 standard)
const vec3 LUMA_BT601    = vec3(0.299, 0.587, 0.114);

// Luminance weights (ITU-R BT.709 standard; more modern)
const vec3 LUMA_BT709    = vec3(0.2126, 0.7152, 0.0722);

// Luminance weights (perceived brightness)
const vec3 LUMA_PERCEIVED = vec3(0.27, 0.67, 0.06);

// ===================================================================
// WORLD & RENDERING CONSTANTS
// ===================================================================

// Maximum shadow distance (blocks)
const float SHADOW_DISTANCE_DEFAULT = 128.0;

// Minecraft sky brightness schedule constants
// Sky brightness varies from 0 (night) to 1 (noon)
// Interpolation is non-linear in Minecraft

// Block light intensity constants
const float TORCH_LIGHT_RADIUS = 12.0;  // Approximate torch influence radius (blocks)
const float TORCH_LIGHT_INTENSITY = 1.0;

// Sun/Moon intensity constants (in overworld coordinates)
const float SUN_INTENSITY = 1.0;
const float MOON_INTENSITY = 0.4;

// ===================================================================
// MATERIAL CONSTANTS
// ===================================================================

// Default material properties (when maps are missing)
const float DEFAULT_ROUGHNESS = 0.5;
const float DEFAULT_METALLIC = 0.0;
const float DEFAULT_F0 = 0.04;  // Dielectric F0 (about 4% reflectance at normal incidence)

// Metal F0 values (for reference; typically derived from specular map)
const float METAL_F0_IRON = 0.75;
const float METAL_F0_COPPER = 0.95;
const float METAL_F0_GOLD = 0.98;

// ===================================================================
// PERFORMANCE TUNING CONSTANTS
// ===================================================================

// Shadow PCF/PCSS sample counts (can be overridden per profile)
const int SHADOW_SAMPLES_LOW = 4;
const int SHADOW_SAMPLES_MEDIUM = 16;
const int SHADOW_SAMPLES_HIGH = 32;

// Cloud volumetric raymarch step counts
const int CLOUD_STEPS_LOW = 8;
const int CLOUD_STEPS_MEDIUM = 16;
const int CLOUD_STEPS_HIGH = 32;
const int CLOUD_STEPS_ULTRA = 48;

// SSR trace step counts
const int SSR_STEPS_QUALITY_1 = 32;
const int SSR_STEPS_QUALITY_2 = 64;
const int SSR_STEPS_QUALITY_3 = 128;

// Bloom prefilter mip levels
const int BLOOM_MIPS = 5;

// ===================================================================
// PROFILE-BASED TIER CONSTANTS
// ===================================================================

// These are symbolic constants for profile tier detection
// Actual tier is set via shaders.properties option TIER

const int TIER_LOW = 1;
const int TIER_MEDIUM = 2;
const int TIER_HIGH = 3;
const int TIER_ULTRA = 4;
const int TIER_CINEMATIC = 5;

// ===================================================================
// DEPTH LINEARIZATION CONSTANTS
// ===================================================================

// These are approximations for standard Minecraft near/far planes
// Actual values should be computed from gl_ProjectionMatrix if needed

const float NEAR_PLANE = 0.05;
const float FAR_PLANE = 1000.0;

// ===================================================================
// DEBUG CONSTANTS
// ===================================================================

// Debug view IDs (corresponds to DEBUG_VIEW option)
const int DEBUG_OFF = 0;
const int DEBUG_NORMALS = 1;
const int DEBUG_ROUGHNESS = 2;
const int DEBUG_METALLIC = 3;
const int DEBUG_EMISSIVE = 4;
const int DEBUG_DEPTH = 5;
const int DEBUG_LIGHTING = 6;
const int DEBUG_HISTORY = 7;
const int DEBUG_SSR = 8;

// ===================================================================
// TEXTURE UNIT ALLOCATION
// ===================================================================

// Standard Minecraft texture units (read-only in shaders)
// These are bound by the Minecraft renderer:
// 0  = Lightmap
// 1  = Block texture atlas (primary)
// 2-3 = Additional samplers (entity texture, etc.)
// etc.

// Custom texture units (defined via customTexture in shaders.properties)
// These should be documented in individual shader files
// Example: customTexture BlueNoise = path/to/blue_noise.png

// ===================================================================
// SHADER OPTION DEFINITIONS (User-Configurable via shaders.properties)
// ===================================================================
// These #defines are set via shaders.properties sliders and options.
// Default values match the "HIGH" profile unless overridden.
// Value lists in comments are for OptiFine slider configuration.

// SHADOWS
#ifndef SHADOW_DISTANCE
#define SHADOW_DISTANCE 128                    // [64 96 128 160 192 256]
#endif

#ifndef SHADOW_SOFTNESS
#define SHADOW_SOFTNESS 1.0                    // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef SHADOW_FILTER_SIZE
#define SHADOW_FILTER_SIZE 1.0                 // [0.5 1.0 1.5 2.0 2.5 3.0]
#endif

#ifndef SHADOW_BIAS
#define SHADOW_BIAS 0.001                      // [0.0001 0.0005 0.001 0.002 0.005 0.01]
#endif

#ifndef PENUMBRA_SCALE
#define PENUMBRA_SCALE 1.0                     // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

// BLOOM
#ifndef BLOOM_STRENGTH
#define BLOOM_STRENGTH 0.5                     // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef BLOOM_THRESHOLD
#define BLOOM_THRESHOLD 0.5                    // [0.1 0.3 0.5 0.7 0.9]
#endif

#ifndef BLOOM_INTENSITY
#define BLOOM_INTENSITY 0.5                    // [0.25 0.5 0.75 1.0 1.5 2.0]
#endif

#ifndef BLOOM_SOFTKNEE
#define BLOOM_SOFTKNEE 0.1                     // [0.0 0.05 0.1 0.15 0.2]
#endif

#ifndef BLOOM_SPECTRAL_SHIFT
#define BLOOM_SPECTRAL_SHIFT 0.0               // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

// OPTICAL EFFECTS
#ifndef CHROMATIC_ABERRATION
#define CHROMATIC_ABERRATION 0.0               // [0.0 0.01 0.02 0.03 0.04 0.05]
#endif

#ifndef AIRY_APERTURE_SIZE
#define AIRY_APERTURE_SIZE 0.01                // [0.001 0.005 0.01 0.02 0.03]
#endif

#ifndef FLARE_INTENSITY
#define FLARE_INTENSITY 0.5                    // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef LENS_DISTORTION
#define LENS_DISTORTION 0.0                    // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef VIGNETTE_AMOUNT
#define VIGNETTE_AMOUNT 0.2                    // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef FILM_GRAIN
#define FILM_GRAIN 0.0                         // [0.0 0.05 0.1 0.15 0.2]
#endif

// CAMERA & TONEMAPPING
#ifndef TONEMAP_EXPOSURE
#define TONEMAP_EXPOSURE 1.0                   // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef ADAPTIVE_EXPOSURE
#define ADAPTIVE_EXPOSURE 1.0                  // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef LIFT_SHADOWS
#define LIFT_SHADOWS 0.0                       // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef GAIN_HIGHLIGHTS
#define GAIN_HIGHLIGHTS 0.0                    // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef CONTRAST_FACTOR
#define CONTRAST_FACTOR 1.0                    // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef SATURATION_FACTOR
#define SATURATION_FACTOR 1.0                  // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef GAMMA_MIDTONES
#define GAMMA_MIDTONES 1.0                     // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef OUTPUT_GAMMA
#define OUTPUT_GAMMA 2.2                       // [1.8 2.0 2.2 2.4 2.6]
#endif

#ifndef COLOR_GRADE_STRENGTH
#define COLOR_GRADE_STRENGTH 1.0               // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef SHARPEN_AMOUNT
#define SHARPEN_AMOUNT 0.0                     // [0.0 0.2 0.4 0.6 0.8 1.0]
#endif

// WATER
#ifndef WATER_REFRACTION_STRENGTH
#define WATER_REFRACTION_STRENGTH 0.5          // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef WATER_WAVE_AMPLITUDE
#define WATER_WAVE_AMPLITUDE 0.5               // [0.1 0.3 0.5 0.7 0.9]
#endif

#ifndef WATER_WAVE_FREQUENCY
#define WATER_WAVE_FREQUENCY 1.0               // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CAUSTICS_SCALE
#define CAUSTICS_SCALE 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CAUSTICS_SPEED
#define CAUSTICS_SPEED 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef FOAM_INTENSITY
#define FOAM_INTENSITY 0.5                     // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef UNDERWATER_DEPTH
#define UNDERWATER_DEPTH 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

// ATMOSPHERE & SKY
#ifndef AEROSOL_DENSITY
#define AEROSOL_DENSITY 0.1                    // [0.05 0.1 0.15 0.2 0.3]
#endif

#ifndef HAZE_AMOUNT
#define HAZE_AMOUNT 1.0                        // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef RAYLEIGH_COEFFICIENT
#define RAYLEIGH_COEFFICIENT 0.2               // [0.1 0.15 0.2 0.25 0.3]
#endif

#ifndef MIE_COEFFICIENT
#define MIE_COEFFICIENT 0.005                  // [0.001 0.002 0.005 0.01 0.02]
#endif

#ifndef ALTITUDE_SCALE
#define ALTITUDE_SCALE 1.0                     // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef AERIAL_FOG_DISTANCE
#define AERIAL_FOG_DISTANCE 100.0              // [50 100 150 200 300 500]
#endif

#ifndef AERIAL_PERSPECTIVE_DISTANCE
#define AERIAL_PERSPECTIVE_DISTANCE 50.0       // [20 35 50 75 100 150]
#endif

#ifndef ATMOSPHERE_TURBIDITY
#define ATMOSPHERE_TURBIDITY 2.0               // [1.0 1.5 2.0 2.5 3.0]
#endif

#ifndef ATMOSPHERE_FOG_DENSITY
#define ATMOSPHERE_FOG_DENSITY 0.1             // [0.0 0.05 0.1 0.15 0.2]
#endif

#ifndef ATMOSPHERE_FOG_ABSORPTION
#define ATMOSPHERE_FOG_ABSORPTION 0.05         // [0.01 0.025 0.05 0.1 0.2]
#endif

#ifndef SKY_SUN_INTENSITY
#define SKY_SUN_INTENSITY 1.0                  // [0.5 0.75 1.0 1.25 1.5]
#endif

// CLOUDS
#ifndef CLOUD_QUALITY
#define CLOUD_QUALITY 2                        // [0 1 2 3]
#endif

#ifndef CLOUD_RAYMARCH_STEPS
#define CLOUD_RAYMARCH_STEPS 64                // [16 32 64 128 256]
#endif

#ifndef CLOUD_SCATTERING_ORDER
#define CLOUD_SCATTERING_ORDER 2               // [1 2 3 4]
#endif

#ifndef CLOUD_NOISE_DETAIL
#define CLOUD_NOISE_DETAIL 0.5                 // [0.25 0.5 0.75 1.0]
#endif

#ifndef CLOUD_ALT1
#define CLOUD_ALT1 100.0                       // [50 100 150 200 300]
#endif

#ifndef CLOUD_ALT2
#define CLOUD_ALT2 200.0                       // [100 150 200 300 400]
#endif

// FOG & VOLUMETRIC
#ifndef FOG_QUALITY
#define FOG_QUALITY 1                          // [0 1 2 3]
#endif

#ifndef VOLUMETRIC_SAMPLES
#define VOLUMETRIC_SAMPLES 16                  // [8 16 32 64 128]
#endif

#ifndef VOLUMETRIC_FOG_ENABLED
#define VOLUMETRIC_FOG_ENABLED 1               // [0 1]
#endif

#ifndef WEATHER_FOG_DENSITY
#define WEATHER_FOG_DENSITY 0.1                // [0.05 0.1 0.15 0.2]
#endif

// GOD RAYS / LIGHT SHAFTS
#ifndef GODRAY_QUALITY
#define GODRAY_QUALITY 2                       // [0 1 2 3]
#endif

#ifndef GOD_RAY_DENSITY
#define GOD_RAY_DENSITY 1.0                    // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef GOD_RAY_SAMPLES
#define GOD_RAY_SAMPLES 16                     // [8 16 32 64]
#endif

#ifndef LIGHTSHAFT_QUALITY
#define LIGHTSHAFT_QUALITY 2                   // [0 1 2 3 4]
#endif

#ifndef LIGHTSHAFT_DAY_I
#define LIGHTSHAFT_DAY_I 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef LIGHTSHAFT_NIGHT_I
#define LIGHTSHAFT_NIGHT_I 0.5                 // [0.25 0.5 0.75 1.0]
#endif

#ifndef LIGHTSHAFT_RAIN_I
#define LIGHTSHAFT_RAIN_I 0.3                  // [0.1 0.2 0.3 0.4 0.5]
#endif

// LIGHTING & GLOBAL ILLUMINATION
#ifndef GI_INTENSITY
#define GI_INTENSITY 1.0                       // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef IBL_INTENSITY
#define IBL_INTENSITY 0.5                      // [0.25 0.5 0.75 1.0 1.5]
#endif

#ifndef IBL_DIFFUSE_INTENSITY
#define IBL_DIFFUSE_INTENSITY 0.5              // [0.25 0.5 0.75 1.0]
#endif

#ifndef IBL_SPECULAR_INTENSITY
#define IBL_SPECULAR_INTENSITY 0.5             // [0.25 0.5 0.75 1.0]
#endif

#ifndef IBL_ROUGHNESS_SCALE
#define IBL_ROUGHNESS_SCALE 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_MAX_MIP_LEVEL
#define IBL_MAX_MIP_LEVEL 5                    // [1 2 3 4 5 6 7 8]
#endif

#ifndef IBL_PROBE_COUNT
#define IBL_PROBE_COUNT 16                     // [4 8 16 32 64]
#endif

#ifndef SSGI_INTENSITY
#define SSGI_INTENSITY 0.5                     // [0.25 0.5 0.75 1.0 1.5]
#endif

#ifndef SSGI_RAY_STEPS
#define SSGI_RAY_STEPS 16                      // [8 16 32 64 128]
#endif

#ifndef SSGI_STRIDE
#define SSGI_STRIDE 1                          // [1 2 4 8]
#endif

#ifndef SSGI_CONE_ANGLE
#define SSGI_CONE_ANGLE 0.5                    // [0.1 0.25 0.5 1.0]
#endif

#ifndef SSGI_MAX_DISTANCE
#define SSGI_MAX_DISTANCE 128.0                // [64 128 256 512]
#endif

#ifndef SSGI_BILATERAL_RADIUS
#define SSGI_BILATERAL_RADIUS 2.0              // [1.0 2.0 4.0 8.0]
#endif

#ifndef SSGI_BILATERAL_SIGMA_D
#define SSGI_BILATERAL_SIGMA_D 1.0             // [0.5 1.0 2.0 4.0]
#endif

#ifndef SSGI_BILATERAL_SIGMA_S
#define SSGI_BILATERAL_SIGMA_S 0.2             // [0.1 0.2 0.4 0.8]
#endif

#ifndef AO_INTENSITY
#define AO_INTENSITY 1.0                       // [0.25 0.5 0.75 1.0 1.5 2.0]
#endif

#ifndef AO_COLOR_BLEED
#define AO_COLOR_BLEED 0.5                     // [0.0 0.25 0.5 0.75 1.0]
#endif

// MATERIALS & PBR
#ifndef NORMAL_MAP_STRENGTH
#define NORMAL_MAP_STRENGTH 1.0                // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef CUSTOM_EMISSION_INTENSITY
#define CUSTOM_EMISSION_INTENSITY 1.0          // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef GENERATED_NORMAL_MULT
#define GENERATED_NORMAL_MULT 1.0              // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef COATED_TEXTURE_MULT
#define COATED_TEXTURE_MULT 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef PARALLAX_QUALITY
#define PARALLAX_QUALITY 1.0                   // [0.5 0.75 1.0 1.25 1.5 2.0]
#endif

#ifndef MATERIAL_IOR
#define MATERIAL_IOR 1.5                       // [1.0 1.3 1.5 1.8 2.0]
#endif

#ifndef MATERIAL_THICKNESS
#define MATERIAL_THICKNESS 0.5                 // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef MATERIAL_CHROMATIC
#define MATERIAL_CHROMATIC 0.5                 // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef MATERIAL_ABBE
#define MATERIAL_ABBE 50.0                     // [20 30 50 70 100]
#endif

#ifndef INTERFERENCE_STRENGTH
#define INTERFERENCE_STRENGTH 0.5              // [0.0 0.25 0.5 0.75 1.0]
#endif

// ANIMATION
#ifndef WIND_STRENGTH
#define WIND_STRENGTH 1.0                      // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef TORCH_FLICKER_SPEED
#define TORCH_FLICKER_SPEED 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

// SUBSURFACE SCATTERING
#ifndef SSS_STRENGTH
#define SSS_STRENGTH 0.5                       // [0.0 0.25 0.5 0.75 1.0]
#endif

// TECHNICAL
#ifndef BLOCKLIGHT_SHAFT_STRENGTH
#define BLOCKLIGHT_SHAFT_STRENGTH 1.0          // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef VBL_NETHER_MULT
#define VBL_NETHER_MULT 1.0                    // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef VBL_END_MULT
#define VBL_END_MULT 1.0                       // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef BLOCKLIGHT_SOURCE_SIZE
#define BLOCKLIGHT_SOURCE_SIZE 0.5             // [0.25 0.5 0.75 1.0 1.5]
#endif

#ifndef TRANSLUCENT_LIGHT_CONDUCTION
#define TRANSLUCENT_LIGHT_CONDUCTION 1.0       // [0.5 0.75 1.0 1.25 1.5]
#endif

// TAA (TEMPORAL ANTI-ALIASING)
#ifndef TAA_JITTER_SCALE
#define TAA_JITTER_SCALE 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef TAA_SAMPLE_WEIGHT
#define TAA_SAMPLE_WEIGHT 0.7                  // [0.5 0.6 0.7 0.8 0.9 0.95]
#endif

#ifndef TAA_SHARPEN
#define TAA_SHARPEN 0.5                        // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef TAA_CLAMP_STRENGTH
#define TAA_CLAMP_STRENGTH 1.0                 // [0.5 0.75 1.0 1.25 1.5]
#endif

// RAYTRACING
#ifndef RAYTRACING_SAMPLES_PER_PIXEL
#define RAYTRACING_SAMPLES_PER_PIXEL 1         // [1 2 4 8]
#endif

#ifndef RAYTRACING_MAX_BOUNCES
#define RAYTRACING_MAX_BOUNCES 3               // [1 2 3 4 5 6 8]
#endif

#ifndef RAYTRACING_DEPTH_THRESHOLD
#define RAYTRACING_DEPTH_THRESHOLD 0.1         // [0.05 0.1 0.2 0.5]
#endif

// INDIRECT LIGHTING
#ifndef INDIRECT_BOUNCES
#define INDIRECT_BOUNCES 3                     // [1 2 3 4 5 6]
#endif

#ifndef INDIRECT_SAMPLES
#define INDIRECT_SAMPLES 4                     // [2 4 8 16 32]
#endif

#ifndef INDIRECT_QUALITY
#define INDIRECT_QUALITY 2                     // [0 1 2 3]
#endif

#ifndef MIS_POWER
#define MIS_POWER 2.0                          // [1.0 1.5 2.0 2.5 3.0]
#endif

// MISC
#ifndef DETAIL_ENHANCEMENT
#define DETAIL_ENHANCEMENT 0.5                 // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef SYNTHESIS_SPEED
#define SYNTHESIS_SPEED 1.0                    // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef BLOCKLIGHT_CHECK_INTERVAL
#define BLOCKLIGHT_CHECK_INTERVAL 1            // [1 2 4 8]
#endif

#ifndef COMPRESSION_QUALITY
#define COMPRESSION_QUALITY 2                  // [0 1 2 3]
#endif

// ===================================================================
// UTILITY MACROS
// ===================================================================

// Branch reduction macro (use sparingly)
#define BRANCH if

// Unroll hint for loops
#define UNROLL_LOOP

// ===================================================================
// END OF CONSTANTS
// ===================================================================

#endif // INCLUDE_CONSTANTS
