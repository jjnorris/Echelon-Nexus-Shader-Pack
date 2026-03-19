// ===================================================================
// Echelon Nexus - Material Texture Sampling & Fallback
// ===================================================================
// Handles safe texture sampling with graceful fallback when textures
// are missing or unavailable. Adapts to LabPBR vs oldPBR formats.
// ===================================================================

#ifndef INCLUDE_MATERIAL_SAMPLING
#define INCLUDE_MATERIAL_SAMPLING

#include "constants.glsl"
#include "functions.glsl"
#include "pbr_material.glsl"

// ===================================================================
// TEXTURE AVAILABILITY DETECTION
// ===================================================================

// Check if a texture sample indicates "missing" texture
// (e.g., flat magenta color #FF00FF or pure white as fallback)
bool isTextureAvailable(vec4 sample) {
    // A missing texture may be:
    // - Flat color (very low variance across samplers)
    // - The default missing texture color (varies by implementation)
    // For now, we'll assume all textures are available and check variance
    return true;
}

// ===================================================================
// ALBEDO/DIFFUSE SAMPLING
// ===================================================================

// Sample base color / albedo from primary texture atlas
vec3 sampleAlbedo(vec2 texCoord) {
    // Standard texture unit 1 (block atlas)
    return texture(tex, texCoord).rgb;
}

// Sample with optional blending (for layered materials in future)
vec3 sampleAlbedoBlended(vec2 texCoord, vec2 texCoord2, float blend) {
    vec3 color1 = sampleAlbedo(texCoord);
    vec3 color2 = sampleAlbedo(texCoord2);
    return mix(color1, color2, blend);
}

// ===================================================================
// SPECULAR/MATERIAL MAP SAMPLING
// ===================================================================

// Sample specular/PBR properties
// Format depends on texture pack format (LabPBR vs oldPBR)
vec4 sampleSpecular(vec2 texCoord) {
    // Specular maps are typically on texture unit 2 (mod-dependent)
    // If unavailable, return default
    vec4 specular = texture(specularTex, texCoord);

    // Validate sampling (check for errors or missing texture)
    if (isNaN(specular.r)) {
        specular = vec4(0.5, 0.04, 0.0, 1.0);  // Default: medium roughness, dielectric
    }

    return specular;
}

// Safe specular sampling with fallback
vec4 sampleSpecularSafe(vec2 texCoord) {
    vec4 sample = sampleSpecular(texCoord);

    // Clamp to valid ranges
    sample.r = clamp(sample.r, 0.0, 1.0);  // Smoothness/Roughness
    sample.g = clamp(sample.g, 0.0, 1.0);  // F0/Metallic
    sample.b = clamp(sample.b, 0.0, 1.0);  // Emissive
    sample.a = clamp(sample.a, 0.0, 1.0);  // Height/Flag

    return sample;
}

// ===================================================================
// NORMAL MAP SAMPLING
// ===================================================================

// Sample surface normal map
vec3 sampleNormalMap(vec2 texCoord) {
    // Standard normal map on unit 2 or bundled with specular
    // Expected format: RGB in [0,1] range (needs decoding to [-1,1])
    vec3 normalSample = texture(specularTex, texCoord).rgb;

    // Validate
    if (length(normalSample) < EPSILON) {
        return vec3(0.5, 0.5, 1.0);  // Default: Z-up normal (when encoded)
    }

    return normalSample;
}

// Sample with fallback to geometric normal
vec3 sampleNormalMapWithFallback(vec2 texCoord, vec3 geometricNormal) {
    vec3 normalMap = sampleNormalMap(texCoord);

    // If normal map is flat/missing, return geometric normal
    float variance = length(normalMap - vec3(0.5));
    if (variance < 0.1) {
        return geometricNormal;
    }

    return normalMap;
}

// ===================================================================
// HEIGHT/PARALLAX MAP SAMPLING
// ===================================================================

// Sample height map (for parallax displacement)
// Typically stored in specular.a or normal.a
float sampleHeight(vec2 texCoord) {
    vec4 specular = sampleSpecular(texCoord);
    return specular.a;
}

// Parallax mapping: adjust texture coordinates based on height + view angle
vec2 applyParallax(
    vec2 texCoord,
    vec3 viewDir,
    vec3 normal,
    float heightScale
) {
    // Simple parallax offset (not full parallax occlusion mapping)
    float height = sampleHeight(texCoord);
    vec3 viewDirTangent = normalize(viewDir - normal * dot(viewDir, normal));

    float parallaxHeight = height * heightScale - heightScale * 0.5;
    vec2 parallaxOffset = viewDirTangent.xy * parallaxHeight;

    return texCoord + parallaxOffset;
}

// ===================================================================
// ALPHA/TRANSPARENCY SAMPLING
// ===================================================================

// Sample transparency/opacity
float sampleAlpha(vec2 texCoord) {
    return texture(tex, texCoord).a;
}

// Alpha test threshold (for cutout materials)
bool alphaTest(vec2 texCoord, float threshold) {
    return sampleAlpha(texCoord) >= threshold;
}

// Dithered alpha test (for translucent blending; not yet implemented)
bool alphaTestDithered(vec2 texCoord, float threshold, vec2 screenCoord) {
    float alpha = sampleAlpha(texCoord);
    float dither = rand(screenCoord);
    return (alpha + dither) >= threshold;
}

// ===================================================================
// UNIFIED MATERIAL SAMPLING
// ===================================================================

// Complete material sampling pipeline
// Handles all texture fetching and fallback logic
Material sampleMaterialComplete(
    vec2 texCoord,
    vec3 geometricNormal,
    vec3 viewDir,
    int pbrMode,
    bool enableParallax
) {
    // Step 1: Sample base textures
    vec3 albedo = sampleAlbedo(texCoord);
    vec4 specular = sampleSpecularSafe(texCoord);
    vec3 normalMap = sampleNormalMapWithFallback(texCoord, geometricNormal);
    float height = sampleHeight(texCoord);

    // Step 2: Apply parallax if enabled and supported
    vec2 adjustedTexCoord = texCoord;
    if (enableParallax && height > 0.0) {
        adjustedTexCoord = applyParallax(texCoord, viewDir, geometricNormal, 0.05);
        // Re-sample with adjusted coordinates
        albedo = sampleAlbedo(adjustedTexCoord);
        specular = sampleSpecularSafe(adjustedTexCoord);
        normalMap = sampleNormalMapWithFallback(adjustedTexCoord, geometricNormal);
    }

    // Step 3: Decode material based on PBR format
    Material material = decodeMaterial(
        albedo,
        specular,
        normalMap,
        height,
        geometricNormal,
        pbrMode
    );

    // Step 4: Validate and clamp
    material = clampMaterial(material);

    return material;
}

// ===================================================================
// LIGHT MAP / BLOCK LIGHT SAMPLING
// ===================================================================

// Sample block light intensity from lightmap
float sampleBlockLight(vec2 texCoordLight) {
    // Lightmap coordinates provided by Minecraft
    // vaTexCoordLight provides lightmap UV
    return texture(lightmap, texCoordLight).r;
}

// Sample sky light intensity
float sampleSkyLight(vec2 texCoordLight) {
    return texture(lightmap, texCoordLight).g;
}

// Compute combined light intensity
float sampleCombinedLight(vec2 texCoordLight) {
    return max(sampleBlockLight(texCoordLight), sampleSkyLight(texCoordLight));
}

// ===================================================================
// AMBIENT OCCLUSION SAMPLING (Future)
// ===================================================================

// Sample ambient occlusion (if available in a custom texture)
float sampleAO(vec2 texCoord) {
    // Not yet implemented; reserved for Phase 10+
    return 1.0;
}

// ===================================================================
// VERTEX COLOR BLENDING
// ===================================================================

// Blend sampled material with vertex color
Material blendWithVertexColor(
    Material sampled,
    vec4 vertexColor
) {
    // Apply vertex color as tint to diffuse
    sampled.albedo *= vertexColor.rgb;

    // Vertex alpha can modulate emissive or transparency
    sampled.emissive *= vertexColor.a;

    return sampled;
}

// ===================================================================
// MATERIAL VALIDATION & SANITIZATION
// ===================================================================

// Ensure material properties are physically valid
Material sanitizeMaterial(Material mat) {
    // Clamp all properties to valid ranges
    mat.albedo = clamp(mat.albedo, 0.0, 1.0);
    mat.roughness = clamp(mat.roughness, 0.0, 1.0);
    mat.metallic = clamp(mat.metallic, 0.0, 1.0);
    mat.emissive = clamp(mat.emissive, 0.0, 1.0);
    mat.f0 = clamp(mat.f0, 0.0, 1.0);
    mat.height = clamp(mat.height, 0.0, 1.0);

    // Normalize normal
    mat.normal = normalize(mat.normal);

    // Prevent NaN
    if (isNaN(mat.albedo.r) || isNaN(mat.roughness)) {
        mat = decodeDefaultMaterial(vec3(0.5), mat.normal);
    }

    return mat;
}

// ===================================================================
// END OF MATERIAL SAMPLING MODULE
// ===================================================================

#endif // INCLUDE_MATERIAL_SAMPLING
