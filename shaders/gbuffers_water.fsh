// ===================================================================
// Echelon Nexus - Water Fragment Shader
// ===================================================================

#version 330 compatibility

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
    vec4 albedoSample = texture(tex, vTexCoord);

    vec3 albedo = albedoSample.rgb;

    // Water: smooth, non-metallic
    colortex1 = vec4(0.0, 0.0, 0.0, 1.0);  // Very smooth (roughness = 0)

    vec3 normal = normalize(vNormal);
    vec2 encodedNormal = encodeUnitVector(normal);

    colortex2 = vec4(encodedNormal.x, encodedNormal.y, gl_FragCoord.z, 1.0);

    colortex0 = vec4(albedo, 0.5);  // Translucent
}
