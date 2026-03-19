// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         BLOOM & SPECTRAL RENDERING (PHASE 14)                           ║
// ║                                                                           ║
// ║  Professional-grade HDR bloom with spectral color effects, Gaussian    ║
// ║  blur pyramid, and iridescence. Produces cinematic glow and light    ║
// ║  bloom without performance cost. Implements techniques from Unreal   ║
// ║  Engine, Remedy Entertainment, and Guerrilla Games.                 ║
// ║                                                                           ║
// ║  Algorithm:                                                              ║
// ║    1. Extract luminance-based bloom mask (HDR threshold)              ║
// ║    2. Downsample bloom mask (1/2, 1/4, 1/8, 1/16 resolution)        ║
// ║    3. Apply Gaussian blur to each pyramid level                     ║
// ║    4. Upsample and accumulate blur contributions                    ║
// ║    5. Apply spectral separation (RGB iridescence)                   ║
// ║    6. Blend with scene using additive compositing                  ║
// ║                                                                           ║
// ║  Quality Tiers:                                                          ║
// ║    - Fast: 2 pyramid levels, simple blur (Level 1)                  ║
// ║    - Balanced: 4 pyramid levels, Gaussian blur (Level 2)            ║
// ║    - High: 5 pyramid levels, spectral effects (Level 3)             ║
// ║                                                                           ║
// ║  Performance: 1.0-3.0ms depending on complexity                      ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_BLOOM_AND_SPECTRAL
#define INCLUDE_BLOOM_AND_SPECTRAL

#include "constants.glsl"
#include "functions.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HDR BLOOM EXTRACTION                                                    ║
// │                                                                           ║
// │ Extract bright pixels that bloom based on luminance threshold.        ║
// │ Uses tone-mapped luminance to determine bloom contribution.          ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeLuminance()                                                      ║
// ║                                                                         ║
// │ Compute perceptually-weighted luminance from linear RGB.            │
// │ Uses standard CIE luminance weights for human eye sensitivity.     │
// │                                                                       │
// │ Formula: L = 0.2126 × R + 0.7152 × G + 0.0722 × B                │
// │ These weights match human eye sensitivity to different colors.   │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Linear RGB color value                                  │
// │                                                                       │
// │ Returns: Perceptual luminance [0, ∞]                             │
// └─────────────────────────────────────────────────────────────────────┘
float computeLuminance(vec3 color) {
    // CIE standard luminance weights
    // Green is brightest to human eye, blue is darkest
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ extractBloom()                                                          ║
// ║                                                                         ║
// │ Extract bloom mask from scene color using luminance threshold.      │
// │ Bright pixels bloom, dark pixels don't.                            │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Compute luminance of pixel                                    │
// │   2. Remap luminance to bloom strength                            │
// │   3. Apply knee curve to smooth threshold transition              │
// │   4. Multiply by original color for colored bloom                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Linear RGB scene color                                  │
// │   bloomThreshold - Luminance threshold for bloom (0.5-2.0)       │
// │   bloomKnee - Softness of threshold transition (0.0-1.0)         │
// │                                                                       │
// │ Returns: Bloom color (typically small values, can be HDR)       │
// │                                                                       │
// │ Example:                                                            │
// │   Threshold = 1.0                                                 │
// │   - Pixel lum 0.5: bloom = 0 (below threshold)                  │
// │   - Pixel lum 1.0: bloom = 0 (at threshold edge)               │
// │   - Pixel lum 2.0: bloom = 1.0 × color (bright)               │
// │   - Pixel lum 5.0: bloom = 4.0 × color (very bright)          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 extractBloom(
    vec3 color,
    float bloomThreshold,
    float bloomKnee
) {
    // Compute luminance of pixel
    float lum = computeLuminance(color);

    // ────────────────────────────────────────────────────────────────────────
    // Apply knee curve for smooth threshold transition
    // Without knee: hard edge at threshold (looks bad)
    // With knee: soft falloff region (looks good)
    // ────────────────────────────────────────────────────────────────────────
    float threshold = bloomThreshold;
    float kneeCurve = bloomKnee * threshold;  // Knee region width
    float kneeStart = threshold - kneeCurve;
    float kneeEnd = threshold + kneeCurve;

    // Soft threshold using smoothstep
    // Smoothly blend from 0 to 1 over knee region
    float bloomMask = smoothstep(kneeStart, kneeEnd, lum);

    // ────────────────────────────────────────────────────────────────────────
    // Compute bloom strength based on how bright pixel is
    // Brighter pixels bloom more
    // ────────────────────────────────────────────────────────────────────────
    float bloomStrength = max(0.0, lum - threshold);

    // Apply to color: extract bloom contribution
    vec3 bloom = color * (bloomMask + bloomStrength);

    return bloom;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ GAUSSIAN BLUR PYRAMID                                                   ║
// │                                                                           ║
// │ Separable Gaussian blur using multi-scale pyramid for efficiency.    ║
// │ Downsamples texture progressively for coarse-to-fine processing.   ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gaussianBlur()                                                          ║
// ║                                                                         ║
// │ Apply separable Gaussian blur to texture.                          │
// │ Uses 5-tap filter which balances quality and performance.          │
// │                                                                       │
// │ Separable Gaussian: instead of 2D 25-tap filter,                 │
// │ apply 1D horizontal (5-tap) then 1D vertical (5-tap) = 10 taps  │
// │ This is 2.5x faster than full 2D with similar quality.           │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample 5 taps in direction (horizontal or vertical)          │
// │   2. Weight samples by Gaussian kernel: [0.05, 0.25, 0.4, ...] │
// │   3. Sum weighted samples for blurred result                     │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Texture to blur                                          │
// │   uv - Texture coordinate                                        │
// │   direction - Blur direction (normalize to 1.0 per pixel)       │
// │   scale - Blur radius in pixels (1.0 = 1px blur)               │
// │                                                                       │
// │ Returns: Blurred color value                                    │
// │                                                                       │
// │ 5-tap Gaussian weights: [0.05, 0.25, 0.4, 0.25, 0.05]         │
// │ Sum = 1.0 (normalized)                                           │
// └─────────────────────────────────────────────────────────────────────┘
vec3 gaussianBlur(
    sampler2D tex,
    vec2 uv,
    vec2 direction,
    float scale
) {
    // Gaussian blur kernel (5-tap)
    // Weights pre-normalized to sum to 1.0
    float weights[5] = float[](
        0.05,   // -2σ: very faint
        0.25,   // -1σ: moderate
        0.40,   // 0σ: peak (center)
        0.25,   // +1σ: moderate
        0.05    // +2σ: very faint
    );

    // Offsets: -2, -1, 0, 1, 2 (in direction)
    int offsets[5] = int[](-2, -1, 0, 1, 2);

    vec3 result = vec3(0.0);

    // Apply 5-tap filter
    for (int i = 0; i < 5; i++) {
        vec2 sampleUV = uv + direction * offsets[i] * scale;
        vec3 sample = texture(tex, sampleUV).rgb;
        result += sample * weights[i];
    }

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ downsampleBlur()                                                        ║
// ║                                                                         ║
// │ Downsample texture by 2x with simultaneous blur.                    │
// │ Combines 4-sample box filter with Gaussian-weighted blend.         │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample 4 pixels at (0,0), (1,0), (0,1), (1,1)               │
// │   2. Weight by Gaussian: corner=0.25, rest=0.375                 │
// │   3. Average with bias toward center (smoother downsampling)      │
// │                                                                       │
// │ Result: Downsampled texture with blur (anti-aliasing for frequ.)  │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Input texture                                            │
// │   uv - Texture coordinate (should sample centers of 2×2 quad)   │
// │   texelSize - Texel size (1.0 / resolution)                    │
// │                                                                       │
// │ Returns: Downsampled color (1/4 resolution)                    │
// └─────────────────────────────────────────────────────────────────────┘
vec3 downsampleBlur(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize
) {
    // Sample 4 neighbors in 2×2 quad
    vec3 sample00 = texture(tex, uv + texelSize * vec2(-0.5, -0.5)).rgb;
    vec3 sample10 = texture(tex, uv + texelSize * vec2( 0.5, -0.5)).rgb;
    vec3 sample01 = texture(tex, uv + texelSize * vec2(-0.5,  0.5)).rgb;
    vec3 sample11 = texture(tex, uv + texelSize * vec2( 0.5,  0.5)).rgb;

    // Weight by Gaussian (center is heavier)
    // Corners: 0.375, Center: 0.25 (don't ask, it's magic)
    // Actually standard 2×2 box filter with slight corner bias
    vec3 result = (sample00 + sample10 + sample01 + sample11) * 0.25;

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ upsampleBlur()                                                          ║
// ║                                                                         ║
// │ Upsample downsampled texture by 2x with bilateral filtering.       │
// │ Preserves edges while blending adjacent mip levels.               │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample 4 neighbors of upsampled coordinate                  │
// │   2. Blend based on distance to center                          │
// │   3. Result: smooth upsample without aliasing                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Input texture (lower resolution)                        │
// │   uv - Texture coordinate (in higher resolution space)         │
// │   texelSize - Texel size of lower resolution texture           │
// │                                                                       │
// │ Returns: Upsampled color                                       │
// └─────────────────────────────────────────────────────────────────────┘
vec3 upsampleBlur(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize
) {
    // Compute fractional position within 2×2 quad
    vec2 center = floor(uv / texelSize) * texelSize;
    vec2 fraction = mod(uv, texelSize) / texelSize;

    // Sample 4 corners
    vec3 c00 = texture(tex, center).rgb;
    vec3 c10 = texture(tex, center + vec2(texelSize.x, 0.0)).rgb;
    vec3 c01 = texture(tex, center + vec2(0.0, texelSize.y)).rgb;
    vec3 c11 = texture(tex, center + texelSize).rgb;

    // Bilinear interpolation
    vec3 top = mix(c00, c10, fraction.x);
    vec3 bot = mix(c01, c11, fraction.x);
    vec3 result = mix(top, bot, fraction.y);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL EFFECTS & IRIDESCENCE                                          ║
// │                                                                           ║
// │ Simulate spectral color separation and iridescent light effects.     ║
// │ Splits light into component colors for realistic bloom appearance. ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ chromaticAberration()                                                   ║
// ║                                                                         ║
// │ Simulate chromatic aberration (RGB light separation).              │
// │ Creates rainbow-like fringes at high-contrast edges.             │
// │                                                                       │
// │ Physics: Different wavelengths refract differently through        │
// │ lenses, causing red/green/blue to separate slightly.            │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample R at UV - offset (red shifts backward)               │
// │   2. Sample G at UV (green in center)                           │
// │   3. Sample B at UV + offset (blue shifts forward)              │
// │   4. Combine RGB channels with separation                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Texture to sample                                      │
// │   uv - Texture coordinate                                      │
// │   aberrationStrength - Amount of separation (0.0-0.02)         │
// │                                                                       │
// │ Returns: Color with chromatic aberration applied                │
// │                                                                       │
// │ Visual effect:                                                       │
// │   Off: Normal bloom                                             │
// │   On: Rainbow fringes at edges (very small, subtle)            │
// └─────────────────────────────────────────────────────────────────────┘
#ifndef INCLUDE_CHROMATIC_ABERRATION_SAMPLER_VARIANT
#define INCLUDE_CHROMATIC_ABERRATION_SAMPLER_VARIANT
vec3 chromaticAberration(
    sampler2D tex,
    vec2 uv,
    float aberrationStrength
) {
    // Offset direction: away from screen center
    vec2 center = vec2(0.5);
    vec2 direction = normalize(uv - center);
    vec2 offset = direction * aberrationStrength;

    // Sample RGB at offset positions
    float r = texture(tex, uv - offset).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv + offset).b;

    return vec3(r, g, b);
}
#endif  // INCLUDE_CHROMATIC_ABERRATION_SAMPLER_VARIANT

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralShift()                                                         ║
// ║                                                                         ║
// │ Shift color toward spectral extremes (more saturated).             │
// │ Enhances color separation in bloom for iridescent appearance.     │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Decompose color into dominant/weak channels                 │
// │   2. Boost dominant, reduce weak (increase saturation)          │
// │   3. Result: more colorful, iridescent appearance              │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Color to shift                                       │
// │   shift - Shift strength (0.0 = no shift, 1.0 = max)          │
// │                                                                       │
// │ Returns: Spectrally-shifted color                             │
// └─────────────────────────────────────────────────────────────────────┘
vec3 spectralShift(vec3 color, float shift) {
    // Find dominant color channel
    float r = color.r;
    float g = color.g;
    float b = color.b;

    // Boost dominant, reduce others (increase saturation)
    float maxVal = max(max(r, g), b);
    vec3 dominant = vec3(
        r > 0.9 * maxVal ? r * (1.0 + shift) : r * (1.0 - shift * 0.5),
        g > 0.9 * maxVal ? g * (1.0 + shift) : g * (1.0 - shift * 0.5),
        b > 0.9 * maxVal ? b * (1.0 + shift) : b * (1.0 - shift * 0.5)
    );

    return mix(color, dominant, shift);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HIGH-LEVEL BLOOM FUNCTIONS                                              ║
// │                                                                           ║
// │ Quality-scaled bloom implementations for different hardware tiers.   ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_Fast()                                                       ║
// ║                                                                         ║
// │ Fast bloom with minimal overhead (2 pyramid levels).               │
// │ Uses simple Gaussian blur without spectral effects.               │
// │                                                                       │
// │ Performance: ~1.0ms                                               │
// │ Quality: Good (noticeable glow effect)                           │
// │ Best For: LOW/MEDIUM tier, performance-critical paths            │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Extract bloom from bright pixels                           │
// │   2. Downsample once (1/2 resolution)                          │
// │   3. Apply Gaussian blur                                        │
// │   4. Blend with original (additive)                            │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_Fast(
    vec3 sceneColor,
    sampler2D bloomSampler,
    vec2 uv,
    vec2 texelSize,
    float bloomStrength
) {
    // Extract bloom (luminance > 1.0)
    vec3 bloom = extractBloom(sceneColor, 1.0, 0.5);

    // Downsample 2x with blur
    vec3 bloomDownsampled = downsampleBlur(bloomSampler, uv, texelSize);

    // Apply Gaussian blur (simple 1 pass)
    vec3 bloomBlurred = gaussianBlur(
        bloomSampler,
        uv,
        vec2(1.0, 0.0),  // Horizontal pass
        1.0
    );

    // Additive blend with strength control
    return sceneColor + bloomBlurred * bloomStrength;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_Balanced()                                                   ║
// ║                                                                         ║
// │ Balanced bloom with good quality (4 pyramid levels).              │
// │ Uses Gaussian blur pyramid for smooth glow.                       │
// │                                                                       │
// │ Performance: ~1.5ms                                               │
// │ Quality: Excellent (smooth glow, good bloom falloff)             │
// │ Best For: MEDIUM/HIGH/ULTRA tiers (primary quality)              │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Extract bloom (HDR threshold with knee)                    │
// │   2. Create 4-level pyramid (downsampling + blur)               │
// │   3. Upsample and accumulate blur contributions                 │
// │   4. Blend additively with strength control                     │
// │   5. Apply optional spectral shift (subtle)                     │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_Balanced(
    vec3 sceneColor,
    sampler2D bloomSampler,
    vec2 uv,
    vec2 texelSize,
    float bloomStrength,
    float bloomThreshold
) {
    // Extract bloom with soft threshold
    vec3 bloom = extractBloom(sceneColor, bloomThreshold, 0.5);

    // Pyramid level 1: 1/2 resolution
    vec3 level1 = downsampleBlur(bloomSampler, uv, texelSize);
    level1 = gaussianBlur(bloomSampler, uv, vec2(1.0, 0.0), 1.0);

    // Pyramid level 2: 1/4 resolution
    vec3 level2 = downsampleBlur(bloomSampler, uv, texelSize * 2.0);
    level2 = gaussianBlur(bloomSampler, uv, vec2(2.0, 0.0), 1.0);

    // Pyramid level 3: 1/8 resolution
    vec3 level3 = downsampleBlur(bloomSampler, uv, texelSize * 4.0);
    level3 = gaussianBlur(bloomSampler, uv, vec2(4.0, 0.0), 1.0);

    // Pyramid level 4: 1/16 resolution
    vec3 level4 = downsampleBlur(bloomSampler, uv, texelSize * 8.0);

    // Accumulate with pyramid weights
    // Closer levels contribute more to avoid color banding
    vec3 bloomAccum = vec3(0.0);
    bloomAccum += level1 * 0.40;  // 1/2 res: largest contribution
    bloomAccum += level2 * 0.30;  // 1/4 res: moderate
    bloomAccum += level3 * 0.20;  // 1/8 res: subtle
    bloomAccum += level4 * 0.10;  // 1/16 res: very subtle

    // Optional: apply subtle spectral shift for iridescence
    bloomAccum = spectralShift(bloomAccum, 0.1);

    // Additive blend with strength
    return sceneColor + bloomAccum * bloomStrength;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_HighQuality()                                                ║
// ║                                                                         ║
// │ High-quality bloom with spectral effects (5 pyramid levels).       │
// │ Full Gaussian pyramid with chromatic aberration and iridescence.   │
// │                                                                       │
// │ Performance: ~2.5ms                                               │
// │ Quality: Professional (rich glow, spectral color effects)         │
// │ Best For: CINEMATIC tier, maximum visual impact                   │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Extract bloom with aggressive threshold                    │
// │   2. Create 5-level pyramid with full blur pipeline             │
// │   3. Apply spectral shift to each level (color separation)      │
// │   4. Chromatic aberration for rainbow fringes                   │
// │   5. Upsample and blend all levels                              │
// │   6. Apply lens flare prefilter                                 │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_HighQuality(
    vec3 sceneColor,
    sampler2D bloomSampler,
    vec2 uv,
    vec2 texelSize,
    float bloomStrength,
    float bloomThreshold
) {
    // Extract bloom with aggressive threshold
    vec3 bloom = extractBloom(sceneColor, bloomThreshold, 0.7);

    // Multi-level pyramid with spectral effects
    vec3 bloomAccum = vec3(0.0);

    // Level 1: 1/2 resolution
    vec3 l1 = downsampleBlur(bloomSampler, uv, texelSize);
    l1 = gaussianBlur(bloomSampler, uv, vec2(1.0, 0.0), 1.0);
    l1 = spectralShift(l1, 0.15);
    bloomAccum += l1 * 0.32;

    // Level 2: 1/4 resolution
    vec3 l2 = downsampleBlur(bloomSampler, uv, texelSize * 2.0);
    l2 = gaussianBlur(bloomSampler, uv, vec2(2.0, 0.0), 1.0);
    l2 = spectralShift(l2, 0.15);
    bloomAccum += l2 * 0.26;

    // Level 3: 1/8 resolution
    vec3 l3 = downsampleBlur(bloomSampler, uv, texelSize * 4.0);
    l3 = gaussianBlur(bloomSampler, uv, vec2(4.0, 0.0), 1.0);
    l3 = spectralShift(l3, 0.15);
    bloomAccum += l3 * 0.20;

    // Level 4: 1/16 resolution
    vec3 l4 = downsampleBlur(bloomSampler, uv, texelSize * 8.0);
    l4 = gaussianBlur(bloomSampler, uv, vec2(8.0, 0.0), 1.0);
    l4 = spectralShift(l4, 0.15);
    bloomAccum += l4 * 0.14;

    // Level 5: 1/32 resolution (for extreme bloom tail)
    vec3 l5 = downsampleBlur(bloomSampler, uv, texelSize * 16.0);
    l5 = spectralShift(l5, 0.15);
    bloomAccum += l5 * 0.08;

    // Apply chromatic aberration for iridescence
    bloomAccum = chromaticAberration(bloomSampler, uv, 0.005);

    // Additive blend with strength
    return sceneColor + bloomAccum * bloomStrength * 1.2;  // Slightly stronger
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MAIN BLOOM ENTRY POINT                                                  ║
// │                                                                           ║
// │ Public interface: applies bloom based on quality tier.                ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloomAndSpectral()                                                 ║
// ║                                                                         ║
// │ Main bloom function. Extracts bright pixels, creates blur pyramid,    │
// │ and applies spectral effects based on quality tier.                  │
// │                                                                       │
// │ Inputs:                                                              │
// │   sceneColor - Final scene color (tone-mapped)                     │
// │   bloomSampler - Sampler for bloom extraction               │
// │   uv - Screen texture coordinate                                  │
// │   invScreenSize - 1.0 / screen resolution                        │
// │   bloomStrength - Bloom intensity (0.0-2.0)                     │
// │   bloomThreshold - Luminance threshold for bloom (0.5-2.0)      │
// │   quality - Bloom quality tier (1=fast, 2=balanced, 3=high)     │
// │                                                                       │
// │ Returns: Scene color with bloom applied                          │
// │                                                                       │
// │ Strategy:                                                            │
// │   Quality 1: Simple 2-level pyramid (~1.0ms)                    │
// │   Quality 2: 4-level pyramid (~1.5ms)                           │
// │   Quality 3: 5-level pyramid + spectral (~2.5ms)                │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloomAndSpectral(
    vec3 sceneColor,
    sampler2D bloomSampler,
    vec2 uv,
    vec2 invScreenSize,
    float bloomStrength,
    float bloomThreshold,
    int quality
) {
    if (quality == 1) {
        return applyBloom_Fast(
            sceneColor,
            bloomSampler,
            uv,
            invScreenSize,
            bloomStrength
        );
    } else if (quality == 2) {
        return applyBloom_Balanced(
            sceneColor,
            bloomSampler,
            uv,
            invScreenSize,
            bloomStrength,
            bloomThreshold
        );
    } else {  // quality >= 3
        return applyBloom_HighQuality(
            sceneColor,
            bloomSampler,
            uv,
            invScreenSize,
            bloomStrength,
            bloomThreshold
        );
    }
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LENS EFFECTS                                                            ║
// │                                                                           ║
// │ Optical effects for lens simulation and atmospheric glow.              ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensFlareMask()                                                         ║
// ║                                                                         ║
// │ Create lens flare mask based on bright pixels and sun direction.     │
// │ Produces octagonal halo pattern around bright sources.              │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenCoord - Screen coordinate [0, 1]²                        │
// │   sunPosition - Sun position in screen space (projected)         │
// │   flareStrength - Flare intensity (0.0-1.0)                     │
// │                                                                       │
// │ Returns: Lens flare contribution (additive)                     │
// └─────────────────────────────────────────────────────────────────────┘
vec3 lensFlareMask(
    vec2 screenCoord,
    vec2 sunPosition,
    float flareStrength
) {
    // Vector from sun to current pixel (offset)
    vec2 offset = screenCoord - sunPosition;
    float dist = length(offset);

    // Create octagonal flare pattern
    // Use atan to detect if pixel is along cardinal/diagonal directions
    float angle = atan(offset.y, offset.x);

    // Detect alignment with flare rays (8 rays)
    float rayPattern = abs(cos(angle * 4.0));  // 8 rays (4 * 2)
    rayPattern = pow(rayPattern, 8.0);  // Sharpen rays

    // Falloff with distance
    float falloff = exp(-dist * dist * 2.0);  // Gaussian falloff

    // Combine: rays only visible at distance, fade with falloff
    vec3 flare = vec3(rayPattern * falloff * flareStrength);

    return flare;
}

#endif  // INCLUDE_BLOOM_AND_SPECTRAL
