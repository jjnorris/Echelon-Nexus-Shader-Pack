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
#include "lib/viewport.glsl"
#include "lib/shadow_sampling.glsl"

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
    float depth = normalSample.b;

    // Compute F0 based on metallic workflow
    vec3 f0 = computeF0(metallic, albedo);

    // Apply roughness remapping (perceptual to alpha)
    float alpha = remapRoughness(roughness);

    // Step 3: Reconstruct view-dependent data
    // Reconstruct view-space position from depth
    vec3 viewPos = reconstructViewPos(vTexCoord, depth, gbufferProjectionInverse);

    // Compute view direction (from fragment toward camera)
    // In view space, camera is at origin, so -viewPos is the view direction
    vec3 viewDir = normalize(-viewPos);

    // Ensure normal is front-facing relative to view
    normal = ensureFrontFacing(normal, viewDir);

    // Step 4: Compute direct lighting with shadows
    // Simple ambient + sun
    vec3 ambient = albedo * 0.15;  // Flat ambient (Phase 12: replace with IBL)

    // Sun lighting
    Light sunlight;
    sunlight.direction = normalize(vec3(0.5, 0.8, 0.2));
    sunlight.radiance = vec3(1.0);

    // Reconstruct world position for shadow computation
    vec3 worldPos = reconstructWorldPosFromScreen(
        vTexCoord,
        depth,
        gbufferProjectionInverse,
        gbufferModelViewInverse,
        cameraPosition
    );

    // Compute shadow factor (placeholder matrices; actual shadow projection in Phase 6)
    float shadowFactor = 0.0;  // No shadow for now (will enable in Phase 6)

    // Direct lighting from sun
    vec3 direct = computeDirectLighting(
        Material(albedo, normal, roughness, metallic, emissive, f0, 0.0),
        sunlight,
        viewDir,
        shadowFactor
    );

    // Step 5: Apply emissive
    vec3 emissiveLight = albedo * emissive * 2.0;

    // Step 6: Combine lighting
    vec3 finalColor = ambient + direct + emissiveLight;

    // Step 7: Clamp to valid range (prevent NaN propagation)
    finalColor = clamp(finalColor, 0.0, 100.0);

    // Output lit color
    colortex0 = vec4(finalColor, albedoSample.a);
}
