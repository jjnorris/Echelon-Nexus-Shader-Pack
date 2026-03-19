#version 330 compatibility


uniform sampler2D tex;

in vec3 vNormal;
in vec2 vTexCoord;
in vec4 vColor;

layout(location = 0) out vec4 gbufferColor;

#include "lib/common.glsl"

void main() {
    vec4 texColor = texture(tex, vTexCoord);

    // Alpha test - hand textures are very specific about transparency
    if (texColor.a < 0.5) discard;

    // Hand color: texture * vertex color (vertex color may add tint)
    vec3 handColor = texColor.rgb * vColor.rgb;

    // Normalize normal
    vec3 normal = normalize(vNormal);
    vec2 encodedNormal = encodeNormal(normal);

    // Output: just the color
    // The hand texture should be peachy/skin-tone colored, NOT yellow
    gbufferColor = vec4(handColor, 1.0);
}
