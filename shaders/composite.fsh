// ===================================================================
// ULTRA-MINIMAL COMPOSITE
// ===================================================================

#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;
    colortex0_out = vec4(color, 1.0);
}
