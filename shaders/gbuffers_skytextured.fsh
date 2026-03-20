#version 400 compatibility

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;

in vec2 uv;
in vec4 tint;

out vec4 fragColor;

void main() {
	vec4 color = texture(gtexture, uv) * tint;
	if (color.a < 0.1) discard;
	fragColor = color;
}
