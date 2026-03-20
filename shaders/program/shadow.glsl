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

// ============================================================================
// VERTEX SHADER SECTION
// ============================================================================
#ifdef VSH

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;
in vec2 vaUV1;
in vec2 vaUV2;
in vec3 vaNormal;

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

#endif // VSH

// ============================================================================
// FRAGMENT SHADER SECTION
// ============================================================================
#ifdef FSH

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 color;

uniform sampler2D tex;
uniform sampler2D normals;

// Shadow output configuration
/* RENDERTARGETS:0,1 */

void main() {
	// Sample base color and alpha
	// Reference: Shadow Tutorial alpha discard logic
	vec4 diffuse = texture2D(tex, texCoord) * color;

	// Discard transparent pixels to prevent shadow casting
	// This creates proper shadows for alpha-tested blocks
	if (diffuse.a < 0.5) {
		discard;
	}

	// Output to shadowcolor0: color information for colored shadows
	// Output to shadowcolor1: optional secondary data
	// Reference: Complementary shadow coloring support

	vec4 shadowColor = vec4(diffuse.rgb, 1.0);

	// Apply foliage-specific adjustments
	// Leaves and similar blocks need special shadow handling
	#ifdef FOLIAGE_SHADOW_FIX
		// Slightly increase alpha to reduce gaps in foliage shadows
		shadowColor.a = mix(1.0, diffuse.a, 0.5);
	#endif

	// Write shadow color data
	// shadowcolor0 = primary shadow information
	// shadowcolor1 = secondary (can store additional material data)

	gl_FragData[0] = shadowColor;  // shadowcolor0
	gl_FragData[1] = vec4(0.0);    // shadowcolor1 (unused for Phase 1)

	// gl_FragDepth is handled automatically by OpenGL
	// Depth output to shadowtex0 and shadowtex1 is implicit
}

#endif // FSH
