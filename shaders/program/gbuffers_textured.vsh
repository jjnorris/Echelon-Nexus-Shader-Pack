// ============================================================================
// GBUFFERS_TEXTURED IMPLEMENTATION
// Phase 1: Foundation - Textured Geometry Rendering
// ============================================================================
//
// References:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/gbuffers_textured.vsh
// - Complementary implementation
//
// Purpose: Render textured blocks/entities with material properties
// Outputs to G-Buffer for deferred rendering
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;
attribute vec2 vaUV1;
attribute vec2 vaUV2;
attribute vec3 vaNormal;

// Standard uniforms for vertex transformation
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat3 normalMatrix;

// Time-based uniforms for vertex animation
uniform float frameTimeCounter;

// Pass to fragment shader
varying vec2 texCoord;           // Texture coordinates
varying vec2 lightCoord;          // Lightmap coordinates (block + sky light)
varying vec3 normal;              // Surface normal (world-space)
varying vec4 vertexColor;         // Vertex color (for tinting)
varying vec3 viewPos;             // Position in view space

void main() {
	// Transform vertex position to view space, then projection space
	// Reference: Shadow Tutorial - standard vertex transformation
	vec3 viewSpacePos = (gbufferModelView * vec4(vaPosition, 1.0)).xyz;
	gl_Position = gbufferProjection * vec4(viewSpacePos, 1.0);

	// Pass texture coordinates to fragment shader
	texCoord = vaUV0;

	// Lightmap coordinates (encoded as block light + sky light)
	// vaUV2 contains (blockLightLevel, skyLightLevel) in 0-15 range
	lightCoord = vaUV2 / 16.0;  // Normalize to 0-1 range

	// Transform normal to world space using normal matrix
	// Reference: Complementary - proper normal transformation
	normal = normalize(normalMatrix * vaNormal);

	// Pass through vertex color
	vertexColor = vaColor;

	// Store view space position for depth-based effects
	viewPos = viewSpacePos;
}
