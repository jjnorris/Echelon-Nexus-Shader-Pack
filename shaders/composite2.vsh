#version 130

// COMPOSITE2 VERTEX SHADER - Phase 3: Quantum-Inspired Sampling
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/composite.vsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - OptiFine post-processing specification
// - Quantum computation concepts adapted to graphics
//
// Purpose: Full-screen quad for quantum-inspired temporal and adaptive sampling
// Combines temporal anti-aliasing with quantum superposition concepts

varying vec2 texCoord;

// Temporal jitter input (from Iris custom uniforms)
uniform int frameCounter;  // Current frame number for temporal coherence

void main() {
	// Simple full-screen quad vertex
	gl_Position = gl_Vertex;
	texCoord = gl_MultiTexCoord0.xy;
}
