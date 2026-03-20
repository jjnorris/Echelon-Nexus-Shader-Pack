// ============================================================================
// COMPOSITE1 SHADER - Phase 2: PCSS Implementation (Simplified)
// Percentage-Closer Soft Shadows with Blocker Search & Penumbra Estimation
// ============================================================================
//
// NOTE: This is a simplified version that passes through the composite
// result for now. Full PCSS implementation may require reworking to match
// what textures/uniforms are available in the composite1 pass.
//
// References:
// - PCSS Algorithm: Percentage-Closer Soft Shadows (2006)
// - Iris/OptiFine composite pass specification

#ifndef INCLUDED_COMPOSITE1
#define INCLUDED_COMPOSITE1

#include "/lib/sampling.glsl"
#include "/lib/math.glsl"

#ifdef FSH

varying vec2 texCoord;

// Current composite result from Phase 1
uniform sampler2D composite;

void main() {
	// For now, simply pass through the composite result
	// Future: Implement PCSS here when we verify texture availability
	vec4 color = texture2D(composite, texCoord);
	gl_FragColor = color;
}

#endif // FSH

#endif // INCLUDED_COMPOSITE1
