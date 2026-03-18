// ===================================================================
// Screen-Space Subsurface Scattering (Phase 22)
// ===================================================================
// Fast SSS for skin, foliage, and translucent materials.

#ifndef INCLUDE_SUBSURFACE_SCATTERING
#define INCLUDE_SUBSURFACE_SCATTERING

// ===================================================================
// SSS PROFILE
// ===================================================================

struct SSSProfile {
    vec3 scatterDistance;   // How far light scatters
    vec3 extinctionCoeff;   // Light absorption
    float thickness;        // Material thickness
};

// Compute SSS for given thickness and light direction
vec3 computeSSS(
    float thickness,
    vec3 lightDir,
    vec3 normal,
    vec3 viewDir,
    SSSProfile profile,
    vec3 lightColor
) {
    // Back-lit term: how much light comes through the surface
    float backlit = max(0.0, -dot(normal, lightDir));

    // Transmission through material (Beer-Lambert)
    vec3 transmission = exp(-profile.extinctionCoeff * thickness);

    // Scattering distance falloff
    float distanceFalloff = exp(-thickness / (profile.scatterDistance + vec3(0.01)));

    // View direction influence (light scatters more perpendicular to view)
    float viewFalloff = 1.0 + dot(viewDir, normal);

    // SSS radiance
    vec3 sss = lightColor * backlit * transmission * distanceFalloff * viewFalloff * 0.5;

    return sss;
}

// ===================================================================
// SKIN-SPECIFIC SSS
// ===================================================================

SSSProfile skinSSSProfile() {
    return SSSProfile(
        vec3(0.5, 0.3, 0.2),   // Scattering distance (RGB)
        vec3(0.2, 0.1, 0.05),  // Extinction
        0.5                      // Typical skin thickness (mm)
    );
}

// Fast skin SSS using curvature approximation
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
