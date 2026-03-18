// ===================================================================
// Echelon Nexus - Terrain Fragment Shader (Solid & Cutout)
// ===================================================================
// Purpose: Capture terrain G-buffers (color, material, normals)
// Output:  colortex0 (lit color / albedo)
//          colortex1 (material: roughness, metallic, emissive)
//          colortex2 (normals + depth)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

// ===================================================================
// FRAGMENT INPUT
// ===================================================================

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;
in float vDepth;

// ===================================================================
// FRAGMENT OUTPUT
// ===================================================================

// G-buffer outputs
layout(location = 0) out vec4 colortex0;  // Lit color
layout(location = 1) out vec4 colortex1;  // Material params
layout(location = 2) out vec4 colortex2;  // Normals + depth

// ===================================================================
// MAIN FRAGMENT SHADER
// ===================================================================

void main() {
    // Sample albedo from block texture atlas
    vec4 albedoSample = texture(tex, vTexCoord);

    // Alpha test (discard transparent pixels)
    if (albedoSample.a < 0.5) {
        discard;
    }

    vec3 albedo = albedoSample.rgb;

    // Sample specular/PBR data (if available)
    // For baseline, we'll assume simple LabPBR format:
    // specularSample.rgb = normal map (in this simplified version, we'll use geometric normal)
    // specularSample.a = smoothness (or leave as default)
    vec4 specularSample = texture(specularTex, vTexCoord);

    // Default material: diffuse white (no specularity)
    float smoothness = 0.5;  // Medium roughness
    float metallic = 0.0;
    float emissive = 0.0;

    // Store in material buffer (colortex1)
    // R = roughness (inverted smoothness), G = metallic, B = emissive, A = ?
    colortex1 = vec4(
        1.0 - smoothness,  // R: roughness
        metallic,          // G: metallic
        emissive,          // B: emissive
        1.0                // A: reserved
    );

    // Store normals in colortex2
    // R, G = encoded normal (oct-wrap or other method)
    // B, A = depth encoding
    vec3 normal = normalize(vNormal);
    vec2 encodedNormal = encodeUnitVector(normal);

    // Encode depth in remaining channels
    float depthLinear = gl_FragCoord.z;  // Placeholder; should linearize properly
    colortex2 = vec4(
        encodedNormal.x,
        encodedNormal.y,
        depthLinear,  // Simplified depth
        1.0
    );

    // Output lit color (for now, just use albedo; deferred pass will add lighting)
    colortex0 = vec4(albedo, 1.0);
}

// ===================================================================
// END OF TERRAIN FRAGMENT SHADER
// ===================================================================
