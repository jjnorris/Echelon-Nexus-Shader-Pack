// Echelon Nexus - Phase 1: Composite pass
// Simple pass-through for Phase 1
// Based on Iris pipeline for Minecraft 1.21.11

// Global uniforms (shared between stages)
uniform sampler2D colortex0;

/* RENDERTARGETS: 0 */

#ifdef VSH

out vec2 uv;

void main() {
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
	uv = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH

in vec2 uv;

out vec4 fragColor;

void main() {
	fragColor = texture(colortex0, uv);
}

#endif
