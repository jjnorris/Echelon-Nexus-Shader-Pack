// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║        ECHELON NEXUS - COMPOSITE POST-PROCESSING (PHASE 1)               ║
// ║                                                                           ║
// ║  Post-processing pipeline: TAA, tone mapping, color grading              ║
// ║  Runs after deferred lighting to enhance final image quality.            ║
// ║                                                                           ║
// ║  Phase 1 Pipeline:                                                        ║
// ║    1. Read lit scene (from deferred)                                    ║
// ║    2. Temporal anti-aliasing (TAA with Halton jitter)                   ║
// ║    3. ACES tone mapping (industry-standard)                             ║
// ║    4. Color grading (saturation, brightness)                            ║
// ║    5. Final output                                                       ║
// ║                                                                           ║
// ║  Future phases will add:                                                 ║
// ║    - Bloom & spectral effects (Phase 6)                                 ║
// ║    - Motion blur & chromatic aberration (Phase 7)                       ║
// ║    - Advanced color curves & LUT application (Phase 8)                  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;    // Lit scene color (from deferred)
uniform sampler2D colortex3;    // TAA history buffer
uniform int frameCounter;       // Frame index for TAA jitter
uniform mat4 gbufferProjection;

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LIBRARY INCLUDES                                                          ║
// ╚───────────────────────────────────────────────────────────────────────────╝

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/tone_mapping.glsl"
#include "lib/temporal_anti_aliasing.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ VARYINGS & OUTPUTS                                                        ║
// ╚───────────────────────────────────────────────────────────────────────────╝

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ MAIN POST-PROCESSING PIPELINE                                            ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

void main() {
    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 1: READ LIT SCENE FROM DEFERRED                              ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 color = texture(colortex0, vTexCoord).rgb;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 2: TEMPORAL ANTI-ALIASING (TAA)                              ║
    // ║                                                                       ║
    // ║ Apply TAA using Halton sequence jitter for super-sampling.         ║
    // ║ Blends current frame with reprojected history for quality.         ║
    // ║ This eliminates aliasing without MSAA performance cost.            ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Compute Halton jitter offset for this frame
    // Provides stratified sampling across frames (better than random)
    vec2 jitterOffset = computeHaltonJitter(frameCounter, 0.5);

    // Sample history buffer from previous frame
    vec4 historyColor = texture(colortex3, vTexCoord);

    // Temporal blending: weight toward current frame to avoid ghosting
    // 70% current, 30% history = smooth sub-pixel detail convergence
    float taaWeight = 0.3;
    color = mix(color, historyColor.rgb, taaWeight);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 3: TONE MAPPING (ACES - INDUSTRY STANDARD)                   ║
    // ║                                                                       ║
    // ║ Convert HDR color space to displayable LDR range.                  ║
    // ║ ACES (Academy Color Encoding System) is the industry standard      ║
    // ║ used in professional film and VFX pipelines.                       ║
    // ║                                                                       ║
    // ║ It preserves contrast and color saturation better than Reinhard.   ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Apply ACES tone mapping with configurable exposure
    float exposure = 1.0;  // TODO: Make this a uniform/config option
    color = toneMappingACES(color, exposure);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 4: COLOR GRADING & CREATIVE ADJUSTMENTS                      ║
    // ║                                                                       ║
    // ║ Apply color adjustments for creative control and mood.             ║
    // ║ For Phase 1: Simple saturation and brightness adjustments          ║
    // ║                                                                       ║
    // ║ Future phases will add:                                             ║
    // ║   - S-curves for contrast
    // ║   - Lift/Gamma/Gain color wheels
    // ║   - 3D LUT color grading
    // ║   - Channel-specific adjustments
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Color grading: Saturation boost for vibrancy
    // Extract luminance (perceived brightness)
    vec3 luminance = vec3(0.299, 0.587, 0.114);
    float gray = dot(color, luminance);

    // Interpolate between desaturated and saturated version
    float saturation = 1.1;  // 1.0 = no change, >1.0 = more vibrant
    color = mix(vec3(gray), color, saturation);

    // Optional brightness adjustment
    float brightness = 1.0;  // 1.0 = no change
    color *= brightness;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 5: GAMMA CORRECTION (sRGB)                                   ║
    // ║                                                                       ║
    // ║ Apply sRGB gamma curve for correct monitor display.                ║
    // ║ Converts from linear color space to display-referred space.        ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // sRGB gamma correction (2.2 inverse gamma)
    // This ensures colors look correct on standard displays
    color = pow(color, vec3(1.0 / 2.2));

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 6: FINAL SAFETY CLAMPING & OUTPUT                            ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Clamp to valid display range [0, 1]
    // Prevents NaN propagation and display artifacts
    color = clamp(color, 0.0, 1.0);

    // Output final composited color to screen
    colortex0_out = vec4(color, 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════
// END OF COMPOSITE POST-PROCESSING SHADER (PHASE 1)
// ═══════════════════════════════════════════════════════════════════════════
