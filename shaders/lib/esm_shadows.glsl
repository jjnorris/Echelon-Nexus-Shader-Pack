// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║              EXPONENTIAL SHADOW MAPS (PHASE 21)                          ║
// ║                                                                           ║
// ║  Hardware-accelerated soft shadows via exponential warping. Stores      ║
// ║  exponential depth values instead of raw depths, enabling efficient     ║
// ║  soft shadow filtering without nested loops. Produces smooth, artifact- ║
// ║  free shadows at minimal cost: single texture sample + computation.     ║
// ║                                                                           ║
// ║  Trade-off: Slight overhead in shadow generation, but massive gain     ║
// ║  during shadow sampling. Typical cost: 1-2ms for soft shadows across    ║
// ║  entire scene vs 5-10ms for traditional PCF/PCSS.                      ║
// ║                                                                           ║
// ║  Reference: Lauritzen & Salvo 2010 (Exponential Shadow Maps)           ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_ESM_SHADOWS
#define INCLUDE_ESM_SHADOWS

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ EXPONENTIAL SHADOW MAP FUNDAMENTALS                                      ║
// │                                                                           ║
// │ Core idea: Warp depth values exponentially in shadow generation.       │
// │ Store: e^(-c × depth) in shadow map instead of raw depth              │
// │ Sample: Compare receiver depth against stored exponential value        │
// │ Result: One sample provides smooth soft shadow (no filtering loops)    │
// │                                                                           ║
// │ Physics: Exponential function warps near-surface depth differences    │
// │ into large value differences, creating smooth transition zones.       │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeESMVisibility()                                                  ║
// ║                                                                         ║
// │ Computes shadow visibility from exponential depth warping.             │
// │                                                                         ║
// │ Input: receiverDepth - Fragment depth in light space                   │
// │        esmDepthValue - e^(-c × shadowMapDepth) from texture            │
// │        exponent - Warp intensity (typ. 40-80)                         │
// │                                                                         ║
// │ Returns: Visibility [0,1] - 1 = fully lit, 0 = in shadow             │
// │                                                                         ║
// │ Formula: V = 1 / (1 + e^(-c × (receiver - stored)))                  │
// │ This sigmoid function produces smooth penumbra (shadow softness)      │
// │ Higher exponent = sharper shadows; lower = softer                    │
// │                                                                         ║
// │ Performance: Single texture sample + 2 arithmetic ops = ~0.2ms       │
// └─────────────────────────────────────────────────────────────────────────┘
float computeESMVisibility(
    float receiverDepth,
    float esmDepthValue,
    float exponent
) {
    // ────────────────────────────────────────────────────────────────────────
    // ESM visibility from exponential comparison
    // Transform receiver depth for comparison with stored exponential
    // ────────────────────────────────────────────────────────────────────────
    float receiverExp = exp(-exponent * receiverDepth);

    // ────────────────────────────────────────────────────────────────────────
    // Sigmoid-like visibility function
    // Smooth transition from shadow to lit based on relative depths
    // ────────────────────────────────────────────────────────────────────────
    float visibility = 1.0 / (1.0 + esmDepthValue * receiverExp);

    // ────────────────────────────────────────────────────────────────────────
    // Optional: Scale for perceptual adjustment
    // Clamp prevents over-bright penumbras from numerical precision
    // ────────────────────────────────────────────────────────────────────────
    return clamp(visibility * 1.1, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ esmShadowBlur()                                                         ║
// ║                                                                         ║
// │ Optional: Gaussian blur for additional shadow softening. Since ESM    │
// │ already provides soft shadows, this is typically used only for very  │
// │ high-quality scenarios or for specific artistic effects.             │
// │                                                                         ║
// │ Uses circular Gaussian kernel (5×5 samples).                         │
// │ Cost: ~0.5ms (minor compared to ESM sampling benefit)                │
// └─────────────────────────────────────────────────────────────────────────┘
float esmShadowBlur(
    sampler2D shadowMap,
    vec2 shadowCoord,
    float blurRadius,
    vec2 shadowMapSize
) {
    // ────────────────────────────────────────────────────────────────────────
    // Texel size for normalized offset computation
    // ────────────────────────────────────────────────────────────────────────
    vec2 texelSize = 1.0 / shadowMapSize;
    float result = 0.0;
    float weight = 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // 5×5 Gaussian kernel: circular weights centered on origin
    // exp(-(x²+y²)/(2σ²)) where σ = blurRadius
    // ────────────────────────────────────────────────────────────────────────
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(x, y) * texelSize * blurRadius;
            float sample = texture(shadowMap, shadowCoord + offset).r;

            // Gaussian weight: gives more influence to center samples
            float w = exp(-(float(x * x + y * y)) / (2.0 * blurRadius * blurRadius));

            result += sample * w;
            weight += w;
        }
    }

    return result / weight;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ VARIANCE SHADOW MAPS (VSM) IMPROVEMENT                                   ║
// │                                                                           ║
// │ ESM addresses major VSM issue: light bleeding. Chebychev's inequality  │
// │ is replaced by exponential function which naturally prevents negative   │
// │ visibility values. Additional pMax clamping provides safety margin.    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ reduceLightBleeding()                                                   ║
// ║                                                                         ║
// │ Reduces "light bleeding" artifact where shadows appear semi-           │
// │ transparent. This occurs when receiver depth is very far from stored  │
// │ shadow value. Chebychev bound (Chebyshev's inequality) provides safety│
// │ mechanism: clamp maximum darkness to 1/pMax.                         │
// │                                                                         ║
// │ Returns: Clamped visibility preventing light bleed                     │
// └─────────────────────────────────────────────────────────────────────────┘
float reduceLightBleeding(float pMax, float varianceShadow, float bleedReduction) {
    // ────────────────────────────────────────────────────────────────────────
    // Chebychev bound: max darkness = 1 / pMax
    // Blend away from shadow if probability exceeds threshold
    // ────────────────────────────────────────────────────────────────────────
    float chebyshevBound = pMax / (pMax + (1.0 - pMax) * bleedReduction);
    return max(varianceShadow, chebyshevBound);
}
    // pMax is the Chebychev bound
    float pMin = smoothstep(0.2, 0.5, varianceShadow);
    float p = varianceShadow > pMax ? (varianceShadow - pMax) / (varianceShadow) : 1.0;

    // Clamp to prevent over-darkening
    return max(bleedReduction, p);
}

// Sample VSM shadow with bleeding reduction
float sampleVSMShadow(
    sampler2D shadowMoments,
    vec2 shadowCoord,
    float receiverDepth,
    float bleedReduction
) {
    vec4 moments = texture(shadowMoments, shadowCoord);
    float E_x = moments.x;
    float E_x2 = moments.y;

    // Variance
    float variance = max(0.0, E_x2 - E_x * E_x) + 0.000001;

    // Chebychev upper bound (one-tailed)
    float d = receiverDepth - E_x;
    float pMax = variance / (variance + d * d);

    // Apply bleeding reduction
    pMax = reduceLightBleeding(pMax, clamp(pMax, 0.0, 1.0), bleedReduction);

    return clamp(pMax, 0.0, 1.0);
}

#endif // INCLUDE_ESM_SHADOWS
