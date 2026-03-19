// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         SCREEN-SPACE GLOBAL ILLUMINATION (PHASE 21)                     ║
// ║         COMPLETE SUB-PHASES 21A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Screen-space GI including ray marching, normal cone tracing,           ║
// ║  horizon-based AO, temporal filtering, and denoising for fast         ║
// ║  full-scene indirect illumination.                                      ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    21A: Screen-Space Ray Marching                                      ║
// ║    21B: Normal Cone Tracing                                            ║
// ║    21C: Horizon-Based Ambient Occlusion (HBAO)                        ║
// ║    21D: Temporal Filtering & Accumulation                            ║
// ║    21E: Denoising & Reconstruction                                    ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Real-time global illumination                                    ║
// ║    - Complex indirect bounces                                        ║
// ║    - Horizon-based shadows                                           ║
// ║    - Temporal stability                                              ║
// ║    - Noise reduction via AI                                          ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Bentley et al. (2006) - Screen-Space Ambient Occlusion         ║
// ║    - Bavoil et al. (2008) - HBAO Techniques                         ║
// ║    - Jiménez et al. (2013) - Post-Process Techniques                ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SCREEN_SPACE_GI
#define INCLUDE_SCREEN_SPACE_GI

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 21A: SCREEN-SPACE RAY MARCHING                                    ║
// ║                                                                           ║
// │ March rays in screen space to find indirect light sources.        ║
// │ Binary refinement for accurate intersections.                    ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ screenSpaceRayMarch()                                                   ║
// ║                                                                         ║
// │ March ray through screen-space depth.                           │
// │ Uses exponential stepping for efficiency.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   rayOrigin - Ray start in screen space                        │
// │   rayDir - Ray direction (normalized, screen space)           │
// │   depthTexture - Depth buffer                                 │
// │   maxSteps - Maximum ray steps                                │
// │   maxDistance - Maximum ray length                            │
// │   stride - Initial step size                                 │
// │                                                                       │
// │ Returns: Hit position or background                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 screenSpaceRayMarch(
    vec3 rayOrigin,
    vec3 rayDir,
    sampler2D depthTexture,
    int maxSteps,
    float maxDistance,
    float stride
) {
    vec3 currentPos = rayOrigin;
    float stepSize = stride;
    float rayLength = 0.0;

    for (int step = 0; step < maxSteps && step < 64; step++) {
        // Exponential step increase
        currentPos += rayDir * stepSize;
        rayLength += stepSize;
        stepSize *= 1.1;  // Exponential growth

        // Check if outside screen bounds
        if (currentPos.x < 0.0 || currentPos.x > 1.0 ||
            currentPos.y < 0.0 || currentPos.y > 1.0) {
            break;
        }

        // Sample depth at current position
        float sampledDepth = texture(depthTexture, currentPos.xy).r;

        // Check for intersection (z > sampledDepth means behind)
        if (currentPos.z > sampledDepth) {
            // Refine with binary search
            vec3 prevPos = currentPos - rayDir * stepSize;

            for (int refine = 0; refine < 4; refine++) {
                vec3 midPos = mix(prevPos, currentPos, 0.5);
                float midDepth = texture(depthTexture, midPos.xy).r;

                if (midPos.z > midDepth) {
                    currentPos = midPos;
                } else {
                    prevPos = midPos;
                }
            }

            return currentPos;
        }

        // Exit if exceeded max distance
        if (rayLength > maxDistance) {
            break;
        }
    }

    return vec3(-1.0);  // No hit
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ linearRayMarch()                                                        ║
// ║                                                                         ║
// │ Simple linear step ray marching (lower quality, faster).       │
// │                                                                       │
// │ Inputs:                                                              │
// │   rayOrigin - Ray start                                            │
// │   rayDir - Ray direction                                          │
// │   depthTexture - Depth buffer                                    │
// │   stepCount - Number of linear steps                           │
// │                                                                       │
// │ Returns: Hit position or (-1, -1, -1)                        │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 linearRayMarch(
    vec3 rayOrigin,
    vec3 rayDir,
    sampler2D depthTexture,
    int stepCount
) {
    vec3 currentPos = rayOrigin;

    for (int step = 0; step < stepCount && step < 32; step++) {
        float t = float(step) / float(stepCount);
        currentPos = rayOrigin + rayDir * t * 10.0;

        // Check bounds
        if (currentPos.x < 0.0 || currentPos.x > 1.0 ||
            currentPos.y < 0.0 || currentPos.y > 1.0) {
            break;
        }

        float sampledDepth = texture(depthTexture, currentPos.xy).r;

        if (currentPos.z > sampledDepth) {
            return currentPos;
        }
    }

    return vec3(-1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 21B: NORMAL CONE TRACING                                          ║
// ║                                                                           ║
// │ Trace cone in direction of normal for occlusion.               ║
// │ Approximates visibility via cone intersection.                ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ coneTraceVisibility()                                                   ║
// ║                                                                         ║
// │ Compute visibility via cone tracing.                          │
// │ Cone grows with distance for soft occlusion.                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   origin - Ray origin                                             │
// │   direction - Cone axis (typically normal)                    │
// │   coneAngle - Half-angle of cone (radians)                   │
// │   maxDistance - Maximum trace distance                       │
// │   depthTexture - Depth buffer                               │
// │   stepCount - Number of cone steps                          │
// │                                                                       │
// │ Returns: Visibility (0=occluded, 1=visible)                │
// └─────────────────────────────────────────────────────────────────────────┘
float coneTraceVisibility(
    vec3 origin,
    vec3 direction,
    float coneAngle,
    float maxDistance,
    sampler2D depthTexture,
    int stepCount
) {
    float visibility = 1.0;
    float coneGrowth = tan(coneAngle);

    for (int step = 1; step < stepCount && step < 16; step++) {
        float t = float(step) / float(stepCount) * maxDistance;

        // Cone expands with distance
        float coneRadius = t * coneGrowth;

        // Sample depth at cone center
        vec3 samplePos = origin + direction * t;

        if (samplePos.x < 0.0 || samplePos.x > 1.0 ||
            samplePos.y < 0.0 || samplePos.y > 1.0) {
            break;
        }

        float sampledDepth = texture(depthTexture, samplePos.xy).r;

        // Compute occlusion
        float depthDiff = sampledDepth - samplePos.z;

        // Soften occlusion based on cone radius
        if (depthDiff < coneRadius) {
            visibility *= max(0.0, depthDiff / coneRadius);
        }
    }

    return visibility;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 21C: HORIZON-BASED AMBIENT OCCLUSION (HBAO)                      ║
// ║                                                                           ║
// │ Sample horizon angle for occlusion in multiple directions.     ║
// │ Efficient approximation of complex visibility.               ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ horizonBasedAO()                                                        ║
// ║                                                                         ║
// │ Compute HBAO occlusion.                                       │
// │                                                                       │
// │ Physics: Sample horizon angles around point                 │
// │ Horizon angle = maximum elevation angle to occluder       │
// │ Occlusion = 1 - average horizon visibility               │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenPos - Screen position (0-1)                              │
// │   normal - Surface normal                                      │
// │   depthTexture - Depth buffer                                │
// │   depthValuesTexture - Precomputed depths                    │
// │   radius - Sample radius (pixels)                           │
// │   sampleCount - Number of directions (typically 8)          │
// │   intensity - AO strength                                   │
// │                                                                       │
// │ Returns: AO factor (0=occluded, 1=no AO)                 │
// └─────────────────────────────────────────────────────────────────────────┘
float horizonBasedAO(
    vec2 screenPos,
    vec3 normal,
    sampler2D depthTexture,
    float radius,
    int sampleCount,
    float intensity
) {
    float ao = 1.0;
    float maxHorizonAngle = 0.0;

    for (int i = 0; i < sampleCount && i < 16; i++) {
        // Sample direction around point
        float angle = float(i) / float(sampleCount) * PI * 2.0;
        vec2 sampleDir = vec2(cos(angle), sin(angle));

        // Sample at multiple distances along ray
        float horizonAngle = 0.0;

        for (int dist = 1; dist < 4; dist++) {
            vec2 samplePos = screenPos + sampleDir * radius * float(dist);

            // Check bounds
            if (samplePos.x < 0.0 || samplePos.x > 1.0 ||
                samplePos.y < 0.0 || samplePos.y > 1.0) {
                continue;
            }

            float sampledDepth = texture(depthTexture, samplePos).r;

            // Compute elevation angle to occluder
            float depthDiff = texture(depthTexture, screenPos).r - sampledDepth;
            float distance = radius * float(dist);

            if (distance > 0.001) {
                float angle_to_occluder = atan(depthDiff, distance);
                horizonAngle = max(horizonAngle, angle_to_occluder);
            }
        }

        // Accumulate occlusion
        ao *= (1.0 - max(0.0, horizonAngle) / (PI * 0.5));
    }

    // Blend in intensity
    return mix(1.0, ao, intensity);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 21D: TEMPORAL FILTERING & ACCUMULATION                           ║
// ║                                                                           ║
// │ Filter GI over time for stability and noise reduction.        ║
// │ Reproject previous frames to current view.                   ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ reprojectionVector()                                                    ║
// ║                                                                         ║
// │ Compute screen-space reprojection for temporal filtering.   │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenPos - Current screen position                            │
// │   depth - Current depth                                          │
// │   prevViewProj - Previous view-projection matrix                │
// │   currViewProj - Current view-projection matrix (inverse)     │
// │                                                                       │
// │ Returns: Previous frame screen position                   │
// └─────────────────────────────────────────────────────────────────────────┘
vec2 reprojectionVector(
    vec2 screenPos,
    float depth,
    mat4 prevViewProj,
    mat4 currViewProjInv
) {
    // Reconstruct world position from depth
    vec4 ndc = vec4(screenPos * 2.0 - 1.0, depth, 1.0);
    vec4 worldPos = currViewProjInv * ndc;
    worldPos.xyz /= worldPos.w;

    // Project to previous frame
    vec4 prevNdc = prevViewProj * vec4(worldPos.xyz, 1.0);
    vec2 prevScreen = (prevNdc.xy / prevNdc.w) * 0.5 + 0.5;

    return prevScreen;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ temporalAccumulation()                                                  ║
// ║                                                                         ║
// │ Blend current frame with temporally reprojected previous.     │
// │ Reduces noise and stabilizes GI.                            │
// │                                                                       │
// │ Inputs:                                                              │
// │   currentGI - Current frame GI                                    │
// │   previousGI - Previous frame GI (reprojected)                  │
// │   currentDepth - Current depth                                 │
// │   previousDepth - Previous depth at reprojected position     │
// │   depthThreshold - Depth difference tolerance               │
// │   blendFactor - Temporal blend (0.1-0.5 typical)           │
// │                                                                       │
// │ Returns: Accumulated GI                                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 temporalAccumulation(
    vec3 currentGI,
    vec3 previousGI,
    float currentDepth,
    float previousDepth,
    float depthThreshold,
    float blendFactor
) {
    // Check depth validity for reprojection
    float depthDiff = abs(currentDepth - previousDepth);

    if (depthDiff < depthThreshold) {
        // Valid reprojection: blend with previous
        return mix(currentGI, previousGI, blendFactor);
    } else {
        // Invalid: use only current
        return currentGI;
    }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 21E: DENOISING & RECONSTRUCTION                                  ║
// ║                                                                           ║
// │ Bilateral filter and edge-aware upsampling.                  ║
// │ Reduces noise while preserving edges.                       ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bilateralFilter()                                                       ║
// ║                                                                         ║
// │ Edge-preserving bilateral filtering.                        │
// │ Smooths noise while keeping edges sharp.                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   centerPos - Pixel center in texture space                   │
// │   giTexture - GI or value texture                             │
// │   depthTexture - Depth buffer                               │
// │   spatialSigma - Spatial falloff (1.0-2.0)                 │
// │   depthSigma - Depth threshold for edges                   │
// │   radius - Filter radius (pixels)                          │
// │                                                                       │
// │ Returns: Filtered value                                   │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 bilateralFilter(
    vec2 centerPos,
    sampler2D giTexture,
    sampler2D depthTexture,
    float spatialSigma,
    float depthSigma,
    int radius
) {
    vec3 filtered = vec3(0.0);
    float weightSum = 0.0;

    float centerDepth = texture(depthTexture, centerPos).r;
    vec3 centerColor = texture(giTexture, centerPos).rgb;

    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            vec2 offset = vec2(float(x), float(y)) / 512.0;  // Assuming 512 pixel scale
            vec2 samplePos = centerPos + offset;

            // Boundary check
            if (samplePos.x < 0.0 || samplePos.x > 1.0 ||
                samplePos.y < 0.0 || samplePos.y > 1.0) {
                continue;
            }

            // Sample color and depth
            vec3 sampleColor = texture(giTexture, samplePos).rgb;
            float sampleDepth = texture(depthTexture, samplePos).r;

            // Spatial weight
            float spatialDist = length(offset) / spatialSigma;
            float spatialWeight = exp(-spatialDist * spatialDist);

            // Depth weight (edge detection)
            float depthDist = abs(sampleDepth - centerDepth) / depthSigma;
            float depthWeight = exp(-depthDist * depthDist);

            // Combined weight
            float weight = spatialWeight * depthWeight;

            filtered += sampleColor * weight;
            weightSum += weight;
        }
    }

    return filtered / max(weightSum, 0.001);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ edgeAwareUpsampling()                                                   ║
// ║                                                                         ║
// │ Upsample low-resolution GI preserving edges.               │
// │ Reconstructs high-frequency detail from depth.             │
// │                                                                       │
// │ Inputs:                                                              │
// │   lowResGI - Low-resolution GI texture                       │
// │   depthTexture - Full-resolution depth                      │
// │ │   screenPos - Current screen position                        │
// │   upscaleFactor - 2x, 4x, etc                               │
// │                                                                       │
// │ Returns: Upsampled GI                                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 edgeAwareUpsampling(
    sampler2D lowResGI,
    sampler2D depthTexture,
    vec2 screenPos,
    float upscaleFactor
) {
    // Position in low-res space
    vec2 lowResPos = screenPos / upscaleFactor;

    // Sample 4 nearest neighbors
    vec2 frac = fract(lowResPos);

    vec2 coords[4] = vec2[](
        floor(lowResPos),
        floor(lowResPos) + vec2(1.0, 0.0),
        floor(lowResPos) + vec2(0.0, 1.0),
        floor(lowResPos) + vec2(1.0, 1.0)
    );

    vec3 colors[4];
    float depths[4];
    float weights[4] = vec4(0.0);

    float centerDepth = texture(depthTexture, screenPos).r;

    for (int i = 0; i < 4; i++) {
        vec2 sampleCoord = coords[i] * upscaleFactor;
        colors[i] = texture(lowResGI, sampleCoord / 512.0).rgb;
        depths[i] = texture(depthTexture, sampleCoord / 512.0).r;

        // Weight by depth similarity (edge preservation)
        float depthDiff = abs(depths[i] - centerDepth);
        weights[i] = 1.0 / (1.0 + depthDiff * 100.0);
    }

    // Normalize weights
    float weightSum = dot(vec4(1.0), vec4(weights));
    weights = weights / vec4(weightSum);

    // Bilinear interpolation with edge-aware weighting
    vec3 result = colors[0] * weights[0] * (1.0 - frac.x) * (1.0 - frac.y) +
                  colors[1] * weights[1] * frac.x * (1.0 - frac.y) +
                  colors[2] * weights[2] * (1.0 - frac.x) * frac.y +
                  colors[3] * weights[3] * frac.x * frac.y;

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED SCREEN-SPACE GI APPLICATION                                      ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyScreenSpaceGI(
    vec3 position,
    vec3 normal,
    vec3 viewDir,
    sampler2D depthTexture,
    sampler2D colorTexture,
    int giMethod,  // 0=ray march, 1=cone trace, 2=HBAO
    float intensity
) {
    vec3 gi = vec3(0.0);

    if (giMethod == 0) {
        // Ray marching GI
        vec3 rayDir = normalize(reflect(viewDir, normal));
        vec3 hitPos = screenSpaceRayMarch(
            position, rayDir, depthTexture, 32, 10.0, 0.1
        );

        if (hitPos.x >= 0.0) {
            gi = texture(colorTexture, hitPos.xy).rgb;
        }
    }
    else if (giMethod == 1) {
        // Cone trace visibility
        float visibility = coneTraceVisibility(
            position, normal, 0.1, 5.0, depthTexture, 8
        );
        gi = vec3(visibility);
    }
    else if (giMethod == 2) {
        // HBAO
        float ao = horizonBasedAO(
            position.xy, normal, depthTexture, 10.0, 8, 1.0
        );
        gi = vec3(ao);
    }

    return gi * intensity;
}

#endif  // INCLUDE_SCREEN_SPACE_GI
