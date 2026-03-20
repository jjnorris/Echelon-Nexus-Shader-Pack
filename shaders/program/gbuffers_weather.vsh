// ============================================================================
// GBUFFERS_WEATHER IMPLEMENTATION
// Phase 1: Foundation - Rain/Snow Particles
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Render weather particles (rain, snow)
in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

varying vec4 vertexColor;
varying vec2 texCoord;

void main() {
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));
	vertexColor = vaColor;
	texCoord = vaUV0;
}
