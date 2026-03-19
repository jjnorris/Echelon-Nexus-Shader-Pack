#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

void main() {
    gl_FragColor = texture(colortex0, vTexCoord);
}
