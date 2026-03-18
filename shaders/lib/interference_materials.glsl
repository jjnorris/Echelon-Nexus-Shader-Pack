// ===================================================================
// Interference-Based Materials (Phase 16)
// ===================================================================
// Thin-film interference effects for material blending and spectral
// property variation. Implements physics-based iridescence and
// thin-film interference patterns.
//
// Theory: Thin-film interference occurs when light bounces between
// parallel surfaces (e.g., oil on water, soap bubbles). Path
// difference causes constructive/destructive interference.
//
// References:
//   - Efficient Rendering of Layered Materials with Atomic Decomposition
//     (Heitz et al., 2019)
//   - Light Field Mapping into Multilayer Architectures (Ghosh et al., 2007)
//   - Born & Wolf, Principles of Optics (1999)

#ifndef INCLUDE_INTERFERENCE_MATERIALS
#define INCLUDE_INTERFERENCE_MATERIALS

// ===================================================================
// THIN-FILM INTERFERENCE CALCULATION
// ===================================================================

// Compute optical path difference for thin film of given thickness
// thickness: film thickness in wavelengths (typically 0.1-10 um mapped to [0,1])
// theta_i: angle of incidence (0 = normal, pi/2 = grazing)
// n_film: refractive index of film (typically 1.3-1.5 for organic films)
float computeOpticalPathDifference(float thickness, float theta_i, float n_film) {
    // Refraction angle (Snell's law: sin(theta_t) = sin(theta_i) / n_film)
    float sin_theta_i = sin(theta_i);
    float sin_theta_t = sin_theta_i / n_film;

    // Prevent total internal reflection
    if (sin_theta_t > 1.0) return 0.0;

    float cos_theta_t = sqrt(1.0 - sin_theta_t * sin_theta_t);

    // Optical path = 2 * thickness * n_film * cos(theta_t)
    // (factor of 2 for down and up paths)
    return 2.0 * thickness * n_film * cos_theta_t;
}

// Map optical path difference to phase shift
// Returns normalized phase in [0, 2pi]
float opd2Phase(float opd, float wavelengthNorm) {
    // wavelengthNorm: normalized wavelength (e.g., 550nm green as 1.0)
    return 2.0 * 3.14159265359 * opd / wavelengthNorm;
}

// Compute intensity from phase (2-beam interference formula)
// Returns normalized intensity [0, 1]
float interferenceFringes(float phase) {
    // I = (A1 + A2)^2 for constructive interference
    // Simplified: I = (1 + cos(phase)) / 2
    float intensity = (1.0 + cos(phase)) * 0.5;
    return intensity;
}

// ===================================================================
// SPECTRAL MATERIAL BLENDING
// ===================================================================

// Blend two material BRDF parameters using spectral interference
// materials: array of 3 material colors (RGB as spectral proxies)
// wavelengths: normalized wavelengths for R,G,B (0.4-0.7um range)
// thickness: film thickness (spectral scale)
// viewAngle: viewing angle relative to surface normal
vec3 spectralMaterialBlend(
    vec3 material1,
    vec3 material2,
    float thickness,
    float viewAngle,
    float n_film
) {
    // Compute optical path difference
    float opd = computeOpticalPathDifference(thickness, viewAngle, n_film);

    // RGB wavelengths (normalized: red=0.65um, green=0.55um, blue=0.45um)
    vec3 wavelengthsNorm = vec3(0.65, 0.55, 0.45);

    // Compute interference for each channel
    vec3 phases = vec3(
        opd2Phase(opd, wavelengthsNorm.r),
        opd2Phase(opd, wavelengthsNorm.g),
        opd2Phase(opd, wavelengthsNorm.b)
    );

    vec3 interference = vec3(
        interferenceFringes(phases.r),
        interferenceFringes(phases.g),
        interferenceFringes(phases.b)
    );

    // Blend materials using interference pattern as blend factor
    return mix(material1, material2, interference);
}

// ===================================================================
// IRIDESCENCE MAPPING
// ===================================================================

// Generate iridescent color based on viewing angle
// Input: normal, viewDirection, iridescence strength
// Returns: iridescent color overlay
vec3 generateIridescence(
    vec3 normal,
    vec3 viewDir,
    float strength
) {
    // Compute viewing angle relative to surface normal
    float viewAngle = acos(abs(dot(viewDir, normal)));

    // Normalize to [0, 1]
    float normalizedAngle = viewAngle / 1.5707963267949; // pi/2

    // Spectral curve for viewing angle
    // Blue at normal, red at grazing
    vec3 spectralResponse;

    if (normalizedAngle < 0.33) {
        // Blue region (0-33%)
        spectralResponse = vec3(0.1, 0.3, 1.0);
    } else if (normalizedAngle < 0.67) {
        // Green region (33-67%)
        float t = (normalizedAngle - 0.33) / 0.34;
        spectralResponse = mix(
            vec3(0.1, 0.3, 1.0),  // Blue
            vec3(0.2, 0.9, 0.3),  // Green
            t
        );
    } else {
        // Red region (67-100%)
        float t = (normalizedAngle - 0.67) / 0.33;
        spectralResponse = mix(
            vec3(0.2, 0.9, 0.3),  // Green
            vec3(1.0, 0.2, 0.1),  // Red
            t
        );
    }

    // Apply saturation and strength
    float saturation = 1.2 + 0.5 * (1.0 - normalizedAngle);
    spectralResponse = mix(vec3(0.5), spectralResponse, saturation);

    return spectralResponse * strength;
}

// ===================================================================
// MULTI-LAYER MATERIAL COMPOSITION
// ===================================================================

// Compose material from multiple layers (dielectric + metallic)
struct LayeredMaterial {
    vec3 color;      // Final blended color
    float roughness; // Blended roughness
    float metallic;  // Blended metallicity
};

LayeredMaterial composeLayeredMaterial(
    vec3 layer1_color,   // Dielectric base (e.g., paint)
    float layer1_rough,
    vec3 layer2_color,   // Metallic layer (e.g., flakes)
    float layer2_metal,
    float layer2_thick,  // Layer 2 thickness
    float viewAngle,
    float layerBlend
) {
    // Thin-film effect on layer 2
    vec3 blendedLayer2 = spectralMaterialBlend(
        layer1_color,
        layer2_color,
        layer2_thick,
        viewAngle,
        1.4  // Typical dielectric n
    );

    // Compose final material
    LayeredMaterial result;
    result.color = mix(layer1_color, blendedLayer2, layerBlend);
    result.roughness = mix(layer1_rough, 0.1, layerBlend);  // Top layer is smoother
    result.metallic = mix(0.0, layer2_metal, layerBlend);

    return result;
}

// ===================================================================
// FRESNEL WITH INTERFERENCE VARIATION
// ===================================================================

// Enhanced Fresnel using thin-film interference
// Produces viewing-angle dependent Fresnel response
vec3 fresnelInterference(
    vec3 F0,
    float HdotV,
    float thickness,
    float n_film
) {
    // Base Fresnel (Schlick)
    vec3 fresnel = F0 + (1.0 - F0) * pow(1.0 - HdotV, 5.0);

    // Interference modulation
    // At grazing angle (HdotV near 0), strong interference effects
    float interferenceStrength = 1.0 - HdotV * HdotV;

    // Compute optical path difference at grazing angle
    float opd = computeOpticalPathDifference(thickness, 1.5707963, n_film);
    float phase = opd2Phase(opd, 0.55);  // Green wavelength
    float interference = interferenceFringes(phase);

    // Modulate Fresnel with interference at grazing angles
    fresnel = mix(fresnel, fresnel * interference, interferenceStrength * 0.5);

    return fresnel;
}

#endif // INCLUDE_INTERFERENCE_MATERIALS
