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
// PHASE 1-5: QUALITY PROFILE & FOUNDATIONAL CONFIGURATION
// ===================================================================
// These are the core settings that configure the entire shader pack.
// They are applied early in the pipeline and affect all downstream systems.

// Quality Profile Selector (Phase 1)
// Determines which preset configuration to use.
// 0=LOW (iGPU, ~120 FPS) | 1=MEDIUM (GTX 960, ~100 FPS) | 2=HIGH (GTX 1060, ~75 FPS)
// 3=ULTRA (RTX 2060, ~55 FPS) | 4=CINEMATIC (RTX 4080+, ~35 FPS)
#ifndef PROFILE
#define PROFILE 2                              // [0 1 2 3 4]
#endif

// Internal tier identifier (synced with PROFILE)
// Tier 1=LOW, Tier 2=MEDIUM, Tier 3=HIGH, Tier 4=ULTRA, Tier 5=CINEMATIC
#ifndef TIER
#define TIER 3                                 // [1 2 3 4 5]
#endif

// ===================================================================
// PHASE 2: FEATURE ENABLE/DISABLE FLAGS
// ===================================================================

// Shadow Rendering - Phase 2
#ifndef SHADOW_QUALITY
#define SHADOW_QUALITY 1                       // [0 1 2]
#endif
#ifndef SHADOW_ALGORITHM
#define SHADOW_ALGORITHM 1                     // [0 1 2]
#endif

// Post-Processing Features - Phase 2
#ifndef BLOOM_ON
#define BLOOM_ON                               // Enable bloom effects
#endif

#ifndef TAA_ON
#define TAA_ON                                 // Enable temporal anti-aliasing
#endif

#ifndef SSR_ON
#define SSR_ON                                 // Enable screen-space reflections
#endif

#ifndef PARALLAX_ON
#define PARALLAX_ON                            // Enable parallax mapping
#endif

#ifndef CAUSTICS_ON
#define CAUSTICS_ON                            // Enable water caustics
#endif

#ifndef WETNESS_ON
#define WETNESS_ON                             // Enable wetness effects
#endif

#ifndef DITHERING_ENABLED
#define DITHERING_ENABLED                      // Enable dithering to reduce banding
#endif

#ifndef PERCEPTUAL_DITHERING
#define PERCEPTUAL_DITHERING                   // Use perceptual dithering pattern
#endif

// Advanced Lighting Features - Phase 3
#ifndef INDIRECT_ON
#define INDIRECT_ON                            // Enable indirect lighting (GI)
#endif

#ifndef IBL_ON
#define IBL_ON                                 // Enable image-based lighting
#endif

#ifndef SSS_ON
#define SSS_ON                                 // Enable subsurface scattering
#endif

#ifndef DIFFRACTION_ON
#define DIFFRACTION_ON                         // Enable diffraction effects
#endif

#ifndef INTERFERENCE_ON
#define INTERFERENCE_ON                        // Enable thin-film interference
#endif

#ifndef IRIDESCENCE_ON
#define IRIDESCENCE_ON                         // Enable iridescence
#endif

// Water & Atmosphere - Phase 3
#ifndef CLOUDS_ON
#define CLOUDS_ON                              // Enable cloud rendering
#endif

#ifndef VOLUMETRIC_FOG_ON
#define VOLUMETRIC_FOG_ON                      // Enable volumetric fog
#endif

#ifndef ATMOSPHERE_ENABLED
#define ATMOSPHERE_ENABLED                     // Enable atmospheric scattering
#endif

// Material System - Phase 4
#ifndef PBR_MODE
#define PBR_MODE 0                             // [0 1]
#endif

#ifndef LABPBR_ON
#define LABPBR_ON                              // Enable LabPBR format support
#endif

#ifndef OLDPBR_ON
#define OLDPBR_ON                              // Enable oldPBR fallback support
#endif

// Advanced Material Properties - Phase 4
#ifndef MATERIAL_IOR
#define MATERIAL_IOR 1.5                       // [1.0 1.33 1.5 1.75 2.0]
#endif

#ifndef MATERIAL_THICKNESS
#define MATERIAL_THICKNESS 0.5                 // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef MATERIAL_ABBE
#define MATERIAL_ABBE 50.0                     // [20.0 30.0 50.0 60.0 80.0]
#endif

// System Type Selectors - Phase 5
#ifndef GI_SYSTEM_TYPE
#define GI_SYSTEM_TYPE 0                       // [0 1 2 3 4]
#endif

#ifndef WATER_SYSTEM_TYPE
#define WATER_SYSTEM_TYPE 1                    // [0 1 2]
#endif

#ifndef RAYTRACING_ENABLED
#define RAYTRACING_ENABLED 0                   // [0 1]
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

#ifndef BLOOM_QUALITY
#define BLOOM_QUALITY 1                        // [0 1 2]
#endif

#ifndef SPECTRAL_BLOOM_ON
#define SPECTRAL_BLOOM_ON                      // Enable spectral bloom effects
#endif

#ifndef BLOOM_SPECTRAL_SHIFT
#define BLOOM_SPECTRAL_SHIFT 0.0               // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

// OPTICAL EFFECTS
#ifndef CHROMATIC_ABERRATION
#define CHROMATIC_ABERRATION 0.0               // [0.0 0.01 0.02 0.03 0.04 0.05]
#endif

#ifndef AIRY_DISK_ON
#define AIRY_DISK_ON                           // Enable Airy disk diffraction
#endif

#ifndef AIRY_APERTURE_SIZE
#define AIRY_APERTURE_SIZE 0.01                // [0.001 0.005 0.01 0.02 0.03]
#endif

#ifndef LENS_FLARE_ON
#define LENS_FLARE_ON                          // Enable lens flare
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

// PARALLAX MAPPING
#ifndef PARALLAX_QUALITY
#define PARALLAX_QUALITY 8                     // [4 8 16 32]
#endif

#ifndef PARALLAX_SELF_SHADOW
#define PARALLAX_SELF_SHADOW 1.0               // [0.0 0.5 1.0 1.5 2.0]
#endif

// MATERIAL TEXTURE PROCESSING
#ifndef GENERATED_NORMALS
#define GENERATED_NORMALS 1.0                  // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef COATED_TEXTURES
#define COATED_TEXTURES 0.5                    // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef GENERATED_NORMAL_MULT
#define GENERATED_NORMAL_MULT 1.0              // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef COATED_TEXTURE_MULT
#define COATED_TEXTURE_MULT 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef NORMAL_MAP_STRENGTH
#define NORMAL_MAP_STRENGTH 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CUSTOM_EMISSION_INTENSITY
#define CUSTOM_EMISSION_INTENSITY 1.0          // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef DETAIL_ENHANCEMENT
#define DETAIL_ENHANCEMENT 0.5                 // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef TEXTURE_COMPRESSION
#define TEXTURE_COMPRESSION 0                  // [0 1 2 3]
#endif

#ifndef TEXTURE_SYNTHESIS
#define TEXTURE_SYNTHESIS 0                    // [0 1]
#endif

#ifndef SYNTHESIS_SPEED
#define SYNTHESIS_SPEED 1.0                    // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef LOD_SYNTHESIS
#define LOD_SYNTHESIS 1                        // [0 1]
#endif

#ifndef LAYER_COUNT
#define LAYER_COUNT 2                          // [1 2 3 4]
#endif

// SHADOW ENHANCEMENTS
#ifndef BLUE_NOISE_DITHER
#define BLUE_NOISE_DITHER 1.0                  // [0.0 0.5 1.0 1.5 2.0]
#endif

// WATER SYSTEMS
#ifndef WATER_QUALITY
#define WATER_QUALITY 2                        // [0 1 2]
#endif

#ifndef WATER_REFRACTION_STRENGTH
#define WATER_REFRACTION_STRENGTH 0.5          // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef WATER_UNDERWATER
#define WATER_UNDERWATER 1                     // [0 1]
#endif

#ifndef WATER_FOAM
#define WATER_FOAM 1                           // [0 1]
#endif

#ifndef WATER_GERSTNER_WAVES
#define WATER_GERSTNER_WAVES 1                 // [0 1]
#endif

#ifndef WATER_PROPAGATION
#define WATER_PROPAGATION 1.0                  // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef WATER_WAVE_AMPLITUDE
#define WATER_WAVE_AMPLITUDE 0.5               // [0.25 0.5 0.75 1.0 1.5]
#endif

#ifndef WATER_WAVE_FREQUENCY
#define WATER_WAVE_FREQUENCY 1.0               // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef WATER_SHORELINE
#define WATER_SHORELINE 1                      // [0 1]
#endif

#ifndef FOAM_INTENSITY
#define FOAM_INTENSITY 0.5                     // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef WATER_FOAM_INTENSITY
#define WATER_FOAM_INTENSITY 0.5               // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef FOAM_AT_SHORES
#define FOAM_AT_SHORES 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CAUSTICS_SCALE
#define CAUSTICS_SCALE 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CAUSTICS_DEPTH
#define CAUSTICS_DEPTH 2.0                     // [1.0 1.5 2.0 2.5 3.0]
#endif

#ifndef CAUSTICS_SPEED
#define CAUSTICS_SPEED 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef UNDERWATER_DEPTH
#define UNDERWATER_DEPTH 32.0                  // [16.0 32.0 64.0 128.0]
#endif

#ifndef UNDERWATER_SCATTERING
#define UNDERWATER_SCATTERING 1.0              // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef SHORELINE_DISTANCE
#define SHORELINE_DISTANCE 8.0                 // [2.0 4.0 8.0 16.0 32.0]
#endif

// ATMOSPHERE & SKY
#ifndef SKY_QUALITY
#define SKY_QUALITY 2                          // [0 1 2]
#endif

#ifndef SKY_SUN_INTENSITY
#define SKY_SUN_INTENSITY 1.0                  // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef ATMOSPHERE_TURBIDITY
#define ATMOSPHERE_TURBIDITY 2.0               // [0.5 1.0 2.0 4.0 8.0]
#endif

#ifndef ATMOSPHERE_FOG_DENSITY
#define ATMOSPHERE_FOG_DENSITY 0.5             // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef ATMOSPHERE_FOG_ABSORPTION
#define ATMOSPHERE_FOG_ABSORPTION 0.5          // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef FOG_QUALITY
#define FOG_QUALITY 1                          // [0 1 2]
#endif

#ifndef CLOUD_QUALITY
#define CLOUD_QUALITY 1                        // [0 1 2]
#endif

#ifndef CLOUD_RAYMARCH_STEPS
#define CLOUD_RAYMARCH_STEPS 32                // [16 32 64 128]
#endif

#ifndef CLOUD_SCATTERING_ORDER
#define CLOUD_SCATTERING_ORDER 2               // [1 2 3]
#endif

#ifndef CLOUD_SELF_SHADOW
#define CLOUD_SELF_SHADOW 1                    // [0 1]
#endif

#ifndef CLOUD_TEMPORAL_REPROJECTION
#define CLOUD_TEMPORAL_REPROJECTION 1          // [0 1]
#endif

#ifndef CLOUD_TEMPORAL_STABILITY
#define CLOUD_TEMPORAL_STABILITY 1.0           // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef CLOUD_NOISE_DETAIL
#define CLOUD_NOISE_DETAIL 2                   // [1 2 3 4]
#endif

#ifndef CLOUD_ALT1
#define CLOUD_ALT1 100.0                       // [50.0 100.0 150.0 200.0]
#endif

#ifndef CLOUD_ALT2
#define CLOUD_ALT2 200.0                       // [150.0 200.0 250.0 300.0]
#endif

// VOLUMETRIC EFFECTS
#ifndef VOLUMETRIC_SAMPLES
#define VOLUMETRIC_SAMPLES 16                  // [8 16 32 64]
#endif

#ifndef WEATHER_FOG_DENSITY
#define WEATHER_FOG_DENSITY 0.5                // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef GODRAY_QUALITY
#define GODRAY_QUALITY 1                       // [0 1 2]
#endif

#ifndef GOD_RAY_DENSITY
#define GOD_RAY_DENSITY 0.5                    // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef GOD_RAY_SAMPLES
#define GOD_RAY_SAMPLES 16                     // [8 16 32 64]
#endif

#ifndef LIGHTSHAFT_QUALITY
#define LIGHTSHAFT_QUALITY 1                   // [0 1 2]
#endif

#ifndef LIGHTSHAFT_BEHAVIOUR
#define LIGHTSHAFT_BEHAVIOUR 1                 // [0 1 2]
#endif

#ifndef LIGHTSHAFT_DAY_I
#define LIGHTSHAFT_DAY_I 0.5                   // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef LIGHTSHAFT_NIGHT_I
#define LIGHTSHAFT_NIGHT_I 0.3                 // [0.0 0.1 0.2 0.3 0.5]
#endif

#ifndef LIGHTSHAFT_RAIN_I
#define LIGHTSHAFT_RAIN_I 0.4                  // [0.0 0.2 0.4 0.6 0.8]
#endif

// ATMOSPHERIC AEROSOLS
#ifndef AEROSOL_DENSITY
#define AEROSOL_DENSITY 0.5                    // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef HAZE_AMOUNT
#define HAZE_AMOUNT 0.3                        // [0.0 0.1 0.2 0.3 0.5]
#endif

#ifndef RAYLEIGH_COEFFICIENT
#define RAYLEIGH_COEFFICIENT 1.0               // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef MIE_COEFFICIENT
#define MIE_COEFFICIENT 1.0                    // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef AERIAL_FOG_DISTANCE
#define AERIAL_FOG_DISTANCE 256.0              // [64.0 128.0 256.0 512.0]
#endif

#ifndef AERIAL_PERSPECTIVE_DISTANCE
#define AERIAL_PERSPECTIVE_DISTANCE 512.0      // [256.0 512.0 1024.0]
#endif

#ifndef ALTITUDE_SCALE
#define ALTITUDE_SCALE 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

// AMBIENT OCCLUSION & LIGHTING
#ifndef AO_INTENSITY
#define AO_INTENSITY 0.5                       // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef AO_COLOR_BLEED
#define AO_COLOR_BLEED 0.25                    // [0.0 0.1 0.25 0.5]
#endif

#ifndef BLOCKLIGHT_SHAFT_STRENGTH
#define BLOCKLIGHT_SHAFT_STRENGTH 0.5          // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef VBL_NETHER_MULT
#define VBL_NETHER_MULT 1.5                    // [0.5 1.0 1.5 2.0]
#endif

#ifndef VBL_END_MULT
#define VBL_END_MULT 2.0                       // [0.5 1.0 2.0 3.0]
#endif

#ifndef BLOCKLIGHT_SOURCE_SIZE
#define BLOCKLIGHT_SOURCE_SIZE 0.5             // [0.1 0.25 0.5 0.75 1.0]
#endif

#ifndef TRANSLUCENT_LIGHT_CONDUCTION
#define TRANSLUCENT_LIGHT_CONDUCTION 1.0       // [0.0 0.5 1.0 1.5 2.0]
#endif

// GLOBAL ILLUMINATION
#ifndef GI_INTENSITY
#define GI_INTENSITY 0.5                       // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef GI_LIGHT_PROPAGATION
#define GI_LIGHT_PROPAGATION 1                 // [0 1 2]
#endif

#ifndef GI_PATH_INTEGRAL
#define GI_PATH_INTEGRAL 0                     // [0 1]
#endif

#ifndef GI_SAMPLE_COUNT
#define GI_SAMPLE_COUNT 4                      // [2 4 8 16]
#endif

#ifndef GI_IRRADIANCE_PROBES
#define GI_IRRADIANCE_PROBES 0                 // [0 1]
#endif

#ifndef GI_SCREEN_SPACE_BOUNCE
#define GI_SCREEN_SPACE_BOUNCE 1               // [0 1]
#endif

#ifndef GI_ENHANCED_AO
#define GI_ENHANCED_AO 1                       // [0 1]
#endif

// IMAGE-BASED LIGHTING
#ifndef IBL_INTENSITY
#define IBL_INTENSITY 1.0                      // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_DIFFUSE_INTENSITY
#define IBL_DIFFUSE_INTENSITY 1.0              // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_SPECULAR_INTENSITY
#define IBL_SPECULAR_INTENSITY 1.0             // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_ROUGHNESS_SCALE
#define IBL_ROUGHNESS_SCALE 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_PARALLAX_CORRECTION
#define IBL_PARALLAX_CORRECTION 1              // [0 1]
#endif

#ifndef IBL_PROBE_COUNT
#define IBL_PROBE_COUNT 8                      // [4 8 16 32]
#endif

#ifndef IBL_MAX_MIP_LEVEL
#define IBL_MAX_MIP_LEVEL 9                    // [5 7 9 11]
#endif

#ifndef IBL_HDRI_INTENSITY
#define IBL_HDRI_INTENSITY 1.0                 // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef IBL_SH_BANDS
#define IBL_SH_BANDS 3                         // [2 3 4]
#endif

#ifndef IBL_USE_SH
#define IBL_USE_SH 1                           // [0 1]
#endif

#ifndef REFLECTION_PROBES_ON
#define REFLECTION_PROBES_ON                   // Enable reflection probes
#endif

#ifndef PROBE_COUNT
#define PROBE_COUNT 64                         // [16 32 64 128]
#endif

#ifndef PROBE_SPACING
#define PROBE_SPACING 16.0                     // [8.0 16.0 32.0 64.0]
#endif

// SCREEN-SPACE GI
#ifndef SSGI_ENABLED
#define SSGI_ENABLED 1                         // [0 1]
#endif

#ifndef SSGI_INTENSITY
#define SSGI_INTENSITY 0.5                     // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef SSGI_RAY_STEPS
#define SSGI_RAY_STEPS 16                      // [8 16 32 64]
#endif

#ifndef SSGI_STRIDE
#define SSGI_STRIDE 2                          // [1 2 4 8]
#endif

#ifndef SSGI_METHOD
#define SSGI_METHOD 0                          // [0 1 2]
#endif

#ifndef SSGI_CONE_ANGLE
#define SSGI_CONE_ANGLE 30.0                   // [15.0 30.0 45.0 60.0]
#endif

#ifndef SSGI_DEPTH_THRESHOLD
#define SSGI_DEPTH_THRESHOLD 0.1               // [0.01 0.05 0.1 0.2]
#endif

#ifndef SSGI_DENOISE_ENABLED
#define SSGI_DENOISE_ENABLED 1                 // [0 1]
#endif

#ifndef SSGI_BILATERAL_RADIUS
#define SSGI_BILATERAL_RADIUS 3                // [1 3 5 7]
#endif

#ifndef SSGI_BILATERAL_SIGMA_D
#define SSGI_BILATERAL_SIGMA_D 1.0             // [0.5 1.0 2.0 4.0]
#endif

#ifndef SSGI_BILATERAL_SIGMA_S
#define SSGI_BILATERAL_SIGMA_S 1.0             // [0.5 1.0 2.0 4.0]
#endif

#ifndef SSGI_HBAO_RADIUS
#define SSGI_HBAO_RADIUS 0.5                   // [0.1 0.25 0.5 1.0]
#endif

#ifndef SSGI_HBAO_SAMPLES
#define SSGI_HBAO_SAMPLES 8                    // [4 8 16 32]
#endif

#ifndef SSGI_MAX_DISTANCE
#define SSGI_MAX_DISTANCE 64.0                 // [16.0 32.0 64.0 128.0]
#endif

#ifndef SSGI_REFINEMENT_STEPS
#define SSGI_REFINEMENT_STEPS 2                // [1 2 3 4]
#endif

#ifndef SSGI_TEMPORAL_BLEND
#define SSGI_TEMPORAL_BLEND 0.9                // [0.8 0.85 0.9 0.95]
#endif

// SCREEN-SPACE REFLECTIONS
#ifndef SSR_QUALITY
#define SSR_QUALITY 1                          // [0 1 2]
#endif

#ifndef SSR_STEP_COUNT
#define SSR_STEP_COUNT 32                      // [16 32 64 128]
#endif

#ifndef SSR_HISTORY_CLAMPING
#define SSR_HISTORY_CLAMPING 1.0               // [0.5 0.75 1.0 1.25 1.5]
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

#ifndef MIS_ENABLED
#define MIS_ENABLED 1                          // [0 1]
#endif

#ifndef MIS_POWER
#define MIS_POWER 2.0                          // [1.0 1.5 2.0 2.5 3.0]
#endif

// TEMPORAL ANTI-ALIASING
#ifndef TAA_QUALITY
#define TAA_QUALITY 1                          // [0 1 2]
#endif

#ifndef TAA_JITTER_SCALE
#define TAA_JITTER_SCALE 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef TAA_SAMPLE_WEIGHT
#define TAA_SAMPLE_WEIGHT 0.1                  // [0.05 0.1 0.15 0.2]
#endif

#ifndef TAA_SHARPEN
#define TAA_SHARPEN 0.5                        // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef TAA_CLAMP_STRENGTH
#define TAA_CLAMP_STRENGTH 0.8                 // [0.5 0.7 0.8 0.9]
#endif

#ifndef TAA_FILTER_TYPE
#define TAA_FILTER_TYPE 0                      // [0 1 2]
#endif

#ifndef TAA_ADAPTIVITY
#define TAA_ADAPTIVITY 1.0                     // [0.5 0.75 1.0 1.25 1.5]
#endif

// RAY TRACING
#ifndef RAYTRACING_TYPE
#define RAYTRACING_TYPE 0                      // [0 1 2]
#endif

#ifndef RAYTRACING_SAMPLES_PER_PIXEL
#define RAYTRACING_SAMPLES_PER_PIXEL 1         // [1 2 4 8]
#endif

#ifndef RAYTRACING_MAX_BOUNCES
#define RAYTRACING_MAX_BOUNCES 3               // [1 2 3 4]
#endif

#ifndef RAYTRACING_DEPTH_THRESHOLD
#define RAYTRACING_DEPTH_THRESHOLD 0.01        // [0.001 0.01 0.1 1.0]
#endif

#ifndef RAYTRACING_ADAPTIVE_RAYS
#define RAYTRACING_ADAPTIVE_RAYS 1             // [0 1]
#endif

#ifndef RAYTRACING_RUSSIAN_ROULETTE
#define RAYTRACING_RUSSIAN_ROULETTE 1          // [0 1]
#endif

#ifndef RAYTRACING_OPTICAL_FLOW
#define RAYTRACING_OPTICAL_FLOW 1              // [0 1]
#endif

#ifndef RAYTRACING_HYBRID_MODE
#define RAYTRACING_HYBRID_MODE 1               // [0 1]
#endif

#ifndef RAYTRACING_TEMPORAL_BLEND
#define RAYTRACING_TEMPORAL_BLEND 0.9          // [0.8 0.85 0.9 0.95]
#endif

#ifndef RAYTRACING_DIFFUSE_INTENSITY
#define RAYTRACING_DIFFUSE_INTENSITY 1.0       // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef RAYTRACING_SPECULAR_INTENSITY
#define RAYTRACING_SPECULAR_INTENSITY 1.0      // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef RAYTRACING_OPTICAL_SEARCH
#define RAYTRACING_OPTICAL_SEARCH 1            // [0 1]
#endif

// TONE MAPPING & COLOR
#ifndef TONEMAP_OPERATOR
#define TONEMAP_OPERATOR 0                     // [0 1 2]
#endif

#ifndef TONE_MAPPING_TYPE
#define TONE_MAPPING_TYPE 1                    // [0 1 2]
#endif

#ifndef TONE_MAPPING_EXPOSURE
#define TONE_MAPPING_EXPOSURE 1.0              // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef ADAPTIVE_EXPOSURE
#define ADAPTIVE_EXPOSURE 1.0                  // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef COLOR_GRADING_ENABLED
#define COLOR_GRADING_ENABLED 1                // [0 1]
#endif

#ifndef COLOR_GRADE_PRESET
#define COLOR_GRADE_PRESET 0                   // [0 1 2 3 4]
#endif

#ifndef COLOR_GRADE_STRENGTH
#define COLOR_GRADE_STRENGTH 1.0               // [0.0 0.5 1.0 1.5 2.0]
#endif

#ifndef LIFT_SHADOWS
#define LIFT_SHADOWS 0.0                       // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef GAIN_HIGHLIGHTS
#define GAIN_HIGHLIGHTS 0.0                    // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef CONTRAST_FACTOR
#define CONTRAST_FACTOR 1.0                    // [0.8 0.9 1.0 1.1 1.2]
#endif

#ifndef SATURATION_FACTOR
#define SATURATION_FACTOR 1.0                  // [0.8 0.9 1.0 1.1 1.2]
#endif

#ifndef GAMMA_MIDTONES
#define GAMMA_MIDTONES 1.0                     // [0.8 0.9 1.0 1.1 1.2]
#endif

#ifndef OUTPUT_GAMMA
#define OUTPUT_GAMMA 2.2                       // [1.8 2.0 2.2 2.4 2.6]
#endif

#ifndef SHARPEN_AMOUNT
#define SHARPEN_AMOUNT 0.0                     // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef DOF_ENABLED
#define DOF_ENABLED 0                          // [0 1]
#endif

// VIGNETTING & FILM EFFECTS
#ifndef VIGNETTE_AMOUNT
#define VIGNETTE_AMOUNT 0.2                    // [0.0 0.1 0.2 0.3 0.4 0.5]
#endif

#ifndef FILM_GRAIN
#define FILM_GRAIN 0.0                         // [0.0 0.05 0.1 0.15 0.2]
#endif

// SUBSURFACE SCATTERING
#ifndef SSS_STRENGTH
#define SSS_STRENGTH 1.0                       // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef SKIN_SSS
#define SKIN_SSS 1.0                           // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef FOLIAGE_TRANSMISSION
#define FOLIAGE_TRANSMISSION 0.5               // [0.0 0.25 0.5 0.75 1.0]
#endif

#ifndef EMISSIVE_RESPONSE
#define EMISSIVE_RESPONSE 1.0                  // [0.5 0.75 1.0 1.25 1.5]
#endif

// ANIMATION & EFFECTS
#ifndef WIND_ANIMATION
#define WIND_ANIMATION 1                       // [0 1]
#endif

#ifndef WIND_STRENGTH
#define WIND_STRENGTH 1.0                      // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef TORCH_FLICKER
#define TORCH_FLICKER 1                        // [0 1]
#endif

#ifndef TORCH_FLICKER_SPEED
#define TORCH_FLICKER_SPEED 1.0                // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef HAND_SWAYING
#define HAND_SWAYING 1                         // [0 1]
#endif

// WAVING EFFECTS
#ifndef WAVING_FOLIAGE
#define WAVING_FOLIAGE 1                       // [0 1]
#endif

#ifndef WAVING_LEAVES
#define WAVING_LEAVES 1                        // [0 1]
#endif

#ifndef WAVING_WATER_VERTEX
#define WAVING_WATER_VERTEX 1                  // [0 1]
#endif

#ifndef NO_WAVING_INDOORS
#define NO_WAVING_INDOORS 1                    // [0 1]
#endif

#ifndef RAIN_PUDDLES
#define RAIN_PUDDLES 1                         // [0 1]
#endif

#ifndef WETNESS_RESPONSE
#define WETNESS_RESPONSE 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

// BLOCKLIGHT CONFIGURATION
#ifndef BLOCKLIGHT_CHECK_INTERVAL
#define BLOCKLIGHT_CHECK_INTERVAL 1            // [1 2 4 8]
#endif

#ifndef BLOCKLIGHT_COLOR_MODE
#define BLOCKLIGHT_COLOR_MODE 0                // [0 1 2]
#endif

#ifndef HELD_LIGHTING_MODE
#define HELD_LIGHTING_MODE 0                   // [0 1 2]
#endif

#ifndef HELD_LIGHT_OCCLUSION_CHECK
#define HELD_LIGHT_OCCLUSION_CHECK 1           // [0 1]
#endif

// DEBUG & DEVELOPMENT
#ifndef DEBUG_VIEW
#define DEBUG_VIEW 0                           // [0 1]
#endif

#ifndef DEBUG_VIEW_MODE
#define DEBUG_VIEW_MODE 0                      // [0 1 2 3 4]
#endif

#ifndef DEBUG_SHOW_BUFFERS
#define DEBUG_SHOW_BUFFERS 0                   // [0 1]
#endif

#ifndef SHOW_LIGHT_LEVEL
#define SHOW_LIGHT_LEVEL 0                     // [0 1]
#endif

#ifndef LESS_LAVA_FOG
#define LESS_LAVA_FOG 0                        // [0 1]
#endif

#ifndef SNOWY_WORLD
#define SNOWY_WORLD 0                          // [0 1]
#endif

#ifndef WORLD_OUTLINE
#define WORLD_OUTLINE 0                        // [0 1]
#endif

#ifndef SELECT_OUTLINE
#define SELECT_OUTLINE 0                       // [0 1]
#endif

#ifndef SELECT_OUTLINE_I
#define SELECT_OUTLINE_I 1.0                   // [0.5 0.75 1.0 1.25 1.5]
#endif

#ifndef SELECT_OUTLINE_R
#define SELECT_OUTLINE_R 1.0                   // [0.0 0.5 1.0]
#endif

#ifndef SELECT_OUTLINE_G
#define SELECT_OUTLINE_G 1.0                   // [0.0 0.5 1.0]
#endif

#ifndef SELECT_OUTLINE_B
#define SELECT_OUTLINE_B 1.0                   // [0.0 0.5 1.0]
#endif

// PERFORMANCE & OPTIMIZATION
#ifndef ALLOW_CONCURRENT_COMPUTE
#define ALLOW_CONCURRENT_COMPUTE 1             // [0 1]
#endif

#ifndef PATH_CACHING
#define PATH_CACHING 1                         // [0 1]
#endif

#ifndef SSBO_PATH_ON
#define SSBO_PATH_ON 0                         // [0 1]
#endif

#ifndef COMPUTE_PATH_ON
#define COMPUTE_PATH_ON 0                      // [0 1]
#endif

#ifndef COMPRESSION_QUALITY
#define COMPRESSION_QUALITY 2                  // [0 1 2 3]
#endif

#ifndef BIT_ALLOCATION
#define BIT_ALLOCATION 2                       // [1 2 3 4]
#endif

#ifndef OCCLUSION_CASCADE_COUNT
#define OCCLUSION_CASCADE_COUNT 4               // [2 4 8 16]
#endif

#ifndef SAMPLING_MODE
#define SAMPLING_MODE 0                        // [0 1 2 3 4]
#endif

#ifndef STRATIFIED_SAMPLES
#define STRATIFIED_SAMPLES 16                  // [8 16 32 64]
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
