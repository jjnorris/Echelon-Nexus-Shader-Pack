#version 130

// COMPOSITE1 VERTEX SHADER - Phase 2: PCSS Shadows
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/composite.vsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - OptiFine post-processing specification
//
// Purpose: Simple full-screen quad for PCSS shadow processing
// Applies advanced percentage-closer soft shadows to G-Buffer data

varying vec2 texCoord;

void main() {
	// Simple full-screen quad vertex
	// Maps screen coordinates directly
	gl_Position = gl_Vertex;

	// Texture coordinate from input (typically 0-1)
	texCoord = gl_MultiTexCoord0.xy;
}
