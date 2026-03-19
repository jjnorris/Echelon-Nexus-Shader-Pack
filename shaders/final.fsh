// ===================================================================
// MINIMAL FINAL PASS
// ===================================================================

#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;
    gl_FragColor = vec4(color, 1.0);
}
