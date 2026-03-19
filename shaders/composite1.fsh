// ===================================================================
// MINIMAL COMPOSITE1 PASS (Pass-through)
// ===================================================================

#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

void main() {
    colortex0_out = texture(colortex0, vTexCoord);
}
