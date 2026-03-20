// Echelon Nexus - Phase 1: Sky textured (sun, moon)
// Based on Iris pipeline for Minecraft 1.21.11

// Global uniforms (shared between stages)
uniform sampler2D gtexture;

/* RENDERTARGETS: 0 */

#ifdef VSH

out vec2 uv;
out vec4 tint;

void main() {
	uv = gl_MultiTexCoord0.xy;
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}

#endif

#ifdef FSH

in vec2 uv;
in vec4 tint;

out vec4 fragColor;

void main() {
	vec4 color = texture(gtexture, uv) * tint;
	if (color.a < 0.1) discard;
	fragColor = color;
}

#endif
