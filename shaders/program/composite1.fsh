// ============================================================================
// COMPOSITE1 FRAGMENT SHADER - Phase 2: Post-Processing Effects
// ============================================================================
//
// References:
// - Complementary Shaders V4: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Post-processing effects layer (bloom, tone mapping, color grading)
// Input: colortex0 (scene color from composite pass)
// Output: Scene with post-processing applied

#include "/lib/math.glsl"

varying vec2 texCoord;

// Inputs from previous composite pass
uniform sampler2D colortex0;  // Scene color (composite output)
uniform sampler2D colortex1;  // Auxiliary data (if available)

// Scene state uniforms
uniform int isEyeInWater;
uniform float blindFactor;           // Blindness effect (0-1)
uniform float rainStrengthS;         // Rain intensity
uniform float screenBrightness;      // Screen brightness

// Screen properties
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;

// Lighting
uniform vec3 skyColor;

// Matrices for potential effects
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

void main() {
	// Sample scene color from previous composite pass
	vec3 color = texture2D(colortex0, texCoord).rgb;

	// PLACEHOLDER: Post-processing effects go here
	// Currently just passing through the composite result
	//
	// Potential effects:
	// - Bloom/glow (sample with larger kernel)
	// - Tone mapping (map HDR to LDR)
	// - Color grading (adjust color balance)
	// - Film grain / dithering
	// - Eye adaptation

	// Apply blindness/rain effects if needed
	if (blindFactor > 0.0) {
		color = mix(color, vec3(0.0), blindFactor);
	}

	// Output to screen
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color, 1.0);
}
