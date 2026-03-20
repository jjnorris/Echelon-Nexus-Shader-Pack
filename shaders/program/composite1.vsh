// ============================================================================
// COMPOSITE1 VERTEX SHADER - Phase 2: Post-Processing Effects
// ============================================================================
//
// Reference: Complementary Shaders V4, Photon Shaders
// Purpose: Simple full-screen quad for post-processing pass

varying vec2 texCoord;

void main() {
	gl_Position = ftransform();
	texCoord = gl_MultiTexCoord0.xy;
}
