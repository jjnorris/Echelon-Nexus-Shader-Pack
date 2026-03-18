// ===================================================================
// Echelon Nexus - Deferred Lighting Fragment Shader
// ===================================================================
// Purpose: Compute per-pixel lighting from G-buffers
// Input:   colortex0 (albedo/unlit color)
//          colortex1 (material: roughness, metallic, emissive)
//          colortex2 (normals + depth)
//          shadowtex0 (shadow map)
// Output:  colortex0 (lit color with full lighting)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0;

void main() {
    // Read G-buffers
    vec4 colorSample = texture(colortex0, vTexCoord);
    vec4 materialSample = texture(colortex1, vTexCoord);
    vec4 normalSample = texture(colortex2, vTexCoord);

    // Decode normal
    vec2 encodedNormal = normalSample.xy;
    vec3 normal = decodeUnitVector(encodedNormal);

    // Extract material properties
    float roughness = materialSample.r;
    float metallic = materialSample.g;
    float emissive = materialSample.b;

    // For now, just output the albedo color
    // Full lighting implementation will be in Phase 5
    colortex0 = colorSample;
}
