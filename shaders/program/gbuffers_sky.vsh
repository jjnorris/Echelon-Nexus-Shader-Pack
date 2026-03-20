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
