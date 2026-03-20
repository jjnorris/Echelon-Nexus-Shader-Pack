#version 130

// COMPOSITE VERTEX SHADER - Phase 1 Foundation
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/composite.vsh
// - OptiFine post-processing specification
//
// Purpose: Simple full-screen quad for post-processing passes
// Applies shadows and lighting to G-Buffer data

varying vec2 texCoord;

void main() {
	// Simple full-screen quad vertex
	// Maps screen coordinates directly
	gl_Position = gl_Vertex;

	// Texture coordinate from input (typically 0-1)
	texCoord = gl_MultiTexCoord0.xy;
}
