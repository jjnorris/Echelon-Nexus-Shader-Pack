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
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

uniform sampler2D tex;
uniform sampler2D lightmap;

// NOTE: LabPBR samplers (normals, specular) not available in Phase 1
// Using basic material properties for now

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	// Sample base texture
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	// Discard fully transparent pixels (cutout blocks like leaves)
	if (diffuse.a < 0.5) {
		discard;
	}

	// Sample lightmap
	vec2 lightData = texture2D(lightmap, lightCoord).xy;
	float blockLight = lightData.x;
	float skyLight = lightData.y;

	// Phase 1: Use basic material properties
	// LabPBR support will be added in future phases

	vec3 worldNormal = normalize(normal);
	float smoothness = 0.5;
	float metallic = 0.0;
	float emissive = 0.0;
	float ambientOcclusion = 1.0;

	// ===== OUTPUT TO G-BUFFERS =====

	// gcolor (colortex0): Albedo + AO
	gl_FragData[0] = vec4(diffuse.rgb * ambientOcclusion, blockLight);

	// gdepth (colortex1): Linear depth
	float depth = length(viewPos) / 256.0;
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	// gnormal (colortex2): Normal + smoothness
	gl_FragData[2] = vec4(
		worldNormal * 0.5 + 0.5,
		smoothness
	);

	// gaux1 (colortex4): Material properties
	gl_FragData[4] = vec4(
		metallic,
		emissive,
		skyLight,
		1.0
	);

	gl_FragData[3] = vec4(0.0);
}
