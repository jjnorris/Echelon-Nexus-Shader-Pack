// ===================================================================
// Echelon Nexus - Weather (Rain/Snow) Fragment Shader
// ===================================================================

#version 330 compatibility
/* RENDERTARGETS: 4,5,6 */

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS (for material_sampling.glsl functions)                    ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D tex;           // Particle texture (for sampleAlbedo, sampleAlpha)
uniform sampler2D specularTex;   // Specular/roughness texture (for future material sampling)
uniform sampler2D lightmap;      // Lightmap texture (for sampleBlockLight, sampleSkyLight)

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
    if (!alphaTest(vTexCoord, 0.1)) {
        discard;
}

    Material material = sampleMaterialComplete(
        vTexCoord,
        normalize(vNormal),
        vec3(0.0),
        0,      // LabPBR
        false   // No parallax
    );

    material = blendWithVertexColor(material, vColor);

    colortex0 = vec4(material.albedo, 1.0);

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
