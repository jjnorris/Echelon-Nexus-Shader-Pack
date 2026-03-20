// ============================================================================
// GBUFFERS_WATER IMPLEMENTATION
// Phase 1: Foundation - Water Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Render water with wave animation, refraction, and reflection setup
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;
attribute vec2 vaUV1;
attribute vec2 vaUV2;
attribute vec3 vaNormal;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat3 normalMatrix;
uniform float frameTimeCounter;

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;
varying vec3 waveNormal;

// Simple wave animation
void main() {
	// Apply wave animation to water surface
	// Reference: Complementary water wave implementation
	vec3 pos = vaPosition;

	// Simple sine wave for water displacement
	float wave = sin(pos.x * 0.1 + frameTimeCounter * 0.5) * 0.1;
	wave += sin(pos.z * 0.15 + frameTimeCounter * 0.3) * 0.05;

	pos.y += wave;

	vec3 viewSpacePos = (gbufferModelView * vec4(pos, 1.0)).xyz;
	gl_Position = gbufferProjection * vec4(viewSpacePos, 1.0);

	texCoord = vaUV0;
	lightCoord = vaUV2 / 16.0;
	normal = normalize(normalMatrix * vaNormal);
	vertexColor = vaColor;
	viewPos = viewSpacePos;

	// Perturbed normal for water
	waveNormal = normal + vec3(sin(frameTimeCounter) * 0.1, 0.0, cos(frameTimeCounter) * 0.1);
}
