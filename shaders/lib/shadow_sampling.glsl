// ===================================================================
// Echelon Nexus - Shadow Sampling & Filtering
// ===================================================================
// Provides PCF and PCSS shadow filtering for realistic soft shadows.
// ===================================================================

#ifndef INCLUDE_SHADOW_SAMPLING
#define INCLUDE_SHADOW_SAMPLING

#include "constants.glsl"
#include "functions.glsl"
#include "lib/blue_noise.glsl"

// ===================================================================
// SHADOW MAP BASICS
// ===================================================================

// Project world position to shadow map coordinates
vec3 projectToShadowSpace(vec3 worldPos, mat4 shadowProjection, mat4 shadowModelView) {
    vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    shadowPos.xyz /= shadowPos.w;
    return shadowPos.xyz * 0.5 + 0.5;  // NDC to [0, 1]
}

// ===================================================================
// BASIC SHADOW COMPARISON
// ===================================================================

// Simple depth comparison: is fragment in shadow?
bool isInShadow(vec3 shadowPos, float compareDepth, float bias) {
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 ||
        shadowPos.y < 0.0 || shadowPos.y > 1.0 ||
        shadowPos.z < 0.0 || shadowPos.z > 1.0) {
        return false;  // Outside shadow map; assume lit
    }

    float shadowMapDepth = texture(shadowtex0, shadowPos.xy).r;
    return compareDepth > shadowMapDepth + bias;
}

// ===================================================================
// PCF (PERCENTAGE-CLOSER FILTERING)
// ===================================================================

// Basic PCF with square kernel
float shadowPCF(
    vec3 shadowPos,
    float compareDepth,
    float filterRadius,
    int sampleCount
) {
    float shadow = 0.0;
    float sampleSize = filterRadius / float(sampleCount);

    for (int x = -sampleCount; x <= sampleCount; x++) {
        for (int y = -sampleCount; y <= sampleCount; y++) {
            vec2 offset = vec2(x, y) * sampleSize;
            vec2 sampleCoord = shadowPos.xy + offset;

            float sampleDepth = texture(shadowtex0, sampleCoord).r;
            if (compareDepth > sampleDepth + SHADOW_BIAS) {
                shadow += 1.0;
            }
        }
    }

    float samples = float((sampleCount * 2 + 1) * (sampleCount * 2 + 1));
    return shadow / samples;
}

// PCF with Poisson disk sampling (better quality, fewer samples)
float shadowPCFPoisson(
    vec3 shadowPos,
    float compareDepth,
    float filterRadius
) {
    // Poisson disk pattern (16 samples)
    vec2 poissonDisk[16] = vec2[](
        vec2(-0.94201, -0.39906), vec2(-0.73744, -0.50497),
        vec2(-0.46212, -0.80840), vec2(-0.34888, -0.72993),
        vec2(-0.29998, -0.04653), vec2(-0.24991, -0.61997),
        vec2(-0.06573, -0.36775), vec2( 0.03477, -0.67946),
        vec2( 0.13586, -0.27554), vec2( 0.30331, -0.41944),
        vec2( 0.46656, -0.09171), vec2( 0.53842, -0.66784),
        vec2( 0.60484, -0.07369), vec2( 0.66847, -0.34519),
        vec2( 0.72490, -0.50617), vec2( 0.85442, -0.12351)
    );

    float shadow = 0.0;
    float randomAngle = rand(shadowPos.xy) * TWO_PI;
    float cos_a = cos(randomAngle);
    float sin_a = sin(randomAngle);

    for (int i = 0; i < 16; i++) {
        vec2 offset = poissonDisk[i] * filterRadius;

        // Rotate offset
        offset = vec2(
            cos_a * offset.x - sin_a * offset.y,
            sin_a * offset.x + cos_a * offset.y
        );

        vec2 sampleCoord = shadowPos.xy + offset;
        float sampleDepth = texture(shadowtex0, sampleCoord).r;

        if (compareDepth > sampleDepth + SHADOW_BIAS) {
            shadow += 1.0;
        }
    }

    return shadow / 16.0;
}

// ===================================================================
// PCSS (PERCENTAGE-CLOSER SOFT SHADOWS)
// ===================================================================

// Estimate shadow receiver distance from light (for soft shadow size)
float findPenumbraSize(
    vec3 shadowPos,
    float compareDepth,
    float lightSize
) {
    // Sample shadow map at nearby points to estimate average blocker distance
    float blockerDistance = 0.0;
    int blockerCount = 0;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(x, y) * 0.01;
            float sampleDepth = texture(shadowtex0, shadowPos.xy + offset).r;

            if (sampleDepth < compareDepth) {
                blockerDistance += sampleDepth;
                blockerCount++;
            }
        }
    }

    if (blockerCount == 0) {
        return 0.0;  // No blockers; no soft shadow
    }

    blockerDistance /= float(blockerCount);

    // Penumbra size is larger when blocker is farther from receiver
    return lightSize * (compareDepth - blockerDistance) / blockerDistance;
}

// PCSS: Contact-hardened soft shadows
float shadowPCSS(
    vec3 shadowPos,
    float compareDepth,
    float lightSize
) {
    // Step 1: Find average blocker distance
    float penumbraSize = findPenumbraSize(shadowPos, compareDepth, lightSize);

    if (penumbraSize < 0.0001) {
        // No soft shadow; use simple comparison
        return isInShadow(shadowPos, compareDepth, SHADOW_BIAS) ? 1.0 : 0.0;
    }

    // Step 2: PCF with penumbra-sized kernel
    return shadowPCFPoisson(shadowPos, compareDepth, penumbraSize);
}

// ===================================================================
// VARIANCE SHADOW MAP (VSM) - Advanced
// ===================================================================

// Chebyshev's inequality for variance shadow mapping
float shadowVSM(vec3 shadowPos, float compareDepth) {
    vec2 moments = texture(shadowtex0, shadowPos.xy).xy;

    // Moments.x = depth, moments.y = depth²
    float p = step(compareDepth, moments.x);

    float variance = moments.y - (moments.x * moments.x);
    variance = max(variance, 0.00002);

    float d = compareDepth - moments.x;
    float pMax = variance / (variance + d * d);

    return max(p, pMax);
}

// ===================================================================
// SHADOW TERM COMPUTATION
// ===================================================================

// Compute final shadow factor based on quality setting
float computeShadowFactor(
    vec3 worldFragPos,
    mat4 shadowProjection,
    mat4 shadowModelView,
    int shadowQuality
) {
    // Project to shadow space
    vec3 shadowPos = projectToShadowSpace(worldFragPos, shadowProjection, shadowModelView);

    // Bias based on surface normal (helps prevent self-shadowing)
    // Simplified: use constant bias for now
    float bias = SHADOW_BIAS;

    // Compute shadow based on quality setting
    float shadowFactor = 0.0;

    switch (shadowQuality) {
        case 0:  // PCF
            shadowFactor = shadowPCF(shadowPos, shadowPos.z, 1.5, 2);
            break;

        case 1:  // PCSS (contact-hardened)
            shadowFactor = shadowPCSS(shadowPos, shadowPos.z, 0.02);
            break;

        case 2:  // Advanced (VSM or blue-noise filtered)
            // For now, use Poisson PCF as substitute
            shadowFactor = shadowPCFPoisson(shadowPos, shadowPos.z, 2.0);
            break;

        default:
            // Fallback: simple comparison
            shadowFactor = isInShadow(shadowPos, shadowPos.z, bias) ? 1.0 : 0.0;
            break;
    }

    return shadowFactor;
}

// ===================================================================
// SHADOW DEBUGGING
// ===================================================================

// Visualize shadow map (for debugging)
vec3 visualizeShadowMap(vec3 shadowPos) {
    float depth = texture(shadowtex0, shadowPos.xy).r;
    return vec3(depth);
}

// Visualize shadow factor
vec3 visualizeShadowFactor(float shadowFactor) {
    // Red = shadowed, green = lit
    return mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), shadowFactor);
}

// ===================================================================
// END OF SHADOW SAMPLING MODULE
// ===================================================================

#endif // INCLUDE_SHADOW_SAMPLING
