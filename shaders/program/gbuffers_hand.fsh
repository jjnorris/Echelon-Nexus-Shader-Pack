// ============================================================================
// GBUFFERS_HAND IMPLEMENTATION
// Phase 1: Foundation - First-Person Hand Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
//
// Purpose: Render first-person hand with items
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

uniform sampler2D tex;
uniform sampler2D lightmap;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	if (diffuse.a < 0.5) {
		discard;
	}

	// Hand gets special lighting (always well-lit)
	float blockLight = 1.0;  // Force full hand light
	float skyLight = 1.0;

	// ===== OUTPUT TO G-BUFFERS =====
	gl_FragData[0] = vec4(diffuse.rgb, blockLight);

	float depth = length(viewPos) / 256.0;
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	gl_FragData[2] = vec4(
		normal * 0.5 + 0.5,
		0.5  // Medium smoothness for hand
	);

	gl_FragData[4] = vec4(0.0, 0.0, skyLight, 1.0);
	gl_FragData[3] = vec4(0.0);
}
