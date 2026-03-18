// ===================================================================
// Echelon Nexus - Deferred Lighting Fragment Shader
// ===================================================================
// Purpose: Compute per-pixel lighting from G-buffers using Cook-Torrance BRDF
// Input:   colortex0 (albedo)
//          colortex1 (material: roughness, metallic, emissive)
//          colortex2 (normals + depth)
//          shadowtex0 (shadow map)
// Output:  colortex0 (lit color with full lighting)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/lighting_common.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0;

// ===================================================================
// LIGHTING COMPUTATION
// ===================================================================

void main() {
    // Step 1: Read G-buffers
    vec4 albedoSample = texture(colortex0, vTexCoord);
    vec4 materialSample = texture(colortex1, vTexCoord);
    vec4 normalSample = texture(colortex2, vTexCoord);

    // Early exit for transparent pixels
    if (albedoSample.a < 0.5) {
        discard;
    }

    // Step 2: Decode material from G-buffers
    vec3 albedo = albedoSample.rgb;
    float roughness = materialSample.r;
    float metallic = materialSample.g;
    float emissive = materialSample.b;

    // Decode normal
    vec2 encodedNormal = normalSample.xy;
    vec3 normal = decodeUnitVector(encodedNormal);

    // Compute F0 based on metallic workflow
    vec3 f0 = computeF0(metallic, albedo);

    // Apply roughness remapping (perceptual to alpha)
    float alpha = remapRoughness(roughness);

    // Step 3: Compute direct lighting
    // For now, simple ambient + sun
    // Full per-light calculation will come in Phase 6+

    vec3 viewDir = normalize(cameraPosition - vFragPos);  // Placeholder; will be fixed in Phase 4

    // Simple ambient occlusion and sky contribution
    vec3 ambient = albedo * 0.15;  // Flat ambient

    // Placeholder sun lighting
    Light sunlight;
    sunlight.direction = normalize(vec3(0.5, 0.8, 0.2));
    sunlight.radiance = vec3(1.0);

    // Direct lighting from sun (simplified; no shadow for now)
    vec3 direct = computeDirectLighting(
        Material(albedo, normal, roughness, metallic, emissive, f0, 0.0),
        sunlight,
        viewDir,
        0.0  // No shadow
    );

    // Step 4: Apply emissive
    vec3 emissiveLight = albedo * emissive * 2.0;

    // Step 5: Combine lighting
    vec3 finalColor = ambient + direct + emissiveLight;

    // Output lit color
    colortex0 = vec4(finalColor, albedoSample.a);
}
