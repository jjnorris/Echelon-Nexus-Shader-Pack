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
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;
varying vec3 waveNormal;

uniform sampler2D tex;
uniform sampler2D lightmap;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	if (diffuse.a < 0.5) {
		discard;
	}

	vec2 lightData = texture2D(lightmap, lightCoord).xy;
	float blockLight = lightData.x;
	float skyLight = lightData.y;

	// ===== OUTPUT TO G-BUFFERS =====
	// Water is treated as smooth, non-metallic surface

	gl_FragData[0] = vec4(diffuse.rgb, blockLight);

	float depth = length(viewPos) / 256.0;
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	// Water: highly smooth, non-metallic
	gl_FragData[2] = vec4(
		normal * 0.5 + 0.5,
		1.0  // High smoothness for water
	);

	gl_FragData[4] = vec4(0.0, 0.0, skyLight, 1.0);
	gl_FragData[3] = vec4(0.0);
}
