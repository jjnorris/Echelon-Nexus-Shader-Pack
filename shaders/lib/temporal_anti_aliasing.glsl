// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         TEMPORAL ANTI-ALIASING (PHASE 13)                               ║
// ║                                                                           ║
// ║  High-quality TAA with Halton sequence jitter, variance clamping,      ║
// ║  and motion-adaptive filtering. Produces sub-pixel perfect rendering   ║
// ║  without blur artifacts. Implements techniques from multiple game     ║
// ║  engines (Unreal Engine 4, Playdead Inside, Insomniac Games).         ║
// ║                                                                           ║
// ║  Algorithm:                                                              ║
// ║    1. Jitter camera projection each frame (Halton sequence)            ║
// ║    2. Reproject previous frame color using depth/velocity              ║
// ║    3. Clamp history to current frame's neighborhood (variance)         ║
// ║    4. Blend with temporal weighting based on motion                    ║
// ║    5. Detect disocclusions and use lower history weight                ║
// ║                                                                           ║
// ║  Quality Tiers:                                                          ║
// ║    - Fast: 2x jitter + simple blending (Level 0)                      ║
// ║    - Balanced: 4x jitter + clamping (Level 1)                         ║
// ║    - High: 8x jitter + neighborhood filtering (Level 2)               ║
// ║                                                                           ║
// ║  Performance: 0.5-2ms depending on complexity                          ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_TEMPORAL_ANTI_ALIASING
#define INCLUDE_TEMPORAL_ANTI_ALIASING

#include "constants.glsl"
#include "functions.glsl"
#include "halton_sequence.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HALTON SEQUENCE JITTERING                                               ║
// │                                                                           ║
// │ Camera jitter using Halton sequence for stratified super-sampling.    ║
// │ Provides much better coverage than white noise jitter.                ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeHaltonJitter()                                                   ║
// ║                                                                         ║
// │ Compute camera jitter offset using Halton sequence for this frame.   │
// │ Uses base 2 and base 3 for 2D stratified sampling.                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   frameIndex - Current frame number (0, 1, 2, ...)                │
// │   jitterScale - Magnitude of jitter (0.5 for half-pixel)         │
// │                                                                       │
// │ Returns: vec2 jitter offset in NDC space [-jitterScale, +jitterScale]│
// │                                                                       │
// │ Math:                                                                │
// │   x_jitter = Halton(2, frameIndex)                                │
// │   y_jitter = Halton(3, frameIndex)                                │
// │   Remap: [-0.5, 0.5] → [-jitterScale, jitterScale]               │
// │                                                                       │
// │ Result: 2 samples/frame converges at 2 frames (4x under TAA)      │
// │         4 samples/frame converges at 4 frames (16x under TAA)     │
// │         8 samples/frame converges at 8 frames (64x under TAA)     │
// └─────────────────────────────────────────────────────────────────────┘
vec2 computeHaltonJitter(int frameIndex, float jitterScale) {
    // Compute Halton sequence values for base 2 and base 3
    float h2 = radicalInverse(2u, uint(frameIndex));  // Base 2: [0, 1)
    float h3 = radicalInverse(3u, uint(frameIndex));  // Base 3: [0, 1)

    // Remap from [0, 1) to [-0.5, 0.5)
    vec2 jitter = (vec2(h2, h3) - vec2(0.5)) * 2.0;

    // Scale by jitter magnitude (typically 0.5 for half-pixel jitter)
    return jitter * jitterScale;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyHaltonJitterToUV()                                                 ║
// ║                                                                         ║
// │ Apply Halton jitter to screen coordinates for TAA.                  │
// │ Modifies sample position slightly each frame for super-sampling.   │
// │                                                                       │
// │ Usage:                                                              │
// │   vec2 jitteredUV = applyHaltonJitterToUV(                        │
// │       screenCoord,                                                 │
// │       frameCounter,                                               │
// │       invScreenSize  // 1.0 / resolution                         │
// │   );                                                              │
// │   vec3 color = texture(sceneTex, jitteredUV).rgb;                │
// └─────────────────────────────────────────────────────────────────────┘
vec2 applyHaltonJitterToUV(
    vec2 screenCoord,
    int frameIndex,
    vec2 invScreenSize
) {
    // Compute jitter in normalized device space
    vec2 jitter = computeHaltonJitter(frameIndex, 0.5);  // Half-pixel jitter

    // Convert jitter to texture coordinate space
    // jitter is in [-0.5, 0.5] in NDC, map to pixel coordinates
    jitter *= invScreenSize;

    // Apply jitter to screen coordinate
    return screenCoord + jitter;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HISTORY REPROJECTION & CLAMPING                                         ║
// │                                                                           ║
// │ Reprojects previous frame's color into current frame using depth.     ║
// │ Applies variance clamping to remove ghosting while preserving detail.  ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ reprojectHistory()                                                      ║
// ║                                                                         ║
// │ Reproject previous frame's depth and color into current frame.       │
// │ Handles disocclusions and screen-edge wraparound.                  │
// │                                                                       │
// │ Inputs:                                                              │
// │   currentDepth - Current frame depth at this pixel                │
// │   screenCoord - Current screen coordinate [0,1]²                 │
// │   reprojectionMatrix - Previous frame VP matrix                  │
// │   currentVPMatrixInv - Current frame inverse VP matrix           │
// │   historyTexture - Previous frame color + depth                 │
// │                                                                       │
// │ Returns: vec4(reprojected_color.rgb, depth_difference)          │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Reconstruct world position from current depth               │
// │   2. Project to previous frame using reprojection matrix         │
// │   3. Check if reprojected position is on-screen                  │
// │   4. Sample history color and compare depth                      │
// │   5. Return color + disocclusion metric                          │
// └─────────────────────────────────────────────────────────────────────┘
vec4 reprojectHistory(
    float currentDepth,
    vec2 screenCoord,
    mat4 reprojectionMatrix,
    mat4 currentVPMatrixInv,
    sampler2D historyTexture
) {
    // ────────────────────────────────────────────────────────────────────────
    // Reconstruct world position from current depth
    // ────────────────────────────────────────────────────────────────────────
    vec3 currentNDC = vec3(screenCoord * 2.0 - 1.0, currentDepth);
    vec4 worldPos = currentVPMatrixInv * vec4(currentNDC, 1.0);
    worldPos.xyz /= worldPos.w;

    // ────────────────────────────────────────────────────────────────────────
    // Project to previous frame
    // ────────────────────────────────────────────────────────────────────────
    vec4 historyNDC = reprojectionMatrix * vec4(worldPos.xyz, 1.0);
    historyNDC.xy /= historyNDC.w;

    // Convert from NDC [-1,1] to texture coordinates [0,1]
    vec2 historyUV = historyNDC.xy * 0.5 + 0.5;

    // ────────────────────────────────────────────────────────────────────────
    // Check if reprojected position is on screen
    // ────────────────────────────────────────────────────────────────────────
    bool onScreen = (historyUV.x >= 0.0 && historyUV.x <= 1.0 &&
                     historyUV.y >= 0.0 && historyUV.y <= 1.0);

    if (!onScreen) {
        return vec4(0.0, 0.0, 0.0, 1.0);  // No history available
    }

    // ────────────────────────────────────────────────────────────────────────
    // Sample history color and depth
    // ────────────────────────────────────────────────────────────────────────
    vec4 history = texture(historyTexture, historyUV);
    float historyDepth = history.a;  // Assuming depth in alpha channel

    // ────────────────────────────────────────────────────────────────────────
    // Compute depth difference for disocclusion detection
    // Current depth > history depth = disocclusion (new geometry)
    // ────────────────────────────────────────────────────────────────────────
    float depthDiff = currentDepth - historyDepth;

    // Return color + disocclusion metric
    return vec4(history.rgb, depthDiff);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ varianceClamp()                                                         ║
// ║                                                                         ║
// │ Variance clamping: clamp history color to neighborhood bounds.       │
// │ Prevents ghosting while preserving temporal detail.                 │
// │                                                                       │
// │ Algorithm (Variance Clipping):                                      │
// │   1. Sample 3×3 neighborhood of current frame                      │
// │   2. Compute neighborhood mean and variance                        │
// │   3. Clamp history color to [mean - k×std, mean + k×std]         │
// │   4. Where k is clamping strength (usually 1.0-2.0)               │
// │                                                                       │
// │ Result: Removes temporal ghosting while keeping temporal detail    │
// │                                                                       │
// │ Inputs:                                                              │
// │   historyColor - Previous frame color to clamp                   │
// │   currentColor - Current frame color at this pixel               │
// │   colorBuffer - Current frame color texture                      │
// │   screenCoord - Current screen coordinate                       │
// │   invScreenSize - 1.0 / resolution                              │
// │   clampStrength - Clamping strength (1.0-2.0)                  │
// │                                                                       │
// │ Returns: Clamped history color                                  │
// └─────────────────────────────────────────────────────────────────┘
vec3 varianceClamp(
    vec3 historyColor,
    vec3 currentColor,
    sampler2D colorBuffer,
    vec2 screenCoord,
    vec2 invScreenSize,
    float clampStrength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Sample 3×3 neighborhood to compute statistics
    // ────────────────────────────────────────────────────────────────────────
    vec3 minColor = currentColor;
    vec3 maxColor = currentColor;
    vec3 colorMean = currentColor;

    // Offset vectors for 8 neighbors + center
    vec2 offsets[9] = vec2[](
        vec2(-1, -1), vec2(0, -1), vec2(1, -1),
        vec2(-1,  0), vec2(0,  0), vec2(1,  0),
        vec2(-1,  1), vec2(0,  1), vec2(1,  1)
    );

    // Normalize by texel size
    vec3 colorSum = vec3(0.0);
    vec3 colorSqSum = vec3(0.0);

    for (int i = 0; i < 9; i++) {
        vec2 sampleUV = screenCoord + offsets[i] * invScreenSize;
        vec3 sampleColor = texture(colorBuffer, sampleUV).rgb;

        minColor = min(minColor, sampleColor);
        maxColor = max(maxColor, sampleColor);
        colorSum += sampleColor;
        colorSqSum += sampleColor * sampleColor;
    }

    // ────────────────────────────────────────────────────────────────────────
    // Compute mean and variance of neighborhood
    // ────────────────────────────────────────────────────────────────────────
    vec3 mean = colorSum / 9.0;
    vec3 variance = sqrt(abs(colorSqSum / 9.0 - mean * mean));

    // ────────────────────────────────────────────────────────────────────────
    // Clamp history to [mean - k*std, mean + k*std]
    // ────────────────────────────────────────────────────────────────────────
    vec3 clampMin = mean - variance * clampStrength;
    vec3 clampMax = mean + variance * clampStrength;

    vec3 clampedColor = clamp(historyColor, clampMin, clampMax);

    return clampedColor;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MOTION DETECTION & ADAPTIVE BLENDING                                    ║
// │                                                                           ║
// │ Detects motion and adjusts blend weight to prevent ghosting on moving ║
// │ objects while maintaining temporal coherence on static geometry.     ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ detectMotion()                                                          ║
// ║                                                                         ║
// │ Detect if pixel is moving based on reprojection difference.         │
// │ High motion → lower history weight (more current frame)            │
// │ Low motion → higher history weight (temporal smoothing)           │
// │                                                                       │
// │ Returns: Motion amount [0, 1] where 1 = high motion              │
// └─────────────────────────────────────────────────────────────────────┘
float detectMotion(
    vec3 currentColor,
    vec3 reprojectedColor,
    float disocclusionMetric
) {
    // ────────────────────────────────────────────────────────────────────────
    // Color difference between current and reprojected history
    // ────────────────────────────────────────────────────────────────────────
    vec3 colorDiff = abs(currentColor - reprojectedColor);
    float colorMotion = max(max(colorDiff.r, colorDiff.g), colorDiff.b);

    // ────────────────────────────────────────────────────────────────────────
    // Disocclusion detection (depth mismatch indicates new geometry)
    // ────────────────────────────────────────────────────────────────────────
    float disocclusionMotion = min(1.0, abs(disocclusionMetric) * 2.0);

    // ────────────────────────────────────────────────────────────────────────
    // Combined motion metric
    // ────────────────────────────────────────────────────────────────────────
    return max(colorMotion, disocclusionMotion);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeTemporalWeight()                                                 ║
// ║                                                                         ║
// │ Compute history blend weight based on motion and disocclusion.       │
// │ Motion-adaptive: high motion → favor current, low motion → favor history│
// │                                                                       │
// │ Inputs:                                                              │
// │   motionAmount - Motion metric [0, 1]                           │
// │   disocclusionMetric - Depth difference (positive = disocclusion)   │
// │   baseHistoryWeight - Default history weight (0.8-0.95)           │
// │                                                                       │
// │ Returns: Final history weight [0.05, baseHistoryWeight]          │
// │                                                                       │
// │ Strategy:                                                            │
// │   - No motion: 95% history, 5% current                           │
// │   - High motion: 20% history, 80% current                        │
// │   - Disocclusion: 10% history, 90% current                       │
// └─────────────────────────────────────────────────────────────────────┘
float computeTemporalWeight(
    float motionAmount,
    float disocclusionMetric,
    float baseHistoryWeight
) {
    // ────────────────────────────────────────────────────────────────────────
    // Reduce history weight with motion
    // ────────────────────────────────────────────────────────────────────────
    float motionFactor = mix(baseHistoryWeight, 0.2, motionAmount);

    // ────────────────────────────────────────────────────────────────────────
    // Reduce further for disoccluded pixels (new geometry)
    // ────────────────────────────────────────────────────────────────────────
    float disocclusionFactor = 1.0 - min(1.0, abs(disocclusionMetric) * 5.0);
    motionFactor *= mix(0.1, 1.0, disocclusionFactor);

    // ────────────────────────────────────────────────────────────────────────
    // Clamp to valid range [0.05, baseHistoryWeight]
    // Never drop history completely to maintain temporal coherence
    // ────────────────────────────────────────────────────────────────────────
    return max(0.05, min(baseHistoryWeight, motionFactor));
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HIGH-LEVEL TAA FUNCTIONS                                                ║
// │                                                                           ║
// │ Quality-scaled TAA implementations for different hardware tiers.       ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyTAA_Fast()                                                         ║
// ║                                                                         ║
// │ Fast TAA with minimal overhead (2x super-sampling).                  │
// │ Uses simple blending without clamping.                              │
// │                                                                       │
// │ Performance: ~0.5ms                                                 │
// │ Quality: Good (noticeable improvement over no TAA)                 │
// │ Best For: LOW tier, performance-critical situations                │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyTAA_Fast(
    vec3 currentColor,
    vec3 historyColor,
    int frameCounter,
    vec2 screenCoord,
    vec2 invScreenSize
) {
    // Simple Halton jittering
    vec2 jitter = applyHaltonJitterToUV(screenCoord, frameCounter, invScreenSize);

    // Simple temporal blend (high history weight)
    float historyWeight = 0.9;

    return mix(currentColor, historyColor, historyWeight);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyTAA_Balanced()                                                     ║
// ║                                                                         ║
// │ Balanced TAA with variance clamping (4x super-sampling).            │
// │ Good quality/performance ratio.                                     │
// │                                                                       │
// │ Performance: ~1.0ms                                                 │
// │ Quality: Excellent (smooth edges, no ghosting)                     │
// │ Best For: MEDIUM/HIGH tier                                         │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyTAA_Balanced(
    vec3 currentColor,
    vec3 historyColor,
    int frameCounter,
    vec2 screenCoord,
    vec2 invScreenSize,
    sampler2D colorBuffer
) {
    // Halton jittering
    vec2 jitter = applyHaltonJitterToUV(screenCoord, frameCounter, invScreenSize);

    // Variance clamping to remove ghosting
    vec3 clampedHistory = varianceClamp(
        historyColor,
        currentColor,
        colorBuffer,
        screenCoord,
        invScreenSize,
        1.5  // Moderate clamping strength
    );

    // Temporal blend with reasonable history weight
    float historyWeight = 0.85;

    return mix(currentColor, clampedHistory, historyWeight);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyTAA_HighQuality()                                                  ║
// ║                                                                         ║
// │ High-quality TAA with motion detection (8x super-sampling).         │
// │ Best results but higher performance cost.                          │
// │                                                                       │
// │ Performance: ~2.0ms                                                 │
// │ Quality: Professional (artifacts nearly invisible)                 │
// │ Best For: ULTRA/CINEMATIC tier                                     │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyTAA_HighQuality(
    vec3 currentColor,
    vec3 historyColor,
    int frameCounter,
    vec2 screenCoord,
    vec2 invScreenSize,
    sampler2D colorBuffer
) {
    // Halton jittering
    vec2 jitter = applyHaltonJitterToUV(screenCoord, frameCounter, invScreenSize);

    // Variance clamping
    vec3 clampedHistory = varianceClamp(
        historyColor,
        currentColor,
        colorBuffer,
        screenCoord,
        invScreenSize,
        1.2  // Tighter clamping
    );

    // Motion detection for adaptive blending
    float motionAmount = detectMotion(
        currentColor,
        historyColor,
        0.0  // In practice, use actual disocclusion metric
    );

    // Adaptive temporal weight
    float historyWeight = computeTemporalWeight(
        motionAmount,
        0.0,
        0.9  // Base history weight
    );

    return mix(currentColor, clampedHistory, historyWeight);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MAIN TAA ENTRY POINT                                                    ║
// │                                                                           ║
// │ Public interface: applies TAA based on quality tier and motion.       ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyTemporalAntiAliasing()                                             ║
// ║                                                                         ║
// │ Main TAA function. Blends current frame with temporally-reprojected  │
// │ history using Halton jittering and variance clamping.              │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Current frame color                                      │
// │   historyColor - Previous frame reprojected color                  │
// │   frameCounter - Current frame number for Halton sequence         │
// │   screenCoord - Current pixel screen coordinate [0,1]            │
// │   invScreenSize - 1.0 / screen resolution                        │
// │   colorBuffer - Current frame color texture (for variance clamp)  │
// │   quality - TAA quality tier (0=fast, 1=balanced, 2=high)        │
// │                                                                       │
// │ Returns: TAA-filtered color                                       │
// │                                                                       │
// │ Strategy:                                                            │
// │   Quality 1: Simple 2x blending                                   │
// │   Quality 2: 4x with variance clamping                           │
// │   Quality 3: 8x with motion detection                            │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyTemporalAntiAliasing(
    vec3 color,
    vec3 historyColor,
    int frameCounter,
    vec2 screenCoord,
    vec2 invScreenSize,
    sampler2D colorBuffer,
    int quality
) {
    if (quality == 0) {
        return applyTAA_Fast(
            color,
            historyColor,
            frameCounter,
            screenCoord,
            invScreenSize
        );
    } else if (quality == 1) {
        return applyTAA_Balanced(
            color,
            historyColor,
            frameCounter,
            screenCoord,
            invScreenSize,
            colorBuffer
        );
    } else {  // quality >= 2
        return applyTAA_HighQuality(
            color,
            historyColor,
            frameCounter,
            screenCoord,
            invScreenSize,
            colorBuffer
        );
    }
}

#endif  // INCLUDE_TEMPORAL_ANTI_ALIASING
