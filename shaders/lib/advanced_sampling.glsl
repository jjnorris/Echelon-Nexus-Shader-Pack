// ===================================================================
// Advanced Sampling Techniques - Importance & Variance Reduction
// ===================================================================
// Implements importance-weighted sampling, multiple importance sampling (MIS),
// and filter reconstruction for TAA history blending.
//
// References:
//   - Importance Sampling for Production Rendering (Pharr et al., 2016)
//   - Temporal Reprojection Anti-Aliasing (Lottes, 2016)
//   - Filtering Distributions of Normals (Yan et al., 2016)

#ifndef INCLUDE_ADVANCED_SAMPLING
#define INCLUDE_ADVANCED_SAMPLING

#include "halton_sequence.glsl"

// ===================================================================
// RECONSTRUCTION FILTERS FOR TAA
// ===================================================================

// Box filter (1.0 in [-0.5, 0.5], 0 elsewhere)
float filterBox(vec2 offset) {
    if (abs(offset.x) <= 0.5 && abs(offset.y) <= 0.5) return 1.0;
    return 0.0;
}

// Tent/Linear filter (triangular falloff)
float filterTent(vec2 offset) {
    float x = max(1.0 - abs(offset.x), 0.0);
    float y = max(1.0 - abs(offset.y), 0.0);
    return x * y;
}

// Lanczos filter (sinc-based, reduces ringing vs linear)
// Support: 2 pixels in each direction
float filterLanczos(vec2 offset) {
    const float pi = 3.14159265359;

    if (length(offset) > 2.0) return 0.0;

    // sinc(x) = sin(pi*x) / (pi*x)
    float sincX = (abs(offset.x) < 0.001) ? 1.0 : sin(pi * offset.x) / (pi * offset.x);
    float sincY = (abs(offset.y) < 0.001) ? 1.0 : sin(pi * offset.y) / (pi * offset.y);

    // window(x) = sinc(x/2)
    float windowX = (abs(offset.x) < 0.001) ? 1.0 : sin(pi * offset.x * 0.5) / (pi * offset.x * 0.5);
    float windowY = (abs(offset.y) < 0.001) ? 1.0 : sin(pi * offset.y * 0.5) / (pi * offset.y * 0.5);

    return sincX * sincY * windowX * windowY;
}

// Catmull-Rom filter (smooth cubic spline)
float filterCatmullRom(vec2 offset) {
    float x = filterCatmullRom1D(offset.x);
    float y = filterCatmullRom1D(offset.y);
    return x * y;
}

float filterCatmullRom1D(float x) {
    float ax = abs(x);

    if (ax < 1.0) {
        return 1.0 - 2.0 * ax * ax + ax * ax * ax;
    } else if (ax < 2.0) {
        return -4.0 + 8.0 * ax - 5.0 * ax * ax + ax * ax * ax;
    }

    return 0.0;
}

// ===================================================================
// SAMPLE WEIGHTING & HISTORY BLENDING
// ===================================================================

// Estimate sample confidence based on neighborhood variance
// High variance regions -> lower history blend to reduce ghosting
float estimateSampleConfidence(vec3 sample, vec3 neighbors[8]) {
    vec3 meanNeighbor = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        meanNeighbor += neighbors[i];
    }
    meanNeighbor /= 8.0;

    float variance = 0.0;
    for (int i = 0; i < 8; i++) {
        vec3 diff = neighbors[i] - meanNeighbor;
        variance += dot(diff, diff);
    }
    variance /= 8.0;

    // Confidence = 1 / (1 + variance) - high variance = low confidence
    float confidence = 1.0 / (1.0 + sqrt(variance));
    return confidence;
}

// Clamp history to neighborhood bounds (reduce ghosting)
vec3 clampToNeighborhood(vec3 history, vec3 neighbors[8], float strength) {
    vec3 minNeighbor = neighbors[0];
    vec3 maxNeighbor = neighbors[0];

    for (int i = 1; i < 8; i++) {
        minNeighbor = min(minNeighbor, neighbors[i]);
        maxNeighbor = max(maxNeighbor, neighbors[i]);
    }

    // Expand bounds by strength for temporal stability
    vec3 center = (minNeighbor + maxNeighbor) * 0.5;
    vec3 extent = (maxNeighbor - minNeighbor) * (0.5 * strength);

    return clamp(history, center - extent, center + extent);
}

// ===================================================================
// IMPORTANCE-WEIGHTED TAA BLENDING
// ===================================================================

// Compute optimal blend factor using importance-weighted history
float computeOptimalBlendFactor(
    vec3 current,
    vec3 history,
    float sampleWeight,    // Importance weight of current sample
    float historyWeight,   // Weight of accumulated history
    float adaptivity       // How adaptive the blending should be (0-1)
) {
    // Bayesian optimal blend:
    // blend = historyWeight / (historyWeight + sampleWeight)
    float baseBlend = historyWeight / (historyWeight + sampleWeight);

    // Modulate by sample weight confidence
    float confidence = clamp(sampleWeight, 0.0, 1.0);
    float adaptiveBlend = mix(0.5, baseBlend, adaptivity * confidence);

    return clamp(adaptiveBlend, 0.1, 0.95); // Clamp to sensible range
}

// ===================================================================
// SAMPLING PATTERN ANALYSIS
// ===================================================================

// Estimate spectral quality of sampling pattern (blue-noise metric)
// Lower = better uniformity, higher = more noise
float estimateSamplingNoise(vec3 sampleColors[16]) {
    // Compute mean
    vec3 mean = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        mean += sampleColors[i];
    }
    mean /= 16.0;

    // Compute variance
    float variance = 0.0;
    for (int i = 0; i < 16; i++) {
        vec3 diff = sampleColors[i] - mean;
        variance += dot(diff, diff);
    }
    variance /= 16.0;

    // Return standard deviation (sqrt of variance)
    return sqrt(variance);
}

// ===================================================================
// MULTIPLE IMPORTANCE SAMPLING (MIS)
// ===================================================================

// Balance heuristic for MIS (Veach & Guibas, 1997)
// Combines samples from multiple distributions
float misPowerHeuristic(float pdfA, float pdfB, float beta) {
    float a = pow(pdfA, beta);
    float b = pow(pdfB, beta);
    return a / (a + b);
}

// Balanced MIS weight (special case of power heuristic with beta=2)
float misBalance(float pdfA, float pdfB) {
    return pdfA / (pdfA + pdfB);
}

// ===================================================================
// VARIANCE REDUCTION ESTIMATORS
// ===================================================================

// Control variate for variance reduction
// Uses low-variance approximation to reduce variance of high-variance sample
struct VarianceEstimate {
    vec3 value;
    float variance;
};

VarianceEstimate controlVariateEstimate(
    vec3 sample,
    vec3 lowVarianceApprox,
    vec3 controlMean
) {
    // E[f] = E[f - g] + E[g] where g is low-variance
    vec3 estimator = (sample - lowVarianceApprox) + controlMean;

    // Variance is reduced by correlation with control variate
    float estimatedVariance = length(sample - controlMean);

    return VarianceEstimate(estimator, estimatedVariance);
}

#endif // INCLUDE_ADVANCED_SAMPLING
