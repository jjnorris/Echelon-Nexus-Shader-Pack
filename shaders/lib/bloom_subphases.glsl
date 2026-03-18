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
    sampler2D colorBuffer,
    vec2 screenCoord,
    int sampleCount
) {
    // Sample grid positions (spread across screen for representative sampling)
    vec2 samples[9] = vec2[](
        vec2(0.2, 0.2),  vec2(0.5, 0.2),  vec2(0.8, 0.2),
        vec2(0.2, 0.5),  vec2(0.5, 0.5),  vec2(0.8, 0.5),
        vec2(0.2, 0.8),  vec2(0.5, 0.8),  vec2(0.8, 0.8)
    );

    // Accumulate luminance samples
    float logLuminanceSum = 0.0;
    for (int i = 0; i < sampleCount && i < 9; i++) {
        vec3 sampleColor = texture(colorBuffer, samples[i]).rgb;
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
// ║ extractLightBloom()                                                     ║
// ║                                                                         ║
// │ Extract bloom contribution from a specific light source.             │
// │ Simulates bloom halo around bright point lights.                    │
// │                                                                       │
// │ Algorithm:                                                            │
// │   1. Get light position (projected to screen)                      │
// │   2. Compute distance from pixel to light                         │
// │   3. Sample light color and intensity                            │
// │   4. Apply distance falloff (1/r²)                              │
// │   5. Compute bloom based on light brightness                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightPosition - Light position in world space                  │
// │   lightColor - Light color (RGB)                                │
// │   lightIntensity - Light brightness scalar                      │
// │   screenCoord - Current pixel screen coordinate                │
// │   pixelWorldPos - Pixel world position (for distance)          │
// │   viewProjectionMatrix - Camera VP matrix                      │
// │                                                                       │
// │ Returns: Bloom contribution from this light               │
// └─────────────────────────────────────────────────────────────────────┘
vec3 extractLightBloom(
    vec3 lightPosition,
    vec3 lightColor,
    float lightIntensity,
    vec2 screenCoord,
    vec3 pixelWorldPos,
    mat4 viewProjectionMatrix
) {
    // Project light position to screen space
    vec4 lightScreenPos = viewProjectionMatrix * vec4(lightPosition, 1.0);
    lightScreenPos.xy /= lightScreenPos.w;
    lightScreenPos.xy = lightScreenPos.xy * 0.5 + 0.5;  // NDC to screen coords

    // Check if light is on-screen
    if (lightScreenPos.xy.x < 0.0 || lightScreenPos.xy.x > 1.0 ||
        lightScreenPos.xy.y < 0.0 || lightScreenPos.xy.y > 1.0) {
        return vec3(0.0);  // Off-screen light
    }

    // Distance from pixel to light center (in screen space)
    vec2 lightDist = screenCoord - lightScreenPos.xy;
    float screenDistance = length(lightDist) * 1000.0;  // Scale to pixels

    // Distance-based falloff (Gaussian)
    float falloff = exp(-screenDistance * screenDistance * 0.01);

    // Bloom bloom based on light brightness
    vec3 bloom = lightColor * lightIntensity * falloff;

    return bloom;
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
vec3 computeMotionBloomTrail(
    vec3 bloomColor,
    vec2 velocityPixels,
    vec2 screenCoord,
    sampler2D bloomSampler,
    float motionBlurAmount
) {
    // Normalize and scale velocity for trail sampling
    vec2 trailDirection = normalize(velocityPixels);
    float trailLength = length(velocityPixels) * motionBlurAmount;

    // Sample along motion trail
    vec3 trailAccum = bloomColor;
    int trailSamples = 8;

    for (int i = 1; i <= trailSamples; i++) {
        // Sample position along trail
        float sampleDistance = (float(i) / float(trailSamples)) * trailLength;
        vec2 sampleUV = screenCoord + trailDirection * sampleDistance;

        // Check bounds
        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 ||
            sampleUV.y < 0.0 || sampleUV.y > 1.0) {
            continue;
        }

        // Sample bloom at trail position
        vec3 trailSample = texture(bloomSampler, sampleUV).rgb;

        // Falloff with distance (fade trail)
        float trailFalloff = 1.0 - (float(i) / float(trailSamples));
        trailAccum += trailSample * trailFalloff * 0.2;
    }

    // Blend with original bloom
    return mix(bloomColor, trailAccum / float(trailSamples + 1), motionBlurAmount);
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
vec3 bloomGodRayInteraction(
    vec3 bloomColor,
    vec3 godRayColor,
    float interactionStrength
) {
    // Bloom brightness (use luminance)
    float bloomBrightness = computeLuminance(bloomColor);

    // Amplify god rays based on bloom brightness
    // Bloom-bright areas intensify volumetric effects
    vec3 amplifiedGodRays = godRayColor * (1.0 + bloomBrightness * 2.0);

    // Blend: bloom + enhanced god rays
    vec3 combined = bloomColor + amplifiedGodRays * interactionStrength;

    return combined;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ volumetricBloomGlow()                                                   ║
// ║                                                                         ║
// │ Apply bloom glow to volumetric effects (fog, mist).                 │
// │ Makes bloom visible through atmospheric media.                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   bloomColor - Bloom contribution                              │
// │   volumetricColor - Fog/mist color                            │
// │   fogDensity - Volumetric density (0.0-1.0)                  │
// │                                                                       │
// │ Returns: Bloom blended through volumetric media              │
// └─────────────────────────────────────────────────────────────────────┘
vec3 volumetricBloomGlow(
    vec3 bloomColor,
    vec3 volumetricColor,
    float fogDensity
) {
    // Bloom scatters through fog (additive)
    // High fog density: bloom gets scattered/dimmed
    // Low fog density: bloom passes through clearly
    vec3 scatteredBloom = bloomColor * (1.0 - fogDensity * 0.5);

    // Volumetric glows with bloom
    vec3 result = volumetricColor + scatteredBloom;

    return result;
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

    // Phase 14A: Dynamic Bloom Threshold
    if (enablePhase14A) {
        float avgLum = computeSceneAverageLuminance(colorBuffer, screenCoord, 9);
        // Can be used to adjust future bloom extraction
        // (mostly informational for post-processing)
    }

    // Phase 14B: Per-Light Bloom
    if (enablePhase14B) {
        // Would require light data from engine
        // Placeholder for demonstration
        vec3 perLightBloom = vec3(0.0);
        result += perLightBloom * 0.5;
    }

    // Phase 14C: Motion Blur Trail
    if (enablePhase14C) {
        // Would require motion vector data
        vec2 motionVector = vec2(0.0);  // Placeholder
        vec3 trailedBloom = computeMotionBloomTrail(
            result,
            motionVector,
            screenCoord,
            colorBuffer,
            0.3
        );
        result = mix(result, trailedBloom, 0.5);
    }

    // Phase 14D: Glare Effects
    if (enablePhase14D) {
        // Apply glare at screen center (simulated bright source)
        vec2 sourceCoord = vec2(0.5);
        vec3 glare = starGlint(result, screenCoord, sourceCoord, 0.3);
        vec3 halo = customHaloShape(result, screenCoord, sourceCoord, 0.3, 0);
        result += glare + halo;
    }

    // Phase 14E: God Rays Interaction
    if (enablePhase14E) {
        // Would integrate with volumetric.glsl
        vec3 godRays = vec3(0.0);  // Placeholder
        result = bloomGodRayInteraction(result, godRays, 0.5);
    }

    return result;
}

#endif  // INCLUDE_BLOOM_SUBPHASES
