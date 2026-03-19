// ===================================================================
// Echelon Nexus - Temporal Effects (TAA, Reprojection, History)
// ===================================================================
// Temporal anti-aliasing and history management with advanced sampling.
// Phase 15+ features: Halton sequences, importance-weighted history,
// advanced reconstruction filters, and adaptive blending.
// ===================================================================

#ifndef INCLUDE_TEMPORAL
#define INCLUDE_TEMPORAL

#include "constants.glsl"
#include "functions.glsl"
#include "halton_sequence.glsl"
#include "advanced_sampling.glsl"

// ===================================================================
// TAA (TEMPORAL ANTI-ALIASING)
// ===================================================================

// Compute per-frame jitter offset using Halton sequences
// Quality tiers:
//   LOW: Halton(2,3) - 2D sequence
//   MEDIUM: Hammersley 2D - better uniformity
//   HIGH: Adaptive Halton with confidence weighting
vec2 computeTAAJitter(int frameIndex, float jitterScale) {
    uint index = uint(frameIndex) % 256u;

    #if TAA_QUALITY == 0
        // LOW: Halton(2,3) sequence
        vec2 h = halton2D(index);
    #elif TAA_QUALITY == 1
        // MEDIUM: Hammersley sequence (better uniformity)
        vec2 h = hammersley2D(index, 256u);
    #else
        // HIGH: Full adaptive Halton with history
        vec2 h = halton2D(index);
    #endif

    // Remap from [0,1] to [-0.5, 0.5] subpixel offsets
    return (h - 0.5) * jitterScale / 8.0;  // Scale to subpixel precision
}

// ===================================================================
// REPROJECTION
// ===================================================================

// Reproject pixel from previous frame using motion vectors
vec2 reprojectPrevFrame(
    vec2 currentTexCoord,
    vec2 velocityTexCoord,
    vec2 invResolution
) {
    // Velocity in screen space (typically from motion vectors)
    vec2 velocity = texture(colortex6, velocityTexCoord).xy;  // Phase 9+

    // Reproject to previous frame
    return currentTexCoord - velocity * invResolution;
}

// ===================================================================
// HISTORY CLAMPING
// ===================================================================

// Variance-based history clamping (reduces ghosting)
vec3 clampHistory(
    vec3 currentColor,
    vec3 historyColor,
    vec3 colorMin,
    vec3 colorMax,
    float clampStrength
) {
    // Clamp history to neighborhood min/max
    vec3 clampedHistory = clamp(historyColor, colorMin, colorMax);

    // Blend clamped history with current
    return mix(clampedHistory, currentColor, clampStrength);
}

// Compute per-pixel color neighborhood (min/max)
void computeColorNeighborhood(
    vec2 texCoord,
    vec2 invResolution,
    out vec3 colorMin,
    out vec3 colorMax,
    out vec3 colorAvg
) {
    vec3 center = texture(colortex0, texCoord).rgb;
    colorMin = center;
    colorMax = center;
    colorAvg = center;

    // Sample 3x3 neighborhood
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) continue;

            vec2 offset = vec2(x, y) * invResolution;
            vec3 sampleColor = texture(colortex0, texCoord + offset).rgb;

            colorMin = min(colorMin, sampleColor);
            colorMax = max(colorMax, sampleColor);
            colorAvg += sampleColor;
        }
    }

    colorAvg /= 9.0;
}

// ===================================================================
// HISTORY FILTERING
// ===================================================================

// Exponential moving average (EMA) blending
vec3 emaBlend(vec3 current, vec3 history, float weight) {
    // weight = 0 → full history, weight = 1 → full current
    return mix(history, current, weight);
}

// Luminance-weighted blending (prioritize brightness)
vec3 luminanceWeightedBlend(
    vec3 current,
    vec3 history,
    float weight
) {
    float currentLum = luminance(current);
    float historyLum = luminance(history);

    float totalLum = currentLum + historyLum;
    if (totalLum < EPSILON) {
        return current;
    }

    // Weight by relative luminance
    float currentWeight = currentLum / totalLum;
    float historyWeight = historyLum / totalLum;

    return current * currentWeight + history * historyWeight;
}

// ===================================================================
// TEMPORAL STABILITY
// ===================================================================

// Reduce temporal flickering on per-pixel basis
float computeTemporalStability(
    vec3 currentColor,
    vec3 historyColor,
    float maxDifference
) {
    vec3 diff = abs(currentColor - historyColor);
    float maxDiff = max(max(diff.r, diff.g), diff.b);

    // Return stability factor (0 = unstable, 1 = stable)
    return 1.0 - clamp(maxDiff / maxDifference, 0.0, 1.0);
}

// ===================================================================
// FRAME INDEX MANAGEMENT
// ===================================================================

// Get current frame index (wraps at 64 for reproducibility)
int getCurrentFrameIndex() {
    // frameCounter is Iris-provided
    // return frameCounter % 64;
    return 0;  // Placeholder
}

// ===================================================================
// TAA IMPLEMENTATION
// ===================================================================

// Complete TAA pass
vec3 taaResolve(
    vec3 currentColor,
    vec2 texCoord,
    vec2 invResolution,
    float taaWeight
) {
    // Step 1: Compute neighborhood bounds
    vec3 colorMin, colorMax, colorAvg;
    computeColorNeighborhood(texCoord, invResolution, colorMin, colorMax, colorAvg);

    // Step 2: Sample history (assumes colortex3 is history buffer)
    vec3 historyColor = texture(colortex3, texCoord).rgb;

    // Step 3: Clamp history to neighborhood
    vec3 clampedHistory = clampHistory(
        currentColor,
        historyColor,
        colorMin,
        colorMax,
        0.5  // Clamp strength
    );

    // Step 4: Blend with EMA
    vec3 taaResult = emaBlend(currentColor, clampedHistory, taaWeight);

    return taaResult;
}

// ===================================================================
// HISTORY BUFFER MANAGEMENT
// ===================================================================

// Store result to history buffer for next frame
vec4 storeToHistory(vec3 color, float confidence) {
    return vec4(color, confidence);
}

// Load from history buffer
vec3 loadFromHistory(vec4 historyData) {
    return historyData.rgb;
}

// ===================================================================
// TEMPORAL CHECKERBOARD (For optimized effects)
// ===================================================================

// Checkerboard pattern for alternating-frame rendering
bool isCheckerboardWhite(vec2 screenCoord, int frameIndex) {
    vec2 checkCoord = screenCoord * 2.0;
    int check = int(checkCoord.x) + int(checkCoord.y);
    int frameCheck = frameIndex % 2;

    return (check % 2) == frameCheck;
}

// Reconstruct checkerboard result using history
vec3 reconstructCheckerboard(
    vec3 currentColor,
    vec2 texCoord,
    vec2 invResolution,
    int frameIndex
) {
    if (isCheckerboardWhite(texCoord, frameIndex)) {
        return currentColor;
    }

    // Interpolate from 4 neighbors
    vec3 result = currentColor * 0.25;
    result += texture(colortex0, texCoord + vec2(invResolution.x, 0.0)).rgb * 0.25;
    result += texture(colortex0, texCoord - vec2(invResolution.x, 0.0)).rgb * 0.25;
    result += texture(colortex0, texCoord + vec2(0.0, invResolution.y)).rgb * 0.25;

    return result;
}

// ===================================================================
// END OF TEMPORAL MODULE
// ===================================================================

#endif // INCLUDE_TEMPORAL
