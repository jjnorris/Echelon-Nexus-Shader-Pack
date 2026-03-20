// ============================================================================
// GBUFFERS_SKY IMPLEMENTATION
// Phase 1: Foundation - Sky Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Render sky dome with gradient coloring

// ============================================================================
// VERTEX SHADER SECTION
// ============================================================================
#ifdef VSH

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

varying vec4 vertexColor;
varying vec3 viewDir;

void main() {
	// Sky doesn't use normal projection - renders at far plane
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));

	vertexColor = vaColor;
	viewDir = normalize(vaPosition);
}

#endif // VSH

// ============================================================================
// FRAGMENT SHADER SECTION
// ============================================================================
#ifdef FSH

varying vec4 vertexColor;
varying vec3 viewDir;

uniform vec3 sunPosition;
uniform vec3 skyColor;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	// Simple sky gradient
	vec3 finalColor = vertexColor.rgb;

	// Sun position glow
	float sunGlow = max(0.0, dot(normalize(viewDir), sunPosition)) * 0.5;
	finalColor += vec3(1.0, 0.9, 0.7) * sunGlow;

	// ===== OUTPUT TO G-BUFFERS =====

	// Sky gets maximum light values
	gl_FragData[0] = vec4(finalColor, 1.0);  // Max brightness

	// Infinite depth (far plane)
	gl_FragData[1] = vec4(1.0, 0.0, 0.0, 1.0);

	// Sky normal (up)
	gl_FragData[2] = vec4(0.5, 1.0, 0.5, 1.0);  // (0, 1, 0) encoded

	gl_FragData[4] = vec4(0.0, 0.0, 1.0, 1.0);  // Max sky light
	gl_FragData[3] = vec4(0.0);
}

#endif // FSH
