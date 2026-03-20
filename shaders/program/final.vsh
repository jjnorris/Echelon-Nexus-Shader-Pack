// ============================================================================
// FINAL VERTEX SHADER
// Phase 1: Foundation - Tonemapping & Screen Output
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Simple full-screen quad for final post-processing
// Renders directly to screen after all deferred passes

varying vec2 texCoord;

void main() {
	gl_Position = gl_Vertex;
	texCoord = gl_MultiTexCoord0.xy;
}
