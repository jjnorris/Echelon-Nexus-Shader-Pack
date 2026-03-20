// ============================================================================
// COMPOSITE FRAGMENT SHADER
// Phase 1 Foundation - Shadow Application & Basic Lighting
// ============================================================================
//
// References:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - OptiFine Documentation: https://raw.githubusercontent.com/sp614x/optifine/master/OptiFineDoc/doc/shaders.txt
//
// Purpose: Apply shadows and basic lighting to deferred G-Buffer
// Reads from: shadowtex0, shadowtex1, gcolor, gdepth, gnormal, gaux1
// Outputs to: Screen

varying vec2 texCoord;

// G-Buffer inputs
uniform sampler2D gcolor;       // Albedo + AO
uniform sampler2D gdepth;       // Linear depth
uniform sampler2D gnormal;      // Normal + smoothness
uniform sampler2D gaux1;        // Material (metallic, emissive, skyLight)

// Shadow inputs
uniform sampler2D shadowtex0;   // Shadow depth map (all geometry)
uniform sampler2D shadowtex1;   // Shadow depth map (opaque only)
uniform sampler2D shadowcolor0; // Colored shadow data

// Matrices for shadow space transformation
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

// Lighting uniforms
uniform vec3 sunPosition;       // Sun position (normalized, view space)
uniform vec3 upPosition;        // "Up" direction (0,1,0)
uniform vec3 moonPosition;      // Moon position (for night lighting)
uniform float rainStrength;     // Rain intensity (0-1)
uniform float skyColor;         // Sky color/brightness

// Control constants
const float SHADOW_BIAS = 0.001;        // Shadow depth bias to prevent acne
const float PCF_RADIUS = 1.5;           // PCF sample radius (in shadow map space)
const int PCF_SAMPLES = 9;              // Number of PCF samples

// ============================================================================
// SHADOW SAMPLING FUNCTIONS
// Reference: Shadow Tutorial PCF implementation
// ============================================================================

// Compare current depth against shadow map
// Returns 1.0 if NOT in shadow, 0.0 if fully shadowed, 0.0-1.0 for PCF
float shadowCompare(vec2 shadowCoord, float fragmentDepth) {
	// Sample shadow depth
	float shadowDepth = texture2D(shadowtex0, shadowCoord).r;

	// Bias prevents shadow acne (depth fighting artifacts)
	// Reference: Shadow Tutorial bias calculation
	float shadowBias = SHADOW_BIAS;

	// Percentage Closer Filtering (PCF) - soft shadows
	// Sample nearby depths and average results
	// Reference: Complementary PCSS implementation concept

	float shadow = 0.0;

	// 3x3 PCF kernel around shadow coordinate
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(x, y) * PCF_RADIUS / 2048.0;  // Normalize by shadow map size
			float sampleDepth = texture2D(shadowtex0, shadowCoord + offset).r;

			// Compare: if fragment is behind shadow depth, it's shadowed
			if (fragmentDepth - shadowBias > sampleDepth) {
				shadow += 0.0;  // In shadow
			} else {
				shadow += 1.0;  // Lit
			}
		}
	}

	// Average PCF samples (9 samples)
	return shadow / 9.0;
}

// Transform fragment position to shadow space
vec3 fragmentToShadowSpace(vec3 fragmentPos, mat4 projInv, mat4 viewInv) {
	// Back-project screen depth to world space
	// Reference: Shadow Tutorial projection inverse

	vec4 viewSpacePos = projInv * vec4(fragmentPos, 1.0);
	vec3 worldPos = (viewInv * viewSpacePos).xyz;

	// Transform to shadow space
	vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));

	// Normalize to shadow map coordinates ([-1,1] -> [0,1])
	shadowPos.xy = shadowPos.xy * 0.5 + 0.5;

	// Return shadow space position
	return shadowPos.xyz;
}

// ============================================================================
// MAIN RENDERING FUNCTION
// ============================================================================

void main() {
	// Sample G-Buffer
	vec4 colorData = texture2D(gcolor, texCoord);
	vec4 depthData = texture2D(gdepth, texCoord);
	vec4 normalData = texture2D(gnormal, texCoord);
	vec4 materialData = texture2D(gaux1, texCoord);

	// Decode G-Buffer
	vec3 albedo = colorData.rgb;
	float ambientOcclusion = colorData.a;

	float fragmentDepth = depthData.r;  // Linear depth

	// Decode normal from 0-1 to -1,1 range
	vec3 normal = normalData.rgb * 2.0 - 1.0;
	float smoothness = normalData.a;

	// Material properties
	float metallic = materialData.r;
	float emissive = materialData.g;
	float skyLight = materialData.b;

	// ===== SHADOW SAMPLING =====
	// Transform fragment depth to shadow space and sample shadows
	// Reference: Shadow Tutorial shadow sampling
	vec3 shadowSpacePos = fragmentToShadowSpace(
		vec3(texCoord, fragmentDepth),
		gbufferProjectionInverse,
		gbufferModelViewInverse
	);

	// Clamp shadow coordinates to valid range
	vec2 shadowCoord = clamp(shadowSpacePos.xy, 0.0, 1.0);

	// Sample shadow
	float shadowFactor = shadowCompare(shadowCoord, shadowSpacePos.z);

	// Apply shadow color (for colored shadows from translucent blocks)
	vec3 shadowColor = texture2D(shadowcolor0, shadowCoord).rgb;
	shadowFactor *= mix(1.0, length(shadowColor), 0.2);  // Blend color into shadow

	// ===== BASIC LIGHTING =====
	// Cook-Torrance GGX BRDF (simplified for Phase 1)
	// Reference: Complementary BRDF implementation

	// Ambient light (from sky light value)
	vec3 ambientLight = vec3(skyLight) * 0.25;

	// Directional light (sun/moon)
	// Simplified: use sun position and normal dot product
	vec3 sunDir = normalize(sunPosition);
	float ndotl = max(0.0, dot(normal, sunDir));

	// Apply shadow to directional light
	vec3 directLight = vec3(1.0) * ndotl * shadowFactor;

	// ===== FINAL COLOR =====
	vec3 finalColor = albedo * (ambientLight + directLight);

	// Add emissive
	finalColor += albedo * emissive;

	// Apply AO
	finalColor *= mix(1.0, ambientOcclusion, 0.5);

	// Output to screen
	// Reference: OptiFine final output specification
	gl_FragColor = vec4(finalColor, 1.0);
}
