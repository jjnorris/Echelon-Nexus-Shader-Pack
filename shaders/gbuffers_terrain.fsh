#version 330 compatibility
/* RENDERTARGETS: 0 */

uniform sampler2D tex;

in vec3 vNormal;
in vec2 vTexCoord;
in vec4 vColor;

layout(location = 0) out vec4 gbufferColor;

#include "lib/common.glsl"

void main() {
    vec4 texColor = texture(tex, vTexCoord);

    // Alpha test
    if (texColor.a < 0.5) discard;

    // Simple: albedo * vertex color
    vec3 albedo = texColor.rgb * vColor.rgb;

    // Encode normal
    vec3 normal = normalize(vNormal);
    vec2 encodedNormal = encodeNormal(normal);

    // Packed format: RGB=color, A=normal.x encoded
    // This is temporary - we'll refine the format
    gbufferColor = vec4(albedo, 1.0);
}
