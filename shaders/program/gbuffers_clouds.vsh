// ============================================================================
// GBUFFERS_CLOUDS IMPLEMENTATION
// Phase 1: Foundation - Cloud Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Render vanilla clouds with smoothing
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

varying vec4 vertexColor;
varying vec2 texCoord;

void main() {
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));
	vertexColor = vaColor;
	texCoord = vaUV0;
}
