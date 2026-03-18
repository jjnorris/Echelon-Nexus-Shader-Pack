// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                  ADVANCED SAMPLING & RECONSTRUCTION FILTERS              ║
// ║                                                                           ║
// ║  Importance-weighted sampling strategies, reconstruction filters,       ║
// ║  and history blending for temporal anti-aliasing (TAA) and Monte       ║
// ║  Carlo sampling tasks. Implements techniques from Pharr et al. (2016)  ║
// ║  and Lottes (2016).                                                    ║
// ║                                                                           ║
// ║  Phase: 15 (Core sampling enhancement)                                 ║
// ║  Research: Pharr et al. (2016), Lottes (2016)                          ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_ADVANCED_SAMPLING
#define INCLUDE_ADVANCED_SAMPLING

#include "halton_sequence.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ RECONSTRUCTION FILTERS FOR TAA                                           ║
// ║                                                                           ║
// │ Implements multiple filter kernels for TAA history blending.            │
// │ Each filter trades off sharpness, ghosting, and quality differently.   │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filterBox()                                                             ║
// ║                                                                         ║
// │ Box filter (nearest neighbor). Simplest reconstruction kernel.         │
// │ Returns 1.0 inside [-0.5, 0.5] box, 0 elsewhere.                      │
// │                                                                         ║
// │ Characteristics:                                                        ║
// │   - Fastest evaluation                                                 ║
// │   - Sharpest, most aliasing artifacts                                  ║
// │   - Good for UI elements and debug views                               ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   offset  - Distance from filter center                               ║
// │                                                                         ║
// │ Returns: Filter weight [0, 1]                                         │
// └─────────────────────────────────────────────────────────────────────────┘
float filterBox(vec2 offset) {
    if (abs(offset.x) <= 0.5 && abs(offset.y) <= 0.5) return 1.0;
    return 0.0;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filterTent()                                                            ║
// ║                                                                         ║
// │ Tent/linear filter. Triangular falloff from center.                   │
// │ Creates smooth weight interpolation across neighboring pixels.        │
// │                                                                         ║
// │ Characteristics:                                                        ║
// │   - Linear interpolation between samples                               ║
// │   - Good temporal stability                                            ║
// │   - Moderate blur, minimal ghosting                                    ║
// │   - Standard choice for TAA                                            ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   offset  - Distance from filter center                               ║
// │                                                                         ║
// │ Returns: Filter weight [0, 1]                                         │
// └─────────────────────────────────────────────────────────────────────────┘
float filterTent(vec2 offset) {
    float x = max(1.0 - abs(offset.x), 0.0);
    float y = max(1.0 - abs(offset.y), 0.0);
    return x * y;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filterLanczos()                                                         ║
// ║                                                                         ║
// │ Lanczos filter (sinc-based, windowed). Professional-quality filter.   │
// │ Minimizes ringing artifacts while maintaining sharpness.              │
// │                                                                         ║
// │ Characteristics:                                                        ║
// │   - Sinc-based reconstruction (theoretically optimal)                  │
// │   - 2-pixel support in each direction                                  ║
// │   - Better frequency response than tent                                ║
// │   - Reduces ringing compared to unwindowed sinc                        ║
// │   - Good for high-quality final reconstruction                         ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   offset  - Distance from filter center                               ║
// │                                                                         ║
// │ Returns: Filter weight [0, 1]                                         │
// └─────────────────────────────────────────────────────────────────────────┘
float filterLanczos(vec2 offset) {
    const float pi = 3.14159265359;

    // ────────────────────────────────────────────────────────────────────────
    // Outside support region (2 pixels), weight is zero
    // ────────────────────────────────────────────────────────────────────────
    if (length(offset) > 2.0) return 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // Compute sinc(x) = sin(πx) / (πx) for X and Y independently
    // Handle singularity at x=0 where sinc(0) = 1
    // ────────────────────────────────────────────────────────────────────────
    float sincX = (abs(offset.x) < 0.001) ? 1.0 : sin(pi * offset.x) / (pi * offset.x);
    float sincY = (abs(offset.y) < 0.001) ? 1.0 : sin(pi * offset.y) / (pi * offset.y);

    // ────────────────────────────────────────────────────────────────────────
    // Apply Hann window: window(x) = sinc(x/2)
    // Windowing reduces ringing artifacts near support edges
    // ────────────────────────────────────────────────────────────────────────
    float windowX = (abs(offset.x) < 0.001) ? 1.0 : sin(pi * offset.x * 0.5) / (pi * offset.x * 0.5);
    float windowY = (abs(offset.y) < 0.001) ? 1.0 : sin(pi * offset.y * 0.5) / (pi * offset.y * 0.5);

    return sincX * sincY * windowX * windowY;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filterCatmullRom()                                                      ║
// ║                                                                         ║
// │ Catmull-Rom cubic spline filter. Smooth, continuous reconstruction.   │
// │ Popular for image upscaling and temporal filtering.                   │
// │                                                                         ║
// │ Characteristics:                                                        ║
// │   - Smooth cubic polynomial interpolation                              ║
// │   - 2-pixel support radius                                             ║
// │   - Better than linear, simpler than Lanczos                          ║
// │   - Good for real-time applications                                    ║
// │   - Moderate sharpness and stability                                   ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   offset  - Distance from filter center                               ║
// │                                                                         ║
// │ Returns: Filter weight [0, 1]                                         │
// └─────────────────────────────────────────────────────────────────────────┘
float filterCatmullRom(vec2 offset) {
    float x = filterCatmullRom1D(offset.x);
    float y = filterCatmullRom1D(offset.y);
    return x * y;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filterCatmullRom1D()                                                    ║
// ║                                                                         ║
// │ 1D Catmull-Rom cubic spline filter kernel.                            │
// │ Computed piecewise as cubic polynomials within [-2, 2] range.        │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   x  - Distance from center (normalized)                              ║
// │                                                                         ║
// │ Returns: Filter weight [0, 1]                                         │
// └─────────────────────────────────────────────────────────────────────────┘
float filterCatmullRom1D(float x) {
    float ax = abs(x);

    // ────────────────────────────────────────────────────────────────────────
    // Inner region [0, 1]: smooth interpolation
    // ────────────────────────────────────────────────────────────────────────
    if (ax < 1.0) {
        return 1.0 - 2.0 * ax * ax + ax * ax * ax;
    }
    // ────────────────────────────────────────────────────────────────────────
    // Outer region [1, 2]: cubic falloff to zero
    // ────────────────────────────────────────────────────────────────────────
    else if (ax < 2.0) {
        return -4.0 + 8.0 * ax - 5.0 * ax * ax + ax * ax * ax;
    }

    return 0.0;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SAMPLE WEIGHTING & HISTORY BLENDING                                      ║
// ║                                                                           ║
// │ Determines how strongly to blend current frame with historical data.   │
// │ Confidence-aware weighting reduces ghosting and temporal artifacts.    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ estimateSampleConfidence()                                              ║
// ║                                                                         ║
// │ Estimates how confident we should be in current sample vs history.    │
// │ Based on neighborhood variance - high variance = lower confidence.    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   sample     - Current frame's sampled value                          │
// │   neighbors  - Array of 8 neighboring pixel values                    │
// │                                                                         ║
// │ Returns: Confidence weight [0, 1] for current sample                  │
// │           1.0 = fully trust current, 0.0 = use only history         │
// └─────────────────────────────────────────────────────────────────────────┘
float estimateSampleConfidence(vec3 sample, vec3 neighbors[8]) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute mean of neighborhood for variance calculation
    // ────────────────────────────────────────────────────────────────────────
    vec3 meanNeighbor = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        meanNeighbor += neighbors[i];
    }
    meanNeighbor /= 8.0;

    // ────────────────────────────────────────────────────────────────────────
    // Compute variance across neighbors
    // High variance = unstable region = lower confidence
    // ────────────────────────────────────────────────────────────────────────
    float variance = 0.0;
    for (int i = 0; i < 8; i++) {
        vec3 diff = neighbors[i] - meanNeighbor;
        variance += dot(diff, diff);
    }
    variance /= 8.0;

    // ────────────────────────────────────────────────────────────────────────
    // Confidence = 1 / (1 + variance)
    // Squared for smoother falloff in high-variance regions
    // ────────────────────────────────────────────────────────────────────────
    float confidence = 1.0 / (1.0 + sqrt(variance));
    return confidence;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ clampToNeighborhood()                                                   ║
// ║                                                                         ║
// │ Clamps history value to neighborhood bounding box.                    │
// │ Prevents ghosting artifacts from disocclusions and motion.            │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   history    - Color value from previous frame                        │
// │   neighbors  - Array of 8 neighboring pixel values                    │
// │   strength   - How aggressively to clamp (0-1)                        │
// │                                                                         ║
// │ Returns: Clamped history value within neighborhood bounds             │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 clampToNeighborhood(vec3 history, vec3 neighbors[8], float strength) {
    // ────────────────────────────────────────────────────────────────────────
    // Find min/max bounds of neighborhood colors
    // ────────────────────────────────────────────────────────────────────────
    vec3 minNeighbor = neighbors[0];
    vec3 maxNeighbor = neighbors[0];

    for (int i = 1; i < 8; i++) {
        minNeighbor = min(minNeighbor, neighbors[i]);
        maxNeighbor = max(maxNeighbor, neighbors[i]);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Expand bounds by strength factor to reduce aggressive clamping
    // Prevents over-darkening from over-conservative bounds
    // ────────────────────────────────────────────────────────────────────────
    vec3 center = (minNeighbor + maxNeighbor) * 0.5;
    vec3 extent = (maxNeighbor - minNeighbor) * (0.5 * strength);

    return clamp(history, center - extent, center + extent);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ IMPORTANCE-WEIGHTED TAA BLENDING                                         ║
// ║                                                                           ║
// │ Computes optimal blend factor using importance-weighted theory.        │
// │ Balances current frame quality with temporal stability.               │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeOptimalBlendFactor()                                             ║
// ║                                                                         ║
// │ Computes Bayesian-optimal blend factor for TAA history blending.      │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   current            - Current frame color                            │
// │   history            - Previous frame accumulated color               │
// │   sampleWeight       - Importance weight of current sample             │
// │   historyWeight      - Accumulated weight of history                   │
// │   adaptivity         - How adaptive blending should be (0-1)          │
// │                                                                         ║
// │ Returns: Optimal blend factor [0.1, 0.95]                            │
// │          0.1 = mostly history, 0.95 = mostly current                 │
// └─────────────────────────────────────────────────────────────────────────┘
float computeOptimalBlendFactor(
    vec3 current,
    vec3 history,
    float sampleWeight,
    float historyWeight,
    float adaptivity
) {
    // ────────────────────────────────────────────────────────────────────────
    // Bayesian optimal blend: blend = historyWeight / (historyWeight + sampleWeight)
    // Mathematically derived for minimum variance
    // ────────────────────────────────────────────────────────────────────────
    float baseBlend = historyWeight / (historyWeight + sampleWeight);

    // ────────────────────────────────────────────────────────────────────────
    // Modulate by sample confidence for adaptive response
    // Higher confidence in current sample = faster blending
    // ────────────────────────────────────────────────────────────────────────
    float confidence = clamp(sampleWeight, 0.0, 1.0);
    float adaptiveBlend = mix(0.5, baseBlend, adaptivity * confidence);

    // ────────────────────────────────────────────────────────────────────────
    // Clamp to sensible range to prevent extreme behavior
    // Too low = ghosting, too high = flickering
    // ────────────────────────────────────────────────────────────────────────
    return clamp(adaptiveBlend, 0.1, 0.95);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MULTIPLE IMPORTANCE SAMPLING (MIS)                                       ║
// ║                                                                           ║
// │ Combines samples from multiple distributions for reduced variance.    │
// │ Used in hybrid indirect lighting and complex sampling tasks.         │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ misPowerHeuristic()                                                     ║
// ║                                                                         ║
// │ Balance heuristic with power parameter for MIS (Veach & Guibas).      │
// │ Combines samples from two distributions using power heuristic.        │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   pdfA    - Probability density from first distribution               │
// │   pdfB    - Probability density from second distribution              │
// │   beta    - Power parameter (typically 2.0 for balance heuristic)    │
// │                                                                         ║
// │ Returns: Weight for current sample [0, 1]                            │
// └─────────────────────────────────────────────────────────────────────────┘
float misPowerHeuristic(float pdfA, float pdfB, float beta) {
    float a = pow(pdfA, beta);
    float b = pow(pdfB, beta);
    return a / (a + b);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ misBalance()                                                            ║
// ║                                                                         ║
// │ Balance heuristic for MIS (power heuristic with beta=1.0).            │
// │ Simple and effective for most applications.                           │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   pdfA    - Probability density from first distribution               │
// │   pdfB    - Probability density from second distribution              │
// │                                                                         ║
// │ Returns: Weight for current sample [0, 1]                            │
// └─────────────────────────────────────────────────────────────────────────┘
float misBalance(float pdfA, float pdfB) {
    return pdfA / (pdfA + pdfB);
}

#endif // INCLUDE_ADVANCED_SAMPLING
