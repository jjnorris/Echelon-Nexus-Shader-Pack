// ============================================================================
// COMPOSITE FRAGMENT SHADER - Phase 1
// ============================================================================
//
// Reference: Shadow Tutorial https://github.com/shaderLABS/Shadow-Tutorial
// Purpose: Pass-through composite - output G-Buffer albedo with basic lighting

varying vec2 texCoord;

uniform sampler2D gcolor;       // Albedo + block light
uniform sampler2D gdepth;       // Linear depth
uniform sampler2D gnormal;      // Normal + smoothness
uniform sampler2D gaux1;        // Material properties

/* RENDERTARGETS:0 */

void main() {
	// Phase 1: Simple pass-through composite
	// Read albedo from G-Buffer
	vec4 albedo = texture2D(gcolor, texCoord);

	// Read material properties
	vec4 material = texture2D(gaux1, texCoord);
	float skyLight = material.b;

	// Basic lighting: albedo * (block light + sky light contribution)
	vec3 color = albedo.rgb;

	// Add minimal sky lighting (0.5 = 50% brightness from sky)
	color *= (albedo.a + skyLight * 0.5);

	// Output to screen
	gl_FragColor = vec4(color, 1.0);
}
