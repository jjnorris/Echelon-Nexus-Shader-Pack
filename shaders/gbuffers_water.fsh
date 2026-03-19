#version 330 compatibility
/* RENDERTARGETS: 0 */

uniform sampler2D tex;

in vec3 vNormal;
in vec2 vTexCoord;
in vec4 vColor;

layout(location = 0) out vec4 gbufferColor;

void main() {
    vec4 texColor = texture(tex, vTexCoord);

    // Water is less opaque
    if (texColor.a < 0.1) discard;

    vec3 color = texColor.rgb * vColor.rgb;

    gbufferColor = vec4(color, texColor.a);
}
