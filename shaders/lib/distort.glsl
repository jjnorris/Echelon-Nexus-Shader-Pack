// ============================================================================
// SHADOW DISTORTION LIBRARY
// Phase 1: Foundation - Shadow Map Optimization
// ============================================================================
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/distort.glsl
// - Complementary Shaders shadow distortion
//
// Purpose: Apply perspective distortion to shadow maps to improve resolution
// utilization. Distant objects are compressed, nearby objects get more detail.

#ifndef INCLUDED_DISTORT
#define INCLUDED_DISTORT

// Distortion function for shadow map coordinates
// Makes nearby shadows higher quality, distant shadows lower quality
// This is more efficient than increasing shadow map resolution everywhere

vec2 distort(vec2 coord) {
	// Reference: Shadow Tutorial distortion implementation
	// Compresses outer regions, expands inner regions

	// Calculate distance from shadow map center
	float dist = length(coord * 2.0 - 1.0);  // 0 at center, ~1.414 at corners

	// Apply distortion curve: compress edges, expand center
	// Using quadratic curve for smooth transition
	float distortion = dist * dist;

	// Normalize back to [-1, 1] range
	return normalize(coord * 2.0 - 1.0) *
	       mix(1.0, distortion * 0.5, 0.5) * 0.5 + 0.5;
}

// Alternative: Polynomial distortion (sharper quality gradient)
vec2 distortPolynomial(vec2 coord) {
	vec2 offset = coord * 2.0 - 1.0;
	float dist = length(offset);
	float distortion = dist * dist * dist;  // Cubic for sharper gradient

	return normalize(offset) * distortion * 0.5 + 0.5;
}

#endif
