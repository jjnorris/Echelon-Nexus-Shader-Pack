// ============================================================================
// GBUFFERS_BASIC IMPLEMENTATION
// Phase 1: Foundation - Simple Geometry Rendering
// ============================================================================
//
// References:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/gbuffers_basic.vsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Render simple geometry (sky, lines, beacon beams) without complex materials
// Faster than gbuffers_textured since no material encoding needed

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

#endif // VSH

// ============================================================================
// FRAGMENT SHADER SECTION
// ============================================================================
#ifdef FSH

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

uniform sampler2D tex;
uniform sampler2D lightmap;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	// Sample base color
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	// Discard transparent pixels
	if (diffuse.a < 0.5) {
		discard;
	}

	// Sample lightmap (no special material data for basic geometry)
	vec2 lightData = texture2D(lightmap, lightCoord).xy;
	float blockLight = lightData.x;
	float skyLight = lightData.y;

	// ===== OUTPUT TO G-BUFFERS =====

	// gcolor (colortex0): Simple color output
	// For basic geometry, use full color without material processing
	gl_FragData[0] = vec4(diffuse.rgb, blockLight);

	// gdepth (colortex1): Depth
	float depth = length(viewPos) / 256.0;
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	// gnormal (colortex2): Normal + flags
	// For basic geometry, use interpolated normal without material smoothness
	gl_FragData[2] = vec4(
		normal * 0.5 + 0.5,  // Encode normal
		0.5                   // Default smoothness (neutral)
	);

	// gaux1 (colortex4): No material data for basic
	gl_FragData[4] = vec4(
		0.0,       // No metallic
		0.0,       // No emissive
		skyLight,  // Sky light
		1.0
	);

	// colortex3 unused
	gl_FragData[3] = vec4(0.0);
}

#endif // FSH
