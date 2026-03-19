// ===================================================================
// Echelon Nexus - Optimization & Performance Utilities
// ===================================================================
// Early exits, LOD selection, and tier-based feature gates.
// ===================================================================

#ifndef INCLUDE_OPTIMIZATION
#define INCLUDE_OPTIMIZATION

#include "constants.glsl"
#include "functions.glsl"

// ===================================================================
// EARLY EXIT PREDICATES
// ===================================================================

// Skip processing for fully transparent pixels
bool shouldSkipTransparent(float alpha) {
    return alpha < 0.01;
}

// Skip processing for fully opaque pixels (optimization opportunity)
bool canSkipTranslucency(float alpha) {
    return alpha > 0.99;
}

// Skip expensive effects if contribution is negligible
bool shouldSkipEffect(float contribution) {
    return contribution < 0.001;
}

// Skip lighting for unlit surfaces (pure emissive)
bool isFullyEmissive(float emissive, float roughness) {
    return emissive > 0.9 && roughness > 0.8;
}

// ===================================================================
// LEVEL-OF-DETAIL (LOD)
// ===================================================================

// Compute LOD level based on screen-space derivatives
int computeLOD(vec2 texCoord, sampler2D tex) {
    // Estimate texture detail from derivatives
    vec2 dx = dFdx(texCoord);
    vec2 dy = dFdy(texCoord);

    float derivative = max(length(dx), length(dy));

    if (derivative > 0.1) return 3;
    if (derivative > 0.05) return 2;
    if (derivative > 0.01) return 1;
    return 0;
}

// Distance-based LOD
int computeDistanceLOD(float depth) {
    if (depth < 0.1) return 0;
    if (depth < 0.3) return 1;
    if (depth < 0.7) return 2;
    return 3;
}

// ===================================================================
// TIER-BASED FEATURE GATES
// ===================================================================

// Conditionally enable/disable features based on TIER
bool isFeatureEnabled(string featureName, int tier) {
    // Compile-time conditional (pseudo-code; actual via preprocessor)
    if (featureName == "SSR") return tier >= 2;
    if (featureName == "BLOOM") return tier >= 3;
    if (featureName == "TAA") return tier >= 2;
    if (featureName == "PARALLAX") return tier >= 3;
    if (featureName == "PCSS") return tier >= 3;
    if (featureName == "VOLUMETRIC_CLOUDS") return tier >= 3;
    return true;  // Baseline feature
}

// Get sample count based on tier
int getSampleCount(int tier, string effectName) {
    if (effectName == "SSR") {
        if (tier >= 4) return 64;
        if (tier >= 3) return 32;
        return 16;
    }

    if (effectName == "SHADOWS") {
        if (tier >= 4) return 32;
        if (tier >= 3) return 16;
        return 4;
    }

    if (effectName == "CLOUDS") {
        if (tier >= 5) return 48;
        if (tier >= 4) return 32;
        if (tier >= 3) return 24;
        return 8;
    }

    return 16;  // Default
}

// ===================================================================
// APPROXIMATION & SIMPLIFICATION
// ===================================================================

// Use approximation for expensive functions on low-end hardware
vec3 simplifyBRDF(vec3 normal, vec3 viewDir, vec3 lightDir, int tier) {
    if (tier <= 1) {
        // Simplified: Blinn-Phong instead of GGX
        vec3 h = normalize(viewDir + lightDir);
        float spec = pow(max(0.0, dot(normal, h)), 32.0);
        return vec3(spec * 0.3);
    }
    // Full GGX for higher tiers
    return vec3(0.5);  // Placeholder
}

// Reduce normal map detail on low-end
vec3 simplifyNormalMap(vec3 normal, int tier) {
    if (tier <= 1) {
        // Reduce impact of high-frequency normals
        return mix(vec3(0.5, 0.5, 1.0), normal, 0.5);
    }
    return normal;
}

// ===================================================================
// CULL & DISCARD OPTIMIZATION
// ===================================================================

// Discard pixels outside important geometry
bool shouldDiscard(float depth, float normalConfidence) {
    // Discard background (very far depth)
    if (depth > 0.99) return true;

    // Discard if normal reconstruction failed
    if (normalConfidence < 0.1) return true;

    return false;
}

// ===================================================================
// BRANCHING OPTIMIZATION
// ===================================================================

// Minimize branching by using step/mix instead of if-else
float branchlessClamp(float value, float min, float max) {
    return mix(min, value, step(min, value)) * step(value, max) + max * (1.0 - step(value, max));
}

// Branchless selection (instead of if-else)
float branchlessSelect(float condition, float ifTrue, float ifFalse) {
    return mix(ifFalse, ifTrue, step(0.5, condition));
}

// ===================================================================
// TEXTURE COMPRESSION & CACHING
// ===================================================================

// Use lower-precision texture for less-critical data
vec4 sampleLowPrecision(sampler2D tex, vec2 coord) {
    // Sample and quantize to lower precision
    vec4 sample = texture(tex, coord);
    return floor(sample * 15.0) / 15.0;  // Quantize to 4-bit
}

// ===================================================================
// TEMPORAL COHERENCE
// ===================================================================

// Reuse previous frame computation if current and previous pixels match
bool canReuseHistory(vec2 currentCoord, vec2 prevCoord, sampler2D currentBuffer, sampler2D historyBuffer) {
    vec3 current = texture(currentBuffer, currentCoord).rgb;
    vec3 history = texture(historyBuffer, prevCoord).rgb;

    float difference = length(current - history);
    return difference < 0.01;
}

// ===================================================================
// PERFORMANCE MONITORING (Debug)
// ===================================================================

// Visualize shader cost
vec3 visualizeShaderCost(float cost) {
    // Green = cheap, yellow = moderate, red = expensive
    if (cost < 0.3) return vec3(0.0, 1.0, 0.0);
    if (cost < 0.7) return vec3(1.0, 1.0, 0.0);
    return vec3(1.0, 0.0, 0.0);
}

// ===================================================================
// SHADER COST CONSTANTS
// ===================================================================

const float COST_SAMPLE_TEXTURE = 0.05;
const float COST_NORMALIZE = 0.02;
const float COST_BRDF = 0.1;
const float COST_SHADOW_PCF = 0.15;
const float COST_SSR = 0.2;
const float COST_BLOOM = 0.08;
const float COST_TAA = 0.1;

// ===================================================================
// END OF OPTIMIZATION MODULE
// ===================================================================

#endif // INCLUDE_OPTIMIZATION
