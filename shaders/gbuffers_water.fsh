#version 400 compatibility

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform sampler2D lightmap;

in vec2 uv;
in vec2 light_levels;
in vec4 tint;

out vec4 fragColor;

void main() {
	vec4 color = texture(gtexture, uv) * tint;
	color *= texture(lightmap, light_levels);
	fragColor = color;
}
