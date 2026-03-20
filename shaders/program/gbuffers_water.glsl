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

#endif // FSH
