// ============================================================================
// SHADOW RENDERING IMPLEMENTATION
// Phase 1: Foundation - Core Shadow Mapping System
// ============================================================================
//
// References:
// - Shadow Tutorial (VERTEX): https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/shadow.vsh
// - Shadow Tutorial (FRAGMENT): https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/shadow.fsh
// - Complementary Shadow Code: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4/tree/main/shaders
// - OptiFine shaders.txt: https://raw.githubusercontent.com/sp614x/optifine/master/OptiFineDoc/doc/shaders.txt
//
// ============================================================================
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;
attribute vec2 vaUV1;
attribute vec2 vaUV2;
attribute vec3 vaNormal;

// Shadow rendering specific uniforms
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

// Pass to fragment shader
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 color;

// Include distortion calculations
#include "/lib/distort.glsl"

void main() {
	// Get world position from entity vertex
	// Reference: Complementary shadow.vsh vertex transformation
	vec3 worldPos = (gbufferModelViewInverse * vec4(vaPosition, 1.0)).xyz;

	// Transform world position to shadow space
	// Reference: Shadow Tutorial shadow space transformation
	vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));

	// Apply shadow distortion for better resolution utilization
	// Closer pixels get more resolution, distant pixels are compressed
	#ifdef SHADOW_DISTORT
		shadowPos.xy *= distort(shadowPos.xy);
	#endif

	gl_Position = shadowPos;

	// Pass coordinates and material properties to fragment shader
	texCoord = vaUV0;
	lightCoord = vaUV2;
	normal = vaNormal;
	color = vaColor;
}
