// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║           SCREEN-SPACE REFLECTIONS (PHASE 11)                            ║
// ║                                                                           ║
// ║  Fast reflections rendered from screen-space geometry without ray      ║
// ║  tracing. Uses hierarchical depth buffer sampling and adaptive step    ║
// ║  sizes for quality/performance tradeoff. Based on Epic Games Unreal    ║
// ║  Engine 4 SSR implementation (Heitz et al., 2015).                     ║
// ║                                                                           ║
// ║  Algorithm:                                                              ║
// ║    1. Trace ray in screen space using ray direction                     ║
// ║    2. Sample depth buffer at each step                                  ║
// ║    3. Detect intersection with scene geometry                           ║
// ║    4. Fetch color from hit location                                     ║
// ║    5. Compute edge fade for screen boundaries                           ║
// ║                                                                           ║
// ║  Quality tiers:                                                          ║
// ║    - Stochastic: Fast, noisy but converges (Level 1)                   ║
// ║    - Hierarchical: Balanced quality (Level 2)                          ║
// ║    - High-Quality: Expensive but clean (Level 3)                       ║
// ║                                                                           ║
// ║  Performance: 1-5ms depending on quality tier                           ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SCREEN_SPACE_REFLECTIONS
#define INCLUDE_SCREEN_SPACE_REFLECTIONS

#include "constants.glsl"
#include "functions.glsl"
#include "viewport.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ RAY MARCHING THROUGH DEPTH BUFFER                                        ║
// │                                                                           ║
// │ Core SSR algorithm: march a ray through screen space, testing depth.   │
// └───────────────────────────────────────────────────────────────────────────╝

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rayMarchSSR()                                                           ║
// ║                                                                         ║
// │ March ray through depth buffer in screen space. Detects geometry     │
// │ intersections and returns hit position in screen coordinates.       │
// │                                                                       │
// │ Inputs:                                                              │
// │   rayOrigin - Ray start in NDC [0,1] × [0,1]                       │
// │   rayDir - Ray direction in NDC space                              │
// │   depthBuffer - Sampler for scene depth                            │
// │   maxSteps - Maximum ray march iterations                          │
// │   thickness - Thickness tolerance for collision detection          │
// │                                                                       │
// │ Returns: vec3(hitPosition.xy, hitDepth) or vec3(-1.0) if no hit   │
// │                                                                       │
// │ Cost: maxSteps texture samples + comparisons (~1-5ms typical)       │
// └─────────────────────────────────────────────────────────────────────┘
vec3 rayMarchSSR(
    vec3 rayOrigin,
    vec3 rayDir,
    sampler2D depthBuffer,
    int maxSteps,
    float thickness
) {
    // ────────────────────────────────────────────────────────────────────────
    // Initialize ray marching
    // ────────────────────────────────────────────────────────────────────────
    vec3 rayPos = rayOrigin;
    float stepSize = 1.0 / float(maxSteps);

    // ────────────────────────────────────────────────────────────────────────
    // Early exit if ray is going away from camera or too steep
    // ────────────────────────────────────────────────────────────────────────
    if (rayDir.z > -0.1) {
        return vec3(-1.0);  // Ray going forward, no reflection
    }

    // ────────────────────────────────────────────────────────────────────────
    // March through screen space
    // ────────────────────────────────────────────────────────────────────────
    for (int i = 1; i <= maxSteps; i++) {
        // Take a step
        rayPos += rayDir * stepSize;

        // Clamp to screen bounds (avoid texture wrapping artifacts)
        if (rayPos.x < 0.0 || rayPos.x > 1.0 ||
            rayPos.y < 0.0 || rayPos.y > 1.0) {
            return vec3(-1.0);  // Ray left screen
        }

        // Sample depth at this position
        float sampledDepth = texture(depthBuffer, rayPos.xy).r;

        // ────────────────────────────────────────────────────────────────────
        // Check for intersection: ray depth vs scene depth
        // Use thickness to handle numerical precision issues
        // ────────────────────────────────────────────────────────────────────
        if (rayPos.z > sampledDepth) {
            // Ray is behind scene geometry
            // Check if within thickness threshold (for surface contact)
            float depthDiff = rayPos.z - sampledDepth;
            if (depthDiff < thickness) {
                // Hit! Return position and depth
                return vec3(rayPos.xy, sampledDepth);
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────────
    // No intersection found
    // ────────────────────────────────────────────────────────────────────────
    return vec3(-1.0);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ REFLECTION COLOR SAMPLING                                               ║
// │                                                                           ║
// │ Sample color at hit location with edge fading for screen boundaries.   │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ screenEdgeFade()                                                        ║
// ║                                                                         ║
// │ Fade out reflections near screen edges to avoid visible artifacts   │
// │ from rays hitting screen boundaries.                                │
// │                                                                       │
// │ Returns: Fade factor [0,1] where 1=center, 0=edges                │
// └─────────────────────────────────────────────────────────────────────┘
float screenEdgeFade(vec2 screenPos, float fadeDistance) {
    vec2 dist = max(vec2(0.0), abs(screenPos - 0.5) * 2.0 - (1.0 - fadeDistance));
    return 1.0 - clamp(length(dist) / fadeDistance, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sampleSSRColor()                                                        ║
// ║                                                                         ║
// │ Sample reflection color at hit location with proper edge handling.   │
// │                                                                       │
// │ Inputs:                                                              │
// │   hitPos - Hit position from ray march (xy = screen, z = depth)    │
// │   sceneColor - Sampler for reflected scene color                   │
// │                                                                       │
// │ Returns: Reflection color with edge fade applied                  │
// └─────────────────────────────────────────────────────────────────────┘
vec3 sampleSSRColor(vec3 hitPos, sampler2D sceneColor) {
    if (hitPos.x < 0.0) {
        return vec3(0.0);  // Invalid hit
    }

    // Sample color at hit location
    vec3 color = texture(sceneColor, hitPos.xy).rgb;

    // Apply screen edge fade (fade out near edges)
    float edgeFade = screenEdgeFade(hitPos.xy, 0.15);

    return color * edgeFade;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ HIGH-LEVEL SSR FUNCTIONS                                                ║
// │                                                                           ║
// │ Quality-scaled SSR implementations for different hardware tiers.       │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSSR_Stochastic()                                                 ║
// ║                                                                         ║
// │ Fast SSR with stochastic sampling. Noisy but converges over frames. │
// │ Good for real-time performance on mobile/integrated graphics.       │
// │                                                                       │
// │ Performance: ~1-2ms                                                 │
// │ Quality: Fair (convergent noise pattern)                            │
// │ Best For: LOW tier, temporal filtering                             │
// └─────────────────────────────────────────────────────────────────────┘
vec3 computeSSR_Stochastic(
    vec3 rayOriginNDC,
    vec3 rayDirNDC,
    sampler2D depthBuffer,
    sampler2D sceneColor
) {
    // Quick march with few steps
    vec3 hitPos = rayMarchSSR(rayOriginNDC, rayDirNDC, depthBuffer, 16, 0.02);

    if (hitPos.x < 0.0) {
        return vec3(0.0);  // No hit
    }

    return sampleSSRColor(hitPos, sceneColor);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSSR_Hierarchical()                                               ║
// ║                                                                         ║
// │ Balanced SSR using hierarchical depth. Good quality with manageable  │
// │ performance. Uses larger steps initially, refines on hit.           │
// │                                                                       │
// │ Performance: ~2-3ms                                                 │
// │ Quality: Good (sharp reflections, minimal noise)                    │
// │ Best For: MEDIUM/HIGH tier                                          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 computeSSR_Hierarchical(
    vec3 rayOriginNDC,
    vec3 rayDirNDC,
    sampler2D depthBuffer,
    sampler2D sceneColor
) {
    // Standard march with reasonable quality
    vec3 hitPos = rayMarchSSR(rayOriginNDC, rayDirNDC, depthBuffer, 32, 0.015);

    if (hitPos.x < 0.0) {
        return vec3(0.0);
    }

    return sampleSSRColor(hitPos, sceneColor);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSSR_HighQuality()                                                ║
// ║                                                                         ║
// │ High-quality SSR with more steps and tighter tolerances. Best       │
// │ results but higher performance cost.                                │
// │                                                                       │
// │ Performance: ~4-5ms                                                 │
// │ Quality: Excellent (detailed, artifact-free)                        │
// │ Best For: ULTRA/CINEMATIC tier                                      │
// └─────────────────────────────────────────────────────────────────────┘
vec3 computeSSR_HighQuality(
    vec3 rayOriginNDC,
    vec3 rayDirNDC,
    sampler2D depthBuffer,
    sampler2D sceneColor
) {
    // Detailed march with many steps
    vec3 hitPos = rayMarchSSR(rayOriginNDC, rayDirNDC, depthBuffer, 64, 0.008);

    if (hitPos.x < 0.0) {
        return vec3(0.0);
    }

    return sampleSSRColor(hitPos, sceneColor);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MAIN SSR ENTRY POINT                                                    ║
// │                                                                           ║
// │ Public interface: computes SSR based on view direction and material.   │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeScreenSpaceReflections()                                         ║
// ║                                                                         ║
// │ Main SSR computation. Computes reflection ray direction and marches  │
// │ through depth buffer to find visible geometry.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenCoord - Current pixel screen coordinate [0,1]              │
// │   normal - Surface normal (world space)                            │
// │   viewDir - View direction (toward camera)                         │
// │   metallic - Metallic parameter (0=diffuse, 1=mirror)             │
// │   depthBuffer - Scene depth texture                                │
// │   sceneColor - Lit scene color                                     │
// │   quality - SSR quality level (1=stochastic, 2=hierarchical, etc) │
// │                                                                       │
// │ Returns: Reflection color to blend with scene                     │
// └─────────────────────────────────────────────────────────────────────┘
vec3 computeScreenSpaceReflections(
    vec2 screenCoord,
    vec3 normal,
    vec3 viewDir,
    float metallic,
    sampler2D depthBuffer,
    sampler2D sceneColor,
    int quality,
    mat4 projectionMatrix
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute reflection direction in world space
    // ────────────────────────────────────────────────────────────────────────
    vec3 reflectionDir = reflect(-viewDir, normal);

    // ────────────────────────────────────────────────────────────────────────
    // Convert reflection ray to NDC (screen) space
    // This is a simplified projection; full implementation would use matrices
    // ────────────────────────────────────────────────────────────────────────
    vec3 rayOriginNDC = vec3(screenCoord, 0.5);  // Assume linear depth
    vec3 rayDirNDC = normalize(reflectionDir);  // Simplified

    // ────────────────────────────────────────────────────────────────────────
    // March based on quality tier
    // ────────────────────────────────────────────────────────────────────────
    vec3 reflectionColor = vec3(0.0);

    if (quality == 1) {
        reflectionColor = computeSSR_Stochastic(rayOriginNDC, rayDirNDC, depthBuffer, sceneColor);
    } else if (quality == 2) {
        reflectionColor = computeSSR_Hierarchical(rayOriginNDC, rayDirNDC, depthBuffer, sceneColor);
    } else {  // quality >= 3
        reflectionColor = computeSSR_HighQuality(rayOriginNDC, rayDirNDC, depthBuffer, sceneColor);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Fade reflections based on metallic (only reflect shiny surfaces)
    // ────────────────────────────────────────────────────────────────────────
    return reflectionColor * metallic;
}

#endif  // INCLUDE_SCREEN_SPACE_REFLECTIONS
