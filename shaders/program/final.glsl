// ============================================================================
// FINAL SHADER IMPLEMENTATION
// Phase 1: Foundation - Tonemapping & Screen Output
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Apply tonemapping, color grading, and output final frame to screen
// This is the last shader that runs before displaying the rendered frame

// ============================================================================
// FRAGMENT SHADER SECTION
// ============================================================================
#ifdef FSH

varying vec2 texCoord;

// Final composite texture from all previous passes
uniform sampler2D gcolor;

void main() {
	// Sample final composited color
	vec3 color = texture2D(gcolor, texCoord).rgb;

	// ===== TONEMAPPING =====
	// Apply simple tonemapping to compress HDR to LDR
	// Reference: Complementary tonemapping approach

	// Filmic tonemapping (Uncharted 2)
	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.02;
	const float F = 0.30;
	const float W = 11.2;

	color = ((color * (A * color + C * B) + D * E) /
	         (color * (A * color + B) + D * F)) - E / F;

	// White point adjustment
	float whiteScale = ((W * (A * W + C * B) + D * E) /
	                     (W * (A * W + B) + D * F)) - E / F;
	color /= whiteScale;

	// ===== GAMMA CORRECTION =====
	// Convert from linear to sRGB for display
	// Reference: Standard gamma correction (2.2)

	color = pow(max(color, 0.0), vec3(1.0 / 2.2));

	// ===== COLOR GRADING =====
	// Simple brightness and contrast adjustment
	float brightness = 1.0;
	float contrast = 1.0;

	color = (color - 0.5) * contrast + 0.5;
	color *= brightness;

	// Clamp to valid output range
	color = clamp(color, 0.0, 1.0);

	// ===== OUTPUT TO SCREEN =====
	gl_FragColor = vec4(color, 1.0);
}

#endif // FSH
