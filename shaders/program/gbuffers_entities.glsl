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

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

void main() {
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
uniform sampler2D normals;
uniform sampler2D specular;
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

	// Sample materials (same as terrain)
	vec4 normalData = texture2D(normals, texCoord);
	vec4 pbrData = texture2D(specular, texCoord);

	float smoothness = pbrData.r;
	float metallic = pbrData.g / 255.0;
	float emissive = pbrData.a / 255.0;
	float ambientOcclusion = normalData.b;

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

#endif // FSH
