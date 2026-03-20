// ============================================================================
// GBUFFERS_BASIC VERTEX SHADER
// Phase 1: Foundation - Simple Geometry Rendering
// ============================================================================
//
// References:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/gbuffers_basic.vsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Render simple geometry (sky, lines, beacon beams) without complex materials

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;
in vec2 vaUV1;
in vec2 vaUV2;
in vec3 vaNormal;

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
	// Standard vertex transformation
	// Reference: Shadow Tutorial basic vertex shader
	vec3 viewSpacePos = (gbufferModelView * vec4(vaPosition, 1.0)).xyz;
	gl_Position = gbufferProjection * vec4(viewSpacePos, 1.0);

	texCoord = vaUV0;
	lightCoord = vaUV2 / 16.0;
	normal = normalize(normalMatrix * vaNormal);
	vertexColor = vaColor;
	viewPos = viewSpacePos;
}
