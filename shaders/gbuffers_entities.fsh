// ===================================================================
// Echelon Nexus - Entities Fragment Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;
in float vDepth;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec4 albedoSample = texture(tex, vTexCoord);

    if (albedoSample.a < 0.5) {
        discard;
    }

    vec3 albedo = albedoSample.rgb;

    colortex1 = vec4(
        1.0 - 0.5,  // Roughness
        0.0,        // Metallic
        0.0,        // Emissive
        1.0
    );

    vec3 normal = normalize(vNormal);
    vec2 encodedNormal = encodeUnitVector(normal);

    colortex2 = vec4(
        encodedNormal.x,
        encodedNormal.y,
        gl_FragCoord.z,
        1.0
    );

    colortex0 = vec4(albedo, 1.0);
}
