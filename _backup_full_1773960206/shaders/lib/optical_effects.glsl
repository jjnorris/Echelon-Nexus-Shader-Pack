// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         OPTICAL EFFECTS (PHASE 17)                                       ║
// ║         COMPLETE SUB-PHASES 17A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Advanced optical phenomena including caustics, spectral bloom,         ║
// ║  diffraction (Airy disk), lens flares, and volumetric god rays.        ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    17A: Caustics (water light patterns)                                ║
// ║    17B: Spectral Bloom (wavelength-separated)                          ║
// ║    17C: Airy Disk (diffraction around bright lights)                   ║
// ║    17D: Lens Flares (realistic multi-element)                          ║
// ║    17E: God Rays (volumetric light cones)                              ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Caustic patterns on water surfaces and underwater                 ║
// ║    - Realistic bloom with spectral separation                          ║
// ║    - Diffraction spikes around bright sources                          ║
// ║    - Multi-element lens artifacts                                      ║
// ║    - Volumetric light rays through atmosphere                          ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Wyman et al. (2011) - Interactive Caustics                        ║
// ║    - Hable (2010) - Uncharted 2 - HDR Rendering                        ║
// ║    - Spencer et al. (1995) - Physically Based Rendering of Lenses      ║
// ║    - Nishita & Nakamae (1994) - Displaying High Dynamic Range Images   ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_OPTICAL_EFFECTS
#define INCLUDE_OPTICAL_EFFECTS

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 17A: CAUSTICS                                                     ║
// ║                                                                           ║
// │ Light refraction patterns through wavy water surfaces.                 ║
// │ Creates realistic swimming pool and underwater effects.                ║
// └───────────────────────────────────────────────────────────────────────────┘

float causticPattern(
    vec2 position,
    float time,
    float scale
) {
    // Multi-layer Perlin-like noise for caustic pattern
    vec2 p = position * scale;

    // First layer: slow, large waves
    float wave1 = sin(p.x * 2.0 + time * 0.3) * cos(p.y * 2.0 - time * 0.25);

    // Second layer: medium, medium waves
    float wave2 = sin(p.x * 4.0 - time * 0.5) * cos(p.y * 4.0 + time * 0.4);

    // Third layer: fast, small ripples
    float wave3 = sin(p.x * 8.0 + time * 1.2) * cos(p.y * 8.0 - time * 0.9);

    // Combine with decreasing amplitude
    float caustic = wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2;

    // Normalize to [0, 1]
    caustic = caustic * 0.5 + 0.5;

    // Nonlinear contrast: enhance dark and bright areas
    caustic = pow(caustic, 1.5);

    return caustic;
}

vec3 causticColor(
    vec2 position,
    float time,
    float depth,
    vec3 waterColor
) {
    // Get base caustic pattern
    float caustic1 = causticPattern(position, time, 2.0);
    float caustic2 = causticPattern(position + vec2(0.5, 0.3), time * 0.8, 3.0);

    // Blend two octaves
    float pattern = mix(caustic1, caustic2, 0.5);

    // Depth attenuation: caustics fade with depth
    // Deeper water has less intense caustics
    float depthFactor = exp(-depth * 0.5);
    pattern *= depthFactor;

    // Frequency-dependent color shift
    // Shallow water: bright white-blue
    // Deep water: darker blue-green
    vec3 shallowColor = vec3(1.0, 1.0, 0.9);
    vec3 deepColor = vec3(0.3, 0.4, 0.6);

    vec3 causticHue = mix(deepColor, shallowColor, depth);

    // Modulate water color by caustic pattern
    vec3 result = waterColor * (0.7 + pattern * 0.3);

    // Add caustic highlights
    result += causticHue * pattern * 0.5;

    return result;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 17B: SPECTRAL BLOOM                                               ║
// ║                                                                           ║
// │ Wavelength-separated bloom: red bleeds further than blue.             ║
// │ Matches physical chromatic dispersion in cameras/optics.              ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomDispersion()                                                       ║
// ║                                                                         ║
// │ Calculate wavelength-dependent bloom spread.                       │
// │ Red bloom radius > Green > Blue (physical optics).                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   wavelength - Light wavelength (nanometers)                    │
// │   baseRadius - Base bloom kernel radius (pixels)               │
// │   intensity - Overall bloom intensity                        │
// │                                                                       │
// │ Returns: Bloom radius for this wavelength                   │
// └─────────────────────────────────────────────────────────────────────────┘
float bloomDispersion(float wavelength, float baseRadius, float intensity) {
    // Longer wavelengths (red) bloom more
    // Follows approximate 1/λ relationship
    float dispersionFactor = (700.0 - wavelength) / 700.0;
    dispersionFactor = clamp(dispersionFactor, 0.0, 1.0);

    // Red (650nm) has ~1.0x spread
    // Green (530nm) has ~0.85x spread
    // Blue (460nm) has ~0.7x spread
    float spreadRatio = 0.7 + dispersionFactor * 0.3;

    return baseRadius * spreadRatio * intensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralBloomColor()                                                    ║
// ║                                                                         ║
// │ Generate spectral bloom with proper wavelength separation.          │
// │ Simulates chromatic dispersion in optical systems.                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Source color (typically bright highlights)           │
// │   bloomAmount - Bloom intensity (0.0-1.0)                    │
// │   wavelengthShift - Spectral shift factor (0.0-1.0)         │
// │                                                                       │
// │ Returns: Color with spectral bloom applied                  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 spectralBloomColor(vec3 color, float bloomAmount, float wavelengthShift) {
    // Extract luminance
    float lum = dot(color, vec3(0.299, 0.587, 0.114));

    // Only bright pixels bloom
    bloomAmount *= smoothstep(0.5, 1.0, lum);

    // Wavelength-dependent color shift
    // Red bleeds first (longer wavelength)
    vec3 redBloom = vec3(1.0, 0.3, 0.2) * (1.0 - wavelengthShift);
    vec3 blueBloom = vec3(0.2, 0.3, 1.0) * wavelengthShift;
    vec3 bloomHue = mix(redBloom, blueBloom, wavelengthShift);

    // Combine bloom with original color
    return color + bloomHue * bloomAmount * lum;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 17C: AIRY DISK                                                    ║
// ║                                                                           ║
// │ Diffraction pattern around bright point sources.                     ║
// │ Circular rings from circular aperture (Bessel function).             ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ airyDiskIntensity()                                                     ║
// ║                                                                         ║
// │ Calculate diffraction intensity for Airy disk.                    │
// │ Models diffraction through circular aperture.                   │
// │                                                                       │
// │ Physics: I(r) = [2J₁(r)/r]² (Bessel function approximation)   │
// │ where r = normalized radius (distance × aperture size)        │
// │                                                                       │
// │ Inputs:                                                              │
// │   distance - Distance from bright center (normalized 0-1)     │
// │   apertureSize - Aperture radius (affects diffraction scale) │
// │   wavelength - Light wavelength                            │
// │                                                                       │
// │ Returns: Intensity (0.0-1.0)                               │
// └─────────────────────────────────────────────────────────────────────────┘
float airyDiskIntensity(float distance, float apertureSize, float wavelength) {
    // Normalized radius for Airy disk
    // Higher aperture = tighter diffraction pattern
    float r = distance * apertureSize / (wavelength * 1e-6);

    // Approximate Bessel function J₁
    // Bessel pattern creates characteristic rings
    float bessel = sin(r * 2.0) / max(r, 0.1);
    bessel = bessel * bessel;

    // Add higher-order diffraction rings
    bessel += sin(r * 4.0) / max(r * 2.0, 0.1) * 0.5;
    bessel += sin(r * 6.0) / max(r * 3.0, 0.1) * 0.25;

    // Normalize and clamp
    bessel = clamp(bessel, 0.0, 1.0);

    // Central spot dominates
    float central = exp(-r * r * 0.5);

    return mix(bessel, central, 0.6);
}

vec3 airyDiskEffect(
    vec3 color,
    float distance,
    float intensity
) {
    // Compute diffraction rings
    float rings = airyDiskIntensity(distance, 0.5, 550.0);

    // Modulate color with diffraction pattern
    vec3 diffracted = color * (1.0 + rings * intensity);

    // Add spectral color to outer rings (diffraction)
    vec3 spectralRing = vec3(
        sin(distance * PI) * 0.5,
        cos(distance * PI) * 0.5,
        sin(distance * PI * 2.0) * 0.5
    );

    diffracted += spectralRing * (1.0 - distance) * intensity;

    return diffracted;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 17D: LENS FLARES                                                  ║
// ║                                                                           ║
// │ Realistic lens artifacts from multi-element optical systems.         ║
// │ Includes ghost reflections, streaks, and secondary images.          ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensFlareGhost()                                                        ║
// ║                                                                         ║
// │ Calculate lens flare ghost (secondary image from reflections).     │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightPos - Screen position of light source (0-1)             │
// │   screenPos - Current screen position (0-1)                  │
// │   ghostIndex - Which ghost (1, 2, 3...)                    │
// │   intensity - Ghost intensity (0.0-1.0)                   │
// │                                                                       │
// │ Returns: Ghost color (RGBA)                               │
// └─────────────────────────────────────────────────────────────────────────┘
vec4 lensFlareGhost(
    vec2 lightPos,
    vec2 screenPos,
    int ghostIndex,
    float intensity
) {
    // Ghost positions are reflections across screen center
    // Multiple reflections create multiple ghosts
    vec2 direction = lightPos - vec2(0.5);
    vec2 ghostPos = vec2(0.5) - direction * float(ghostIndex) * 0.25;

    // Distance from this ghost position
    float dist = length(screenPos - ghostPos);

    // Gaussian falloff for ghost
    float ghostIntensity = exp(-dist * dist * 100.0);

    // Color varies by ghost (dispersion simulation)
    vec3 ghostColor = vec3(
        1.0 - float(ghostIndex) * 0.2,
        1.0 - float(ghostIndex) * 0.1,
        1.0 - float(ghostIndex) * 0.3
    );

    return vec4(ghostColor, ghostIntensity) * intensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensFlareStreak()                                                       ║
// ║                                                                         ║
// │ Calculate lens flare radial streaks (from aperture blades).         │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightPos - Screen position of light (0-1)                    │
// │   screenPos - Current screen position (0-1)                  │
// │   bladeCount - Number of aperture blades (typically 6-8)     │
// │   intensity - Streak intensity (0.0-1.0)                   │
// │                                                                       │
// │ Returns: Streak color                                      │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lensFlareStreak(
    vec2 lightPos,
    vec2 screenPos,
    int bladeCount,
    float intensity
) {
    vec2 direction = screenPos - lightPos;
    float dist = length(direction);
    float angle = atan(direction.y, direction.x);

    // Radial streak pattern from aperture blades
    // Higher blade count = more streaks
    float streak = sin(angle * float(bladeCount)) * 0.5 + 0.5;

    // Falloff along light ray
    streak *= exp(-dist * 5.0);

    // Streak color (cyan-magenta)
    vec3 streakColor = vec3(
        1.0 - streak,
        streak,
        1.0
    );

    return streakColor * intensity * streak;
}

vec3 lensFlareEffect(
    vec3 baseColor,
    vec2 lightScreenPos,
    vec2 currentScreenPos,
    float intensity
) {
    // Add multiple ghosts
    vec4 ghost1 = lensFlareGhost(lightScreenPos, currentScreenPos, 1, intensity);
    vec4 ghost2 = lensFlareGhost(lightScreenPos, currentScreenPos, 2, intensity * 0.5);
    vec4 ghost3 = lensFlareGhost(lightScreenPos, currentScreenPos, 3, intensity * 0.25);

    // Combine ghosts
    vec3 flare = ghost1.rgb * ghost1.a;
    flare += ghost2.rgb * ghost2.a;
    flare += ghost3.rgb * ghost3.a;

    // Add streaks
    vec3 streaks = lensFlareStreak(lightScreenPos, currentScreenPos, 8, intensity);
    flare += streaks;

    return baseColor + flare;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 17E: GOD RAYS                                                     ║
// ║                                                                           ║
// │ Volumetric light cones (rays from bright sources through medium).   ║
// │ Creates dramatic lighting effects in dusty/foggy atmospheres.        ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ godRayAtmosphere()                                                      ║
// ║                                                                         ║
// │ Calculate volumetric god ray intensity.                           │
// │ Samples along ray from camera to light source.                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   cameraPos - Camera position (world space)                   │
// │   lightPos - Light position (world space)                    │
// │   samplePoint - Point being evaluated                       │
// │   mediumDensity - Atmospheric density (0.0-1.0)            │
// │   sampleCount - Number of samples along ray              │
// │                                                                       │
// │ Returns: Volumetric lighting intensity                     │
// └─────────────────────────────────────────────────────────────────────────┘
float godRayAtmosphere(
    vec3 cameraPos,
    vec3 lightPos,
    vec3 samplePoint,
    float mediumDensity,
    int sampleCount
) {
    // Ray from camera through sample point
    vec3 rayDir = normalize(samplePoint - cameraPos);

    // Distance along ray
    float maxDist = length(lightPos - cameraPos);

    // Accumulate light scattering
    float lighting = 0.0;
    float stepSize = maxDist / float(sampleCount);

    // Sample along ray
    for (int i = 0; i < sampleCount; i++) {
        vec3 samplePos = cameraPos + rayDir * float(i) * stepSize;

        // Distance to light source
        float distToLight = length(lightPos - samplePos);

        // Inverse square falloff
        float falloff = 1.0 / (1.0 + distToLight * distToLight);

        // Scattering intensity (exponential based on density)
        float scatter = exp(-mediumDensity * float(i) * stepSize);

        lighting += falloff * scatter;
    }

    // Normalize by sample count
    lighting /= float(sampleCount);

    return lighting;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ godRayColor()                                                           ║
// ║                                                                         ║
// │ Compute god ray color with depth-based attenuation.               │
// │ Simulates Rayleigh scattering in atmosphere.                     │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightColor - Light source color                           │
// │   distance - Distance to light source                      │
// │   mediumColor - Atmospheric medium color                 │
// │   visibility - Atmospheric visibility range             │
// │                                                                       │
// │ Returns: God ray color                                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 godRayColor(
    vec3 lightColor,
    float distance,
    vec3 mediumColor,
    float visibility
) {
    // Atmospheric extinction (fog)
    float extinction = exp(-distance / visibility);

    // Rayleigh scattering: blue scatters more
    // Shorter wavelengths scattered more
    vec3 scatterColor = mix(lightColor, vec3(0.5, 0.7, 1.0), 0.3);

    // Combine extinction and scattering
    vec3 rayColor = lightColor * extinction + scatterColor * (1.0 - extinction);

    // Modulate by medium color
    rayColor *= mediumColor;

    return rayColor;
}

vec3 godRayEffect(
    vec3 baseColor,
    vec3 lightColor,
    float lightIntensity,
    float distance,
    float mediumDensity
) {
    // Calculate volumetric lighting
    float godRayIntensity = exp(-mediumDensity * distance);

    // Color with scattering
    vec3 rayColor = godRayColor(
        lightColor,
        distance,
        vec3(0.8, 0.9, 1.0),
        100.0
    );

    // Combine with base
    return baseColor + rayColor * godRayIntensity * lightIntensity;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED OPTICAL EFFECTS APPLICATION                                      ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyOpticalEffect(
    vec3 baseColor,
    vec2 screenPos,
    vec2 lightScreenPos,
    vec3 worldPos,
    vec3 lightWorldPos,
    int effectType,
    float intensity,
    float time
) {
    if (effectType == 0) {
        // Caustics
        return causticColor(worldPos.xz, time, worldPos.y, baseColor);
    }
    else if (effectType == 1) {
        // Spectral bloom
        return spectralBloomColor(baseColor, intensity, screenPos.x);
    }
    else if (effectType == 2) {
        // Airy disk
        float dist = length(screenPos - lightScreenPos);
        return airyDiskEffect(baseColor, dist, intensity);
    }
    else if (effectType == 3) {
        // Lens flares
        return lensFlareEffect(baseColor, lightScreenPos, screenPos, intensity);
    }
    else if (effectType == 4) {
        // God rays
        float dist = length(lightWorldPos - worldPos);
        return godRayEffect(baseColor, vec3(1.0, 0.9, 0.8), intensity, dist, 0.5);
    }

    return baseColor;
}

#endif  // INCLUDE_OPTICAL_EFFECTS
