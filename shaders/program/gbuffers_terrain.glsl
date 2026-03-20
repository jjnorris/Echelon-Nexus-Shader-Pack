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
	// Transform to view space then projection
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

	// Sample LabPBR materials
	// Reference: LabPBR 1.3 specification
	vec4 normalData = texture2D(normals, texCoord);
	vec4 pbrData = texture2D(specular, texCoord);

	// Decode LabPBR normal
	vec3 decodedNormal = vec3(
		normalData.r * 2.0 - 1.0,
		normalData.g * 2.0 - 1.0,
		0.0
	);
	decodedNormal.z = sqrt(max(0.0, 1.0 - dot(decodedNormal.xy, decodedNormal.xy)));
	vec3 worldNormal = normalize(normal);

	// Decode LabPBR specular
	float smoothness = pbrData.r;
	float metallic = pbrData.g / 255.0;
	float emissive = pbrData.a / 255.0;

	// AO from normal map blue channel
	float ambientOcclusion = normalData.b;

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

#endif // FSH
