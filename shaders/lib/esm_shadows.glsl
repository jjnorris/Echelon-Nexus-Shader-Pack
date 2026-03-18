// ===================================================================
// Exponential Shadow Maps (Phase 21)
// ===================================================================
// Fast soft shadow filtering using exponential warping.

#ifndef INCLUDE_ESM_SHADOWS
#define INCLUDE_ESM_SHADOWS

// ===================================================================
// EXPONENTIAL SHADOW MAP
// ===================================================================

// Compute visibility using ESM
// ESM stores exp(c * depth) instead of raw depth
float computeESMVisibility(
    float receiverDepth,
    float esmDepthValue,
    float exponent
) {
    // ESM visibility: V = exp(-c * (receiver_depth - shadow_depth))
    // esmDepthValue contains exp(-c * shadow_depth)

    float visibility = 1.0 / (1.0 + esmDepthValue);

    // Smooth step for better soft shadows
    return clamp(visibility * 1.1, 0.0, 1.0);
}

// Gaussian blur for shadow smoothing (ESM soft shadows)
float esmShadowBlur(
    sampler2D shadowMap,
    vec2 shadowCoord,
    float blurRadius,
    vec2 shadowMapSize
) {
    vec2 texelSize = 1.0 / shadowMapSize;
    float result = 0.0;
    float weight = 0.0;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(x, y) * texelSize * blurRadius;
            float sample = texture(shadowMap, shadowCoord + offset).r;
            float w = exp(-(float(x * x + y * y)) / (2.0 * blurRadius * blurRadius));

            result += sample * w;
            weight += w;
        }
    }

    return result / weight;
}

// ===================================================================
// VARIANCE SHADOW MAPS (VSM) IMPROVEMENT
// ===================================================================

// Reduce light bleeding in VSM/ESM
// Uses Chebychev's inequality to detect bleeding
float reduceLightBleeding(float pMax, float varianceShadow, float bleedReduction) {
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
