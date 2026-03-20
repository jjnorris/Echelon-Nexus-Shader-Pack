#version 400 compatibility

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;

in vec2 uv;

out vec4 fragColor;

void main() {
	fragColor = texture(colortex0, uv);
}
