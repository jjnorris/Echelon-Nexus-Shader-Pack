#version 130
precision highp float;
// Saved without BOM to avoid GLSL preprocessor errors
// Phase 2 PCSS integration completed: reconstructWorldPosition, projectToShadowSpace, PCSS usage.
// Integrated per user request; ready for in-game testing.

// ============================================================================
// COMPOSITE FSH - PHASE 2: PCSS SHADOWS
// ============================================================================

// Samplers for input textures
uniform sampler2D colortex0;    // Base color from gbuffers
uniform sampler2D depthtex0;    // Scene depth buffer
uniform sampler2D shadowtex0;   // Shadow map (directional light)
uniform sampler2D shadowcolor0; // Colored shadow data

// Transformation matrices from Iris
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
int debugMode = 9; // 0=off,1=depth,2=worldPos,3=shadowCoord,4=shadow value
// Toggle to invert sampled shadow-map depth (1=invert, 0=normal)
int shadowDepthInvert = 0;
// Small constant bias added to sampled shadow-map depth to avoid self-occlusion
// and reduce false-positive blockers caused by precision/format mismatches.
float shadowBias = 0.002;

// Input UV coordinates
in vec2 uv;

// Output color
out vec4 fragColor;

// ============================================================================
// PCSS SHADOW IMPLEMENTATION
// ============================================================================

/**
 * PCSS: Percentage-Closer Soft Shadows
 * Reference: Fernando et al., "Percentage-Closer Soft Shadows" (SIGGRAPH 2006)
 */

// Poisson disk patterns
const vec2 poissonDisk16[16] = vec2[](
    vec2(-0.94201624,  -0.39906216),
    vec2( 0.94558609,  -0.76890725),
    vec2(-0.74205544,  -0.94693636),
    vec2( 0.34495938,   0.29387760),
    vec2(-0.91588581,   0.45771432),
    vec2(-0.03617221,  -0.99518287),
    vec2( 0.81479360,   0.41529015),
    vec2( 0.78512320,  -0.64545042),
    vec2(-0.48821436,   0.04532837),
    vec2(-0.87421629,   0.19379118),
    vec2(-0.30331618,   0.47817620),
    vec2( 0.14918677,   0.87314927),
    vec2( 0.48140316,   0.15541062),
    vec2( 0.11003546,   0.44798897),
    vec2(-0.61149926,   0.78995058),
    vec2( 0.13168975,  -0.04332821)
);

/**
 * Stage 1: Blocker Search
 */
vec3 pcssBlockerSearch(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float searchRadius, int sampleCount, int invert) {
    float avgBlockerDepth = 0.0;
    float blockerCount = 0.0;

    for (int i = 0; i < 16; i++) {
        if (i >= sampleCount) break;

        vec2 offset = poissonDisk16[i] * searchRadius;
        vec2 samplePos = sampleCoord + offset;
        samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

        float sampledDepth = texture(shadowMap, samplePos).x;
        if (invert == 1) sampledDepth = 1.0 - sampledDepth;
        if (sampledDepth + shadowBias < receiverDepth) {
            avgBlockerDepth += sampledDepth;
            blockerCount += 1.0;
        }
    }

    if (blockerCount > 0.0) {
        avgBlockerDepth /= blockerCount;
    } else {
        avgBlockerDepth = 0.0;
        blockerCount = 0.0;
    }

    return vec3(avgBlockerDepth, blockerCount, searchRadius);
}

/**
 * Stage 2: Penumbra Estimation
 */
float pcssComputePenumbra(float avgBlockerDepth, float receiverDepth, float lightSize) {
    float blockerDistance = avgBlockerDepth;
    float receiverDistance = receiverDepth;
    float penumbraDistance = receiverDistance - blockerDistance;

    if (penumbraDistance <= 0.0) {
        return 0.0;
    }

    float penumbraWidth = (penumbraDistance / blockerDistance) * lightSize;
    return clamp(penumbraWidth, 0.0, 1.0);
}

/**
 * Stage 3: Variable-Radius PCF
 */
float pcssShadowSample(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float filterSize, int sampleCount, int invert) {
    float shadow = 0.0;

    if (filterSize < 0.001) {
        sampleCount = 4;
    } else if (filterSize < 0.05) {
        sampleCount = 8;
    } else if (filterSize < 0.15) {
        sampleCount = 16;
    } else {
        sampleCount = 32;
    }

    for (int i = 0; i < 32; i++) {
        if (i >= sampleCount) break;

        vec2 offset = poissonDisk16[i % 16] * filterSize;
        vec2 samplePos = sampleCoord + offset;
        samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

        float sampledDepth = texture(shadowMap, samplePos).x;
        if (invert == 1) sampledDepth = 1.0 - sampledDepth;
        shadow += ((sampledDepth + shadowBias) >= receiverDepth) ? 1.0 : 0.0;
    }

    return shadow / float(sampleCount);
}

/**
 * Full PCSS Algorithm
 */
float pcssShadow(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                 float lightSize, float searchRadius, int invert) {
    // Stage 1: Blocker search
    vec3 blockerInfo = pcssBlockerSearch(shadowMap, sampleCoord, receiverDepth,
                                          searchRadius, 16, invert);
    float avgBlockerDepth = blockerInfo.x;
    float blockerCount = blockerInfo.y;

    if (blockerCount < 0.5) {
        return 1.0; // No blockers - fully lit
    }

    // Stage 2: Penumbra estimation
    float penumbraSize = pcssComputePenumbra(avgBlockerDepth, receiverDepth, lightSize);
    penumbraSize = clamp(penumbraSize, 0.0, 0.1);

    // Stage 3: PCF filtering
    float shadow = pcssShadowSample(shadowMap, sampleCoord, receiverDepth,
                                    penumbraSize, 16, invert);

    return shadow;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Reconstruct world position from depth buffer
 *
 * @param uv Texture coordinates (0-1)
 * @param depth Linear depth (0-1)
 * @return World position (xyz)
 */
vec3 reconstructWorldPosition(vec2 uv, float depth) {
    // Convert from UV to NDC (Normalized Device Coordinates)
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth * 2.0 - 1.0);

    // Transform to view space using inverse projection
    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
    viewPos /= viewPos.w;  // Perspective divide

    // Transform to world space using inverse model-view
    vec4 worldPos = gbufferModelViewInverse * viewPos;

    return worldPos.xyz;
}

/**
 * Transform world position to shadow space coordinates
 *
 * @param worldPos World position (xyz)
 * @return Shadow texture coordinates (xy) and depth (z)
 */
vec4 projectToShadowSpace(vec3 worldPos) {
    // Transform to shadow space using shadow matrices
    vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    shadowPos /= shadowPos.w;  // Perspective divide

    // Convert from [-1,1] to [0,1] for texture lookup
    vec2 shadowCoord = shadowPos.xy * 0.5 + 0.5;
    float shadowDepth = shadowPos.z * 0.5 + 0.5;  // Normalize depth

    return vec4(shadowCoord, shadowDepth, shadowPos.w);
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

void main() {
    // Load base color from colortex0
    vec4 baseColor = texture(colortex0, uv);

    // Load depth from depth buffer
    float depth = texture(depthtex0, uv).r;

    // Sky check - no shadows on sky
    if (depth > 0.9999) {
        fragColor = baseColor;
        return;
    }

    // Reconstruct world position
    vec3 worldPos = reconstructWorldPosition(uv, depth);

    // Transform to shadow space
    vec4 shadowData = projectToShadowSpace(worldPos);
    vec2 shadowCoord = shadowData.xy;
    float shadowDepth = shadowData.z;

    // PCSS parameters (configurable)  declared early to allow debug sampling
    // Reduced defaults and derivative-based search radius to use normalized
    // shadow-map UV units instead of large absolute offsets that sampled
    // outside the shadow map and produced fully-lit results.
    float lightSize = 0.3;        // Light angular size (smaller => tighter penumbra)
    float baseSearchRadius = 0.01; // Base search radius in normalized shadow UV

    // Approximate per-pixel footprint in shadow UV using derivatives.
    // This yields a stable, resolution-independent radius for blocker searches
    // and PCF filtering.
    vec2 ddx = dFdx(shadowCoord);
    vec2 ddy = dFdy(shadowCoord);
    float texelSize = max(length(ddx), length(ddy));
    texelSize = max(texelSize, 1e-5);

    // Scale the search radius relative to the local UV footprint.
    float searchRadius = max(baseSearchRadius, texelSize * 8.0);

    // Auto-detect shadow-map depth convention per-fragment by sampling the
    // shadow map at the center and comparing which representation (normal or
    // inverted) is closer to the computed `shadowDepth`. This avoids a global
    // toggle mismatch between engines that store depth inverted.
    vec2 scClamp = clamp(shadowCoord, vec2(0.0), vec2(1.0));
    float centerSample = texture(shadowtex0, scClamp).x;
    float normalDiff = abs((centerSample + shadowBias) - shadowDepth);
    float invDiff = abs(((1.0 - centerSample) + shadowBias) - shadowDepth);
    // Test override: set to -1 to keep auto-detection, 0 to force normal, 1 to force inverted.
    int forceFragInvert = 1;
    int fragInvert = (invDiff < normalDiff) ? 1 : 0;
    if (forceFragInvert >= 0) fragInvert = forceFragInvert;

    // Debug visualization modes (set `debugMode` uniform):
    // 0 = off (normal rendering)
    // 1 = show linear depth
    // 2 = show world position (RGB)
    // 3 = show shadow texture coordinates
    // 4 = show PCSS shadow value (0..1)
    if (debugMode == 1) {
        fragColor = vec4(vec3(depth), baseColor.a);
        return;
    } else if (debugMode == 2) {
        vec3 col = normalize(worldPos) * 0.5 + 0.5;
        fragColor = vec4(col, baseColor.a);
        return;
    } else if (debugMode == 3) {
        fragColor = vec4(vec3(shadowCoord, 0.0), baseColor.a);
        return;
    } else if (debugMode == 4) {
        float debugShadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth, lightSize, searchRadius, fragInvert);
        fragColor = vec4(vec3(debugShadow), baseColor.a);
        return;
    } else if (debugMode == 5) {
        // Visualize computed shadow depth in shadow projection space
        fragColor = vec4(vec3(shadowDepth), baseColor.a);
        return;
    } else if (debugMode == 6) {
        // Visualize sampled depth value from the shadow map at this coord
        vec2 sc = clamp(shadowCoord, vec2(0.0), vec2(1.0));
        float sampledDepth = texture(shadowtex0, sc).x;
        // Show sampled depth and also visualize the bias-adjusted sampled depth if helpful
        float adj = clamp(sampledDepth + shadowBias, 0.0, 1.0);
        fragColor = vec4(vec3(adj), baseColor.a);
        return;
    } else if (debugMode == 7) {
        // Visualize difference (receiverDepth - sampledDepth) -> positive = occluder
        vec2 sc = clamp(shadowCoord, vec2(0.0), vec2(1.0));
        float sampledDepth = texture(shadowtex0, sc).x;
        float diff = shadowDepth - (sampledDepth + shadowBias);
        diff = clamp(diff * 10.0, 0.0, 1.0); // scale for visibility
        fragColor = vec4(vec3(diff), baseColor.a);
        return;
    } else if (debugMode == 8) {
        // Visualize blocker count from a single blocker search (0..1 normalized)
        vec3 binfo = pcssBlockerSearch(shadowtex0, shadowCoord, shadowDepth, searchRadius, 16, fragInvert);
        float blockerCount = binfo.y;
        fragColor = vec4(vec3(clamp(blockerCount / 16.0, 0.0, 1.0)), baseColor.a);
        return;
    } else if (debugMode == 9) {
        // Diagnostic: compare computed shadowDepth against INVERTED sampledDepth
        // This helps test whether the shadow map depth convention is reversed.
        vec2 sc = clamp(shadowCoord, vec2(0.0), vec2(1.0));
        float sampledDepth = texture(shadowtex0, sc).x;
        float invSample = 1.0 - sampledDepth;
        float diffInv = shadowDepth - invSample;
        diffInv = clamp(diffInv * 10.0, 0.0, 1.0);
        fragColor = vec4(vec3(diffInv), baseColor.a);
        return;
    }

    else if (debugMode == 10) {
        // Combined diagnostic: R = sampled depth, G = inverted sampled depth,
        // B = occlusion indicator (shadowDepth - sampledDepth - bias scaled)
        vec2 sc = clamp(shadowCoord, vec2(0.0), vec2(1.0));
        float sampledDepth = texture(shadowtex0, sc).x;
        float invSample = 1.0 - sampledDepth;
        float occl = clamp((shadowDepth - (sampledDepth + shadowBias)) * 10.0, 0.0, 1.0);
        fragColor = vec4(vec3(sampledDepth, invSample, occl), baseColor.a);
        return;
    }

    // Check if fragment is within shadow map bounds
    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
        // Outside shadow map - fully lit
        fragColor = baseColor;
        return;
    }

    // Call PCSS algorithm (pass per-fragment invert heuristic)
    float shadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth, lightSize, searchRadius, fragInvert);

    // Apply shadow to color (50-100% brightness range in shadow)
    vec3 shadowed = baseColor.rgb * (0.5 + shadow * 0.5);

    // Output final color
    fragColor = vec4(shadowed, baseColor.a);
}













