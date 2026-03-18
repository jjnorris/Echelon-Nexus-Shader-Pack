// ===================================================================
// Echelon Nexus - Common Lighting Utilities & BRDF
// ===================================================================
// Provides Cook-Torrance GGX BRDF, light source definitions,
// and common lighting calculations for deferred passes.
// ===================================================================

#ifndef INCLUDE_LIGHTING_COMMON
#define INCLUDE_LIGHTING_COMMON

#include "constants.glsl"
#include "functions.glsl"
#include "pbr_material.glsl"

// ===================================================================
// LIGHT SOURCE STRUCTURE
// ===================================================================

struct Light {
    vec3 direction;     // Light direction (normalized, pointing toward light)
    vec3 radiance;      // Light color * intensity
    float shadowBias;   // Shadow map bias
};

// ===================================================================
// FRESNEL TERMS
// ===================================================================

// Schlick's Fresnel approximation
// F0: Reflectance at normal incidence
// cosTheta: Absolute dot product of view/light direction with half-vector
vec3 fresnelSchlick(vec3 f0, float cosTheta) {
    cosTheta = clamp(cosTheta, 0.0, 1.0);
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Schlick Fresnel with roughness modulation (reduces highlight roughness)
vec3 fresnelSchlickRough(vec3 f0, float cosTheta, float roughness) {
    vec3 f90 = mix(vec3(1.0), f0, roughness);
    return f0 + (f90 - f0) * pow(1.0 - cosTheta, 5.0);
}

// ===================================================================
// MICROFACET NORMAL DISTRIBUTION (GGX/Trowbridge-Reitz)
// ===================================================================

// GGX normal distribution function
// alpha: Roughness squared (Disney/Unreal convention)
// cosH: Dot product of normal with half-vector
float distributionGGX(float alpha, float cosH) {
    cosH = clamp(cosH, 0.0, 1.0);
    float alpha2 = alpha * alpha;
    float denom = cosH * cosH * (alpha2 - 1.0) + 1.0;
    return alpha2 / (PI * denom * denom);
}

// ===================================================================
// GEOMETRIC ATTENUATION (Visibility Term)
// ===================================================================

// Smith height-correlated G term (recommended)
// Uses heightcorrelation variant for better energy conservation
float geometrySmith(float alpha, float cosNL, float cosNV) {
    cosNL = clamp(cosNL, 0.0, 1.0);
    cosNV = clamp(cosNV, 0.0, 1.0);

    float alpha2 = alpha * alpha;

    float lambdaL = cosNL * sqrt(cosNV * cosNV * (1.0 - alpha2) + alpha2);
    float lambdaV = cosNV * sqrt(cosNL * cosNL * (1.0 - alpha2) + alpha2);

    return 0.5 / max(lambdaL + lambdaV, EPSILON);
}

// Simpler Schlick G (faster, less accurate)
float geometrySchlick(float alpha, float cosN) {
    float k = (alpha + 1.0) * (alpha + 1.0) / 8.0;  // Direct lighting variant
    return cosN / (cosN * (1.0 - k) + k + EPSILON);
}

// ===================================================================
// BRDF: COOK-TORRANCE GGX
// ===================================================================

// Cook-Torrance specular BRDF
// n: Surface normal
// v: View direction (from fragment toward camera)
// l: Light direction (from fragment toward light)
// f0: Reflectance at normal incidence
// alpha: Roughness squared
vec3 brdfCookTorrance(vec3 n, vec3 v, vec3 l, vec3 f0, float alpha) {
    // Half-vector
    vec3 h = safeNormalize(v + l);

    // Cosines
    float cosNL = dot(n, l);
    float cosNV = dot(n, v);
    float cosNH = dot(n, h);
    float cosVH = dot(v, h);

    // Skip backface
    if (cosNL <= 0.0 || cosNV <= 0.0) {
        return vec3(0.0);
    }

    // BRDF components
    vec3 f = fresnelSchlick(f0, cosVH);
    float d = distributionGGX(alpha, cosNH);
    float g = geometrySmith(alpha, cosNL, cosNV);

    // Specular contribution
    vec3 specular = (f * d * g) / (4.0 * cosNL * cosNV + EPSILON);

    // Diffuse contribution (Lambertian)
    // Albedo * (1 - F) / PI
    vec3 diffuse = (vec3(1.0) - f) * (1.0 / PI);

    return specular + diffuse;
}

// ===================================================================
// DIFFUSE BRDF
// ===================================================================

// Lambertian diffuse BRDF (constant)
vec3 brdfLambertian(vec3 albedo) {
    return albedo / PI;
}

// Oren-Nayar diffuse (roughness-aware diffuse, more realistic)
// Simplified version
vec3 brdfOrenNayar(vec3 albedo, float roughness, vec3 n, vec3 v, vec3 l) {
    vec3 h = safeNormalize(v + l);

    float cosNL = dot(n, l);
    float cosNV = dot(n, v);

    if (cosNL <= 0.0 || cosNV <= 0.0) {
        return vec3(0.0);
    }

    float roughnessSquared = roughness * roughness;
    float a = 1.0 - 0.5 * roughnessSquared / (roughnessSquared + 0.33);
    float b = 0.45 * roughnessSquared / (roughnessSquared + 0.09);

    float theta_i = acos(cosNV);
    float theta_r = acos(cosNL);

    float alpha = max(theta_i, theta_r);
    float beta = min(theta_i, theta_r);

    return (albedo / PI) * (a + b * cos(alpha - beta) * sin(alpha) * tan(beta));
}

// ===================================================================
// LIGHT SOURCES
// ===================================================================

// Sunlight (directional, time-of-day dependent)
Light computeSunlight(vec3 sunDirection, float skyBrightness) {
    Light light;
    light.direction = sunDirection;
    light.radiance = vec3(1.0, 0.95, 0.8) * skyBrightness * SUN_INTENSITY;
    light.shadowBias = SHADOW_BIAS;
    return light;
}

// Moonlight (directional, weaker than sun)
Light computeMoonlight(vec3 moonDirection, float skyBrightness) {
    Light light;
    light.direction = moonDirection;
    light.radiance = vec3(0.7, 0.8, 1.0) * (1.0 - skyBrightness) * MOON_INTENSITY;
    light.shadowBias = SHADOW_BIAS;
    return light;
}

// ===================================================================
// SHADOW SAMPLING
// ===================================================================

// Simple depth comparison for shadow detection
// shadowPos: Position in shadow texture space
// shadowDepth: Depth value from shadow map
// bias: Shadow bias to prevent acne
bool isInShadow(vec3 shadowPos, float shadowDepth, float bias) {
    // Basic early-out for out-of-bounds
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 ||
        shadowPos.y < 0.0 || shadowPos.y > 1.0 ||
        shadowPos.z < 0.0 || shadowPos.z > 1.0) {
        return false;  // Outside shadow map; assume lit
    }

    // Depth comparison
    return shadowPos.z > shadowDepth + bias;
}

// PCF (Percentage-Closer Filtering) shadow sampling
float shadowPCF(sampler2D shadowMap, vec3 shadowPos, float texelSize, int sampleCount) {
    float bias = SHADOW_BIAS;
    float shadow = 0.0;
    float baseline = texture(shadowMap, shadowPos.xy).r;

    for (int i = 0; i < sampleCount; i++) {
        for (int j = 0; j < sampleCount; j++) {
            vec2 offset = vec2(i, j) * texelSize;
            vec2 sampleCoord = shadowPos.xy + offset;

            float sampleDepth = texture(shadowMap, sampleCoord).r;
            shadow += isInShadow(vec3(sampleCoord, shadowPos.z), sampleDepth, bias) ? 1.0 : 0.0;
        }
    }

    return shadow / float(sampleCount * sampleCount);
}

// ===================================================================
// MATERIAL RESPONSE HELPERS
// ===================================================================

// Apply metallic workflow: interpolate between dielectric and metallic
vec3 applyMetallicWorkflow(vec3 albedo, float metallic, out vec3 f0) {
    // For metals: use albedo as reflance; for dielectrics use constant F0
    f0 = mix(vec3(DEFAULT_F0), albedo, metallic);

    // Darken albedo for metals (metals don't have diffuse)
    vec3 baseDiffuse = mix(albedo, vec3(0.0), metallic);

    return baseDiffuse;
}

// Apply roughness remapping (perceptual to alpha)
float applyRoughnessRemapping(float roughness) {
    return remapRoughness(roughness);
}

// ===================================================================
// EMISSIVE RESPONSE
// ===================================================================

// Apply emissive self-illumination
vec3 applyEmissive(vec3 baseColor, float emissiveStrength) {
    // Scale baseColor by emissive intensity
    return baseColor * emissiveStrength;
}

// ===================================================================
// AMBIENT / SKY CONTRIBUTION
// ===================================================================

// Simple ambient/sky contribution (flat; replace with IBL in Phase 12+)
vec3 computeAmbient(vec3 albedo, vec3 normal, vec3 skyColor) {
    // Diffuse ambient from sky
    float skyInfluence = mix(0.5, 1.0, normal.y * 0.5 + 0.5);  // Higher for upward-facing
    return albedo * skyColor * skyInfluence * 0.2;
}

// ===================================================================
// COMPLETE LIGHTING CALCULATION
// ===================================================================

// Compute direct lighting from a single light source
vec3 computeDirectLighting(
    Material material,
    Light light,
    vec3 viewDir,
    float shadowFactor
) {
    // BRDF evaluation
    vec3 brdf = brdfCookTorrance(
        material.normal,
        viewDir,
        light.direction,
        vec3(material.f0),
        applyRoughnessRemapping(material.roughness)
    );

    // Incoming light angle
    float cosNL = max(0.0, dot(material.normal, light.direction));

    // Final: BRDF * light * (1 - shadow)
    return brdf * light.radiance * cosNL * (1.0 - shadowFactor);
}

// ===================================================================
// END OF LIGHTING COMMON MODULE
// ===================================================================

#endif // INCLUDE_LIGHTING_COMMON
