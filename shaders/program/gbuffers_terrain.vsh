// ============================================================================
// GBUFFERS_TERRAIN IMPLEMENTATION
// Phase 1: Foundation - Terrain Block Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
//
// Purpose: Render terrain blocks with full LabPBR material support
// Handles solid terrain, cutout blocks (grass), and material properties
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;
attribute vec2 vaUV1;
attribute vec2 vaUV2;
attribute vec3 vaNormal;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat3 normalMatrix;

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

void main() {
	// Transform to view space then projection
	vec3 viewSpacePos = (gbufferModelView * vec4(vaPosition, 1.0)).xyz;
	gl_Position = gbufferProjection * vec4(viewSpacePos, 1.0);

	texCoord = vaUV0;
	lightCoord = vaUV2 / 16.0;
	normal = normalize(normalMatrix * vaNormal);
	vertexColor = vaColor;
	viewPos = viewSpacePos;
}
