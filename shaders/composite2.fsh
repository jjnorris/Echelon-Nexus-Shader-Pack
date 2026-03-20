#version 400 compatibility

/* RENDERTARGETS: 0 */

/* PHASE 2: PCSS SHADOWS COMPOSITE PASS

   Input: G-Buffer from Phase 1
   - colortex0: Base color from gbuffers
   - depthtex0: Scene depth (linear, 0-1)

   Processing:
   - Reconstruct world position from depth
   - Transform to shadow space
   - Apply PCSS three-stage algorithm
   - Apply shadow to base color

   Output: colortex5 (shadows applied, ready for Phase 3)
*/

#include "/program/pcss.glsl"

uniform sampler2D colortex0;      // G-Buffer color (raw gbuffers output)
uniform sampler2D colortex1;      // Phase 1 base lighting (from composite.fsh)
uniform sampler2D depthtex0;      // Scene depth (linear)
uniform sampler2D shadowtex0;     // Shadow map from directional light

// Camera/transform matrices
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

// Camera position (for sky detection)
uniform vec3 cameraPosition;

in vec2 uv;

out vec4 fragColor;

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Reconstruct world position from screen-space depth
 *
 * Converts from:
 * - Screen UV coordinates (0-1)
 * - Linear depth (0-1)
 *
 * To:
 * - World-space XYZ coordinates
 */
vec3 reconstructWorldPos(vec2 screenUV, float depth) {
	// Convert screen UV to normalized device coordinates (NDC)
	// Screen space (0-1) → NDC space (-1 to 1)
	vec3 ndc = vec3(screenUV * 2.0 - 1.0, depth * 2.0 - 1.0);

	// Transform NDC → view space
	vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
	viewPos /= viewPos.w;  // Perspective divide

	// Transform view space → world space
	vec4 worldPos = gbufferModelViewInverse * viewPos;

	return worldPos.xyz;
}

/**
 * Project world position to shadow map coordinates
 *
 * Converts world XYZ to shadow texture coordinates (0-1)
 * and depth value for comparison
 */
vec3 projectToShadowSpace(vec3 worldPos) {
	// Transform to shadow space
	vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));

	// Perspective divide
	shadowPos /= shadowPos.w;

	// Convert from [-1, 1] to [0, 1] for texture lookup
	vec2 shadowCoord = shadowPos.xy * 0.5 + 0.5;
	float shadowDepth = shadowPos.z * 0.5 + 0.5;

	// Clamp to valid texture range (prevent sampling outside shadow map)
	shadowCoord = clamp(shadowCoord, vec2(0.0), vec2(1.0));

	return vec3(shadowCoord, shadowDepth);
}

/**
 * Calculate distance from camera to fragment
 * Used for cascade selection and quality scaling
 */
float getLinearDepth(vec3 worldPos) {
	vec3 diff = worldPos - cameraPosition;
	return length(diff);
}

// ============================================================================
// MAIN SHADER
// ============================================================================

void main() {
	// Load base color from Phase 1 (composite.fsh output)
	vec4 baseColor = texture(colortex1, uv);

	// Load scene depth
	float depth = texture(depthtex0, uv).r;

	// ========================================================================
	// SKY HANDLING - No shadows on sky
	// ========================================================================

	// Far depth = sky (no shadow calculation needed)
	if (depth > 0.9999) {
		fragColor = baseColor;
		return;
	}

	// ========================================================================
	// WORLD POSITION RECONSTRUCTION
	// ========================================================================

	vec3 worldPos = reconstructWorldPos(uv, depth);

	// ========================================================================
	// SHADOW SPACE PROJECTION
	// ========================================================================

	vec3 shadowSpacePos = projectToShadowSpace(worldPos);
	vec2 shadowCoord = shadowSpacePos.xy;
	float shadowDepth = shadowSpacePos.z;

	// Clamp shadow depth to valid range
	shadowDepth = clamp(shadowDepth, 0.0, 1.0);

	// ========================================================================
	// PCSS SHADOW COMPUTATION
	// ========================================================================

	// PCSS parameters (can be made configurable later)
	float lightSize = 0.5;      // Light angular size (0.3-1.0)
	float searchRadius = 3.0;   // Blocker search radius in shadow space

	// Call PCSS algorithm (three-stage: blocker search → penumbra → PCF)
	float shadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth,
	                          lightSize, searchRadius);

	// ========================================================================
	// APPLY SHADOW TO COLOR
	// ========================================================================

	// Shadow value: 0 = fully shadowed, 1 = fully lit
	// Apply shadow by darkening shadowed areas
	// Keep at least 40% brightness in shadow (avoid pure black)
	vec3 shadowColor = baseColor.rgb * (0.4 + shadow * 0.6);

	// ========================================================================
	// OUTPUT
	// ========================================================================

	// Pass to Phase 3 (TAA) or final render
	fragColor = vec4(shadowColor, baseColor.a);
}
