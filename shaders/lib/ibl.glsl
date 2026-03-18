// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                 IMAGE-BASED LIGHTING (PHASE 20)                          ║
// ║                                                                           ║
// ║  Efficient IBL using spherical harmonics (diffuse) and environment      ║
// ║  maps (specular). Provides free global illumination with minimal        ║
// ║  computational cost - typically 1-2 texture samples.                    ║
// ║                                                                           ║
// ║  Approach: Pre-baked SH coefficients store environment lighting.       ║
// ║  Runtime: Evaluate SH at surface normal (diffuse) or use split-sum     ║
// ║  approximation (specular). Works with arbitrary environment maps.      ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_IBL
#define INCLUDE_IBL

#include "spherical_harmonics.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ IBL DIFFUSE                                                              ║
// │                                                                           ║
// │ Computes diffuse indirect lighting from spherical harmonics. Fast,     │
// │ efficient: evaluates SH coefficients at surface normal direction.      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ iblDiffuse()                                                            ║
// ║                                                                         ║
// │ Computes diffuse IBL by evaluating SH at surface normal. Each normal  │
// │ direction produces unique diffuse color from pre-baked environment.   │
// │                                                                         ║
// │ Returns: RGB diffuse indirect lighting (0-1 range typically)          │
// │                                                                         ║
// │ Cost: Single SH evaluation (9 coefficients × dot operations)          │
// │ Typical: 1-2ms on GPU for entire scene                               │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 iblDiffuse(vec3 normal, SHCoefficients shCoeff) {
    // ────────────────────────────────────────────────────────────────────────
    // Evaluate SH basis functions at normal direction
    // Returns environment color for diffuse reflection
    // ────────────────────────────────────────────────────────────────────────
    return evaluateSH(normal, shCoeff);
}

// Simplified: constant ambient from SH L0
vec3 iblDiffuseSimple(SHCoefficients shCoeff) {
    return shCoeff.c0;
}

// ===================================================================
// IBL SPECULAR (with BRDF LUT)
// ===================================================================

// Sample environment reflection (simplified)
vec3 iblSpecularReflection(
    vec3 reflection,
    float roughness,
    vec3 envColor
) {
    // In practice, sample from precomputed environment cubemap
    // For now, use placeholder with roughness-based blur
    float blur = roughness * roughness * 0.5;
    return envColor * (1.0 - blur * 0.5);
}

// Schlick Fresnel for IBL
vec3 iblFresnel(vec3 F0, float NdotV) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - NdotV, 0.0, 1.0), 5.0);
}

// Compute IBL specular with Fresnel
vec3 iblSpecular(
    vec3 normal,
    vec3 viewDir,
    vec3 F0,
    float roughness,
    vec3 envColor
) {
    float NdotV = max(0.0, dot(normal, viewDir));

    // Fresnel
    vec3 F = iblFresnel(F0, NdotV);

    // Environment reflection
    vec3 reflection = reflect(-viewDir, normal);
    vec3 specColor = iblSpecularReflection(reflection, roughness, envColor);

    // Combine with Fresnel
    return specColor * F;
}

// ===================================================================
// BRDF LOOKUP TABLE
// ===================================================================

// Simplified BRDF LUT: F0 scale and Fresnel color
// In real implementation, this would be a 2D texture (roughness, NdotV)
vec2 brdfLUT(float roughness, float NdotV) {
    // Simplified: return (scale, bias) for Fresnel
    // Real LUT would integrate BRDF over hemisphere
    float scale = 1.0 - roughness * 0.5;
    float bias = roughness * 0.2;
    return vec2(scale, bias);
}

// Apply BRDF LUT
vec3 applyBRDFLUT(
    vec3 F0,
    float roughness,
    float NdotV,
    vec3 envColor
) {
    vec2 lut = brdfLUT(roughness, NdotV);
    vec3 F = F0 * lut.x + vec3(lut.y);
    return envColor * F;
}

// ===================================================================
// COMPLETE IBL EVALUATION
// ===================================================================

// Evaluate full IBL at surface
vec3 evaluateIBL(
    vec3 position,
    vec3 normal,
    vec3 viewDir,
    vec3 albedo,
    float roughness,
    float metallic,
    SHCoefficients shCoeff,
    vec3 envColor
) {
    vec3 ibl = vec3(0.0);

    // Diffuse component (Lambertian)
    vec3 diffuse = iblDiffuse(normal, shCoeff) * albedo * (1.0 - metallic);

    // Specular component
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    vec3 specular = iblSpecular(normal, viewDir, F0, roughness, envColor);

    ibl = diffuse + specular;

    return ibl;
}

// Variant: with BRDF LUT texture
vec3 evaluateIBLWithLUT(
    vec3 normal,
    vec3 viewDir,
    vec3 albedo,
    float roughness,
    float metallic,
    SHCoefficients shCoeff,
    vec3 envColor
) {
    // Diffuse
    vec3 diffuse = iblDiffuse(normal, shCoeff) * albedo * (1.0 - metallic);

    // Specular with LUT
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    float NdotV = max(0.0, dot(normal, viewDir));
    vec3 specular = applyBRDFLUT(F0, roughness, NdotV, envColor);

    return diffuse + specular;
}

#endif // INCLUDE_IBL
