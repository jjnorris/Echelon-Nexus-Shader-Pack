// ============================================================================
// FINAL FRAGMENT SHADER - Phase 1
// ============================================================================
//
// Reference: Shadow Tutorial https://github.com/shaderLABS/Shadow-Tutorial
// Purpose: Output final frame to screen with basic gamma correction

varying vec2 texCoord;

// Composite output from previous pass
uniform sampler2D colortex0;

void main() {
	// Sample composited color
	vec3 color = texture2D(colortex0, texCoord).rgb;

	// ===== GAMMA CORRECTION =====
	// Convert from linear to sRGB for display
	color = pow(max(color, 0.0), vec3(1.0 / 2.2));

	// Clamp to valid output range
	color = clamp(color, 0.0, 1.0);

	// Output to screen
	gl_FragColor = vec4(color, 1.0);
}
