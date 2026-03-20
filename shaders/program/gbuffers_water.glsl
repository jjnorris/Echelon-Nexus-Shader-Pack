// Echelon Nexus - Phase 1: Translucent rendering (water, stained glass, ice)
// Based on Iris pipeline for Minecraft 1.21.11

#ifdef VSH

out vec2 uv;
out vec2 light_levels;
out vec4 tint;

void main() {
	uv = gl_MultiTexCoord0.xy;
	light_levels = gl_MultiTexCoord1.xy / 240.0;
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}

#endif

#ifdef FSH

in vec2 uv;
in vec2 light_levels;
in vec4 tint;

uniform sampler2D gtexture;
uniform sampler2D lightmap;

/* RENDERTARGETS: 0 */

out vec4 fragColor;

void main() {
	vec4 color = texture(gtexture, uv) * tint;
	color *= texture(lightmap, light_levels);
	fragColor = color;
}

#endif
