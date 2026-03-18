// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║               DYNAMIC SKY DOME (PHASE 24)                                ║
// ║                                                                           ║
// ║  Physical sky rendering via Rayleigh and Mie scattering simulation.     ║
// ║  Scatters sunlight through atmosphere, producing realistic blue sky,    ║
// ║  orange sunsets, and atmospheric haze. Parameterized by sun angle,      ║
// ║  aerosol density, and optical depth for artistic control.               ║
// ║                                                                           ║
// ║  Physics: Rayleigh scattering (λ^-4 wavelength dependence) explains     ║
// ║  why sky is blue and sunsets are orange. Mie scattering (aerosols,     ║
// ║  pollution) causes haze. Combined: realistic day/night cycle.           ║
// ║                                                                           ║
// ║  Key insight: Different wavelengths scatter differently. Blue (450nm)   ║
// ║  scatters ~10× more than red (650nm), creating blue daytime sky.       ║
// ║  At sunset, red light dominates because blue is scattered away.         ║
// ║                                                                           ║
// ║  References: Nishita et al. 1993, Preetham et al. 1999                 ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SKY_DOME
#define INCLUDE_SKY_DOME

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ RAYLEIGH SCATTERING                                                      ║
// │                                                                           ║
// │ Scattering from molecules smaller than light wavelength (N2, O2 in     │
// │ atmosphere). Wavelength-dependent: ∝ λ^-4 explains blue sky.           │
// │ Dominates at high angles; nearly zero along sun direction.              │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rayleighScattering()                                                    ║
// ║                                                                         ║
// │ Computes scattered light from Rayleigh scattering. Key factors:      │
// │   1. Optical depth (zenith angle) - more atmosphere at horizons      │
// │   2. Wavelength dependence - blue scatters most, red least           │
// │   3. Phase function - angular distribution of scattered light       │
// │                                                                         ║
// │ Physics formula:                                                       │
// │   L_scattered = (1 - e^(-μλ × τ)) × P(θ)                           │
// │   Where: μλ = wavelength-dependent absorption                        │
// │          τ = optical depth (path length through atmosphere)          │
// │          P(θ) = Rayleigh phase function                             │
// │                                                                         ║
// │ Typical result: Blue sky during day, orange at sunset               │
// │                                                                         ║
// │ Returns: RGB color from scattered light [0,1]                       │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 rayleighScattering(
    vec3 lightDir,
    vec3 viewDir,
    float rayleighCoeff
) {
    // ────────────────────────────────────────────────────────────────────────
    // Optical depth from zenith angle
    // Empirical formula: τ(θ) ≈ 1/cos(θ+0.50949)
    // Accounts for spherical atmosphere geometry
    // ────────────────────────────────────────────────────────────────────────
    float zenith = acos(viewDir.y);
    float opticalDepth = 1.0 / (cos(zenith) + 0.50949);

    // ────────────────────────────────────────────────────────────────────────
    // Wavelength-dependent scattering coefficients
    // Rayleigh: σ ∝ 1/λ^4
    // Blue (0.45μm) scatters ~10× more than red (0.65μm)
    // ────────────────────────────────────────────────────────────────────────
    vec3 rayleighWavelengths = vec3(
        1.0 / pow(0.65, 4.0),  // Red: 0.65μm (low scattering)
        1.0 / pow(0.55, 4.0),  // Green: 0.55μm (medium)
        1.0 / pow(0.45, 4.0)   // Blue: 0.45μm (high scattering)
    );

    // ────────────────────────────────────────────────────────────────────────
    // Rayleigh phase function: P(θ) = 3/4 × (1 + cos²(θ))
    // Scatters mostly sideways (perpendicular to sun)
    // ────────────────────────────────────────────────────────────────────────
    float cosTheta = dot(lightDir, viewDir);
    float phase = 0.75 * (1.0 + cosTheta * cosTheta);

    // ────────────────────────────────────────────────────────────────────────
    // Extinction: e^(-μλ × τ) shows how much light is scattered away
    // Higher optical depth = more scattering = darker light ray
    // ────────────────────────────────────────────────────────────────────────
    vec3 extinction = exp(-rayleighWavelengths * rayleighCoeff * opticalDepth);

    return (1.0 - extinction) * phase * rayleighCoeff;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MIE SCATTERING                                                           ║
// │                                                                           ║
// │ Scattering from aerosol particles (dust, pollution, water droplets)   │
// │ much larger than light wavelength. Wavelength-independent (white haze).│
// │ Forward-scattering heavy: creates halos around sun.                    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ miePhaseFunction()                                                      ║
// ║                                                                         ║
// │ Henyey-Greenstein phase function for Mie scattering. Anisotropic:    │
// │ scatters mainly forward (toward sun) creating sun halo effect.        │
// │                                                                         ║
// │ Parameter g ∈ [-1,1]:                                                 │
// │   g ≈ 0: isotropic (like Rayleigh)                                   │
// │   g > 0: forward scattering (like Mie)                               │
// │   g = 0.8: strong forward scattering (realistic aerosols)            │
// │                                                                         ║
// │ Formula: P(cos θ) = (1-g²) / (4π(1+g²-2g·cosθ)^1.5)                │
// └─────────────────────────────────────────────────────────────────────────┘
float miePhaseFunction(float cosTheta, float g) {
    // ────────────────────────────────────────────────────────────────────────
    // Henyey-Greenstein: efficient anisotropic phase function
    // ────────────────────────────────────────────────────────────────────────
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265359 * pow(denom, 1.5));
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ mieScattering()                                                         ║
// ║                                                                         ║
// │ Aerosol scattering: produces white haze. Stronger with aerosol      │
// │ density (pollution, dust storms). Forward-biased scattering creates  │
// │ sun halos and reduces contrast at low elevations.                     │
// │                                                                         ║
// │ Returns: White/neutral light contribution from Mie scattering        │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 mieScattering(
    vec3 lightDir,
    vec3 viewDir,
    float mieCoeff,
    float aerosolDensity
) {
    // ────────────────────────────────────────────────────────────────────────
    // Anisotropic phase: forward-biased (sun halos)
    // ────────────────────────────────────────────────────────────────────────
    float cosTheta = dot(lightDir, viewDir);
    float phase = miePhaseFunction(cosTheta, 0.8);

    // ────────────────────────────────────────────────────────────────────────
    // Mie: wavelength-independent (white) scattering
    // Intensity scales with aerosol density
    // ────────────────────────────────────────────────────────────────────────
    // Mie is more white than Rayleigh
    vec3 scatterColor = vec3(1.0);

    return scatterColor * mieCoeff * aerosolDensity * phase;
}

// ===================================================================
// COMPLETE SKY COLOR
// ===================================================================

vec3 computeSkyColor(
    vec3 lightDir,
    vec3 viewDir,
    float rayleighCoeff,
    float mieCoeff,
    float aerosolDensity
) {
    vec3 sky = rayleighScattering(lightDir, viewDir, rayleighCoeff);
    sky += mieScattering(lightDir, viewDir, mieCoeff, aerosolDensity);

    return sky;
}

// ===================================================================
// SUN DISK
// ===================================================================

vec3 sunDisk(
    vec3 viewDir,
    vec3 lightDir,
    vec3 sunColor
) {
    float angle = acos(dot(viewDir, lightDir));
    float sunSize = 0.01;  // Angular size

    if (angle < sunSize) {
        // Sharp sun disk
        return sunColor * (1.0 - angle / sunSize);
    }

    return vec3(0.0);
}

#endif // INCLUDE_SKY_DOME
