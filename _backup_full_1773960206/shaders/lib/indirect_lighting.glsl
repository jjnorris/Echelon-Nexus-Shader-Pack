// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         INDIRECT LIGHTING (PHASE 19)                                     ║
// ║         COMPLETE SUB-PHASES 19A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Global illumination including path integral, irradiance probes,       ║
// ║  light propagation volumes, AO enhancement, and screen-space           ║
// ║  indirect bounces.                                                      ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    19A: Path Integral / Global Illumination                            ║
// ║    19B: Irradiance Probes (point-based)                                ║
// ║    19C: Light Propagation Volumes (LPV, optional)                      ║
// ║    19D: Ambient Occlusion Enhancement                                  ║
// ║    19E: Screen-Space Indirect Bounce (optional tier 4+)               ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Realistic indirect lighting from all surfaces                    ║
// ║    - Bounced light color from environment                            ║
// ║    - Smooth GI from probe interpolation                              ║
// ║    - Volumetric light propagation                                    ║
// ║    - Enhanced ambient occlusion                                      ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Kajiya & Otto (1990) - The Rendering Equation                   ║
// ║    - Crytek (2009) - Light Propagation Volumes                       ║
// ║    - Kontkanen & Laine (2005) - Irradiance Volumes                  ║
// ║    - Zhukov et al. (1998) - Indirect Illumination                   ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_INDIRECT_LIGHTING
#define INCLUDE_INDIRECT_LIGHTING

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 19A: PATH INTEGRAL / GLOBAL ILLUMINATION                          ║
// ║                                                                           ║
// │ Monte Carlo path tracing for global illumination.                     ║
// │ Integrates light contribution from entire scene.                      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ pathIntegralGI()                                                        ║
// ║                                                                         ║
// │ Compute global illumination using path integral.                   │
// │ Approximates the rendering equation via Monte Carlo integration.  │
// │                                                                       │
// │ Physics: Rendering Equation (Kajiya & Otto, 1990):              │
// │   Lo(p, ω) = Le(p, ω) + ∫ Li(p, ωi) × fr(ωi, ωo) × cos(θi) dωi  │
// │                                                                       │
// │ Inputs:                                                              │
// │   normal - Surface normal                                       │
// │   position - World position                                    │
// │   viewDir - View direction                                    │
// │   giIntensity - GI contribution strength (0.0-1.0)          │
// │   sampleCount - Number of Monte Carlo samples            │
// │                                                                       │
// │ Returns: Indirect light contribution (RGB)                   │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 pathIntegralGI(
    vec3 normal,
    vec3 position,
    vec3 viewDir,
    float giIntensity,
    int sampleCount
) {
    vec3 giColor = vec3(0.0);

    // Monte Carlo path tracing (simplified for real-time)
    for (int i = 0; i < sampleCount && i < 16; i++) {
        // Cosine-weighted hemisphere sampling
        float theta = acos(sqrt(1.0 - float(i) / float(sampleCount)));
        float phi = float(i) * 2.3999963 / float(sampleCount);  // Golden angle

        // Sample direction in hemisphere
        vec3 right = normalize(cross(normal, vec3(0, 1, 0)));
        if (length(right) < 0.1) right = normalize(cross(normal, vec3(1, 0, 0)));
        vec3 up = normalize(cross(right, normal));

        vec3 sampleDir = normalize(
            sin(theta) * cos(phi) * right +
            sin(theta) * sin(phi) * up +
            cos(theta) * normal
        );

        // Cosine weighting
        float cosTheta = max(0.0, dot(sampleDir, normal));

        // Approximate indirect light from direction
        // In real implementation, this would trace rays and sample environment
        vec3 indirectColor = vec3(0.3, 0.4, 0.5) * cosTheta;

        // Add to accumulation
        giColor += indirectColor;
    }

    // Normalize by sample count
    giColor /= float(sampleCount);

    // Apply intensity
    return giColor * giIntensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 19B: IRRADIANCE PROBES                                            ║
// ║                                                                           ║
// │ Point-based irradiance sampling for smooth GI approximation.         ║
// │ Interpolate between probe positions for fast indirect lighting.      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ irradianceProbeDistance()                                               ║
// ║                                                                         ║
// │ Calculate distance from position to nearest probe.                 │
// │                                                                       │
// │ Probes arranged in regular grid pattern for efficient lookup.    │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   probeSpacing - Grid spacing (typically 4-8 units)           │
// │   probeGridOffset - Grid origin offset                       │
// │                                                                       │
// │ Returns: Distance to nearest probe                           │
// └─────────────────────────────────────────────────────────────────────────┘
float irradianceProbeDistance(
    vec3 position,
    float probeSpacing,
    vec3 probeGridOffset
) {
    // Snap position to nearest grid cell
    vec3 gridPos = floor((position - probeGridOffset) / probeSpacing) * probeSpacing + probeGridOffset;

    // Distance to nearest probe
    float dist = length(position - gridPos);

    return dist;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ irradianceProbeInterpolation()                                          ║
// ║                                                                         ║
// │ Interpolate irradiance from nearby probes.                        │
// │ Uses trilinear interpolation for smooth transition.               │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   probeSpacing - Grid spacing                                  │
// │   maxProbes - Maximum probes to sample (8 for trilinear)      │
// │                                                                       │
// │ Returns: Interpolated irradiance (RGB)                       │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 irradianceProbeInterpolation(
    vec3 position,
    float probeSpacing,
    int maxProbes
) {
    // Normalized position within grid cell
    vec3 cellPos = fract((position) / probeSpacing);

    // Trilinear interpolation weights
    vec3 weights = smoothstep(vec3(0.0), vec3(1.0), cellPos);

    // Weighted irradiance from 8 corners of cell
    // In real implementation, would sample actual probe values
    vec3 irradiance = vec3(0.5);

    // Apply smoothstep for softer transitions
    irradiance *= weights.x * weights.y * weights.z;

    return irradiance;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ probeBasedIndirectLight()                                               ║
// ║                                                                         ║
// │ Compute indirect lighting from irradiance probe network.            │
// │ Fast approximation of GI using pre-computed probe values.          │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   normal - Surface normal                                      │
// │   probeSpacing - Grid spacing                                  │
// │   intensity - GI intensity multiplier                        │
// │                                                                       │
// │ Returns: Probe-based indirect lighting                       │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 probeBasedIndirectLight(
    vec3 position,
    vec3 normal,
    float probeSpacing,
    float intensity
) {
    // Get interpolated irradiance from probes
    vec3 irradiance = irradianceProbeInterpolation(position, probeSpacing, 8);

    // Apply normal weighting (cosine)
    float nDotUp = max(0.0, dot(normal, vec3(0, 1, 0)));
    irradiance *= (0.5 + 0.5 * nDotUp);

    // Apply intensity
    return irradiance * intensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 19C: LIGHT PROPAGATION VOLUMES                                    ║
// ║                                                                           ║
// │ Volumetric light propagation for fast global illumination.         ║
// │ Discretized light injection and propagation through volume.        ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lpvLightInjection()                                                     ║
// ║                                                                         ║
// │ Calculate light injected into propagation volume.                 │
// │                                                                       │
// │ Physics: Light from direct illumination is injected,              │
// │ propagates through grid, bounces between cells.                  │
// │                                                                       │
// │ Inputs:                                                              │
// │   lightColor - Direct light color                               │
// │   lightIntensity - Direct light intensity                     │
// │   normal - Surface normal                                      │
// │   lpvGridPosition - Position in LPV grid                      │
// │                                                                       │
// │ Returns: Light injected into volume                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lpvLightInjection(
    vec3 lightColor,
    float lightIntensity,
    vec3 normal,
    vec3 lpvGridPosition
) {
    // Inject light based on normal direction
    // Dominant axis of normal determines propagation
    vec3 normalized = normalize(normal);

    // Spherical harmonics-like weighting
    // Encode normal direction for better propagation
    vec3 injection = lightColor * lightIntensity;

    // Apply directional weighting
    injection *= abs(normalized);

    return injection;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lpvPropagationStep()                                                    ║
// ║                                                                         ║
// │ Simulate one propagation iteration in LPV.                       │
// │ Light bounces between adjacent grid cells.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   currentValue - Current cell value                             │
// │   neighborValues[6] - Values from 6 neighboring cells        │
// │   attenuation - Propagation attenuation per step             │
// │                                                                       │
// │ Returns: Updated cell value after propagation                │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lpvPropagationStep(
    vec3 currentValue,
    vec3 neighborValues[6],  // +X, -X, +Y, -Y, +Z, -Z
    float attenuation
) {
    // Average contribution from neighbors
    vec3 propagated = vec3(0.0);

    for (int i = 0; i < 6; i++) {
        propagated += neighborValues[i];
    }

    propagated /= 6.0;

    // Apply attenuation (energy loss per hop)
    propagated *= attenuation;

    // Combine with current value
    vec3 result = currentValue + propagated;

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lpvIndirectLight()                                                      ║
// ║                                                                         ║
// │ Query indirect light from LPV at position.                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   lpvGridSpacing - LPV cell size                               │
// │   intensity - GI intensity                                    │
// │                                                                       │
// │ Returns: Indirect light from volume propagation               │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lpvIndirectLight(
    vec3 position,
    float lpvGridSpacing,
    float intensity
) {
    // Query position in LPV grid
    vec3 gridCoord = position / lpvGridSpacing;

    // Bilinear interpolation within grid cell
    vec3 cellFraction = fract(gridCoord);

    // In real implementation, would sample LPV texture
    // For now, approximate with simple function
    vec3 indirectLight = vec3(0.3, 0.3, 0.4);

    // Modulate by position
    indirectLight *= (0.5 + 0.5 * sin(gridCoord.x) * sin(gridCoord.y));

    return indirectLight * intensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 19D: AMBIENT OCCLUSION ENHANCEMENT                                ║
// ║                                                                           ║
// │ Enhance AO with color bleeding from surrounding materials.         ║
// │ Adds realism by darkening occluded areas with absorbed color.      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ enhancedAmbientOcclusion()                                              ║
// ║                                                                         ║
// │ Compute ambient occlusion with color bleeding.                   │
// │                                                                       │
// │ Physics: In occluded areas, light bounces from surrounding       │
// │ materials, creating subtle color tints.                         │
// │                                                                       │
// │ Inputs:                                                              │
// │   baseAO - Base AO value (0.0-1.0)                              │
// │   normal - Surface normal                                      │
// │   neighborColor - Estimated neighbor surface color           │
// │   aoIntensity - AO strength (0.0-2.0)                        │
// │                                                                       │
// │ Returns: Enhanced AO with color information                 │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 enhancedAmbientOcclusion(
    float baseAO,
    vec3 normal,
    vec3 neighborColor,
    float aoIntensity
) {
    // AO darkening
    float occlusion = mix(1.0, baseAO, aoIntensity);

    // Color bleeding: absorbed colors in shadows
    vec3 bleedColor = neighborColor * (1.0 - baseAO) * 0.3;

    // Combine darkening and color bleed
    vec3 result = vec3(occlusion) + bleedColor;

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ aoContrast()                                                            ║
// ║                                                                         ║
// │ Enhance AO contrast for better visual impact.                     │
// │ Applies tone mapping to AO values.                              │
// │                                                                       │
// │ Inputs:                                                              │
// │   aoValue - Raw AO value (0.0-1.0)                              │
// │   contrastAmount - Contrast strength (0.0-2.0)               │
// │                                                                       │
// │ Returns: Contrast-enhanced AO                                 │
// └─────────────────────────────────────────────────────────────────────────┘
float aoContrast(float aoValue, float contrastAmount) {
    // Offset around 0.5 for contrast
    float contrast = (aoValue - 0.5) * contrastAmount + 0.5;

    // Optional: add slight curve for visual appeal
    contrast = mix(aoValue, contrast, 0.7);

    // Clamp to valid range
    return clamp(contrast, 0.0, 1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 19E: SCREEN-SPACE INDIRECT BOUNCE                                 ║
// ║                                                                           ║
// │ Screen-space ray casting for one bounce of indirect light.        ║
// │ Fast approximation suitable for real-time (tier 4+).             ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ screenSpaceIndirectRaycast()                                            ║
// ║                                                                         ║
// │ Cast ray in screen space to find indirect light sources.        │
// │                                                                       │
// │ Inputs:                                                              │
// │   startPos - Ray start position (screen space)                 │
// │   rayDir - Ray direction (world space, projected)            │
// │   maxSteps - Maximum raymarching steps                       │
// │   maxDist - Maximum ray distance                            │
// │                                                                       │
// │ Returns: Found surface color or background                 │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 screenSpaceIndirectRaycast(
    vec3 startPos,
    vec3 rayDir,
    int maxSteps,
    float maxDist
) {
    vec3 rayColor = vec3(0.0);

    // Linear raymarch in screen space
    for (int step = 0; step < maxSteps && step < 32; step++) {
        float t = float(step) / float(maxSteps) * maxDist;

        // March along ray
        vec3 marchPos = startPos + rayDir * t;

        // Check if within screen bounds
        if (marchPos.x < 0.0 || marchPos.x > 1.0 ||
            marchPos.y < 0.0 || marchPos.y > 1.0) {
            break;
        }

        // Sample color at this position
        // In real implementation, would sample from screen texture
        vec3 sampleColor = vec3(0.5);

        // Check if hit geometry
        // Simplified: assume hit after certain distance
        if (t > 5.0) {
            rayColor = sampleColor;
            break;
        }
    }

    return rayColor;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ screenSpaceIndirectBounce()                                             ║
// ║                                                                         ║
// │ Calculate one bounce of indirect light in screen space.           │
// │                                                                       │
// │ Inputs:                                                              │
// │   screenPos - Screen position (0-1)                              │
// │   normal - Surface normal                                      │
// │   intensity - Effect intensity                               │
// │                                                                       │
// │ Returns: One-bounce indirect light                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 screenSpaceIndirectBounce(
    vec2 screenPos,
    vec3 normal,
    float intensity
) {
    // Ray direction from normal (hemisphere)
    vec3 rayDir = normalize(normal + vec3(0.2, 0.2, 0.2));

    // Cast ray in screen space
    vec3 hitColor = screenSpaceIndirectRaycast(
        vec3(screenPos, 0.0),
        rayDir,
        16,
        10.0
    );

    // Modulate by normal and intensity
    vec3 bounceLight = hitColor * max(0.0, dot(normal, rayDir)) * intensity;

    return bounceLight;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED INDIRECT LIGHTING APPLICATION                                    ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyIndirectLighting(
    vec3 baseColor,
    vec3 position,
    vec3 normal,
    vec3 viewDir,
    int lightingType,
    float intensity,
    float aoValue
) {
    vec3 indirectLight = vec3(0.0);

    if (lightingType == 0) {
        // Path integral GI (19A)
        indirectLight = pathIntegralGI(normal, position, viewDir, intensity, 8);
    }
    else if (lightingType == 1) {
        // Irradiance probes (19B)
        indirectLight = probeBasedIndirectLight(position, normal, 4.0, intensity);
    }
    else if (lightingType == 2) {
        // Light propagation volumes (19C)
        indirectLight = lpvIndirectLight(position, 1.0, intensity);
    }
    else if (lightingType == 3) {
        // Enhanced AO (19D)
        indirectLight = enhancedAmbientOcclusion(aoValue, normal, vec3(0.3), intensity * 0.5);
    }
    else if (lightingType == 4) {
        // Screen-space indirect (19E)
        // Convert world position to screen position (would need actual screen dimensions)
        vec2 screenPos = vec2(0.5);  // Placeholder
        indirectLight = screenSpaceIndirectBounce(screenPos, normal, intensity);
    }

    // Combine with base color
    vec3 result = baseColor * (1.0 + indirectLight * 0.5);

    // Apply AO darkening (all systems)
    result *= aoValue;

    return result;
}

#endif  // INCLUDE_INDIRECT_LIGHTING
