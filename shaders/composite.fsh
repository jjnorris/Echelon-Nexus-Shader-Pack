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

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/post_processing.glsl"
#include "lib/temporal.glsl"
#include "lib/spectral_bloom.glsl"
#include "lib/blue_noise.glsl"
#include "lib/volumetric.glsl"
#include "lib/viewport.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
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
uniform mat4 gbufferProjectionInverse;  // For depth reconstruction
uniform mat4 gbufferModelViewInverse;   // For world position
uniform vec3 cameraPosition;    // Camera world position

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
    // ║ Step 1: Read Lit Scene (PHASE 5)                                   ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec4 litScene = texture(colortex0, vTexCoord);
    vec3 color = litScene.rgb;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 2: Volumetric Effects (PHASE 10 COMPLETE)                    ║
    // ║                                                                       ║
    // ║ Apply volumetric fog and god rays for atmospheric depth.           ║
    // ║ Scales quality based on FOG_QUALITY tier setting.                  ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    #ifdef VOLUMETRIC_FOG_ON
        // Read depth to determine fog density
        vec4 gbuffer2 = texture(colortex2, vTexCoord);
        float depth = gbuffer2.b;

        // Early exit if fully transparent (sky)
        if (depth > 0.999) {
            // Sky pixels don't get fog
        } else {
            // Reconstruct world position from depth
            vec3 viewPos = reconstructViewPos(vTexCoord, depth, gbufferProjectionInverse);
            vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

            // Camera-to-pixel ray direction
            vec3 rayDir = normalize(worldPos - cameraPosition);

            // Volumetric fog color (sky-like gradient)
            vec3 fogColor = vec3(0.85, 0.90, 0.98);
            float distance = length(worldPos - cameraPosition);

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
    // ║ Step 2b: Screen-Space Reflections (PHASE 11)                       ║
    // ║ TODO: Implement SSR sampling and blending                          ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Placeholder: No SSR for now (Phase 11)
    // vec3 ssr = sampleScreenSpaceReflections(vTexCoord, color);
    // color = mix(color, ssr, 0.3);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 3: Temporal Anti-Aliasing (PHASE 15)                          ║
    // ║ TODO: Implement Halton jitter and history blending                 ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Placeholder: No TAA for now (Phase 15)
    // vec3 taaColor = applySampleTAA(color, vTexCoord, frameCounter);
    // color = mix(color, taaColor, 0.8);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 4: Bloom & Spectral Bloom (PHASE 17)                          ║
    // ║ TODO: Sample prefiltered bloom and apply with spectral separation  ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Placeholder: No bloom for now (Phase 17)
    // vec3 bloomColor = sampleBloomPyramid(vTexCoord);
    // color = applySpectralBloom(color, bloomColor);

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

    colortex0_out = vec4(color, litScene.a);
}
