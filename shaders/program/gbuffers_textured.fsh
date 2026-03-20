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
varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

// Texture samplers
uniform sampler2D tex;           // Block texture atlas
uniform sampler2D lightmap;      // Block + sky light

// NOTE: Custom LabPBR samplers (normals, specular) not available in base Minecraft
// Phase 1 uses basic materials without LabPBR support
// LabPBR support to be added in future phases with resource pack integration

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

	// Phase 1: Use basic material properties (no LabPBR)
	// LabPBR support will be added in future phases with proper resource pack integration

	vec3 worldNormal = normalize(normal);
	float smoothness = 0.5;        // Default: medium smoothness
	float metallic = 0.0;          // Default: not metallic
	float emissive = 0.0;          // Default: not self-emissive
	float ambientOcclusion = 1.0;  // Default: no ambient occlusion

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
