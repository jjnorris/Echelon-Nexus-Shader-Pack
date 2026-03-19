#version 330 compatibility


uniform sampler2D tex;

in vec3 vNormal;
in vec2 vTexCoord;
in vec4 vColor;

layout(location = 0) out vec4 gbufferColor;

void main() {
    vec4 texColor = texture(tex, vTexCoord);

    // Weather particles can be very transparent
    if (texColor.a < 0.05) discard;

    vec3 color = texColor.rgb * vColor.rgb;

    gbufferColor = vec4(color, texColor.a);
}
