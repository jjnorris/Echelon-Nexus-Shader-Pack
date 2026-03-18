// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║              INTERFERENCE-BASED MATERIALS (PHASE 16)                     ║
// ║                                                                           ║
// ║  Thin-film interference effects for material blending and spectral       ║
// ║  property variation. Implements physics-based iridescence and            ║
// ║  thin-film interference patterns using optical path difference.          ║
// ║                                                                           ║
// ║  Theory: When light bounces between parallel surfaces (oil on water,    ║
// ║  soap bubbles), path difference causes constructive/destructive         ║
// ║  interference, producing characteristic color shifts.                    ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Heitz et al. (2019) - Layered Materials with Atomic Decomposition  ║
// ║    - Ghosh et al. (2007) - Light Field Mapping in Multilayers           ║
// ║    - Born & Wolf (1999) - Principles of Optics                          ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_INTERFERENCE_MATERIALS
#define INCLUDE_INTERFERENCE_MATERIALS

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ THIN-FILM INTERFERENCE CALCULATION                                       ║
// ║                                                                           ║
// │ Core optical physics for multi-layer materials. Computes phase shifts    │
// │ from path differences, enabling realistic color variation with viewing   │
// │ angle (iridescence, oil slicks, soap bubbles).                          │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeOpticalPathDifference()                                          ║
// ║                                                                         ║
// │ Computes optical path difference for thin film using Snell's law.     │
// │ Path difference causes phase shifts in light bouncing through film.    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   thickness   - Film thickness (0.1-10 μm, mapped to [0,1])          │
// │   theta_i     - Angle of incidence (0=normal, π/2=grazing)           │
// │   n_film      - Refractive index (1.3-1.5 for organic films)         │
// │                                                                         ║
// │ Returns: Optical path difference used for interference calculation    │
// │                                                                         ║
// │ Physics: OPD = 2 * thickness * n * cos(θ_transmitted)                │
// │ (factor of 2 accounts for down and up light paths)                   │
// └─────────────────────────────────────────────────────────────────────────┘
float computeOpticalPathDifference(float thickness, float theta_i, float n_film) {
    // ────────────────────────────────────────────────────────────────────────
    // Apply Snell's law: sin(θ_transmitted) = sin(θ_incident) / n_film
    // ────────────────────────────────────────────────────────────────────────
    float sin_theta_i = sin(theta_i);
    float sin_theta_t = sin_theta_i / n_film;

    // Prevent total internal reflection (critical angle violation)
    if (sin_theta_t > 1.0) return 0.0;

    float cos_theta_t = sqrt(1.0 - sin_theta_t * sin_theta_t);

    // ────────────────────────────────────────────────────────────────────────
    // Optical path = 2 × thickness × n × cos(θ_transmitted)
    // Factor of 2: light travels down and back up through film
    // ────────────────────────────────────────────────────────────────────────
    return 2.0 * thickness * n_film * cos_theta_t;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ opd2Phase()                                                             ║
// ║                                                                         ║
// │ Converts optical path difference to phase shift in radians.            │
// │ Phase = 2π × OPD / λ (constructive when phase = 2πk for integer k)    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   opd             - Optical path difference (from computeOptical...)   │
// │   wavelengthNorm  - Normalized wavelength (550nm green = 1.0 unit)    │
// │                                                                         ║
// │ Returns: Phase shift in radians [0, 2π]                              │
// │                                                                         ║
// │ Mathematical: φ = (2π / λ) × OPD                                      │
// └─────────────────────────────────────────────────────────────────────────┘
float opd2Phase(float opd, float wavelengthNorm) {
    return 2.0 * 3.14159265359 * opd / wavelengthNorm;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ interferenceFringes()                                                   ║
// ║                                                                         ║
// │ Computes intensity from phase using 2-beam interference formula.       │
// │ Produces characteristic "fringe" patterns seen in oil films/bubbles.   │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   phase - Phase shift from opd2Phase() in radians                     │
// │                                                                         ║
// │ Returns: Normalized intensity [0, 1]                                 │
// │   - 1.0 = constructive (phase = 2πk)                                 │
// │   - 0.0 = destructive (phase = π(2k+1))                              │
// │                                                                         ║
// │ Formula: I = (1 + cos(φ)) / 2  (two-wave interference)               │
// └─────────────────────────────────────────────────────────────────────────┘
float interferenceFringes(float phase) {
    // ────────────────────────────────────────────────────────────────────────
    // Two-beam interference: I = |A₁ + A₂e^(iφ)|² = (1 + cos(φ)) / 2
    // Normalized to [0, 1] for color channel blending
    // ────────────────────────────────────────────────────────────────────────
    return (1.0 + cos(phase)) * 0.5;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL MATERIAL BLENDING                                               ║
// ║                                                                           ║
// │ Blends two materials using wavelength-dependent interference patterns.  │
// │ Different wavelengths (RGB) interfere constructively/destructively at  │
// │ different angles, producing iridescent color shifts (oil slicks, etc). │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralMaterialBlend()                                                 ║
// ║                                                                         ║
// │ Blends two materials using spectral interference as blend factor.      │
// │ Each RGB channel has different wavelength → different interference     │
// │ patterns → iridescent color shift with viewing angle.                  │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   material1  - Base material color (blended from)                     │
// │   material2  - Top material color (blended to)                        │
// │   thickness  - Film thickness (0-1, affects wavelength scale)         │
// │   viewAngle  - Viewing angle from surface normal (radians)            │
// │   n_film     - Film refractive index (1.3-1.5)                        │
// │                                                                         ║
// │ Returns: Blended color based on RGB wavelength interference           │
// │                                                                         ║
// │ Color Response:                                                         ║
// │   - Red (650nm) interferes at wider angles                            │
// │   - Green (550nm) interferes at medium angles                         │
// │   - Blue (450nm) interferes at narrower angles                        │
// │   Result: RGB shift with angle creates iridescence                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 spectralMaterialBlend(
    vec3 material1,
    vec3 material2,
    float thickness,
    float viewAngle,
    float n_film
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute optical path difference for given angle and thickness
    // ────────────────────────────────────────────────────────────────────────
    float opd = computeOpticalPathDifference(thickness, viewAngle, n_film);

    // ────────────────────────────────────────────────────────────────────────
    // RGB wavelengths (nm → normalized units)
    // Red: 650nm, Green: 550nm, Blue: 450nm
    // Higher wavelength = longer periodicity = wider interference spacing
    // ────────────────────────────────────────────────────────────────────────
    vec3 wavelengthsNorm = vec3(0.65, 0.55, 0.45);

    // ────────────────────────────────────────────────────────────────────────
    // Compute phase shift for each wavelength
    // Shorter wavelengths phase faster (more periods)
    // ────────────────────────────────────────────────────────────────────────
    vec3 phases = vec3(
        opd2Phase(opd, wavelengthsNorm.r),
        opd2Phase(opd, wavelengthsNorm.g),
        opd2Phase(opd, wavelengthsNorm.b)
    );

    // ────────────────────────────────────────────────────────────────────────
    // Convert phases to intensities via interference fringe pattern
    // ────────────────────────────────────────────────────────────────────────
    vec3 interference = vec3(
        interferenceFringes(phases.r),
        interferenceFringes(phases.g),
        interferenceFringes(phases.b)
    );

    // ────────────────────────────────────────────────────────────────────────
    // Use per-channel interference as blend weights
    // Wavelengths with constructive interference show material2 more
    // ────────────────────────────────────────────────────────────────────────
    return mix(material1, material2, interference);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ IRIDESCENCE MAPPING                                                      ║
// ║                                                                           ║
// │ Generates viewing-angle dependent color variation. Simulates effects    │
// │ like peacock feathers, butterfly wings, and oil films through direct   │
// │ wavelength-dependent color mapping (not physical thin-film, but         │
// │ perceptually convincing).                                               │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ generateIridescence()                                                   ║
// ║                                                                         ║
// │ Generates iridescent color overlay based on viewing angle.              │
// │ Produces smooth color transition from blue (normal) → green → red      │
// │ (grazing angle) with saturation/brightness modulation.                 │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   normal    - Surface normal (normalized)                             │
// │   viewDir   - View direction (normalized)                             │
// │   strength  - Iridescence intensity multiplier (0-1)                 │
// │                                                                         ║
// │ Returns: RGB iridescent color overlay to blend over base material      │
// │                                                                         ║
// │ Behavior by Angle:                                                      ║
// │   - 0° (normal):  Blue with high saturation                           │
// │   - 45° (glance): Green/cyan transition                               │
// │   - 90° (grazing): Red with reduced saturation                        │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 generateIridescence(
    vec3 normal,
    vec3 viewDir,
    float strength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute angle between view and normal (0° = looking straight on,
    // 90° = looking at glancing angle)
    // ────────────────────────────────────────────────────────────────────────
    float viewAngle = acos(abs(dot(viewDir, normal)));

    // ────────────────────────────────────────────────────────────────────────
    // Normalize to [0, 1] where 0 = normal, 1 = grazing (π/2 radians)
    // ────────────────────────────────────────────────────────────────────────
    float normalizedAngle = viewAngle / 1.5707963267949; // π/2

    // ────────────────────────────────────────────────────────────────────────
    // Map normalized angle to spectral color response
    // Dividing into three regions for smooth color transitions
    // ────────────────────────────────────────────────────────────────────────
    vec3 spectralResponse;

    if (normalizedAngle < 0.33) {
        // ────────────────────────────────────────────────────────────────────
        // Blue region (0-33%): normal viewing angle dominates
        // ────────────────────────────────────────────────────────────────────
        spectralResponse = vec3(0.1, 0.3, 1.0);
    } else if (normalizedAngle < 0.67) {
        // ────────────────────────────────────────────────────────────────────
        // Transition region (33-67%): blue → green blend
        // ────────────────────────────────────────────────────────────────────
        float t = (normalizedAngle - 0.33) / 0.34;
        spectralResponse = mix(
            vec3(0.1, 0.3, 1.0),  // Blue
            vec3(0.2, 0.9, 0.3),  // Green
            t
        );
    } else {
        // ────────────────────────────────────────────────────────────────────
        // Red region (67-100%): green → red transition at grazing angles
        // ────────────────────────────────────────────────────────────────────
        float t = (normalizedAngle - 0.67) / 0.33;
        spectralResponse = mix(
            vec3(0.2, 0.9, 0.3),  // Green
            vec3(1.0, 0.2, 0.1),  // Red
            t
        );
    }

    // ────────────────────────────────────────────────────────────────────────
    // Apply saturation modulation: highest at glancing angles, lower at normal
    // Mix toward neutral (0.5) to reduce saturation effect at normal angles
    // ────────────────────────────────────────────────────────────────────────
    float saturation = 1.2 + 0.5 * (1.0 - normalizedAngle);
    spectralResponse = mix(vec3(0.5), spectralResponse, saturation);

    return spectralResponse * strength;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MULTI-LAYER MATERIAL COMPOSITION                                         ║
// ║                                                                           ║
// │ Combines dielectric and metallic layers into single material parameters.│
// │ Supports complex effects like metallic flakes in paint, clear coats     │
// │ over metal, and thin-film effects on layered surfaces.                  │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ LayeredMaterial (structure)                                             ║
// ║                                                                         ║
// │ Represents composed multi-layer material properties                    │
// │   color:      Final blended RGB (0-1)                                 │
// │   roughness:  Blended roughness (0=mirror, 1=diffuse)                │
// │   metallic:   Blended metallicity (0=dielectric, 1=conductor)        │
// └─────────────────────────────────────────────────────────────────────────┘
struct LayeredMaterial {
    vec3 color;      // Final blended color
    float roughness; // Blended roughness
    float metallic;  // Blended metallicity
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ composeLayeredMaterial()                                                ║
// ║                                                                         ║
// │ Composes two material layers into single BRDF parameters with thin-    │
// │ film interference effects on the top layer.                            │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   layer1_color   - Base layer color (e.g., paint)                     │
// │   layer1_rough   - Base layer roughness                               │
// │   layer2_color   - Top layer color (e.g., metallic flakes)            │
// │   layer2_metal   - Top layer metallicity (0=none, 1=full)             │
// │   layer2_thick   - Top layer thickness (affects interference)         │
// │   viewAngle      - Viewing angle for interference calculation          │
// │   layerBlend     - Blend strength (0=layer1 only, 1=layer2 full)     │
// │                                                                         ║
// │ Returns: Composed LayeredMaterial with blended properties             │
// │                                                                         ║
// │ Behavior:                                                               ║
// │   - Thin-film interference on layer2 with layer1 as reference         │
// │   - Top layer color blends over base via spectral interference         │
// │   - Roughness: top layer much smoother (thin coats are polished)      │
// │   - Metallicity: fully controlled by layer blend strength              │
// └─────────────────────────────────────────────────────────────────────────┘
LayeredMaterial composeLayeredMaterial(
    vec3 layer1_color,   // Dielectric base (e.g., paint)
    float layer1_rough,
    vec3 layer2_color,   // Metallic layer (e.g., flakes)
    float layer2_metal,
    float layer2_thick,  // Layer 2 thickness
    float viewAngle,
    float layerBlend
) {
    // ────────────────────────────────────────────────────────────────────────
    // Apply thin-film interference to layer 2 against layer 1 base
    // Spectral blending creates iridescent effect on layer 2
    // n_film = 1.4 is typical for clear coat dielectrics
    // ────────────────────────────────────────────────────────────────────────
    vec3 blendedLayer2 = spectralMaterialBlend(
        layer1_color,
        layer2_color,
        layer2_thick,
        viewAngle,
        1.4  // Typical clear coat refractive index
    );

    // ────────────────────────────────────────────────────────────────────────
    // Compose into final material
    // ────────────────────────────────────────────────────────────────────────
    LayeredMaterial result;

    // Color: blend base with interference-modified top layer
    result.color = mix(layer1_color, blendedLayer2, layerBlend);

    // Roughness: thin coats are very smooth (0.1), base can be rough
    result.roughness = mix(layer1_rough, 0.1, layerBlend);

    // Metallicity: controlled by layerBlend and layer2_metal
    result.metallic = mix(0.0, layer2_metal, layerBlend);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ FRESNEL WITH INTERFERENCE VARIATION                                      ║
// ║                                                                           ║
// │ Enhances Schlick Fresnel with thin-film interference modulation.        │
// │ Produces more realistic specular response for layered materials,        │
// │ especially at grazing angles where thin films have strongest effect.    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ fresnelInterference()                                                   ║
// ║                                                                         ║
// │ Computes Fresnel response modulated by thin-film interference effects. │
// │ At grazing angles where interference is strong, modulates the Fresnel  │
// │ intensity to match realistic oil/soap/clear-coat behavior.             │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   F0        - Base Fresnel reflectance at normal angle (0-1)           │
// │   HdotV     - Dot product of half-vector and view (0=grazing, 1=normal)│
// │   thickness - Film thickness (affects interference period)             │
// │   n_film    - Film refractive index (1.3-1.5)                          │
// │                                                                         ║
// │ Returns: Fresnel reflectance modulated by interference                 │
// │                                                                         ║
// │ Physics:                                                                ║
// │   - Base: Schlick Fresnel at normal viewing conditions                 │
// │   - Modulation: Interference peaks/dips at grazing angles              │
// │   - Strength: Maximum at 90° (grazing), zero at normal (0°)            │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 fresnelInterference(
    vec3 F0,
    float HdotV,
    float thickness,
    float n_film
) {
    // ────────────────────────────────────────────────────────────────────────
    // Base Fresnel using Schlick's approximation (standard PBR)
    // F = F₀ + (1 - F₀) × (1 - cos(θ))⁵
    // ────────────────────────────────────────────────────────────────────────
    vec3 fresnel = F0 + (1.0 - F0) * pow(1.0 - HdotV, 5.0);

    // ────────────────────────────────────────────────────────────────────────
    // Compute interference modulation strength
    // Strong at grazing angles (HdotV → 0), zero at normal (HdotV → 1)
    // ────────────────────────────────────────────────────────────────────────
    float interferenceStrength = 1.0 - HdotV * HdotV;

    // ────────────────────────────────────────────────────────────────────────
    // Compute optical path difference at extreme grazing angle (π/2)
    // Phase shift determines if interference adds or subtracts from Fresnel
    // ────────────────────────────────────────────────────────────────────────
    float opd = computeOpticalPathDifference(thickness, 1.5707963, n_film);
    float phase = opd2Phase(opd, 0.55);  // Green wavelength (550nm)
    float interference = interferenceFringes(phase);

    // ────────────────────────────────────────────────────────────────────────
    // Modulate Fresnel response with interference pattern
    // At grazing angles: apply interference modulation at full strength
    // At normal angles: minimal interference effect (interferenceStrength ≈ 0)
    // ────────────────────────────────────────────────────────────────────────
    fresnel = mix(fresnel, fresnel * interference, interferenceStrength * 0.5);

    return fresnel;
}

#endif // INCLUDE_INTERFERENCE_MATERIALS
