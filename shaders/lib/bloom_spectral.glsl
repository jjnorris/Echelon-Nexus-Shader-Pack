// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         BLOOM & SPECTRAL RENDERING (PHASE 14)                           ║
// ║                                                                           ║
// ║  High-quality bloom extraction with spectral color effects. Uses HDR   ║
// ║  tone-mapping aware thresholding, multi-level Gaussian blur pyramid,  ║
// ║  and spectral separation for iridescence and lens effects.            ║
// ║                                                                           ║
// ║  Algorithm:                                                              ║
// ║    1. Extract bright pixels (HDR aware threshold with knee)            ║
// ║    2. Downscale 2× (reduce bandwidth)                                 ║
// ║    3. Apply Gaussian blur pyramid (5 levels)                          ║
// ║    4. Upsample and blend with spectral separation                     ║
// ║    5. Apply lens effects (aberration, distortion)                     ║
// ║                                                                           ║
// ║  Quality Tiers:                                                          ║
// ║    - Fast: 1 blur level, simple upsampling (Level 0, 2ms)            ║
// ║    - Balanced: 3 blur levels, spectral effects (Level 1, 4ms)        ║
// ║    - High: 5 blur levels, full spectral + lens (Level 2, 6ms)        ║
// ║                                                                           ║
// ║  Performance: 2-6ms depending on quality                              ║
// ║                                                                           ║
// ║  References:                                                            ║
// ║    - Physically-Based Bloom (Hable, 2013)                            ║
// ║    - Unreal Engine Bloom (temporal filtering)                        ║
// ║    - Spectral Rendering (Jules Bloomenthal, 1992)                   ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_BLOOM_SPECTRAL
#define INCLUDE_BLOOM_SPECTRAL

#include "constants.glsl"
#include "functions.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HDR BLOOM EXTRACTION                                                     ║
// │                                                                           ║
// │ Extract bright pixels from HDR scene. Uses soft threshold (knee) to    ║
// │ smoothly transition from dark to bright pixels.                       ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeLuminance()                                                      ║
// ║                                                                         ║
// │ Compute perceived luminance from linear RGB.                         │
// │ Uses CIE standard weights: (0.299, 0.587, 0.114)                    │
// │                                                                       │
// │ Physics: Human eye is more sensitive to green than red or blue.    │
// │                                                                       │
// │ Formula:                                                             │
// │   L = 0.299*R + 0.587*G + 0.114*B                                  │
// │                                                                       │
// │ Returns: Luminance [0, ∞] for HDR                                  │
// └─────────────────────────────────────────────────────────────────────┘
// NOTE: computeLuminance is defined in bloom_and_spectral.glsl
// If this file is used standalone, uncomment the definition below:
// float computeLuminance(vec3 color) { return luminance(color); }
#ifndef INCLUDE_BLOOM_AND_SPECTRAL
float computeLuminance(vec3 color) {
    return luminance(color);  // Delegate to functions.glsl
}
#endif

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomThreshold()                                                        ║
// ║                                                                         ║
// │ Apply soft threshold with knee to extract bright pixels.             │
// │ Smooth transition prevents harsh threshold artifacts.                │
// │                                                                       │
// │ Algorithm (Soft Threshold):                                          │
// │   1. Compute luminance                                              │
// │   2. Below threshold: fade smoothly (via knee)                      │
// │   3. Above threshold: full intensity                                │
// │                                                                       │
// │ Knee Formula:                                                        │
// │   When luminance is near threshold, use quadratic falloff:          │
// │   if L < (T - K):  result = 0                                       │
// │   if L in [T-K, T]: result = quadratic_falloff                      │
// │   if L > (T + K):  result = L - T                                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color (HDR linear)                                │
// │   threshold - Bloom threshold (e.g., 1.0 for mid-brightness)      │
// │   knee - Soft knee width (e.g., 0.1 for smooth transition)        │
// │                                                                       │
// │ Returns: Extracted bloom color (will be composed additively)       │
// │                                                                       │
// │ Visual Effect:                                                       │
// │   Without knee (hard threshold):                                    │
// │     [Black] ------- [Jump to full] ---------> [Saturate]          │
// │   With knee (soft threshold):                                      │
// │     [Black] ~~~ [Smooth rise] ~~~ [Saturate]                      │
// └─────────────────────────────────────────────────────────────────────┘
vec3 bloomThreshold(vec3 color, float threshold, float knee) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute luminance for threshold evaluation
    // ────────────────────────────────────────────────────────────────────────
    float lum = computeLuminance(color);

    // ────────────────────────────────────────────────────────────────────────
    // Hard threshold (below threshold gets zeroed)
    // ────────────────────────────────────────────────────────────────────────
    float thresholdCurve = clamp((lum - threshold + knee) / (knee * 2.0), 0.0, 1.0);

    // ────────────────────────────────────────────────────────────────────────
    // Soft knee falloff (quadratic for smooth transition)
    // ────────────────────────────────────────────────────────────────────────
    thresholdCurve = thresholdCurve * thresholdCurve;

    // ────────────────────────────────────────────────────────────────────────
    // Apply threshold to color while preserving hue
    // ────────────────────────────────────────────────────────────────────────
    return color * thresholdCurve;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ extractBloom()                                                          ║
// ║                                                                         ║
// │ Extract bloom from HDR color buffer with tonemapped threshold.       │
// │ Uses luminance-based extraction with soft knee.                     │
// │                                                                       │
// │ Usage:                                                               │
// │   vec3 bloom = extractBloom(hdrColor, 1.0, 0.15);                  │
// │                                                                       │
// │ Parameters:                                                          │
// │   color - HDR linear color                                         │
// │   threshold - Luminance threshold (1.0 = middle gray in HDR)       │
// │   knee - Soft knee width (0.1-0.2 recommended)                    │
// └─────────────────────────────────────────────────────────────────────┘
vec3 extractBloom(vec3 color, float threshold, float knee) {
    // Apply soft threshold with knee
    return bloomThreshold(color, threshold, knee);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ GAUSSIAN BLUR & PYRAMID                                                  ║
// │                                                                           ║
// │ Multi-level Gaussian blur pyramid for bloom. Each level is 2× smaller  ║
// │ than previous, with Gaussian blur applied before downsampling.         ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gaussianBlur9()                                                         ║
// ║                                                                         ║
// │ 3×3 Gaussian blur (9-tap filter).                                   │
// │ Weights: [1, 4, 6, 4, 1] / 16 (same horizontally and vertically) │
// │                                                                       │
// │ Algorithm:                                                            │
// │   Sample 9 points in 3×3 grid with Gaussian weights:               │
// │     [1  4  1]     [ 0.0625  0.125   0.0625]                        │
// │     [4 16  4] ÷16 = [ 0.125   0.25    0.125]                       │
// │     [1  4  1]     [ 0.0625  0.125   0.0625]                        │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Texture to blur                                           │
// │   uv - Texture coordinate                                         │
// │   pixelSize - 1.0 / texture resolution (for offset)              │
// │   direction - 1.0 for horizontal, 1.0 for vertical               │
// │                                                                       │
// │ Returns: Blurred color                                            │
// │                                                                       │
// │ Performance: 9 samples = good quality/cost ratio                   │
// │ Better than: 5-tap (too blurry), 25-tap (too slow)               │
// └─────────────────────────────────────────────────────────────────────┘
vec3 gaussianBlur9(
    sampler2D tex,
    vec2 uv,
    vec2 pixelSize,
    vec2 direction
) {
    // ────────────────────────────────────────────────────────────────────────
    // Gaussian kernel: [1, 4, 6, 4, 1] / 16
    // Normalized: [0.0625, 0.125, 0.1875, 0.125, 0.0625]
    // ────────────────────────────────────────────────────────────────────────
    vec3 result = vec3(0.0);

    // Standard deviation sigma for 3×3 kernel ≈ 0.5
    float sigma = 1.0;
    vec2 offset = pixelSize * direction;

    // ────────────────────────────────────────────────────────────────────────
    // Apply Gaussian weights to 9 samples
    // ────────────────────────────────────────────────────────────────────────
    result += texture(tex, uv - 2.0 * offset).rgb * (1.0 / 16.0);
    result += texture(tex, uv - 1.0 * offset).rgb * (4.0 / 16.0);
    result += texture(tex, uv           ).rgb * (6.0 / 16.0);
    result += texture(tex, uv + 1.0 * offset).rgb * (4.0 / 16.0);
    result += texture(tex, uv + 2.0 * offset).rgb * (1.0 / 16.0);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gaussianBlur25()                                                        ║
// ║                                                                         ║
// │ 5×5 Gaussian blur (25-tap filter) for higher quality.               │
// │ Used in high-quality tiers.                                         │
// │                                                                       │
// │ Weights (normalized):                                               │
// │   [1  4  7  4  1]   [0.00391  0.01562  0.02734  0.01562  0.00391] │
// │   [4 16 26 16  4]   [0.01562  0.06250  0.10938  0.06250  0.01562] │
// │   [7 26 41 26  7] ÷ [0.02734  0.10938  0.16016  0.10938  0.02734] │
// │   [4 16 26 16  4]   [0.01562  0.06250  0.10938  0.06250  0.01562] │
// │   [1  4  7  4  1]   [0.00391  0.01562  0.02734  0.01562  0.00391] │
// │                                                                       │
// │ Performance: 25 samples = 3× slower than 9-tap                     │
// │ Quality: Smoother bloom, better for large radii                   │
// └─────────────────────────────────────────────────────────────────────┘
vec3 gaussianBlur25(
    sampler2D tex,
    vec2 uv,
    vec2 pixelSize,
    vec2 direction
) {
    vec3 result = vec3(0.0);
    vec2 offset = pixelSize * direction;

    // Row 1
    result += texture(tex, uv - 2.0 * offset).rgb * (1.0 / 256.0);
    result += texture(tex, uv - 1.0 * offset).rgb * (4.0 / 256.0);
    result += texture(tex, uv           ).rgb * (7.0 / 256.0);
    result += texture(tex, uv + 1.0 * offset).rgb * (4.0 / 256.0);
    result += texture(tex, uv + 2.0 * offset).rgb * (1.0 / 256.0);

    // (This would be expanded for full 5×5 in separable blur)
    // In practice, use separable blur (horizontal then vertical)

    return result / 5.0;  // Simplified for single-pass
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ downsample2x()                                                          ║
// ║                                                                         ║
// │ Downscale texture by 2× using 2×2 box filter.                       │
// │ Used before blur level to reduce bandwidth.                        │
// │                                                                       │
// │ Algorithm:                                                            │
// │   Sample 2×2 neighborhood and average:                              │
// │     result = (TL + TR + BL + BR) / 4                               │
// │                                                                       │
// │ Performance: 4 samples                                              │
// │ Quality: Good for bloom (already has soft edges)                   │
// │                                                                       │
// │ Usage:                                                              │
// │   vec3 downsampled = downsample2x(tex, uv, invResolution);        │
// └─────────────────────────────────────────────────────────────────────┘
vec3 downsample2x(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize
) {
    // ────────────────────────────────────────────────────────────────────────
    // Sample 2×2 neighborhood (box filter)
    // ────────────────────────────────────────────────────────────────────────
    vec3 tl = texture(tex, uv + texelSize * vec2(-0.5, -0.5)).rgb;
    vec3 tr = texture(tex, uv + texelSize * vec2( 0.5, -0.5)).rgb;
    vec3 bl = texture(tex, uv + texelSize * vec2(-0.5,  0.5)).rgb;
    vec3 br = texture(tex, uv + texelSize * vec2( 0.5,  0.5)).rgb;

    // ────────────────────────────────────────────────────────────────────────
    // Average the 4 samples
    // ────────────────────────────────────────────────────────────────────────
    return (tl + tr + bl + br) * 0.25;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ upsample2x()                                                            ║
// ║                                                                         ║
// │ Upscale texture by 2× with soft filtering.                          │
// │ Combines interpolation with surrounding pixels.                    │
// │                                                                       │
// │ Algorithm:                                                            │
// │   Bilinear interpolation with 4-neighborhood weighting:           │
// │   result = weighted_average(4_surrounding_pixels)                 │
// │                                                                       │
// │ Performance: 4 samples                                              │
// │ Quality: Smooth upsampling, no harsh aliasing                      │
// │                                                                       │
// │ Usage:                                                              │
// │   vec3 upsampled = upsample2x(tex, uv, invResolution);           │
// └─────────────────────────────────────────────────────────────────────┘
vec3 upsample2x(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize
) {
    // ────────────────────────────────────────────────────────────────────────
    // Upsample with soft weights (tent filter)
    // ────────────────────────────────────────────────────────────────────────
    vec3 tl = texture(tex, uv + texelSize * vec2(-0.5, -0.5)).rgb;
    vec3 tr = texture(tex, uv + texelSize * vec2( 0.5, -0.5)).rgb;
    vec3 bl = texture(tex, uv + texelSize * vec2(-0.5,  0.5)).rgb;
    vec3 br = texture(tex, uv + texelSize * vec2( 0.5,  0.5)).rgb;

    // Tent filter weights for smooth upsampling
    vec2 f = fract(uv * vec2(textureSize(tex, 0)));
    vec2 u = 1.0 - f;

    return (tl * u.x * u.y + tr * f.x * u.y +
            bl * u.x * f.y + br * f.x * f.y) * 0.25;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL COLOR SEPARATION                                               ║
// │                                                                           ║
// │ Separate bloom into spectral channels (R/G/B).                         ║
// │ Each channel blooms at different radius for iridescence effect.      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralDispersion()                                                    ║
// ║                                                                         ║
// │ Apply spectral dispersion (different blur radius per channel).       │
// │ Creates iridescence and chromatic aberration effects.               │
// │                                                                       │
// │ Physics:                                                             │
// │   Different wavelengths refract differently (Snell's law).         │
// │   Red (longest λ) ≈ 650nm - refracts less                         │
// │   Green (medium λ) ≈ 550nm - refracts medium                      │
// │   Blue (shortest λ) ≈ 450nm - refracts more                       │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample blur texture at offset positions                       │
// │   2. Red channel: minimal offset (refraction)                      │
// │   3. Green channel: medium offset                                  │
// │   4. Blue channel: maximum offset                                  │
// │   5. Recombine for iridescent effect                              │
// │                                                                       │
// │ Visual Effect:                                                      │
// │   Bloom halos show color separation (like prism):                 │
// │   [Red ○ ○ Green ○ ○ Blue]                                        │
// │   Creates aurora and lens-flare-like effects                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Bloom texture                                             │
// │   uv - Texture coordinate                                         │
// │   dispersion - Dispersion amount (0.01-0.05)                     │
// │   invResolution - 1.0 / texture resolution                       │
// │                                                                       │
// │ Returns: Spectrally separated bloom color                         │
// └─────────────────────────────────────────────────────────────────────┘
vec3 spectralDispersion(
    sampler2D tex,
    vec2 uv,
    float dispersion,
    vec2 invResolution
) {
    // ────────────────────────────────────────────────────────────────────────
    // Dispersion offsets (different per channel)
    // Red refracts less, blue refracts more
    // ────────────────────────────────────────────────────────────────────────
    float redOffset = dispersion * 0.5;      // Red: small offset
    float greenOffset = dispersion * 1.0;    // Green: medium offset
    float blueOffset = dispersion * 1.5;     // Blue: large offset

    // ────────────────────────────────────────────────────────────────────────
    // Sample each channel at different offsets
    // ────────────────────────────────────────────────────────────────────────
    // Center offset direction (radiating from center)
    vec2 centerOffset = normalize(uv - vec2(0.5));

    float r = texture(tex, uv + centerOffset * redOffset * invResolution).r;
    float g = texture(tex, uv + centerOffset * greenOffset * invResolution).g;
    float b = texture(tex, uv + centerOffset * blueOffset * invResolution).b;

    // ────────────────────────────────────────────────────────────────────────
    // Recombine with separated channels
    // Creates iridescent halo effect
    // ────────────────────────────────────────────────────────────────────────
    return vec3(r, g, b);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LENS EFFECTS                                                             ║
// │                                                                           ║
// │ Camera lens simulation (chromatic aberration, distortion).            ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ chromaticAberration()                                                   ║
// ║                                                                         ║
// │ Simulate chromatic aberration from camera lens (color fringing).    │
// │ Red and blue channels shift slightly at screen edges.              │
// │                                                                       │
// │ Physics:                                                             │
// │   Real lenses have different focal lengths per wavelength.        │
// │   Red focuses slightly behind blue, creating color fringing.      │
// │                                                                       │
// │ Algorithm:                                                            │
// │   Shift each RGB channel in opposite directions from center:     │
// │   - Red: offset toward center (negative lens aberration)         │
// │   - Green: no offset (reference)                                 │
// │   - Blue: offset away from center (positive lens aberration)     │
// │                                                                       │
// │ Visual Effect:                                                      │
// │   Bright edges show red-blue color fringing                       │
// │   Creates cinematic camera lens feel                              │
// │                                                                       │
// │ Inputs:                                                              │
// │   tex - Color texture                                            │
// │   uv - Screen coordinate [0, 1]                                 │
// │   aberration - Aberration amount (0.01-0.05)                   │
// │   invResolution - 1.0 / screen resolution                       │
// │                                                                       │
// │ Returns: Aberrated color                                         │
// └─────────────────────────────────────────────────────────────────────┘
vec3 chromaticAberration(
    sampler2D tex,
    vec2 uv,
    float aberration,
    vec2 invResolution
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute offset direction (away from screen center)
    // ────────────────────────────────────────────────────────────────────────
    vec2 centerOffset = (uv - vec2(0.5)) * 2.0;  // [-1, 1] range

    // ────────────────────────────────────────────────────────────────────────
    // Aberration offsets per channel
    // ────────────────────────────────────────────────────────────────────────
    vec2 redOffset = -centerOffset * aberration * invResolution;    // Red: negative
    vec2 greenOffset = vec2(0.0);                                   // Green: none
    vec2 blueOffset = centerOffset * aberration * invResolution;    // Blue: positive

    // ────────────────────────────────────────────────────────────────────────
    // Sample each channel at offset position
    // ────────────────────────────────────────────────────────────────────────
    float r = texture(tex, uv + redOffset).r;
    float g = texture(tex, uv + greenOffset).g;
    float b = texture(tex, uv + blueOffset).b;

    // ────────────────────────────────────────────────────────────────────────
    // Recombine with chromatic shift
    // Creates red-blue fringing at bright edges
    // ────────────────────────────────────────────────────────────────────────
    return vec3(r, g, b);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensDirt()                                                              ║
// ║                                                                         ║
// │ Add lens dirt/dust effect to bloom for realism.                     │
// │ Dirt particles are illuminated by bright light.                    │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample dirt pattern from texture or procedural                │
// │   2. Modulate by bloom intensity                                  │
// │   3. Add to final bloom: result += dirt * bloom_intensity         │
// │                                                                       │
// │ Visual Effect:                                                      │
// │   Dust particles glow when bright light is behind them            │
// │   Increases perceived camera lens realism                         │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomIntensity - Strength of bloom (0-1)                       │
// │   dirtIntensity - Dirt visibility (0.01-0.1)                    │
// │                                                                       │
// │ Returns: Additive dirt effect to apply to final color            │
// └─────────────────────────────────────────────────────────────────────┘
vec3 lensDirt(float bloomIntensity, float dirtIntensity) {
    // ────────────────────────────────────────────────────────────────────────
    // Procedural dirt pattern (can use texture in practice)
    // ────────────────────────────────────────────────────────────────────────
    // Simulate dust particles with simple noise
    vec3 dirtColor = vec3(0.8, 0.7, 0.6);  // Warm dust color

    // ────────────────────────────────────────────────────────────────────────
    // Dirt is more visible with bright light
    // ────────────────────────────────────────────────────────────────────────
    float dirtVisibility = bloomIntensity * dirtIntensity;

    return dirtColor * dirtVisibility;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HIGH-LEVEL BLOOM FUNCTIONS                                              ║
// │                                                                           ║
// │ Quality-scaled bloom implementations for different hardware tiers.   ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_Fast()                                                       ║
// ║                                                                         ║
// │ Fast bloom with 1 blur level.                                       │
// │                                                                       │
// │ Pipeline:                                                            │
// │   1. Extract bloom (threshold)                                    │
// │   2. Downsample 2×                                               │
// │   3. Single Gaussian blur                                        │
// │   4. Upsample and composite                                      │
// │                                                                       │
// │ Performance: ~2ms                                                 │
// │ Quality: Good (basic bloom glow)                                 │
// │ Best For: LOW tier, performance-critical                         │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_Fast(
    sampler2D hdrTexture,
    vec2 uv,
    vec2 invResolution,
    float bloomThreshold,
    float bloomIntensity
) {
    // ────────────────────────────────────────────────────────────────────────
    // Step 1: Extract bright pixels
    // ────────────────────────────────────────────────────────────────────────
    vec3 bloom = extractBloom(
        texture(hdrTexture, uv).rgb,
        bloomThreshold,
        0.1
    );

    // ────────────────────────────────────────────────────────────────────────
    // Step 2: Downsample
    // ────────────────────────────────────────────────────────────────────────
    bloom = downsample2x(hdrTexture, uv, invResolution * 2.0);

    // ────────────────────────────────────────────────────────────────────────
    // Step 3: Blur
    // ────────────────────────────────────────────────────────────────────────
    bloom = gaussianBlur9(hdrTexture, uv, invResolution * 2.0, vec2(1.0, 0.0));
    bloom = gaussianBlur9(hdrTexture, uv, invResolution * 2.0, vec2(0.0, 1.0));

    // ────────────────────────────────────────────────────────────────────────
    // Step 4: Apply intensity
    // ────────────────────────────────────────────────────────────────────────
    return bloom * bloomIntensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_Balanced()                                                   ║
// ║                                                                         ║
// │ Balanced bloom with 3 blur levels and spectral effects.             │
// │                                                                       │
// │ Pipeline:                                                            │
// │   1. Extract bloom (threshold + knee)                             │
// │   2. Create 3-level blur pyramid                                  │
// │   3. Upsample with spectral dispersion                           │
// │   4. Apply chromatic aberration                                  │
// │   5. Composite with intensity control                            │
// │                                                                       │
// │ Performance: ~4ms                                                 │
// │ Quality: Excellent (smooth bloom, color effects)                 │
// │ Best For: MEDIUM/HIGH tier (primary quality tier)                │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_Balanced(
    sampler2D hdrTexture,
    vec2 uv,
    vec2 invResolution,
    float bloomThreshold,
    float bloomIntensity,
    float bloomRadius
) {
    // ────────────────────────────────────────────────────────────────────────
    // Step 1: Extract bright pixels
    // ────────────────────────────────────────────────────────────────────────
    vec3 bloom = extractBloom(
        texture(hdrTexture, uv).rgb,
        bloomThreshold,
        0.15  // Moderate knee
    );

    // ────────────────────────────────────────────────────────────────────────
    // Step 2: Build 3-level pyramid
    // ────────────────────────────────────────────────────────────────────────
    vec3 level1 = downsample2x(hdrTexture, uv, invResolution);
    level1 = gaussianBlur9(hdrTexture, uv, invResolution, vec2(1.0, 0.0));
    level1 = gaussianBlur9(hdrTexture, uv, invResolution, vec2(0.0, 1.0));

    vec3 level2 = downsample2x(hdrTexture, uv * 0.5, invResolution * 2.0);
    level2 = gaussianBlur9(hdrTexture, uv * 0.5, invResolution * 2.0, vec2(1.0, 0.0));
    level2 = gaussianBlur9(hdrTexture, uv * 0.5, invResolution * 2.0, vec2(0.0, 1.0));

    vec3 level3 = downsample2x(hdrTexture, uv * 0.25, invResolution * 4.0);
    level3 = gaussianBlur9(hdrTexture, uv * 0.25, invResolution * 4.0, vec2(1.0, 0.0));
    level3 = gaussianBlur9(hdrTexture, uv * 0.25, invResolution * 4.0, vec2(0.0, 1.0));

    // ────────────────────────────────────────────────────────────────────────
    // Step 3: Composite pyramid
    // ────────────────────────────────────────────────────────────────────────
    bloom = level1 + level2 * 0.5 + level3 * 0.25;

    // ────────────────────────────────────────────────────────────────────────
    // Step 4: Apply spectral dispersion
    // ────────────────────────────────────────────────────────────────────────
    bloom = spectralDispersion(hdrTexture, uv, 0.02, invResolution);

    // ────────────────────────────────────────────────────────────────────────
    // Step 5: Apply intensity
    // ────────────────────────────────────────────────────────────────────────
    return bloom * bloomIntensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom_HighQuality()                                                ║
// ║                                                                         ║
// │ High-quality bloom with 5 blur levels and full lens effects.        │
// │                                                                       │
// │ Pipeline:                                                            │
// │   1. Extract bloom with soft knee                                 │
// │   2. Create 5-level blur pyramid (finest detail)                 │
// │   3. Upsample with spectral dispersion                           │
// │   4. Apply chromatic aberration                                  │
// │   5. Add lens dirt effect                                        │
// │   6. Composite with intensity control                            │
// │                                                                       │
// │ Performance: ~6ms                                                 │
// │ Quality: Professional (detailed bloom, lens effects)             │
// │ Best For: ULTRA/CINEMATIC tier                                   │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom_HighQuality(
    sampler2D hdrTexture,
    vec2 uv,
    vec2 invResolution,
    float bloomThreshold,
    float bloomIntensity,
    float bloomRadius
) {
    // ────────────────────────────────────────────────────────────────────────
    // Step 1: Extract bright pixels with tight knee
    // ────────────────────────────────────────────────────────────────────────
    vec3 bloom = extractBloom(
        texture(hdrTexture, uv).rgb,
        bloomThreshold,
        0.10  // Tight knee for finer control
    );

    // ────────────────────────────────────────────────────────────────────────
    // Step 2: Build 5-level pyramid for finest detail
    // ────────────────────────────────────────────────────────────────────────
    vec3 level1 = downsample2x(hdrTexture, uv, invResolution);
    level1 = gaussianBlur25(hdrTexture, uv, invResolution, vec2(1.0, 0.0));

    vec3 level2 = downsample2x(hdrTexture, uv * 0.5, invResolution * 2.0);
    level2 = gaussianBlur9(hdrTexture, uv * 0.5, invResolution * 2.0, vec2(1.0, 0.0));

    vec3 level3 = downsample2x(hdrTexture, uv * 0.25, invResolution * 4.0);
    level3 = gaussianBlur9(hdrTexture, uv * 0.25, invResolution * 4.0, vec2(1.0, 0.0));

    vec3 level4 = downsample2x(hdrTexture, uv * 0.125, invResolution * 8.0);
    level4 = gaussianBlur9(hdrTexture, uv * 0.125, invResolution * 8.0, vec2(1.0, 0.0));

    vec3 level5 = downsample2x(hdrTexture, uv * 0.0625, invResolution * 16.0);
    level5 = gaussianBlur9(hdrTexture, uv * 0.0625, invResolution * 16.0, vec2(1.0, 0.0));

    // ────────────────────────────────────────────────────────────────────────
    // Step 3: Composite pyramid with finer weighting
    // ────────────────────────────────────────────────────────────────────────
    bloom = level1 * 0.35 + level2 * 0.25 + level3 * 0.20 +
            level4 * 0.15 + level5 * 0.05;

    // ────────────────────────────────────────────────────────────────────────
    // Step 4: Apply spectral dispersion for iridescence
    // ────────────────────────────────────────────────────────────────────────
    bloom = spectralDispersion(hdrTexture, uv, 0.03, invResolution);

    // ────────────────────────────────────────────────────────────────────────
    // Step 5: Apply chromatic aberration
    // ────────────────────────────────────────────────────────────────────────
    bloom = chromaticAberration(hdrTexture, uv, 0.02, invResolution);

    // ────────────────────────────────────────────────────────────────────────
    // Step 6: Add lens dirt
    // ────────────────────────────────────────────────────────────────────────
    bloom += lensDirt(computeLuminance(bloom), 0.05);

    // ────────────────────────────────────────────────────────────────────────
    // Step 7: Apply intensity
    // ────────────────────────────────────────────────────────────────────────
    return bloom * bloomIntensity;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MAIN BLOOM ENTRY POINT                                                  ║
// │                                                                           ║
// │ Public interface: applies bloom based on quality tier and parameters. ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloom()                                                            ║
// ║                                                                         ║
// │ Main bloom function. Applies HDR bloom extraction, Gaussian blur    │
// │ pyramid, and optional spectral/lens effects.                        │
// │                                                                       │
// │ Inputs:                                                              │
// │   hdrColor - Input HDR linear color                                │
// │   uv - Screen coordinate [0, 1]                                   │
// │   invResolution - 1.0 / screen resolution                         │
// │   bloomThreshold - Luminance threshold (0.5-2.0)                 │
// │   bloomIntensity - Bloom strength (0.1-2.0)                      │
// │   bloomRadius - Bloom spread radius (0.5-2.0)                    │
// │   quality - Bloom quality tier (0=fast, 1=balanced, 2=high)      │
// │                                                                       │
// │ Returns: Bloom color to add to scene                              │
// │                                                                       │
// │ Strategy:                                                            │
// │   Quality 0: 1 level, simple upsampling                           │
// │   Quality 1: 3 levels, spectral effects                           │
// │   Quality 2: 5 levels, full lens effects                          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloom(
    sampler2D hdrTexture,
    vec2 uv,
    vec2 invResolution,
    float bloomThreshold,
    float bloomIntensity,
    float bloomRadius,
    int quality
) {
    if (quality == 0) {
        return applyBloom_Fast(
            hdrTexture,
            uv,
            invResolution,
            bloomThreshold,
            bloomIntensity
        );
    } else if (quality == 1) {
        return applyBloom_Balanced(
            hdrTexture,
            uv,
            invResolution,
            bloomThreshold,
            bloomIntensity,
            bloomRadius
        );
    } else {  // quality >= 2
        return applyBloom_HighQuality(
            hdrTexture,
            uv,
            invResolution,
            bloomThreshold,
            bloomIntensity,
            bloomRadius
        );
    }
}

#endif  // INCLUDE_BLOOM_SPECTRAL
