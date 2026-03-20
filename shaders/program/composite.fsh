// ============================================================================
// COMPOSITE FRAGMENT SHADER - Phase 1
// ============================================================================
//
// Reference: Shadow Tutorial https://github.com/shaderLABS/Shadow-Tutorial
// Purpose: Pass-through composite - output G-Buffer albedo with basic lighting

varying vec2 texCoord;

uniform sampler2D colortex0;    // Albedo + block light (from gbuffers)
uniform sampler2D colortex1;    // Linear depth
uniform sampler2D colortex2;    // Normal + smoothness
uniform sampler2D colortex4;    // Material properties

void main() {
	// Phase 1: Simple pass-through composite
	// Read albedo from G-Buffer (colortex0)
	vec4 albedo = texture2D(colortex0, texCoord);

	// Read material properties
	vec4 material = texture2D(colortex4, texCoord);
	float skyLight = material.b;

	// Basic lighting: albedo * (block light + sky light contribution)
	vec3 color = albedo.rgb;

	// Add minimal sky lighting (0.5 = 50% brightness from sky)
	color *= (albedo.a + skyLight * 0.5);

	// Output to screen (becomes colortex0 for next pass)
	gl_FragColor = vec4(color, 1.0);
}
