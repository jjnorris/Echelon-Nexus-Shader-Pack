// Echelon Nexus - Phase 1: Basic rendering (sky color, debug lines)
// Fallback for programs without textures
// Based on Iris pipeline for Minecraft 1.21.11

/* RENDERTARGETS: 0 */

#ifdef VSH

out vec4 tint;

void main() {
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}

#endif

#ifdef FSH

in vec4 tint;

out vec4 fragColor;

void main() {
	fragColor = tint;
}

#endif
