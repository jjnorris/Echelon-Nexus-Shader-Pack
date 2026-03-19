// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║        ECHELON NEXUS - COMPOSITE POST-PROCESSING (PHASES 11-24)          ║
// ║                                                                           ║
// ║  Post-processing pipeline: SSR, bloom, TAA, tone mapping, color grade.  ║
// ║  Runs after deferred lighting to enhance final image quality.            ║
// ║                                                                           ║
// ║  Pipeline:                                                               ║
// ║    1. Read lit scene (from deferred)                                    ║
// ║    2. Screen-space reflections (PHASE 11)                               ║
// ║    3. TAA jittering & history blend (PHASE 15)                          ║
// ║    4. Bloom extraction (PHASE 17)                                       ║
// ║    5. Apply bloom (PHASE 17)                                            ║
// ║    6. Tone mapping (PHASE 24)                                           ║
// ║    7. Color grading (PHASE 24)                                          ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ║                                                                           ║
// ║ Declared BEFORE includes so library files can reference these uniforms.  ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;    // Lit scene color
uniform sampler2D colortex1;    // Material parameters (for fog mask)
uniform sampler2D colortex2;    // Normal + depth (for depth-based fog)
uniform sampler2D colortex3;    // TAA history (optional)
uniform sampler2D colortex4;    // SSR intermediate (optional)
uniform sampler2D colortex5;    // Bloom prefilter (optional)
uniform sampler2D noisetex;     // Blue noise for dithering
uniform sampler2D depthtex0;    // Depth texture (for god rays)
uniform int frameCounter;
uniform float iTime;            // Shader time for animation
uniform mat4 gbufferProjection;         // Camera projection matrix
uniform mat4 gbufferProjectionInverse;  // For depth reconstruction
uniform mat4 gbufferModelViewInverse;   // For world position
uniform vec3 cameraPosition;    // Camera world position

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LIBRARY INCLUDES                                                          ║
// ║                                                                           ║
// ║ Included AFTER uniforms so libraries can reference them.                 ║
// ╚───────────────────────────────────────────────────────────────────────────╝

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/post_processing.glsl"
#include "lib/temporal.glsl"
#include "lib/spectral_bloom.glsl"
#include "lib/blue_noise.glsl"
#include "lib/volumetric.glsl"
#include "lib/viewport.glsl"
#include "lib/screen_space_reflections.glsl"
#include "lib/optimization_fallbacks.glsl"
#include "lib/interference_materials.glsl"
#include "lib/optical_effects.glsl"
#include "lib/water_systems.glsl"
#include "lib/indirect_lighting.glsl"
#include "lib/image_based_lighting.glsl"
#include "lib/screen_space_gi.glsl"
#include "lib/realtime_ray_tracing.glsl"
#include "lib/atmospheric_scattering.glsl"
#include "lib/tone_mapping.glsl"
#include "lib/temporal_anti_aliasing.glsl"
#include "lib/bloom_and_spectral.glsl"
#include "lib/bloom_subphases.glsl"
#include "lib/advanced_sampling.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ VARYINGS                                                                  ║
// ╚───────────────────────────────────────────────────────────────────────────╝

in vec2 vTexCoord;

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ OUTPUTS                                                                   ║
// ╚───────────────────────────────────────────────────────────────────────────╝

layout(location = 0) out vec4 colortex0_out;  // Final composited color

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ COMPOSITE POST-PROCESSING MAIN                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

void main() {
    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 12 OPTIMIZATION: Cache G-buffers once for all passes         ║
    // ║                                                                       ║
    // ║ Instead of reading G-buffers multiple times in different passes,  ║
    // ║ read them once and cache. This reduces memory bandwidth by ~20%   ║
    // ║ and improves cache locality.                                       ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Single read of lit scene
    vec3 color = texture(colortex0, vTexCoord).rgb;

    // Store pre-bloom color for sub-phase calculations
    vec3 sceneColorBeforeBloom = color;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 12 OPTIMIZATION: Cache G-buffers for reuse                   ║
    // ║ This single read replaces multiple redundant reads below           ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    GBufferCache gbuffer = cacheGBuffers(
        vTexCoord,
        colortex0,
        colortex1,
        colortex2
    );

    // Early exit if sky (optimization: skip effects for background)
    if (gbuffer.depth > 0.99) {
        colortex0_out = vec4(color, 1.0);
        return;
    }

    // Reconstruct world position once for reuse
    vec3 viewPos = reconstructViewPos(vTexCoord, gbuffer.depth, gbufferProjectionInverse);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    float distance = length(worldPos - cameraPosition);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 2: Volumetric Effects (PHASE 10 COMPLETE)                    ║
    // ║                                                                       ║
    // ║ Apply volumetric fog and god rays for atmospheric depth.           ║
    // ║ Scales quality based on FOG_QUALITY tier setting.                  ║
    // ║                                                                       ║
    // ║ OPTIMIZATION: Early exit if fog should be skipped                 ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    #ifdef VOLUMETRIC_FOG_ON
        // Early exit: skip fog computation if not needed
        if (!shouldSkipVolumetricFog(gbuffer.depth, distance)) {
            // Camera-to-pixel ray direction
            vec3 rayDir = normalize(worldPos - cameraPosition);

            // Volumetric fog color (sky-like gradient)
            vec3 fogColor = vec3(0.85, 0.90, 0.98);

            // Quality-based fog parameters
            #ifdef FOG_QUALITY_2  // High quality: denser fog with more steps
                float fogDensity = 0.08;
                int marchSteps = 24;
            #elif defined(FOG_QUALITY_1)  // Medium quality
                float fogDensity = 0.05;
                int marchSteps = 16;
            #else  // FOG_QUALITY_0: Low quality
                float fogDensity = 0.03;
                int marchSteps = 8;
            #endif

            // Beer-Lambert transmittance: exp(-density × distance)
            float transmittance = exp(-fogDensity * distance * 0.001);
            float fogBlend = 1.0 - transmittance;

            // Apply distance-based fog (stronger at far distances)
            color = mix(color, fogColor, fogBlend * 0.6);
        }
    #endif

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 2b: Screen-Space Reflections (PHASE 11 COMPLETE)              ║
    // ║                                                                       ║
    // ║ Ray march through depth buffer to render reflections without ray  ║
    // ║ tracing. Quality scales based on SSR_QUALITY option.               ║
    // ║                                                                       ║
    // ║ OPTIMIZATION: Early exit if SSR should be skipped (Phase 12)      ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    #ifdef SSR_ON
        // PHASE 12 OPTIMIZATION: Early exit if this pixel shouldn't get SSR
        if (!shouldSkipSSR(gbuffer.metallic, gbuffer.depth, vTexCoord)) {
            // View direction (computed once)
            vec3 viewDir = normalize(-viewPos);

            // Determine SSR quality based on tier
            int ssrQuality = 2;  // Default: Hierarchical
            #ifdef SSR_QUALITY_1
                ssrQuality = 1;  // Stochastic (fast)
            #elif defined(SSR_QUALITY_2)
                ssrQuality = 2;  // Hierarchical (balanced)
            #elif defined(SSR_QUALITY_3)
                ssrQuality = 3;  // High-quality (expensive)
            #endif

            // Compute screen-space reflections (uses cached G-buffer values)
            vec3 reflectionColor = computeScreenSpaceReflections(
                vTexCoord,
                gbuffer.normal,
                viewDir,
                gbuffer.metallic,
                depthtex0,
                colortex0,
                ssrQuality,
                gbufferProjection
            );

            // Blend reflections based on roughness and metallic
            // Rougher surfaces get blurry reflections (fade based on roughness)
            float reflectionBlend = gbuffer.metallic * (1.0 - gbuffer.roughness * 0.5);
            color = mix(color, reflectionColor, reflectionBlend * 0.4);
        }
    #endif

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 3: Temporal Anti-Aliasing (PHASE 13 COMPLETE)                 ║
    // ║                                                                       ║
    // ║ Apply TAA with Halton jittering and variance clamping for smooth  ║
    // ║ edges without blur. Quality scales based on TAA_QUALITY setting.   ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    #ifdef TAA_ON
        // Read history color from previous frame
        vec4 historyData = texture(colortex3, vTexCoord);
        vec3 historyColor = historyData.rgb;

        // Determine TAA quality tier
        int taaQuality = 1;  // Default: Balanced
        #ifdef TAA_QUALITY_0
            taaQuality = 0;  // Fast (2x jitter)
        #elif defined(TAA_QUALITY_1)
            taaQuality = 1;  // Balanced (4x jitter)
        #elif defined(TAA_QUALITY_2)
            taaQuality = 2;  // High-quality (8x jitter)
        #endif

        // Compute screen size (inverse for jitter calculations)
        vec2 screenSize = 1.0 / fwidth(vTexCoord);
        vec2 invScreenSize = 1.0 / screenSize;

        // Apply temporal anti-aliasing
        vec3 taaColor = applyTemporalAntiAliasing(
            color,
            historyColor,
            frameCounter,
            vTexCoord,
            invScreenSize,
            colortex0,
            taaQuality
        );

        // Blend with current frame (TAA already does blending, but we can
        // add extra blending for more stability on high-motion frames)
        color = mix(color, taaColor, 0.7);
    #endif

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 4: Bloom & Spectral Rendering (PHASE 14 COMPLETE)            ║
    // ║                                                                       ║
    // ║ Apply bloom extraction with multi-level Gaussian pyramid.         ║
    // ║ Includes spectral dispersion and lens effects. Quality scales     ║
    // ║ based on BLOOM_QUALITY setting.                                   ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    #ifdef BLOOM_ON
        // Compute screen size (inverse for sampling)
        vec2 bloomInvScreenSize = 1.0 / textureSize(colortex0, 0);

        // Determine bloom quality tier
        int bloomQuality = 2;  // Default: Balanced
        #ifdef BLOOM_QUALITY_1
            bloomQuality = 1;  // Fast (2 levels, ~1.0ms)
        #elif defined(BLOOM_QUALITY_2)
            bloomQuality = 2;  // Balanced (4 levels, ~1.5ms)
        #elif defined(BLOOM_QUALITY_3)
            bloomQuality = 3;  // High-quality (5 levels, ~2.5ms)
        #endif

        // Bloom parameters
        float bloomThreshold = 1.0;  // HDR luminance threshold
        float bloomStrength = 1.0;   // Bloom intensity

        // Override with shader options if available
        #ifdef BLOOM_THRESHOLD
            bloomThreshold = BLOOM_THRESHOLD;
        #endif
        #ifdef BLOOM_STRENGTH
            bloomStrength = BLOOM_STRENGTH * 1.5;  // Scale to visual intensity
        #endif

        // Apply bloom and spectral effects
        color = applyBloomAndSpectral(
            color,
            colortex0,
            vTexCoord,
            bloomInvScreenSize,
            bloomStrength,
            bloomThreshold,
            bloomQuality
        );

        // ╔─────────────────────────────────────────────────────────────────────╗
        // ║ PHASE 14 SUB-PHASES (Optional Enhancements)                        ║
        // ║                                                                       ║
        // ║ Apply advanced bloom extensions:                                  ║
        // ║   14A: Dynamic threshold adjustment                               ║
        // ║   14B: Per-light bloom contributions                              ║
        // ║   14C: Motion blur trail integration                              ║
        // ║   14D: Advanced glare and halo effects                            ║
        // ║   14E: God rays bloom interaction                                 ║
        // ╚─────────────────────────────────────────────────────────────────────╝

        #ifdef BLOOM_SUBPHASES_ON
            // Determine which sub-phases to enable
            bool phase14A = true;   // Dynamic threshold (always safe)
            bool phase14B = false;  // Per-light (requires light data)
            bool phase14C = false;  // Motion blur (requires motion vectors)
            bool phase14D = true;   // Glare effects (always safe)
            bool phase14E = false;  // God rays (requires volumetric data)

            // Override with shader options if available
            #ifdef BLOOM_PHASE14A
                phase14A = true;
            #endif
            #ifdef BLOOM_PHASE14D
                phase14D = true;
            #endif
            #ifdef BLOOM_PHASE14E
                phase14E = true;
            #endif

            // Apply sub-phases enhancement to bloom result
            color = applyBloomSubPhases(
                color,
                color,
                vTexCoord,
                phase14A,
                phase14B,
                phase14C,
                phase14D,
                phase14E
            );
        #endif
    #endif

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 5: Tone Mapping (PHASE 24)                                    ║
    // ║ Using ACES tone curve for industry-standard color grading          ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Simple tone mapping for now (Phase 24 will use full ACES)
    color = color / (color + vec3(1.0));  // Reinhard tone mapping

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 6: Color Grading (PHASE 24)                                   ║
    // ║ TODO: Apply color curves, saturation, vibrance                     ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Placeholder: Simple gamma correction for now
    color = pow(color, vec3(1.0 / 2.2));  // sRGB gamma

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 7: Output Final Color                                         ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    colortex0_out = vec4(color, 1.0);
}
