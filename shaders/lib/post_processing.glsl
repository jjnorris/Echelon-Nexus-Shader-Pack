// ===================================================================
// Echelon Nexus - Post-Processing & Effects
// ===================================================================
// Bloom, lens effects, and final compositing.
// ===================================================================

#ifndef INCLUDE_POST_PROCESSING
#define INCLUDE_POST_PROCESSING

#include "constants.glsl"
#include "functions.glsl"

// ===================================================================
// BLOOM PREFILTER
// ===================================================================

// Threshold-based bright pixel extraction
vec3 bloomPrefilter(vec3 color, float threshold, float softKnee) {
    float brightness = luminance(color);

    // Hard threshold
    float curve = smoothstep(threshold - softKnee, threshold + softKnee, brightness);

    // Preserve color hue
    vec3 brightColor = color * curve;

    return brightColor;
}

// ===================================================================
// BLOOM BLUR
// ===================================================================

// Gaussian blur (separable)
vec3 gaussianBlurX(
    sampler2D tex,
    vec2 texCoord,
    vec2 invResolution,
    float radius
) {
    vec3 result = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = -4; i <= 4; i++) {
        float offset = float(i) * radius * invResolution.x;
        vec2 sampleCoord = texCoord + vec2(offset, 0.0);

        // Gaussian weight
        float weight = exp(-(float(i * i)) / (2.0 * radius * radius));

        result += texture(tex, sampleCoord).rgb * weight;
        totalWeight += weight;
    }

    return result / totalWeight;
}

vec3 gaussianBlurY(
    sampler2D tex,
    vec2 texCoord,
    vec2 invResolution,
    float radius
) {
    vec3 result = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = -4; i <= 4; i++) {
        float offset = float(i) * radius * invResolution.y;
        vec2 sampleCoord = texCoord + vec2(0.0, offset);

        float weight = exp(-(float(i * i)) / (2.0 * radius * radius));

        result += texture(tex, sampleCoord).rgb * weight;
        totalWeight += weight;
    }

    return result / totalWeight;
}

// ===================================================================
// BLOOM UPSAMPLE & COMBINE
// ===================================================================

// Bilinear upsampling for bloom reconstruction
vec3 upsampleBloom(sampler2D bloomTex, vec2 texCoord, vec2 invResolution) {
    // Sample 4 corners and interpolate
    vec2 texelSize = invResolution * 2.0;  // Half-res → full-res

    vec3 sample00 = texture(bloomTex, texCoord - texelSize * 0.5).rgb;
    vec3 sample10 = texture(bloomTex, texCoord + vec2(texelSize.x, -texelSize.y) * 0.5).rgb;
    vec3 sample01 = texture(bloomTex, texCoord + vec2(-texelSize.x, texelSize.y) * 0.5).rgb;
    vec3 sample11 = texture(bloomTex, texCoord + texelSize * 0.5).rgb;

    // Bilinear interpolation
    vec2 frac = fract(texCoord * vec2(textureSize(bloomTex, 0)));
    return mix(
        mix(sample00, sample10, frac.x),
        mix(sample01, sample11, frac.x),
        frac.y
    );
}

// Additive bloom blend
vec3 addBloom(vec3 baseColor, vec3 bloomColor, float bloomStrength) {
    return baseColor + bloomColor * bloomStrength;
}

// ===================================================================
// LENS FLARE & ARTIFACTS
// ===================================================================

// Simple lens flare (ghost reflections)
vec3 lensFlare(vec3 rayDir, vec3 sunDir, float sunIntensity) {
    float sunDot = clamp(dot(rayDir, sunDir), 0.0, 1.0);

    // Sun glow
    float glow = exp(-length(rayDir - sunDir) * 10.0) * sunIntensity;

    // Ghost reflections
    float ghostDistance = length(rayDir - sunDir);
    float ghost1 = exp(-ghostDistance * 5.0) * 0.3;
    float ghost2 = exp(-ghostDistance * 3.0) * 0.1;

    return vec3(glow + ghost1 + ghost2);
}

// ===================================================================
// DEPTH OF FIELD
// ===================================================================

// Simple depth-of-field blur (reserved for Phase 13)
vec3 applyDOF(
    vec3 color,
    float fragDepth,
    float focusDepth,
    float blurAmount
) {
    // Placeholder: return color as-is
    return color;
}

// ===================================================================
// CHROMATIC ABERRATION
// ===================================================================

// Simple chromatic aberration
#ifndef INCLUDE_CHROMATIC_ABERRATION
#define INCLUDE_CHROMATIC_ABERRATION
vec3 chromaticAberration(
    sampler2D tex,
    vec2 texCoord,
    float amount
) {
    vec3 color = texture(tex, texCoord).rgb;

    // Shift red and blue channels
    vec3 colorR = texture(tex, texCoord + vec2(amount, 0.0)).rgb;
    vec3 colorB = texture(tex, texCoord - vec2(amount, 0.0)).rgb;

    return vec3(colorR.r, color.g, colorB.b);
}
#endif  // INCLUDE_CHROMATIC_ABERRATION

// ===================================================================
// VIGNETTE
// ===================================================================

// Dark vignette at screen edges
vec3 applyVignette(vec3 color, vec2 texCoord, float strength) {
    vec2 uv = (texCoord - 0.5) * 2.0;
    float vignette = 1.0 - length(uv) * 0.5;
    vignette = pow(vignette, 2.0);

    return color * mix(1.0, vignette, strength);
}

// ===================================================================
// FILM GRAIN
// ===================================================================

// Perlin-like noise for film grain
vec3 applyFilmGrain(vec3 color, vec2 texCoord, float strength) {
    float grain = fract(sin(dot(texCoord, vec2(12.9898, 78.233))) * 43758.5453);
    grain = mix(0.5, grain, strength);

    return color * grain;
}

// ===================================================================
// MOTION BLUR (Reserved for Phase 9)
// ===================================================================

vec3 applyMotionBlur(sampler2D tex, vec2 texCoord, vec2 velocity, int samples) {
    // Placeholder: return texture as-is
    return texture(tex, texCoord).rgb;
}

// ===================================================================
// FINAL COMPOSITING
// ===================================================================

// Combine all post-processing effects
vec3 finalComposite(
    vec3 baseColor,
    vec3 bloom,
    float exposure,
    float saturation,
    float contrast
) {
    // Apply bloom
    vec3 withBloom = addBloom(baseColor, bloom, 0.5);

    // Apply exposure
    vec3 exposed = withBloom * pow(2.0, exposure);

    // Apply saturation
    float lum = luminance(exposed);
    vec3 saturated = mix(vec3(lum), exposed, saturation);

    // Apply contrast
    vec3 contrasted = mix(vec3(0.5), saturated, contrast);

    return contrasted;
}

// ===================================================================
// END OF POST-PROCESSING MODULE
// ===================================================================

#endif // INCLUDE_POST_PROCESSING
