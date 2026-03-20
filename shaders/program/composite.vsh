// ============================================================================
// COMPOSITE VERTEX SHADER
// Phase 1 Foundation - Shadow Application & Basic Lighting
// ============================================================================
//
// References:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - OptiFine Documentation: https://raw.githubusercontent.com/sp614x/optifine/master/OptiFineDoc/doc/shaders.txt
//
// Purpose: Apply shadows and basic lighting to deferred G-Buffer
// Simple full-screen quad for post-processing passes

varying vec2 texCoord;

void main() {
	// Simple full-screen quad vertex
	// Maps screen coordinates directly
	gl_Position = gl_Vertex;

	// Texture coordinate from input (typically 0-1)
	texCoord = gl_MultiTexCoord0.xy;
}
