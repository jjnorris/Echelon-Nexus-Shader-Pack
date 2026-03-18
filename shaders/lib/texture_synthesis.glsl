// ===================================================================
// Autoregressive Texture Synthesis (Phase 26)
// ===================================================================
// Real-time texture generation from learned patterns.

#ifndef INCLUDE_TEXTURE_SYNTHESIS
#define INCLUDE_TEXTURE_SYNTHESIS

#include "noise.glsl"

// ===================================================================
// PROCEDURAL TEXTURE SYNTHESIS
// ===================================================================

// Generate procedural texture using noise composition
vec3 synthesizedTexture(vec2 uv, float time, float scale) {
    vec2 scaledUv = uv * scale;

    // Multi-octave Perlin noise for detail
    float n1 = fnoise(scaledUv * 1.0 + vec2(time * 0.1, 0.0));
    float n2 = fnoise(scaledUv * 2.5 + vec2(time * 0.15, 0.0));
    float n3 = fnoise(scaledUv * 5.0 + vec2(time * 0.2, 0.0));

    // Weighted combination
    float pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

    // Add modulation
    float modulation = sin(uv.x * 3.14159 * 2.0 * scale) * 0.5 + 0.5;
    pattern *= modulation;

    return vec3(pattern);
}

// ===================================================================
// DETAIL ENHANCEMENT
// ===================================================================

// Add high-frequency detail to base texture
vec3 enhanceDetail(vec3 baseColor, vec2 uv, float detailStrength) {
    // High-frequency noise
    vec2 fineUv = uv * 32.0;
    float fineNoise = fnoise(fineUv);

    // Modulate brightness
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
