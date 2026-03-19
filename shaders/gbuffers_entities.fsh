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

    if (texColor.a < 0.5) discard;

    vec3 color = texColor.rgb * vColor.rgb;
    vec3 normal = normalize(vNormal);

    gbufferColor = vec4(color, 1.0);
}
