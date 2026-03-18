// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║              AUTOREGRESSIVE TEXTURE SYNTHESIS (PHASE 26)                 ║
// ║                                                                           ║
// ║  Real-time procedural texture generation via noise composition and       ║
// ║  autoregressive patterns. Generates infinite detail without storage;     ║
// ║  creates tileable, temporally coherent textures on demand.              ║
// ║                                                                           ║
// ║  Approach: Combine multiple noise octaves at different scales/times.    ║
// ║  Result: Stone, wood, fabric, terrain textures with no memory overhead. ║
// ║  Dynamic: Time parameter enables cloud drift, water ripples, flames.    ║
// ║                                                                           ║
// ║  Benefits:                                                                ║
// ║    - Infinite LOD (no pre-generated mipmaps)                             ║
// ║    - Temporal coherence (smooth animation)                              ║
// ║    - Memory efficient (algorithm vs storage)                            ║
// ║    - Procedurally parameterizable appearance                            ║
// ║                                                                           ║
// ║  Performance: ~1-2ms for complex procedural pattern (vs 1-5ms for      ║
// ║  texture lookups + filtering)                                            ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_TEXTURE_SYNTHESIS
#define INCLUDE_TEXTURE_SYNTHESIS

#include "noise.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ PROCEDURAL TEXTURE SYNTHESIS                                             ║
// │                                                                           ║
// │ Generates textures via noise composition (Fractional Brownian Motion).  │
// │ Each octave adds frequency content at different scales. Temporal        │
// │ animation enabled by time parameter for dynamic effects.                │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ synthesizedTexture()                                                    ║
// ║                                                                         ║
// │ Procedural texture generation via multi-octave noise composition.     │
// │ Combines 3 noise octaves with decreasing amplitude:                   │
// │   - n1 (50%): Base large-scale structure                              │
// │   - n2 (30%): Medium-scale detail                                    │
// │   - n3 (20%): Fine-scale texture                                     │
// │                                                                         ║
// │ Formula: pattern = 0.5×f(s) + 0.3×f(2.5s) + 0.2×f(5s)             │
// │ Where f = Perlin noise, s = scaled UV, modulated by sine wave       │
// │                                                                         ║
// │ Animation: Each octave shifts via time parameter (different speeds)   │
// │   - Slow (0.1): Large cloud drift                                     │
// │   - Medium (0.15): Medium ripples                                     │
// │   - Fast (0.2): Fine turbulence                                       │
// │                                                                         ║
// │ Returns: Grayscale texture [0,1] suitable for color multiplication   │
// │                                                                         ║
// │ Cost: 3 Perlin evaluations + modulation (~1-2ms)                     │
// │ Typical use: Clouds, water, fire, stone texture generation          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 synthesizedTexture(vec2 uv, float time, float scale) {
    // ────────────────────────────────────────────────────────────────────────
    // Scale UV by parameter (controls zoom level)
    // ────────────────────────────────────────────────────────────────────────
    vec2 scaledUv = uv * scale;

    // ────────────────────────────────────────────────────────────────────────
    // Multi-octave noise at different frequencies and time speeds
    // Each octave adds detail at progressively finer scales
    // ────────────────────────────────────────────────────────────────────────
    float n1 = fnoise(scaledUv * 1.0 + vec2(time * 0.1, 0.0));     // Slow drift
    float n2 = fnoise(scaledUv * 2.5 + vec2(time * 0.15, 0.0));    // Medium
    float n3 = fnoise(scaledUv * 5.0 + vec2(time * 0.2, 0.0));     // Fast detail

    // ────────────────────────────────────────────────────────────────────────
    // Weighted octave composition (decreasing amplitude)
    // Larger features have more influence, smaller add detail
    // ────────────────────────────────────────────────────────────────────────
    float pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

    // ────────────────────────────────────────────────────────────────────────
    // Apply wave modulation: spatially varying intensity
    // Creates banding/striation effects (like wood grain, sediment layers)
    // ────────────────────────────────────────────────────────────────────────
    float modulation = sin(uv.x * 3.14159 * 2.0 * scale) * 0.5 + 0.5;
    pattern *= modulation;

    return vec3(pattern);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ DETAIL ENHANCEMENT                                                       ║
// │                                                                           ║
// │ Adds high-frequency surface detail to base texture. Simulates          │
// │ microscopic roughness, wear patterns, weathering on materials.         │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ enhanceDetail()                                                         ║
// ║                                                                         ║
// │ Adds fine-scale surface detail to base color. Uses high-frequency     │
// │ noise (32× magnification) to create microsurface texture. Useful      │
// │ for: roughness variation, age/wear marks, natural imperfections.     │
// │                                                                         ║
// │ Formula: detail = base + (noise - 0.5) × strength                   │
// │ Where noise is sampled at high frequency (32× UV scale)              │
// │                                                                         ║
// │ Parameters:                                                            │
// │   baseColor - Base texture color to enhance                           │
// │   uv - Texture coordinates                                           │
// │   detailStrength - Detail magnitude [0,1] (0.1-0.3 typical)         │
// │                                                                         ║
// │ Returns: Enhanced color with fine detail                              │
// │                                                                         ║
// │ Cost: Single high-freq noise sample (~0.3ms)                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 enhanceDetail(vec3 baseColor, vec2 uv, float detailStrength) {
    // ────────────────────────────────────────────────────────────────────────
    // High-frequency detail layer: 32× UV magnification
    // Produces visible small-scale texture (~1cm at 1m distance)
    // ────────────────────────────────────────────────────────────────────────
    vec2 fineUv = uv * 32.0;
    float fineNoise = fnoise(fineUv);

    // ────────────────────────────────────────────────────────────────────────
    // Blend detail into base: (noise-0.5) centers on zero for modulation
    // Strength parameter controls visibility (0.1-0.3 typical)
    // ────────────────────────────────────────────────────────────────────────
    vec3 detail = baseColor + (fineNoise - 0.5) * detailStrength;

    return detail;
}

// ===================================================================
// LOD TEXTURE GENERATION
// ===================================================================

// Generate LOD variant at reduced resolution
vec3 lodTexture(vec2 uv, int lodLevel, float scale) {
    // Blur level increases with LOD
    float blur = pow(2.0, float(lodLevel));

    // Sample at multiple scales and average
    vec3 result = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        vec2 offset = vec2(sin(float(i)), cos(float(i))) * blur;
        result += synthesizedTexture(uv + offset * 0.01, 0.0, scale);
    }

    return result / 4.0;
}

#endif // INCLUDE_TEXTURE_SYNTHESIS
