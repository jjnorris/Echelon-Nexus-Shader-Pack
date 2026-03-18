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
