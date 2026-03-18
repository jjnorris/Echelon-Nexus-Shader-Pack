// ===================================================================
// Echelon Nexus - Water Fragment Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/material_sampling.glsl"

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    // Water is always rendered (no alpha test)
    vec3 albedo = sampleAlbedo(vTexCoord);

    // Water material: smooth (roughness ≈ 0.0), non-metallic, non-emissive
    // Use a fixed material for water
    Material material;
    material.albedo = srgbToLinear(albedo);
    material.normal = normalize(vNormal);
    material.roughness = 0.0;      // Very smooth
    material.metallic = 0.0;       // Non-metallic
    material.emissive = 0.0;       // Non-emissive
    material.f0 = 0.04;            // Dielectric (water)
    material.height = 0.0;

    colortex0 = vec4(material.albedo, 0.5);  // Translucent alpha

    colortex1 = vec4(
        material.roughness,
        material.metallic,
        material.emissive,
        1.0
    );

    vec2 encodedNormal = encodeUnitVector(material.normal);
    float depthNormalized = clamp(gl_FragCoord.z / FAR_PLANE, 0.0, 1.0);

    colortex2 = vec4(
        encodedNormal.x,
        encodedNormal.y,
        depthNormalized,
        1.0
    );
}
