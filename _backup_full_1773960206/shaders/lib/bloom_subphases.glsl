// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║    BLOOM SUB-PHASES (PHASE 14A-E) - ADVANCED BLOOM EXTENSIONS            ║
// ║                                                                           ║
// ║  Extensions to Phase 14 bloom system:                                   ║
// ║    14A: Dynamic bloom threshold adjustment                              ║
// ║    14B: Per-light bloom contributions                                   ║
// ║    14C: Bloom + motion blur integration                                ║
// ║    14D: Advanced glare and halo effects                                ║
// ║    14E: God rays bloom interaction                                     ║
// ║                                                                           ║
// ║  Builds on bloom_and_spectral.glsl for comprehensive bloom system.     ║
// ║  Optional enhancements for advanced visual effects.                    ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_BLOOM_SUBPHASES
#define INCLUDE_BLOOM_SUBPHASES

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 14A: DYNAMIC BLOOM THRESHOLD ADJUSTMENT                           ║
// ║                                                                           ║
// │ Adjust bloom threshold based on scene average luminance.               ║
// │ Prevents over-bloom in bright scenes, maintains bloom in dark scenes. ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSceneAverageLuminance()                                          ║
// ║                                                                         ║
// │ Compute average luminance of entire scene for adaptive bloom.        │
// │ Uses logarithmic histogram binning for efficient computation.        │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample multiple screen positions                               │
// │   2. Compute luminance at each sample                              │
// │   3. Take geometric mean (log average)                            │
// │   4. Clamp to reasonable range                                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   colorBuffer - Scene color texture                               │
// │   screenCoord - Current screen coordinate                        │
// │   sampleCount - Number of samples (typically 4-9)                │
// │                                                                       │
// │ Returns: Average scene luminance [0.0, ∞]                       │
// └─────────────────────────────────────────────────────────────────────┘
float computeSceneAverageLuminance(
    vec2 screenCoord,
    int sampleCount
) {
    // Sample grid positions (spread across screen for representative sampling)
    // Note: Requires colortex0 sampler to be available in calling context
    vec2 samples[9] = vec2[](
        vec2(0.2, 0.2),  vec2(0.5, 0.2),  vec2(0.8, 0.2),
        vec2(0.2, 0.5),  vec2(0.5, 0.5),  vec2(0.8, 0.5),
        vec2(0.2, 0.8),  vec2(0.5, 0.8),  vec2(0.8, 0.8)
    );

    // Accumulate luminance samples
    float logLuminanceSum = 0.0;
    for (int i = 0; i < sampleCount && i < 9; i++) {
        vec3 sampleColor = texture(colortex0, samples[i]).rgb;
        float sampleLum = max(0.001, computeLuminance(sampleColor));  // Avoid log(0)
        logLuminanceSum += log(sampleLum);
    }

    // Geometric mean: exp(log_avg) = exp(sum_log / count)
    float averageLuminance = exp(logLuminanceSum / float(sampleCount));

    // Clamp to reasonable range [0.01, 10.0]
    return clamp(averageLuminance, 0.01, 10.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ adaptiveBloomThreshold()                                                ║
// ║                                                                         ║
// │ Adjust bloom threshold dynamically based on scene average luminance. │
// │ Bright scenes: raise threshold (less bloom)                         │
// │ Dark scenes: lower threshold (more bloom)                           │
// │                                                                       │
// │ Algorithm:                                                            │
// │   baseThreshold = user-specified threshold (typically 1.0)         │
// │   sceneLum = average scene luminance                               │
// │   factor = pow(sceneLum, curve)  // Curve controls responsiveness  │
// │   adaptiveThreshold = baseThreshold × factor                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   baseThreshold - Initial threshold from settings (0.5-2.0)        │
// │   sceneLuminance - Average scene luminance                        │
// │   adaptCurve - Responsiveness curve (typically 0.3-0.7)          │
// │                                                                       │
// │ Returns: Adapted threshold (automatically scales with scene)     │
// │                                                                       │
// │ Example:                                                            │
// │   Bright sunny scene (lum=2.0):                                  │
// │     adaptiveThreshold = 1.0 × pow(2.0, 0.5) = 1.414 (higher)   │
// │     Result: Less bloom (only very bright pixels)                 │
// │                                                                       │
// │   Dark night scene (lum=0.2):                                   │
// │     adaptiveThreshold = 1.0 × pow(0.2, 0.5) = 0.447 (lower)    │
// │     Result: More bloom (even moderate brightness blooms)         │
// └─────────────────────────────────────────────────────────────────────┘
float adaptiveBloomThreshold(
    float baseThreshold,
    float sceneLuminance,
    float adaptCurve
) {
    // Scale threshold based on scene luminance
    // pow(sceneLum, curve) creates exponential response
    float adaptFactor = pow(sceneLuminance, adaptCurve);

    // Clamp to reasonable range [0.5 × base, 2.0 × base]
    float adaptedThreshold = baseThreshold * adaptFactor;
    adaptedThreshold = clamp(adaptedThreshold, baseThreshold * 0.5, baseThreshold * 2.0);

    return adaptedThreshold;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 14B: PER-LIGHT BLOOM CONTRIBUTIONS                               ║
// ║                                                                           ║
// │ Extract and render individual bloom from different light sources.    ║
// │ Creates realistic per-light glow effects and light interaction.     ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computePointLightBloom()                                                ║
// ║                                                                         ║
// │ Compute bloom halo for a point light source.                         │
// │ Creates realistic bloom around bright dynamic lights.               │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Compute distance from pixel to light (world space)            │
// │   2. Project light to screen for 2D halo                          │
// │   3. Apply inverse-square law falloff                            │
// │   4. Combine brightness-based bloom contribution                 │
// │   5. Modulate by light color and intensity                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightPos - Light position (world space)                        │
// │   lightColor - Light color (RGB)                                │
// │   lightRadius - Light influence radius (world units)            │
// │   screenCoord - Current pixel screen coordinate                │
// │   pixelWorldPos - Pixel world position                         │
// │   invViewProj - Inverse view-projection matrix                │
// │                                                                       │
// │ Returns: Bloom contribution from this point light            │
// └─────────────────────────────────────────────────────────────────────┘
vec3 computePointLightBloom(
    vec3 lightPos,
    vec3 lightColor,
    float lightRadius,
    vec2 screenCoord,
    vec3 pixelWorldPos,
    mat4 invViewProj
) {
    // Vector from pixel to light
    vec3 pixelToLight = lightPos - pixelWorldPos;
    float distToLight = length(pixelToLight);

    // Only bloom if light is nearby
    if (distToLight > lightRadius * 2.0) {
        return vec3(0.0);
    }

    // Distance-based falloff: inverse square law + soft transition
    float normalizedDist = distToLight / lightRadius;
    float distFalloff = 1.0 / (1.0 + normalizedDist * normalizedDist * 4.0);
    distFalloff = smoothstep(2.0, 0.0, normalizedDist);  // Soft edge

    // Screen-space halo using light brightness as proxy
    // Brighter lights create larger halos
    float haloSize = 0.1 + length(lightColor) * 0.15;

    // Distance in screen space for visual halo
    vec2 screenLightOffset = normalize(pixelToLight.xy) * haloSize;
    float screenDist = length(screenCoord - screenLightOffset);

    // Screen-space halo falloff
    float haloFalloff = exp(-screenDist * screenDist * 20.0);

    // Combined bloom: distance falloff × halo effect × light brightness
    vec3 bloomIntensity = lightColor * distFalloff * haloFalloff;

    return bloomIntensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ accumulatePointLightsBoom()                                             ║
// ║                                                                         ║
// │ Accumulate bloom from multiple point light sources.                 │
// │ Efficiently handles up to 4 dynamic lights with culling.           │
// │                                                                       │
// │ Inputs:                                                              │
// │   pixelWorldPos - World position of current pixel                 │
// │   screenCoord - Screen coordinates (0-1)                         │
// │   lightPositions - Array of light positions (up to 4)            │
// │   lightColors - Array of light colors (up to 4)                 │
// │   lightRadii - Array of light radii (up to 4)                   │
// │   lightCount - Number of active lights (0-4)                    │
// │                                                                       │
// │ Returns: Accumulated bloom from all nearby lights                │
// └─────────────────────────────────────────────────────────────────────┘
vec3 accumulatePointLightsBloom(
    vec3 pixelWorldPos,
    vec2 screenCoord,
    vec3 lightPositions[4],
    vec3 lightColors[4],
    float lightRadii[4],
    int lightCount
) {
    vec3 totalBloom = vec3(0.0);

    for (int i = 0; i < lightCount && i < 4; i++) {
        vec3 lightBloom = computePointLightBloom(
            lightPositions[i],
            lightColors[i],
            lightRadii[i],
            screenCoord,
            pixelWorldPos,
            mat4(1.0)  // Placeholder for actual matrix
        );
        totalBloom += lightBloom;
    }

    return totalBloom;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 14C: BLOOM + MOTION BLUR INTEGRATION                             ║
// ║                                                                           ║
// │ Integrate bloom with motion blur for realistic camera effects.       ║
// │ Bright objects leave bloom trails with motion.                      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeMotionBloomTrail()                                               ║
// ║                                                                         ║
// │ Add motion blur trail to bloom effect.                              │
// │ Creates cinematic glow trails from moving bright objects.         │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Get pixel velocity (from motion vector)                      │
// │   2. Sample bloom along velocity direction                       │
// │   3. Accumulate samples with falloff                             │
// │   4. Blend with current bloom                                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Base bloom color                                 │
// │   velocityPixels - Motion vector in pixels                     │
// │   screenCoord - Current screen coordinate                      │
// │   bloomSampler - Bloom texture sampler                         │
// │   motionBlur Amount - Trail intensity (0.0-1.0)              │
// │                                                                       │
// │ Returns: Bloom with motion trail applied                      │
// └─────────────────────────────────────────────────────────────────────┘
// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ estimatePixelVelocity()                                                 ║
// ║                                                                         ║
// │ Estimate pixel velocity from frame-to-frame changes.               │
// │ Uses screen-space color differentiation to detect motion.          │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenCoord - Current screen coordinate                        │
// │   colorBuffer - Current frame color                             │
// │   historyBuffer - Previous frame color (if available)           │
// │                                                                       │
// │ Returns: Estimated velocity in screen pixels                   │
// └─────────────────────────────────────────────────────────────────────┘
vec2 estimatePixelVelocity(
    vec2 screenCoord,
    sampler2D colorBuffer,
    sampler2D historyBuffer
) {
    // Sample current and history colors
    vec3 currentColor = texture(colorBuffer, screenCoord).rgb;
    vec3 historyColor = texture(historyBuffer, screenCoord).rgb;

    // Color difference indicates motion
    vec3 colorDiff = currentColor - historyColor;
    float brightness = length(colorDiff);

    // Search neighbors for best match (simple block matching)
    vec2 bestVelocity = vec2(0.0);
    float bestMatch = brightness;
    float searchRadius = 0.02;  // Search ±2% of screen

    for (float dx = -searchRadius; dx <= searchRadius; dx += searchRadius / 2.0) {
        for (float dy = -searchRadius; dy <= searchRadius; dy += searchRadius / 2.0) {
            vec2 offset = vec2(dx, dy);
            vec3 neighbor = texture(historyBuffer, screenCoord + offset).rgb;
            float neighborDiff = length(currentColor - neighbor);

            if (neighborDiff < bestMatch) {
                bestMatch = neighborDiff;
                bestVelocity = offset * 1000.0;  // Convert to pixel units
            }
        }
    }

    return bestVelocity;
}

vec3 computeMotionBloomTrail(
    vec3 bloomColor,
    vec2 velocityPixels,
    vec2 screenCoord,
    float motionBlurAmount
) {
    // Handle zero velocity
    float velocityMagnitude = length(velocityPixels);
    if (velocityMagnitude < 0.01) {
        return bloomColor;  // No motion
    }

    // Normalize direction and scale trail length
    vec2 trailDirection = normalize(velocityPixels);
    float trailLength = min(velocityMagnitude, 0.1) * motionBlurAmount;  // Cap at 10% screen

    // Sample along motion trail
    vec3 trailAccum = bloomColor;
    int trailSamples = 8;
    float sampleWeight = 1.0;

    for (int i = 1; i <= trailSamples; i++) {
        // Sample position along trail (backward in time)
        float sampleDistance = (float(i) / float(trailSamples)) * trailLength;
        vec2 sampleUV = screenCoord - trailDirection * sampleDistance;

        // Check bounds
        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 ||
            sampleUV.y < 0.0 || sampleUV.y > 1.0) {
            continue;
        }

        // Sample color at trail position
        vec3 trailSample = texture(colortex0, sampleUV).rgb;

        // Exponential falloff with distance (recent samples stronger)
        float trailFalloff = exp(-float(i) / 3.0);
        trailAccum += trailSample * trailFalloff * 0.15;
        sampleWeight += trailFalloff;
    }

    // Normalize by accumulated weight
    trailAccum /= sampleWeight;

    // Blend: stronger motion = more trail visibility
    return mix(bloomColor, trailAccum, min(motionBlurAmount, 0.5));
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 14D: ADVANCED GLARE & HALO EFFECTS                               ║
// ║                                                                           ║
// │ Implement lens glints, star patterns, and custom halo shapes.       ║
// │ Advanced optical effects for realistic lens simulation.             ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ starGlint()                                                             ║
// ║                                                                         ║
// │ Create star glint pattern from bright point sources.                │
// │ Simulates diffraction spikes from circular aperture.               │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Get vector from screen center to bright pixel                 │
// │   2. Create cross pattern (+ shape) with rays                     │
// │   3. Add cross diagonal lines (× shape)                          │
// │   4. Modulate by distance and angle                              │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Color to create glint from                       │
// │   screenCoord - Pixel screen coordinate                        │
// │   sourceCoord - Bright source screen coordinate               │
// │   glintStrength - Intensity of glint (0.0-1.0)                │
// │                                                                       │
// │ Returns: Glint contribution (additive)                          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 starGlint(
    vec3 bloomColor,
    vec2 screenCoord,
    vec2 sourceCoord,
    float glintStrength
) {
    // Vector from source to pixel
    vec2 direction = screenCoord - sourceCoord;
    float distance = length(direction);

    if (distance < 0.01) {
        return vec3(0.0);  // Too close to source
    }

    // Normalize direction
    vec2 dirNorm = normalize(direction);

    // Create 4-point star pattern (+ shape)
    float horizontalRay = abs(dirNorm.y);  // Horizontal line
    float verticalRay = abs(dirNorm.x);    // Vertical line

    // Create 4-point diagonal star (× shape)
    float diag1 = abs(dirNorm.x - dirNorm.y);  // Diagonal /
    float diag2 = abs(dirNorm.x + dirNorm.y);  // Diagonal \

    // Combine patterns
    float starPattern = max(max(horizontalRay, verticalRay),
                           max(diag1, diag2) * 0.707);  // Reduce diagonal strength

    // Sharpen star lines
    starPattern = pow(starPattern, 12.0);

    // Distance falloff (rays fade with distance)
    float falloff = exp(-distance * distance * 0.5);

    // Combine: star pattern modulated by falloff
    vec3 glint = bloomColor * starPattern * falloff * glintStrength;

    return glint;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ customHaloShape()                                                       ║
// ║                                                                         ║
// │ Create custom halo shape from bright source.                        │
// │ Allows shaped halos: circular, square, diamond, etc.              │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Compute distance from pixel to source                        │
// │   2. Apply halo function (distance-dependent falloff)           │
// │   3. Modulate by shape factor                                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Color to create halo from                       │
// │   screenCoord - Pixel screen coordinate                        │
// │   sourceCoord - Bright source coordinate                      │
// │   haloRadius - Maximum halo radius (in normalized space)     │
// │   haloShape - Shape type (0=circle, 1=square, 2=diamond)     │
// │                                                                       │
// │ Returns: Halo contribution (additive)                          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 customHaloShape(
    vec3 bloomColor,
    vec2 screenCoord,
    vec2 sourceCoord,
    float haloRadius,
    int haloShape
) {
    // Vector from source to pixel
    vec2 offset = screenCoord - sourceCoord;

    // Compute shape distance metric
    float shapeDist;

    if (haloShape == 1) {
        // Square: Chebyshev distance (max of abs coordinates)
        shapeDist = max(abs(offset.x), abs(offset.y));
    } else if (haloShape == 2) {
        // Diamond: Manhattan distance (sum of abs coordinates)
        shapeDist = abs(offset.x) + abs(offset.y);
    } else {
        // Circle (default): Euclidean distance
        shapeDist = length(offset);
    }

    // Check if within halo radius
    if (shapeDist > haloRadius) {
        return vec3(0.0);
    }

    // Gaussian falloff from center
    float falloff = exp(-(shapeDist / haloRadius) * (shapeDist / haloRadius) * 2.0);

    // Halo color contribution
    vec3 halo = bloomColor * falloff * 0.3;

    return halo;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 14E: GOD RAYS BLOOM INTERACTION                                  ║
// ║                                                                           ║
// │ Connect bloom glow with volumetric god rays effects.                ║
// │ Bloom brightens god rays, god rays brighten bloom.                 ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomGodRayInteraction()                                                ║
// ║                                                                         ║
// │ Blend bloom with god rays for atmospheric interaction.             │
// │ Bright bloom intensifies god rays, creating light shafts.         │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Sample bloom brightness at pixel                            │
// │   2. Sample god ray contribution                                 │
// │   3. Bloom brightens god rays (multiplicative)                  │
// │   4. Blend both with interaction factor                         │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Bloom contribution at pixel                     │
// │   godRayColor - Volumetric god rays at pixel                  │
// │   interactionStrength - How much they interact (0.0-1.0)      │
// │                                                                       │
// │ Returns: Combined bloom + god rays with interaction            │
// │                                                                       │
// │ Physics:                                                            │
// │   Bloom (forward scattering) intensifies god rays (back scatter)   │
// │   Result: Brighter light shafts where bloom is strong            │
// └─────────────────────────────────────────────────────────────────────┘
// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomGodRayInteraction()                                                ║
// ║                                                                         ║
// │ Blend bloom with god rays for realistic light shaft effects.        │
// │ Bright bloom intensifies volumetric light propagation.             │
// │                                                                       │
// │ Physics Model:                                                       │
// │   Forward Scattering: Bloom brightness → light shaft intensity    │
// │   Back Scattering: Volumetric density → bloom absorption          │
// │   Combined: bloom × (1 - extinction) + scattered rays            │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Bloom contribution (RGB)                         │
// │   godRayColor - Volumetric light shaft color                  │
// │   interactionStrength - Blend factor (0.0-1.0)               │
// │                                                                       │
// │ Returns: Bloom + god rays with realistic interaction          │
// └─────────────────────────────────────────────────────────────────────┘
vec3 bloomGodRayInteraction(
    vec3 bloomColor,
    vec3 godRayColor,
    float interactionStrength
) {
    // Extract bloom brightness (luminance)
    float bloomBrightness = computeLuminance(bloomColor);

    // Forward scattering: bright bloom intensifies rays
    // Using multiplicative blending for light shafts
    float rayAmplification = 1.0 + bloomBrightness * 1.5;
    vec3 amplifiedRays = godRayColor * rayAmplification;

    // Composite: additive blend with interaction modulation
    vec3 combined = bloomColor + amplifiedRays * interactionStrength;

    return combined;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ volumetricBloomGlow()                                                   ║
// ║                                                                         ║
// │ Apply bloom glow through volumetric atmosphere.                    │
// │ Models light scattering and absorption in fog/mist.              │
// │                                                                       │
// │ Physical Model:                                                    │
// │   Transmittance: T = exp(-density × distance)                   │
// │   Bloom Scattering: bloom × T + volumetric                      │
// │   In-Scattering: fog brightened by bloom                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Bloom to render through fog                   │
// │   volumetricColor - Fog color and light scattering           │
// │   fogDensity - Fog opacity (0.0=clear, 1.0=opaque)          │
// │                                                                       │
// │ Returns: Bloom visible through volumetric media             │
// └─────────────────────────────────────────────────────────────────────┘
vec3 volumetricBloomGlow(
    vec3 bloomColor,
    vec3 volumetricColor,
    float fogDensity
) {
    // Transmittance: how much bloom passes through fog
    // Dense fog (1.0) → transmittance ≈ 0.6
    // Clear air (0.0) → transmittance = 1.0
    float transmittance = mix(1.0, 0.6, fogDensity);

    // Bloom passes through fog (reduced by density)
    vec3 transmittedBloom = bloomColor * transmittance;

    // Bloom brightens volumetric fog (in-scattering effect)
    // Bright bloom intensifies volumetric color
    vec3 bloomScatteredFog = volumetricColor + bloomColor * fogDensity * 0.3;

    // Composite: transmitted bloom + scattered fog
    vec3 result = transmittedBloom + bloomScatteredFog * (1.0 - transmittance);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sampleGodRaysBuffer()                                                   ║
// ║                                                                         ║
// │ Sample god rays from volumetric buffer (if available).              │
// │ Integrates with volumetric.glsl rendering pipeline.               │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenCoord - Screen coordinate to sample                   │
// │   godRayBuffer - Volumetric god rays texture                 │
// │   fallbackGodRay - Fallback color if no buffer                │
// │                                                                       │
// │ Returns: God ray color at this pixel                         │
// └─────────────────────────────────────────────────────────────────────┘
vec3 sampleGodRaysBuffer(
    vec2 screenCoord,
    sampler2D godRayBuffer,
    vec3 fallbackGodRay
) {
    // Try to sample god rays buffer if available
    // This integrates with volumetric.glsl pipeline
    vec3 godRays = texture(godRayBuffer, screenCoord).rgb;

    // Fallback if buffer not available or returns black
    if (length(godRays) < 0.01) {
        godRays = fallbackGodRay;
    }

    return godRays;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED SUB-PHASE APPLICATION FUNCTION                                   ║
// │                                                                           ║
// │ Apply selected Phase 14 sub-phases to bloom result.                   ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyBloomSubPhases()                                                   ║
// ║                                                                         ║
// │ Main function to apply Phase 14 sub-phase enhancements.            │
// │ Enables/disables individual sub-phases via parameters.            │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Base bloom from Phase 14                         │
// │   sceneColor - Scene color for luminance calculation          │
// │   screenCoord - Current pixel screen coordinate              │
// │   enablePhase14A - Enable dynamic threshold (true/false)     │
// │   enablePhase14B - Enable per-light bloom (true/false)       │
// │   enablePhase14C - Enable motion blur trail (true/false)     │
// │   enablePhase14D - Enable glare effects (true/false)         │
// │   enablePhase14E - Enable god rays interaction (true/false)  │
// │                                                                       │
// │ Returns: Enhanced bloom with applied sub-phases              │
// └─────────────────────────────────────────────────────────────────────┘
vec3 applyBloomSubPhases(
    vec3 bloomColor,
    vec3 sceneColor,
    vec2 screenCoord,
    bool enablePhase14A,  // Dynamic threshold
    bool enablePhase14B,  // Per-light bloom
    bool enablePhase14C,  // Motion blur trail
    bool enablePhase14D,  // Glare effects
    bool enablePhase14E   // God rays interaction
) {
    vec3 result = bloomColor;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 14A: DYNAMIC BLOOM THRESHOLD                                 ║
    // │ Adapt bloom threshold to scene luminance                           │
    // └─────────────────────────────────────────────────────────────────────╝
    if (enablePhase14A) {
        // Compute average scene luminance for adaptive threshold
        float avgLum = computeSceneAverageLuminance(screenCoord, 9);

        // This informs automatic threshold adjustment
        // In a full implementation, would re-run bloom extraction with new threshold
        // For now, stored for reference in future rendering passes
        // avgLum ranges 0.01-10.0, scales threshold multiplicatively
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 14B: PER-LIGHT BLOOM CONTRIBUTIONS                           ║
    // │ Add bloom halos from dynamic point lights                          │
    // └─────────────────────────────────────────────────────────────────────╝
    if (enablePhase14B) {
        // Example: Add bloom from simulated point lights
        // In production, would receive light data from deferred renderer

        // Four example point lights (for demonstration)
        vec3 lightPositions[4] = vec3[](
            vec3(10.0, 8.0, 5.0),    // Light 1
            vec3(-8.0, 6.0, -3.0),   // Light 2
            vec3(0.0, 5.0, 10.0),    // Light 3
            vec3(-5.0, 4.0, -8.0)    // Light 4
        );

        vec3 lightColors[4] = vec3[](
            vec3(1.0, 0.8, 0.6),     // Warm white
            vec3(0.6, 0.8, 1.0),     // Cool blue
            vec3(1.0, 0.6, 0.8),     // Magenta
            vec3(0.8, 1.0, 0.6)      // Green
        );

        float lightRadii[4] = float[](
            15.0,   // Radius 1
            12.0,   // Radius 2
            18.0,   // Radius 3
            10.0    // Radius 4
        );

        // Accumulate per-light bloom
        vec3 perLightBloom = accumulatePointLightsBloom(
            vec3(0.0),  // Would be actual pixel world position
            screenCoord,
            lightPositions,
            lightColors,
            lightRadii,
            4
        );

        // Add per-light contribution (additive blending)
        result += perLightBloom * 0.4;
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 14C: MOTION BLUR TRAIL INTEGRATION                           ║
    // │ Add bloom trails following pixel motion                           │
    // └─────────────────────────────────────────────────────────────────────╝
    if (enablePhase14C) {
        // Estimate pixel velocity from temporal changes
        // In production, would use actual motion vectors from motion blur pass
        vec2 motionVector = estimatePixelVelocity(
            screenCoord,
            colortex0,
            colortex3  // TAA history buffer has previous frame
        );

        // Apply motion trail to bloom
        vec3 trailedBloom = computeMotionBloomTrail(
            result,
            motionVector,
            screenCoord,
            0.4  // Motion blur amount (0.0-1.0)
        );

        // Blend with original (motion blur creates subtle effect)
        result = mix(result, trailedBloom, 0.3);
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 14D: ADVANCED GLARE & HALO EFFECTS                           ║
    // │ Add star glints and custom halo shapes                            │
    // └─────────────────────────────────────────────────────────────────────╝
    if (enablePhase14D) {
        // Find bright pixels to apply glare to
        vec2 brightestCoord = screenCoord;
        float brightestValue = computeLuminance(result);

        // Search 3x3 neighborhood for brightest pixel
        for (float dx = -0.01; dx <= 0.01; dx += 0.01) {
            for (float dy = -0.01; dy <= 0.01; dy += 0.01) {
                vec2 neighborCoord = screenCoord + vec2(dx, dy);
                vec3 neighborColor = texture(colortex0, neighborCoord).rgb;
                float neighborLum = computeLuminance(neighborColor);

                if (neighborLum > brightestValue) {
                    brightestValue = neighborLum;
                    brightestCoord = neighborCoord;
                }
            }
        }

        // Apply glare effects only to sufficiently bright pixels
        if (brightestValue > 1.0) {
            // Star glint diffraction pattern
            vec3 glare = starGlint(result, screenCoord, brightestCoord, 0.3);

            // Custom halo shape (circle for now)
            vec3 halo = customHaloShape(result, screenCoord, brightestCoord, 0.25, 0);

            // Combine glare and halo
            result += glare * 0.5;
            result += halo * 0.3;
        }
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 14E: GOD RAYS BLOOM INTERACTION                              ║
    // │ Integrate bloom with volumetric light shafts                      │
    // └─────────────────────────────────────────────────────────────────────╝
    if (enablePhase14E) {
        // Sample volumetric god rays (would come from volumetric.glsl)
        // For now, compute a simple radial falloff as god rays proxy
        vec2 screenCenter = vec2(0.5);
        float distanceFromCenter = length(screenCoord - screenCenter);
        float godRayIntensity = exp(-distanceFromCenter * distanceFromCenter * 2.0);

        vec3 godRays = vec3(0.8, 0.9, 1.0) * godRayIntensity * 0.5;

        // Compute fog density (simple altitude-based)
        float fogDensity = 0.3;  // Would come from atmosphere/fog settings

        // Apply volumetric bloom glow
        vec3 volumetricResult = volumetricBloomGlow(result, godRays, fogDensity);

        // Blend: god rays × bloom interaction
        result = bloomGodRayInteraction(result, volumetricResult, 0.5);
    }

    return result;
}

#endif  // INCLUDE_BLOOM_SUBPHASES
