// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         ATMOSPHERIC SCATTERING (PHASE 23)                               ║
// ║         COMPLETE SUB-PHASES 23A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Atmospheric effects including Rayleigh scattering, Mie scattering,    ║
// ║  aerial perspective, volumetric fog, and sky rendering for            ║
// ║  photorealistic natural environments.                                  ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    23A: Rayleigh Scattering                                            ║
// ║    23B: Mie Scattering                                                ║
// ║    23C: Aerial Perspective                                            ║
// ║    23D: Volumetric Fog                                                ║
// ║    23E: Sky Rendering                                                 ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Realistic sky colors (sunset, sunrise, blue sky)                ║
// ║    - Atmospheric haze and perspective                               ║
// ║    - Volumetric fog and mist                                       ║
// ║    - Distance-based atmosphere                                     ║
// ║    - Environmental authenticity                                    ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - O'Neill (2002) - Realistic Atmosphere Scattering              ║
// ║    - Nishita et al. (1993) - Real-Time Sky Computation            ║
// ║    - Preetham et al. (1999) - Physically-Based Atmosphere Model  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_ATMOSPHERIC_SCATTERING
#define INCLUDE_ATMOSPHERIC_SCATTERING

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 23A: RAYLEIGH SCATTERING                                          ║
// ║                                                                           ║
// │ Molecular scattering (blue sky, sunsets).                          ║
// │ Dominates for small particles and short wavelengths.              ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rayleighScatteringCoefficient()                                         ║
// ║                                                                         ║
// │ Compute Rayleigh scattering per wavelength.                      │
// │                                                                       │
// │ Physics: Rayleigh scattering (λ⁻⁴ dependence)                    │
// │   σ_R(λ) = (8π³/3) × (n² - 1)² / (N × λ⁴)                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   wavelength - Light wavelength (nanometers)                    │
// │   altitude - Height above sea level (0-10000m)                 │
// │                                                                       │
// │ Returns: Rayleigh scattering coefficient                    │
// └─────────────────────────────────────────────────────────────────────────┘
float rayleighScatteringCoefficient(float wavelength, float altitude) {
    // Rayleigh scattering coefficient (approximate)
    // σ_R ∝ λ⁻⁴

    float lambda_um = wavelength / 1000.0;  // Convert to micrometers
    float rayleigh = 8.3e-6 / (lambda_um * lambda_um * lambda_um * lambda_um);

    // Altitude correction (exponential decrease)
    float altitudeFactor = exp(-altitude / 8000.0);  // Scale height ~8km

    return rayleigh * altitudeFactor;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rayleighPhaseFunction()                                                 ║
// ║                                                                         ║
// │ Compute Rayleigh phase function.                                 │
// │ Determines scattering direction distribution.                   │
// │                                                                       │
// │ Physics: Phase function (viewing angle dependent)              │
// │   P(θ) = (3/4) × (1 + cos²(θ))                                │
// │                                                                       │
// │ Inputs:                                                              │
// │   cosTheta - cos(angle between sun and view)                   │
// │                                                                       │
// │ Returns: Phase function value (normalized)                   │
// └─────────────────────────────────────────────────────────────────────────┘
float rayleighPhaseFunction(float cosTheta) {
    // Rayleigh phase: stronger forward/backward, weaker at 90°
    return 0.75 * (1.0 + cosTheta * cosTheta);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 23B: MIE SCATTERING                                               ║
// ║                                                                           ║
// │ Aerosol scattering (haze, fog, dust particles).                   ║
// │ Dominates for larger particles and longer wavelengths.           ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ mieScatteringCoefficient()                                              ║
// ║                                                                         ║
// │ Compute Mie scattering coefficient.                             │
// │                                                                       │
// │ Physics: Mie theory (aerosol scattering)                       │
// │   σ_M ≈ constant (weakly wavelength dependent)                │
// │                                                                       │
// │ Inputs:                                                              │
// │   turbidity - Atmospheric turbidity factor (1-10)              │
// │   altitude - Height above sea level                            │
// │                                                                       │
// │ Returns: Mie scattering coefficient                        │
// └─────────────────────────────────────────────────────────────────────────┘
float mieScatteringCoefficient(float turbidity, float altitude) {
    // Mie scattering (weakly wavelength dependent)
    float baseMie = turbidity * 2.0e-5;

    // Altitude factor (concentrated near surface)
    float altitudeFactor = exp(-altitude / 1200.0);  // Scale height ~1.2km

    return baseMie * altitudeFactor;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ miePhaseFunction()                                                      ║
// ║                                                                         ║
// │ Compute Mie phase function.                                     │
// │ Forward-peaked for aerosol particles.                          │
// │                                                                       │
// │ Physics: Mie phase (highly forward-scattering)                 │
// │   P(θ) biased towards forward direction                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   cosTheta - cos(angle between sun and view)                   │
// │   g - Asymmetry factor (0.76 typical for aerosols)           │
// │                                                                       │
// │ Returns: Mie phase function value                         │
// └─────────────────────────────────────────────────────────────────────────┘
float miePhaseFunction(float cosTheta, float g) {
    // Henyey-Greenstein phase function
    // Strongly forward-peaked for aerosols

    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;

    return (1.0 - g2) / (4.0 * PI * denom * sqrt(denom));
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 23C: AERIAL PERSPECTIVE                                           ║
// ║                                                                           ║
// │ Distance-based atmospheric haze and color shift.               ║
// │ Creates sense of depth through atmospheric absorption.         ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ aerialPerspective()                                                     ║
// ║                                                                         ║
// │ Blend surface color with atmospheric color based on distance. │
// │                                                                       │
// │ Physics: Atmospheric absorption and scattering               │
// │   C_out = C_in × T(d) + C_atm × (1 - T(d))                  │
// │   T(d) = exp(-σ × d)  (transmittance)                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   surfaceColor - Original surface color                       │
// │   distance - Distance from camera (world units)               │
// │   atmosphereColor - Atmospheric fog color                   │
// │   aerialFogDensity - Fog density coefficient                │
// │                                                                       │
// │ Returns: Atmosphere-blended color                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 aerialPerspective(
    vec3 surfaceColor,
    float distance,
    vec3 atmosphereColor,
    float aerialFogDensity
) {
    // Transmittance (how much light gets through)
    float transmittance = exp(-aerialFogDensity * distance);

    // Blend: surface fades to atmosphere with distance
    vec3 result = surfaceColor * transmittance + atmosphereColor * (1.0 - transmittance);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ atmosphereDensity()                                                     ║
// ║                                                                         ║
// │ Compute atmospheric density at given altitude.               │
// │                                                                       │
// │ Inputs:                                                              │
// │   altitude - Height above surface (0-30000 meters)           │
// │ │   seaLevelDensity - Density at sea level (1.0 typical)     │
// │                                                                       │
// │ Returns: Relative density                                  │
// └─────────────────────────────────────────────────────────────────────────┘
float atmosphereDensity(float altitude, float seaLevelDensity) {
    // Exponential density model
    // ρ(h) = ρ₀ × exp(-h / H)

    const float scaleHeight = 8500.0;  // Earth's scale height (meters)

    return seaLevelDensity * exp(-altitude / scaleHeight);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 23D: VOLUMETRIC FOG                                               ║
// ║                                                                           ║
// │ Volumetric fog rendering via depth sampling.                   ║
// │ Creates visible volumetric light effects.                     ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ volumetricFog()                                                         ║
// ║                                                                         ║
// │ Compute volumetric fog contribution.                         │
// │                                                                       │
// │ Physics: Volumetric light transport                         │
// │   L = ∫ τ(t) × σ_s × L_sun dt                              │
// │                                                                       │
// │ Inputs:                                                              │
// │   viewDistance - Distance along view ray                      │
// │   sunDirection - Direction to sun                           │
// │   sunColor - Color of direct sunlight                      │
// │   fogDensity - Fog opacity                                 │
// │   absorption - Fog absorption coefficient                 │
// │   samples - Number of volume samples                      │
// │                                                                       │
// │ Returns: Volumetric fog color                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 volumetricFog(
    float viewDistance,
    vec3 sunDirection,
    vec3 sunColor,
    float fogDensity,
    float absorption,
    int samples
) {
    vec3 fog = vec3(0.0);
    float stepSize = viewDistance / float(samples);

    for (int i = 0; i < samples && i < 32; i++) {
        float dist = float(i) * stepSize;

        // Transmittance to this point
        float transmittance = exp(-absorption * dist);

        // Fog density at this point
        float sampleDensity = fogDensity * transmittance;

        // Light contribution (simplified: assumes sun hits fog)
        vec3 scattering = sunColor * sampleDensity;

        // Accumulate
        fog += scattering * stepSize;
    }

    return fog;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ fogAbsorption()                                                         ║
// ║                                                                         ║
// │ Compute light absorption through fog.                        │
// │                                                                       │
// │ Inputs:                                                              │
// │   distance - Distance through fog                              │
// │   density - Fog density                                       │
// │                                                                       │
// │ Returns: Absorption factor (0=fully absorbed, 1=no absorption) │
// └─────────────────────────────────────────────────────────────────────────┘
float fogAbsorption(float distance, float density) {
    // Beer's law: I = I₀ × exp(-σ × d)
    return exp(-density * distance);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 23E: SKY RENDERING                                                ║
// ║                                                                           ║
// │ Physically-based sky color and lighting.                      ║
// │ Reproduces realistic sky gradients and colors.               ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ skyColor()                                                              ║
// ║                                                                         ║
// │ Compute sky color from direction.                            │
// │                                                                       │
// │ Physics: Rayleigh + Mie scattering components              │
// │   Sky = Rayleigh(angle, wavelength) + Mie(turbidity)      │
// │                                                                       │
// │ Inputs:                                                              │
// │   direction - Sky direction (normalized)                      │
// │   sunDirection - Direction to sun                           │
// │   sunColor - Direct sunlight color                         │
// │   skyColor - Zenith sky color (typically (0.5, 0.7, 1.0))  │
// │   turbidity - Atmospheric turbidity (1-10)                 │
// │                                                                       │
// │ Returns: Sky color at direction                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 skyColor(
    vec3 direction,
    vec3 sunDirection,
    vec3 sunColor,
    vec3 baseColor,
    float turbidity
) {
    vec3 normalized = normalize(direction);

    // Angle to sun
    float cosTheta = dot(normalized, sunDirection);
    cosTheta = clamp(cosTheta, -1.0, 1.0);

    // Rayleigh component (blue sky)
    float rayleighFactor = rayleighPhaseFunction(cosTheta);
    vec3 rayleigh = baseColor * rayleighFactor;

    // Mie component (haze/sun glow)
    float mieFactor = miePhaseFunction(cosTheta, 0.76);
    vec3 mie = mix(baseColor, sunColor, 0.5) * mieFactor * turbidity;

    // Sun disk
    float sunDisk = 0.0;
    if (cosTheta > 0.9998) {  // ~0.5° angular width
        sunDisk = smoothstep(0.9998, 0.99999, cosTheta);
    }

    // Combine
    vec3 sky = rayleigh + mie + (sunColor * sunDisk);

    // Altitude fade (darker towards horizon)
    float altitude = normalized.y;
    float altitudeFactor = smoothstep(-0.1, 0.3, altitude);

    sky *= altitudeFactor;

    return sky;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sunsetColor()                                                           ║
// ║                                                                         ║
// │ Compute realistic sunset/sunrise colors.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   sunHeight - Sun height above horizon (-1 to 1)              │
// │   turbidity - Atmospheric turbidity                           │
// │                                                                       │
// │ Returns: Sunset-adjusted color                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 sunsetColor(float sunHeight, float turbidity) {
    // Sunset happens when sun is near horizon (low sunHeight)

    // Color shift based on sun position
    vec3 color = vec3(1.0);

    if (sunHeight < 0.2) {
        // Sunset zone
        float factor = (0.2 - sunHeight) / 0.2;

        // Shift from blue towards orange/red
        color = mix(
            vec3(0.5, 0.7, 1.0),  // Blue sky
            vec3(1.0, 0.6, 0.3),  // Orange sunset
            factor
        );

        // Increase saturation with turbidity
        color = mix(color, vec3(1.0, 0.4, 0.1), turbidity * 0.3);
    }

    return color;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED ATMOSPHERIC RENDERING                                            ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyAtmosphericScattering(
    vec3 baseColor,
    vec3 viewDir,
    float distance,
    vec3 sunDirection,
    vec3 sunColor,
    float turbidity,
    float fogDensity,
    bool renderSky
) {
    // Sky rendering
    vec3 atmosphereColor = vec3(0.5, 0.7, 1.0);
    if (renderSky) {
        atmosphereColor = skyColor(viewDir, sunDirection, sunColor, vec3(0.5, 0.7, 1.0), turbidity);
    }

    // Sunset shift
    float sunHeight = sunDirection.y;
    atmosphereColor *= sunsetColor(sunHeight, turbidity);

    // Volumetric fog
    vec3 fogColor = volumetricFog(distance, sunDirection, sunColor, fogDensity, 0.1, 16);

    // Aerial perspective
    vec3 result = aerialPerspective(baseColor, distance, atmosphereColor + fogColor, 0.01 * fogDensity);

    return result;
}

#endif  // INCLUDE_ATMOSPHERIC_SCATTERING
