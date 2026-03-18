// ===================================================================
// Multi-Layer Material Composition (Phase 16)
// ===================================================================
// Stacking dielectric + metallic + specular layers for complex materials.
// Supports paint-over-metal, clear coats, translucent layers, etc.

#ifndef INCLUDE_LAYER_MATERIALS
#define INCLUDE_LAYER_MATERIALS

#include "interference_materials.glsl"

// ===================================================================
// LAYER STRUCTURE DEFINITION
// ===================================================================

struct MaterialLayer {
    vec3 albedo;        // Layer color
    float roughness;    // Layer surface roughness
    float metallic;     // Metallicity (0=dielectric, 1=conductor)
    float thickness;    // Relative thickness (affects transparency/opacity)
    float ior;          // Index of refraction (for dielectrics)
    float transmission; // How much light passes through (0=opaque, 1=fully transparent)
};

// ===================================================================
// LAYER COMPOSITION
// ===================================================================

// Compose multiple layers into single BRDF parameters
struct ComposedMaterial {
    vec3 albedo;
    float roughness;
    float metallic;
    float opacity;      // Overall material opacity
    vec3 subsurfaceColor; // For translucent layers
};

ComposedMaterial composeLayers(
    MaterialLayer base,
    MaterialLayer coat,
    float coatStrength,
    float viewAngle
) {
    ComposedMaterial result;

    // Base: typically more metallic/rough
    // Coat: typically dielectric, smoother

    // Blend using coat strength
    float coatOpacity = coat.transmission * coatStrength;
    float baseOpacity = 1.0 - coatOpacity;

    // Color blending: coat absorbs/reflects over base
    result.albedo = mix(base.albedo, coat.albedo, coatOpacity);

    // Roughness: coat is smoother, blends over base
    result.roughness = mix(base.roughness, coat.roughness, coatOpacity);

    // Metallic: coat reduces metallic response
    result.metallic = base.metallic * baseOpacity;

    // Opacity composition
    result.opacity = base.transmission + coat.transmission * (1.0 - base.transmission);

    // Subsurface: only visible if coat is somewhat transparent
    result.subsurfaceColor = base.albedo * (1.0 - coatOpacity);

    return result;
}

// ===================================================================
// SPECIALIZED MATERIAL PRESETS
// ===================================================================

// Paint over metallic base (e.g., car paint)
ComposedMaterial paintedMetal(
    vec3 paintColor,
    float paintRoughness,
    vec3 metalColor,
    float metalRoughness,
    float clearCoatStrength
) {
    MaterialLayer metal = MaterialLayer(
        metalColor, metalRoughness, 1.0, 0.8, 1.5, 0.1
    );

    MaterialLayer paint = MaterialLayer(
        paintColor, paintRoughness, 0.0, 0.9, 1.5, 0.8
    );

    MaterialLayer clearCoat = MaterialLayer(
        vec3(1.0), 0.05, 0.0, 1.0, 1.4, 0.95
    );

    // Compose paint over metal
    ComposedMaterial painted = composeLayers(metal, paint, 1.0, 0.5);

    // Apply clear coat
    MaterialLayer coatLayer = MaterialLayer(
        painted.albedo, painted.roughness, painted.metallic, 1.0, 1.4, 0.9
    );

    return composeLayers(coatLayer, clearCoat, clearCoatStrength, 0.5);
}

// Fabric/cloth material (translucent + rough)
ComposedMaterial fabricMaterial(
    vec3 fabricColor,
    float roughness,
    float subsurfaceIntensity
) {
    ComposedMaterial result;

    result.albedo = fabricColor;
    result.roughness = clamp(roughness, 0.5, 1.0);  // Fabrics are rough
    result.metallic = 0.0;  // Never metallic
    result.opacity = 1.0 - subsurfaceIntensity;  // Some light passes through
    result.subsurfaceColor = fabricColor * subsurfaceIntensity;

    return result;
}

// Plastic material (dielectric, moderate gloss)
ComposedMaterial plasticMaterial(
    vec3 plasticColor,
    float gloss
) {
    ComposedMaterial result;

    result.albedo = plasticColor;
    result.roughness = 1.0 - gloss;  // Higher gloss = lower roughness
    result.metallic = 0.0;
    result.opacity = 1.0;
    result.subsurfaceColor = vec3(0.0);

    return result;
}

// Rubber material (very rough, absorptive)
ComposedMaterial rubberMaterial(
    vec3 rubberColor,
    float weathering
) {
    ComposedMaterial result;

    result.albedo = rubberColor * (0.8 + 0.2 * weathering);  // Weathered = lighter
    result.roughness = 0.9 + 0.1 * weathering;  // Very rough, slightly more with weathering
    result.metallic = 0.0;
    result.opacity = 1.0;
    result.subsurfaceColor = vec3(0.0);

    return result;
}

// ===================================================================
// LAYER-AWARE FRESNEL
// ===================================================================

// Compute Fresnel accounting for layer composition
vec3 fresnelComposed(
    ComposedMaterial material,
    float HdotV,
    float baseF0_metallic,
    float baseF0_dielectric
) {
    // Metallic: use metallic color as F0
    vec3 F0_metal = material.albedo;

    // Dielectric: use typical F0 values
    vec3 F0_dielectric = vec3(baseF0_dielectric);

    // Blend based on metallic property
    vec3 F0 = mix(F0_dielectric, F0_metal, material.metallic);

    // Schlick's approximation with composition
    vec3 fresnel = F0 + (1.0 - F0) * pow(clamp(1.0 - HdotV, 0.0, 1.0), 5.0);

    // Modulate by opacity
    fresnel *= material.opacity;

    return fresnel;
}

// ===================================================================
// LAYER THICKNESS EFFECTS
// ===================================================================

// Compute absorption based on layer thickness
float computeAbsorption(float thickness, vec3 absorptionCoefficient) {
    // Beer-Lambert law: transmission = exp(-mu * d)
    vec3 transmission = exp(-absorptionCoefficient * thickness);
    return (transmission.r + transmission.g + transmission.b) / 3.0;
}

// Apply thickness-based color shift (thicker = darker)
vec3 applyThicknessAbsorption(
    vec3 color,
    float thickness,
    float maxThickness
) {
    float normalizedThickness = clamp(thickness / maxThickness, 0.0, 1.0);

    // Absorption coefficient (increases darkness)
    float absorption = 1.0 - normalizedThickness;

    return color * absorption;
}

#endif // INCLUDE_LAYER_MATERIALS
