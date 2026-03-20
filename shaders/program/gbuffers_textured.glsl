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

// Texture samplers
uniform sampler2D tex;           // Block texture atlas
uniform sampler2D normals;       // Normal/specular map (LabPBR)
uniform sampler2D specular;      // PBR material properties
uniform sampler2D lightmap;      // Block + sky light

// G-Buffer render targets
/* RENDERTARGETS:0,1,2,3,4 */

// Reference: OptiFine shader specification for G-Buffer layout
// gcolor (colortex0) = albedo + AO
// gdepth (colortex1) = linear depth + 1 byte data
// gnormal (colortex2) = normal + smoothness
// composite (colortex3) = not used in Phase 1
// gaux1 (colortex4) = material properties + metallic

void main() {
	// Sample base color from texture
	// Reference: Shadow Tutorial basic sampling
	vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

	// Discard fully transparent pixels
	if (diffuse.a < 0.5) {
		discard;
	}

	// Sample lightmap (block light + sky light)
	// vaUV2 is pre-normalized (0-15 block, 0-15 sky)
	vec2 lightData = texture2D(lightmap, lightCoord).xy;
	float blockLight = lightData.x;
	float skyLight = lightData.y;

	// Sample normal map (LabPBR format)
	// Reference: LabPBR 1.3 specification
	// https://github.com/rre36/lab-pbr/wiki
	vec4 normalData = texture2D(normals, texCoord);

	// Decode LabPBR normal
	// Red, Green = normal XY (DirectX format)
	// Blue = AO
	// Alpha = height (for parallax, unused in Phase 1)
	vec3 decodedNormal = vec3(
		normalData.r * 2.0 - 1.0,
		normalData.g * 2.0 - 1.0,
		0.0
	);

	// Reconstruct Z from X and Y (since normalized: x² + y² + z² = 1)
	decodedNormal.z = sqrt(1.0 - dot(decodedNormal.xy, decodedNormal.xy));

	// Transform normal from tangent space to world space
	// For Phase 1, we'll use simplified approach (no tangent basis)
	// Reference: Complementary normal handling
	vec3 worldNormal = normalize(normal);  // Use interpolated normal for now

	// Sample PBR properties
	vec4 pbrData = texture2D(specular, texCoord);

	// Decode LabPBR specular
	// Red = smoothness (0-1, 0=rough, 1=mirror)
	// Green = F0 reflectance / metallic
	// Blue = porosity / SSS
	// Alpha = emissive (0-254, 255=skip)
	float smoothness = pbrData.r;
	float metallic = pbrData.g / 255.0;
	float emissive = pbrData.a / 255.0;

	// Convert smoothness to roughness
	float roughness = 1.0 - smoothness;

	// Ambient Occlusion from normal map blue channel
	float ambientOcclusion = normalData.b;

	// ===== OUTPUT TO G-BUFFERS =====

	// gcolor (colortex0): Albedo + AO
	gl_FragData[0] = vec4(diffuse.rgb * ambientOcclusion, blockLight);

	// gdepth (colortex1): Depth + flags
	// Store linear depth in red channel
	// Distance = length(viewPos)
	float depth = length(viewPos) / 256.0;  // Normalize to 0-1 for far plane
	gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

	// gnormal (colortex2): Normal + smoothness
	gl_FragData[2] = vec4(
		worldNormal * 0.5 + 0.5,  // Encode normal to 0-1 range
		smoothness                 // Store smoothness in alpha
	);

	// gaux1 (colortex4): Material properties
	// Red = metallic
	// Green = emissive
	// Blue = skyLight
	// Alpha = unused
	gl_FragData[4] = vec4(
		metallic,      // Metallic property
		emissive,      // Emissive/glow
		skyLight,      // Sky light level
		1.0
	);

	// colortex3 (composite) - unused in Phase 1
	gl_FragData[3] = vec4(0.0);
}

#endif // FSH
