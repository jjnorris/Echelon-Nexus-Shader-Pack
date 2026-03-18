// ===================================================================
// Echelon Nexus - PBR Material Decoding (LabPBR + oldPBR Support)
// ===================================================================
// Decodes material properties from texture samplers.
// Supports two formats:
//   1. LabPBR (modern, preferred)
//   2. oldPBR (legacy, graceful fallback)
// ===================================================================

#ifndef INCLUDE_PBR_MATERIAL
#define INCLUDE_PBR_MATERIAL

#include "constants.glsl"
#include "functions.glsl"

// ===================================================================
// MATERIAL STRUCTURE
// ===================================================================

// Unified material representation (independent of source format)
struct Material {
    vec3 albedo;        // Base color (linear)
    vec3 normal;        // Surface normal (world space, normalized)
    float roughness;    // Roughness [0, 1]; 0=smooth, 1=rough
    float metallic;     // Metallic [0, 1]; 0=dielectric, 1=metal
    float emissive;     // Emissive intensity [0, 1]
    float f0;           // Reflectance at normal incidence (computed or read)
    float height;       // Height/parallax magnitude [0, 1]
};

// ===================================================================
// LABPBR DECODING
// ===================================================================

// LabPBR uses standard texture naming:
//   _d.png = Diffuse / Albedo (RGB)
//   _s.png = Specular (R=smoothness, G=F0, B=emissive)
//   _n.png = Normal (RGB), Height (A) [optional]
//
// Semantics:
//   R (Smoothness) : [0, 1] inverted from roughness
//   G (Specular/F0): Reflectance or metallic property
//   B (Emissive)   : Self-illumination intensity
//   A (Height)     : Optional parallax/displacement

Material decodeLabPBR(
    vec3 albedoSample,
    vec4 specularSample,
    vec3 normalMapSample,
    float heightSample,
    vec3 geometricNormal
) {
    Material mat;

    // Albedo (linear RGB, assuming sRGB input from texture)
    mat.albedo = srgbToLinear(albedoSample);

    // Smoothness to roughness conversion
    float smoothness = specularSample.r;
    mat.roughness = 1.0 - smoothness;

    // F0 / Metallic (second channel interpretation varies)
    // In LabPBR standard, G channel encodes reflectance at normal incidence
    // For simplicity: treat as F0 directly
    mat.f0 = specularSample.g;

    // Determine metallic from F0
    // Metals have F0 > 0.5; dielectrics have F0 ≈ 0.04
    mat.metallic = (mat.f0 > 0.4) ? 1.0 : 0.0;

    // Emissive intensity
    mat.emissive = specularSample.b;

    // Height (for parallax mapping)
    mat.height = heightSample;

    // Normal map
    // Standard RGB normal map encoding: [0,1] -> [-1,1]
    mat.normal = normalize(normalMapSample * 2.0 - 1.0);

    // Blend geometric normal if normal map is missing
    if (length(normalMapSample) < EPSILON) {
        mat.normal = geometricNormal;
    }

    return mat;
}

// ===================================================================
// OLDPBR DECODING (Legacy)
// ===================================================================

// oldPBR format (common in older resourcepacks):
//   _d.png = Diffuse (RGB)
//   _s.png / _n.png combined = Normal (RGB) + Specular (R), Height (A)
//
// Semantics vary but typically:
//   Normal XYZ in RGB
//   Height/Parallax in A or separate channel
//   Specular properties less clearly defined

Material decodeOldPBR(
    vec3 albedoSample,
    vec4 specularSample,
    vec3 normalSample,
    float heightSample,
    vec3 geometricNormal
) {
    Material mat;

    // Albedo
    mat.albedo = srgbToLinear(albedoSample);

    // Default roughness (oldPBR doesn't always have explicit roughness)
    // Use specular channel as hint
    mat.roughness = 1.0 - clamp(specularSample.r, 0.0, 1.0);

    // Default F0 for dielectrics
    mat.f0 = DEFAULT_F0;

    // Metallic not typically encoded in oldPBR; default to non-metallic
    mat.metallic = 0.0;

    // Emissive (not always present in oldPBR)
    mat.emissive = 0.0;

    // Height
    mat.height = heightSample;

    // Normal (assume normalSample is already in [-1, 1] or needs decoding)
    mat.normal = normalize(normalSample * 2.0 - 1.0);

    if (length(normalSample) < EPSILON) {
        mat.normal = geometricNormal;
    }

    return mat;
}

// ===================================================================
// GRACEFUL FALLBACK DECODING
// ===================================================================

// If no specular/material map is available, use defaults
Material decodeDefaultMaterial(
    vec3 albedoSample,
    vec3 geometricNormal
) {
    Material mat;

    mat.albedo = srgbToLinear(albedoSample);
    mat.roughness = DEFAULT_ROUGHNESS;
    mat.metallic = DEFAULT_METALLIC;
    mat.f0 = DEFAULT_F0;
    mat.emissive = 0.0;
    mat.height = 0.0;
    mat.normal = geometricNormal;

    return mat;
}

// ===================================================================
// UNIFIED MATERIAL DECODING
// ===================================================================

// Main entry point: decodes material based on available textures
// pbrMode: 0 = LabPBR (preferred), 1 = oldPBR (legacy)
Material decodeMaterial(
    vec3 albedoSample,
    vec4 specularSample,
    vec3 normalSample,
    float heightSample,
    vec3 geometricNormal,
    int pbrMode
) {
    if (pbrMode == 0) {
        // LabPBR decoding (preferred)
        return decodeLabPBR(
            albedoSample,
            specularSample,
            normalSample,
            heightSample,
            geometricNormal
        );
    } else {
        // oldPBR decoding (legacy fallback)
        return decodeOldPBR(
            albedoSample,
            specularSample,
            normalSample,
            heightSample,
            geometricNormal
        );
    }
}

// ===================================================================
// MATERIAL PROPERTY UTILITIES
// ===================================================================

// Compute F0 from metallic + albedo
float computeF0(float metallic, vec3 albedo) {
    // For metals: F0 is approximated from albedo
    // For dielectrics: F0 ≈ 0.04 (typical)
    float dielectricF0 = DEFAULT_F0;
    float metalF0 = luminance(albedo);  // Simplified; can be more sophisticated
    return mix(dielectricF0, metalF0, metallic);
}

// Apply perceptual roughness remapping (Disney/Unreal convention)
// Perceptual roughness is squared for alpha in GGX distribution
float remapRoughness(float roughness) {
    roughness = clamp(roughness, 0.0, 1.0);
    return roughness * roughness;
}

// Clamp material properties to valid ranges
Material clampMaterial(Material mat) {
    mat.albedo = clamp(mat.albedo, 0.0, 1.0);
    mat.roughness = clamp(mat.roughness, 0.0, 1.0);
    mat.metallic = clamp(mat.metallic, 0.0, 1.0);
    mat.f0 = clamp(mat.f0, 0.0, 1.0);
    mat.emissive = clamp(mat.emissive, 0.0, 1.0);
    mat.height = clamp(mat.height, 0.0, 1.0);
    mat.normal = normalize(mat.normal);
    return mat;
}

// ===================================================================
// DEBUG UTILITIES
// ===================================================================

// Visualize material properties (for DEBUG_VIEW)
vec3 visualizeMaterialProperty(Material mat, int debugProperty) {
    switch (debugProperty) {
        case 1:  // Roughness
            return vec3(mat.roughness);
        case 2:  // Metallic
            return vec3(mat.metallic);
        case 3:  // F0 / Reflectance
            return vec3(mat.f0);
        case 4:  // Emissive
            return vec3(mat.emissive);
        case 5:  // Height
            return vec3(mat.height);
        case 6:  // Albedo
            return mat.albedo;
        case 7:  // Normal (as color: N*0.5+0.5)
            return mat.normal * 0.5 + 0.5;
        default:
            return mat.albedo;
    }
}

// ===================================================================
// END OF PBR MATERIAL MODULE
// ===================================================================

#endif // INCLUDE_PBR_MATERIAL
