// ============================================================================
// GBUFFERS_ENTITIES IMPLEMENTATION
// Phase 1: Foundation - Entity Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
//
// Purpose: Render mobs, armor stands, and other entities with full materials
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

uniform sampler2D tex;
uniform sampler2D lightmap;

// NOTE: LabPBR samplers not available in Phase 1

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	if (diffuse.a < 0.5) {
		discard;
	}

	vec2 lightData = texture2D(lightmap, lightCoord).xy;
	float blockLight = lightData.x;
	float skyLight = lightData.y;

	// Phase 1: Basic materials
	float smoothness = 0.5;
	float metallic = 0.0;
	float emissive = 0.0;
	float ambientOcclusion = 1.0;

	// ===== OUTPUT TO G-BUFFERS =====
	gl_FragData[0] = vec4(diffuse.rgb * ambientOcclusion, blockLight);

	float depth = length(viewPos) / 256.0;
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	gl_FragData[2] = vec4(
		normal * 0.5 + 0.5,
		smoothness
	);

	gl_FragData[4] = vec4(metallic, emissive, skyLight, 1.0);
	gl_FragData[3] = vec4(0.0);
}
