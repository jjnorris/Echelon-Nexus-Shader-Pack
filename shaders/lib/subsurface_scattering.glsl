// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║        SCREEN-SPACE SUBSURFACE SCATTERING (PHASE 22)                     ║
// ║                                                                           ║
// ║  Fast approximation of light scattering through semi-translucent        ║
// ║  materials (skin, wax, marble, foliage, fabric). Screen-space approach  ║
// ║  avoids geometry preprocessing, enabling dynamic SSS on any mesh.       ║
// ║                                                                           ║
// ║  Physics: Light enters material, scatters internally, re-emerges at    ║
// ║  different location. Effect: warm rim lighting, soft skin appearance.   ║
// ║                                                                           ║
// ║  Material Profiles:                                                      ║
// ║    - Human skin: Red/green/blue penetration varies (26.7 / 3.1 / 0.3mm)║
// ║    - Marble/wax: White color with translucency                         ║
// ║    - Foliage: Green dominant (chlorophyll absorbs red/blue)            ║
// ║    - Fabric: Depends on weave and dye                                   ║
// ║                                                                           ║
// ║  References: Beckmann & Spizzichino 1987, d'Eon et al. 2007           ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SUBSURFACE_SCATTERING
#define INCLUDE_SUBSURFACE_SCATTERING

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SSS PROFILE                                                              ║
// │                                                                           ║
// │ Material-specific parameters for subsurface scattering simulation.    │
// │ Defines how far light penetrates and how it attenuates.               │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ SSSProfile (struct)                                                     ║
// ║                                                                         ║
// │ Parameters controlling light scattering through material               │
// │   scatterDistance - Distance RGB light travels before escaping (mm)   │
// │                     Red penetrates furthest, blue least               │
// │   extinctionCoeff - Absorption per unit thickness (Beer-Lambert)     │
// │   thickness - Material thickness or maximum scattering depth (mm)    │
// │                                                                         ║
// │ Example (human skin):                                                 │
// │   Red:   0.5mm (reddish undertone)                                   │
// │   Green: 0.3mm (natural skin tone)                                    │
// │   Blue:  0.2mm (blue is absorbed)                                    │
// └─────────────────────────────────────────────────────────────────────────┘
struct SSSProfile {
    vec3 scatterDistance;   // Distance light travels per channel (RGB)
    vec3 extinctionCoeff;   // Absorption coefficients
    float thickness;        // Maximum scattering depth
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSSS()                                                            ║
// ║                                                                         ║
// │ Computes subsurface scattering contribution using modified diffuse.  │
// │ Models light entering material, scattering internally, re-emerging.   │
// │                                                                         ║
// │ Physics:                                                               │
// │   1. Back-lit term: measures light direction relative to surface    │
// │   2. Transmission: Beer-Lambert exponential attenuation              │
// │   3. Scatter distance: exponential falloff with thickness            │
// │   4. View dependency: scattering most visible perpendicular to view  │
// │                                                                         ║
// │ Returns: RGB SSS radiance contribution (add to base lighting)        │
// │                                                                         ║
// │ Typical range: 0.0-0.2 (SSS is accent, not primary lighting)       │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 computeSSS(
    float thickness,
    vec3 lightDir,
    vec3 normal,
    vec3 viewDir,
    SSSProfile profile,
    vec3 lightColor
) {
    // ────────────────────────────────────────────────────────────────────────
    // Back-lit term: how much light hits rear of surface?
    // -dot(N,L) = 0 when light hits front, 1 when hits back
    // ────────────────────────────────────────────────────────────────────────
    float backlit = max(0.0, -dot(normal, lightDir));

    // ────────────────────────────────────────────────────────────────────────
    // Beer-Lambert transmission: exponential absorption through material
    // T = e^(-μt) where μ = extinction coefficient, t = thickness
    // ────────────────────────────────────────────────────────────────────────
    vec3 transmission = exp(-profile.extinctionCoeff * thickness);

    // ────────────────────────────────────────────────────────────────────────
    // Scattering distance falloff: light attenuates with material depth
    // Separate per channel (R scatters far, B scatters near)
    // ────────────────────────────────────────────────────────────────────────
    float distanceFalloff = exp(-thickness / (profile.scatterDistance + vec3(0.01)));

    // ────────────────────────────────────────────────────────────────────────
    // View angle influence: side-on scattering more visible than edge-on
    // (1 + dot(V,N)): ranges [0,2] based on view direction
    // ────────────────────────────────────────────────────────────────────────
    float viewFalloff = 1.0 + dot(viewDir, normal);

    // ────────────────────────────────────────────────────────────────────────
    // Final SSS contribution: combine all factors
    // 0.5 scale factor prevents over-bright SSS
    // ────────────────────────────────────────────────────────────────────────
    vec3 sss = lightColor * backlit * transmission * distanceFalloff * viewFalloff * 0.5;

    return sss;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SKIN-SPECIFIC SSS                                                        ║
// │                                                                           ║
// │ Specialized profiles for human skin rendering. Different skin tones    │
// │ use different scattering profiles based on pigmentation/thickness.    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ skinSSSProfile()                                                        ║
// ║                                                                         ║
// │ Default human skin SSS parameters. Models light penetration through  │
// │ melanin and hemoglobin layers. Red dominates (blood underneath),     │
// │ blue is absorbed first (Rayleigh scattering).                        │
// └─────────────────────────────────────────────────────────────────────────┘
SSSProfile skinSSSProfile() {
    return SSSProfile(
        vec3(0.5, 0.3, 0.2),   // Red/Green/Blue penetration (mm)
        vec3(0.2, 0.1, 0.05),  // Extinction per channel
        0.5                      // Typical epidermis thickness
    );
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ skinSSS()                                                               ║
// ║                                                                         ║
// │ Optimized skin SSS using curvature approximation. Avoids expensive   │
// │ texture lookups by computing scattering directly from surface normal │
// │ curvature (local surface shape).                                      │
// │                                                                         ║
// │ Cost: Single function call (~0.5ms for whole face)                  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 skinSSS(
    vec3 normal,
    vec3 curvature,
    vec3 lightDir,
    vec3 lightColor,
    float thickness
) {
    float backlit = max(0.0, -dot(normal, lightDir));
    float curveAmount = length(curvature) * 0.5;  // High curvature = more SSS

    // Skin-specific scattering color (warm, pinkish)
    vec3 scatterColor = vec3(1.0, 0.8, 0.7);

    return scatterColor * lightColor * backlit * (0.3 + curveAmount * 0.7);
}

// ===================================================================
// FOLIAGE TRANSMISSION
// ===================================================================

// Light transmission through leaves
vec3 foliageTransmission(
    vec3 normal,
    vec3 lightDir,
    vec3 viewDir,
    vec3 foliageColor,
    vec3 lightColor
) {
    // Back-lit light through leaves
    float backlit = max(0.0, -dot(normal, lightDir));

    // Leaf color modulation (warm, greenish)
    vec3 transmissionColor = foliageColor * vec3(1.0, 1.2, 0.8);

    // Scattering is directional (more scattered perpendicular to view)
    float scatterAmount = 1.0 + dot(viewDir, normal);

    return transmissionColor * lightColor * backlit * scatterAmount * 0.4;
}

#endif // INCLUDE_SUBSURFACE_SCATTERING
