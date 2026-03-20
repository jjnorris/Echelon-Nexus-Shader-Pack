// ============================================================================
// COMPOSITE2 VERTEX SHADER - Phase 3: Temporal Anti-Aliasing
// ============================================================================
//
// Reference: Karis 2014, SIGGRAPH
// Purpose: Simple full-screen quad for TAA vertex stage

varying vec2 texCoord;

void main() {
	gl_Position = ftransform();
	texCoord = gl_MultiTexCoord0.xy;
}
