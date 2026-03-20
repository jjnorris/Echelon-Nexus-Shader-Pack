// ============================================================================
// FINAL FRAGMENT SHADER - Phase 1
// ============================================================================
//
// Reference: Shadow Tutorial https://github.com/shaderLABS/Shadow-Tutorial
// Purpose: Output final frame to screen with basic gamma correction

varying vec2 texCoord;

void main() {
	// For now, just output magenta to verify this pass runs
	// If you see magenta on screen, the pipeline is working
	gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
}
