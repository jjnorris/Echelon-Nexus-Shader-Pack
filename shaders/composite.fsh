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

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;    // Lit scene color
uniform sampler2D colortex3;    // TAA history (optional)
uniform sampler2D colortex4;    // SSR intermediate (optional)
uniform sampler2D colortex5;    // Bloom prefilter (optional)
uniform sampler2D noisetex;     // Blue noise for dithering
uniform int frameCounter;

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
    // ║ Step 2: Screen-Space Reflections (PHASE 11)                        ║
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
