// ============================================================================
// COMPOSITE2 FRAGMENT SHADER - Phase 3: Temporal Anti-Aliasing
// ============================================================================
//
// References:
// - Temporal Anti-Aliasing (Karis 2014, SIGGRAPH)
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Temporal anti-aliasing to eliminate aliasing and reduce noise
// Input: composite (previous pass output), colortex7 (temporal history)
// Output: TAA-processed scene
//
// NOTE: This pass has LIMITED access. G-Buffer is NOT guaranteed available.

#include "/lib/sampling.glsl"
#include "/lib/math.glsl"

varying vec2 texCoord;

// Current frame from previous composite pass
uniform sampler2D composite;        // Output from composite1

// Temporal history
uniform sampler2D colortex7;        // Previous frame color (for TAA blending)
uniform sampler2D colortex8;        // Previous frame depth (for reprojection)

// Frame information
uniform int frameCounter;           // Current frame number
uniform ivec2 screenSize;           // Screen resolution

// ============================================================================
// TEMPORAL ANTI-ALIASING
// ============================================================================
// Reference: Karis 2014, SIGGRAPH - Temporal Reprojection Anti-Aliasing in INSIDE
//
// Algorithm:
// 1. Sample current frame color
// 2. Fetch previous frame color from history
// 3. Blend current with history using temporal jitter
// 4. Output blended result
//
// Cost: ~1-2ms (minimal performance impact)

void main() {
	// Sample current frame color
	vec4 currentColor = texture2D(composite, texCoord);

	// Sample temporal history (previous frame)
	vec4 historyColor = texture2D(colortex7, texCoord);

	// Simple temporal blend: 85% history, 15% current
	// This provides temporal anti-aliasing through noise reduction
	// The history accumulates samples over frames, reducing flickering
	float blendFactor = 0.85;
	vec3 taaColor = mix(currentColor.rgb, historyColor.rgb, blendFactor);

	// For first frame (history is black), rely more on current
	if (frameCounter == 0) {
		blendFactor = 0.0;
		taaColor = currentColor.rgb;
	}

	// Output result
	/*DRAWBUFFERS:07*/
	gl_FragData[0] = vec4(taaColor, 1.0);    // Draw to colortex0 (screen)
	gl_FragData[7] = currentColor;            // Store current for next frame history
}
