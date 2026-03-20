// Echelon Nexus - Phase 1: Cloud rendering
// Based on Iris pipeline for Minecraft 1.21.11

// Global varyings - visible to both vertex and fragment stages
out vec4 tint;

/* RENDERTARGETS: 0 */

#ifdef VSH

void main() {
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}

#endif

#ifdef FSH

out vec4 fragColor;

void main() {
	fragColor = tint;
}

#endif
