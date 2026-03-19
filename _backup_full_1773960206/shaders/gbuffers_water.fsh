// ===================================================================
// MINIMAL WATER G-BUFFER (Clean Foundation)
// ===================================================================

#version 330 compatibility
/* RENDERTARGETS: 4,5,6 */

uniform sampler2D tex;
uniform sampler2D specularTex;
uniform sampler2D lightmap;

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec3 albedo = vec3(0.1, 0.3, 0.5) * vColor.rgb;  // Blue water color
    vec3 normal = normalize(vNormal);

    // Water: very smooth, non-metallic
    float roughness = 0.1;   // Smooth
    float metallic = 0.0;
    float emissive = 0.0;

    vec2 encodedNormal = encodeUnitVector(normal);
    float depthNormalized = clamp(gl_FragCoord.z / FAR_PLANE, 0.0, 1.0);

    colortex0 = vec4(albedo, 0.5);  // Half transparent
    colortex1 = vec4(roughness, metallic, emissive, 1.0);
    colortex2 = vec4(encodedNormal, depthNormalized, 1.0);
}
