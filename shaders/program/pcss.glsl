/* =============================================================================
   PCSS.GLSL - Percentage-Closer Soft Shadows

   Phase 2: Advanced Shadow Filtering Implementation

   Reference: "Percentage-Closer Soft Shadows" (Fernando et al., SIGGRAPH 2006)
   Algorithm: Three-stage adaptive shadow filtering

   Benefits vs. basic PCF:
   - Penumbra size varies with occluder distance
   - Soft shadows near occluders, sharp shadows far away
   - Physically-based soft shadow appearance
   - Adaptive filtering reduces sample count overhead

   Mathematical Foundation:
   PCSS Shadow = Avg(PCF_Filter(blocker_average_depth))

   Where:
   1. Blocker Search: Find average depth of shadow casters
   2. Penumbra Estimation: Calculate shadow softness from geometry
   3. PCF Filtering: Apply variable-radius filter kernel

   ============================================================================= */

#ifndef INCLUDED_PCSS
#define INCLUDED_PCSS

// ============================================================================
// POISSON DISK SAMPLING PATTERNS
// ============================================================================

/**
 * 16-sample Poisson disk pattern with golden angle spacing
 * Used for blocker search and shadow sampling
 * Reference: "The Unreasonable Effectiveness of the Golden Angle in Science"
 */
const vec2 poissonDisk16[16] = vec2[](
	vec2(-0.94201624,  -0.39906216),
	vec2( 0.94558609,  -0.76890725),
	vec2(-0.74205544,  -0.94693636),
	vec2( 0.34495938,   0.29387760),
	vec2(-0.91588581,   0.45771432),
	vec2(-0.03617221,  -0.99518287),
	vec2( 0.81479360,   0.41529015),
	vec2( 0.78512320,  -0.64545042),
	vec2(-0.48821436,   0.04532837),
	vec2(-0.87421629,   0.19379118),
	vec2(-0.30331618,   0.47817620),
	vec2( 0.14918677,   0.87314927),
	vec2( 0.48140316,   0.15541062),
	vec2( 0.11003546,   0.44798897),
	vec2(-0.61149926,   0.78995058),
	vec2( 0.13168975,  -0.04332821)
);

/**
 * 4-sample minimal pattern (for LOW profile)
 */
const vec2 poissonDisk4[4] = vec2[](
	vec2(-0.7071,  0.7071),
	vec2( 0.7071,  0.7071),
	vec2(-0.7071, -0.7071),
	vec2( 0.7071, -0.7071)
);

// ============================================================================
// BLOCKER SEARCH - Stage 1 of PCSS
// ============================================================================

/**
 * Search for shadow occluders (blockers) at fragment position
 *
 * Returns information about occluders blocking light:
 * - Average depth of blockers
 * - Number of blockers found
 * - Search radius used
 *
 * @param shadowMap Shadow depth map (shadowtex0)
 * @param sampleCoord Texture coordinate in shadow space
 * @param receiverDepth Depth of receiver (fragment being shadowed)
 * @param searchRadius Size of search region (in shadow space)
 * @param sampleCount Number of samples (4 or 16)
 * @return vec3(avgBlockerDepth, blockerCount, searchRadius)
 */
vec3 pcssBlockerSearch(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float searchRadius, int sampleCount) {

	float avgBlockerDepth = 0.0;
	float blockerCount = 0.0;

	// Sample shadow map at multiple locations around the receiver
	for (int i = 0; i < 16; i++) {
		if (i >= sampleCount) break;  // Early exit if fewer samples needed

		// Offset sample position using Poisson disk pattern
		vec2 offset = poissonDisk16[i] * searchRadius;
		vec2 samplePos = sampleCoord + offset;

		// Clamp to texture bounds (prevent wraparound at edges)
		samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

		// Sample shadow depth
		float sampledDepth = texture(shadowMap, samplePos).x;

		// Count occluders: samples closer to light than receiver
		// Receiver is in shadow if light distance < receiver distance
		if (sampledDepth < receiverDepth) {
			avgBlockerDepth += sampledDepth;
			blockerCount += 1.0;
		}
	}

	// Compute average blocker depth
	if (blockerCount > 0.0) {
		avgBlockerDepth /= blockerCount;
	} else {
		// No blockers found - fully lit
		avgBlockerDepth = 0.0;
		blockerCount = 0.0;
	}

	return vec3(avgBlockerDepth, blockerCount, searchRadius);
}

// ============================================================================
// PENUMBRA ESTIMATION - Stage 2 of PCSS
// ============================================================================

/**
 * Estimate the size of the penumbra (soft shadow edge)
 *
 * Based on geometric relationship between light size, occluder distance,
 * and receiver distance.
 *
 * Physics: Larger distance from occluder  larger penumbra
 *
 * Formula: penumbra_width = (receiver_dist - blocker_dist) / blocker_dist * light_size
 *
 * @param avgBlockerDepth Average depth of shadow casters
 * @param receiverDepth Depth of fragment being shadowed
 * @param lightSize Angular size of light source (0.3-1.0 typical)
 * @return Penumbra size (shadow filter radius in texture space)
 */
float pcssComputePenumbra(float avgBlockerDepth, float receiverDepth, float lightSize) {

	// Distance from light to occluder
	float blockerDistance = avgBlockerDepth;

	// Distance from light to receiver (fragment)
	float receiverDistance = receiverDepth;

	// Penumbra distance (how far from occluder the shadow softens)
	float penumbraDistance = receiverDistance - blockerDistance;

	// Clamp to prevent negative penumbra
	if (penumbraDistance <= 0.0) {
		return 0.0;  // No penumbra if receiver is closer than blocker
	}

	// Calculate penumbra width using light size estimate
	// Large light = large penumbra; small light = sharp shadow
	float penumbraWidth = (penumbraDistance / blockerDistance) * lightSize;

	// Clamp penumbra to reasonable range (0.0 = sharp, 1.0 = very soft)
	return clamp(penumbraWidth, 0.0, 1.0);
}

// ============================================================================
// VARIABLE-RADIUS PCF - Stage 3 of PCSS
// ============================================================================

/**
 * Percentage-Closer Filtering with variable kernel size
 *
 * Larger kernel = softer shadows (for large penumbra)
 * Smaller kernel = sharper shadows (for small penumbra)
 *
 * @param shadowMap Shadow depth map (shadowtex0)
 * @param sampleCoord Texture coordinate in shadow space
 * @param receiverDepth Depth of fragment (for comparison)
 * @param filterSize Radius of filter kernel (varies by penumbra)
 * @param sampleCount Number of samples (adaptive: 4, 8, 16, 32)
 * @return Shadow value (0 = fully shadowed, 1 = fully lit)
 */
float pcssShadowSample(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float filterSize, int sampleCount) {

	float shadow = 0.0;

	// Adaptive sample count based on penumbra size
	if (filterSize < 0.001) {
		sampleCount = 4;      // Very small penumbra = sharp shadow
	} else if (filterSize < 0.05) {
		sampleCount = 8;      // Small penumbra
	} else if (filterSize < 0.15) {
		sampleCount = 16;     // Medium penumbra
	} else {
		sampleCount = 32;     // Large penumbra = soft shadow
	}

	// Sample shadow map at multiple locations
	for (int i = 0; i < 32; i++) {
		if (i >= sampleCount) break;  // Early exit

		// Scale Poisson offset by filter size (larger penumbra = larger kernel)
		vec2 offset = poissonDisk16[i % 16] * filterSize;
		vec2 samplePos = sampleCoord + offset;

		// Clamp to texture bounds
		samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

		// Sample shadow depth and compare (PCF comparison)
		float sampledDepth = texture(shadowMap, samplePos).x;

		// If sampled depth >= receiver depth, fragment is lit at this sample
		// Average of lit samples = shadow value (0 = all shadowed, 1 = all lit)
		shadow += (sampledDepth >= receiverDepth) ? 1.0 : 0.0;
	}

	// Return average (shadow = sum / count)
	return shadow / float(sampleCount);
}

// ============================================================================
// COMPLETE PCSS SHADOW CALCULATION
// ============================================================================

/**
 * Full three-stage PCSS algorithm
 *
 * @param shadowMap Shadow depth map
 * @param sampleCoord Texture coordinate in shadow space
 * @param receiverDepth Depth of fragment being shadowed
 * @param lightSize Light angular size (0.5 is good default)
 * @param searchRadius Blocker search radius (3.0 is typical)
 * @return Shadow value (0 = fully shadowed, 1 = fully lit)
 */
float pcssShadow(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                 float lightSize, float searchRadius) {

	// ========================================================================
	// Stage 1: BLOCKER SEARCH
	// ========================================================================
	// Find average depth of shadow casters

	vec3 blockerInfo = pcssBlockerSearch(shadowMap, sampleCoord, receiverDepth,
	                                      searchRadius, 16);  // 16 blocker search samples

	float avgBlockerDepth = blockerInfo.x;
	float blockerCount = blockerInfo.y;

	// If no blockers found, fragment is fully lit
	if (blockerCount < 0.5) {
		return 1.0;
	}

	// ========================================================================
	// Stage 2: PENUMBRA ESTIMATION
	// ========================================================================
	// Calculate soft shadow radius based on geometry

	float penumbraSize = pcssComputePenumbra(avgBlockerDepth, receiverDepth, lightSize);

	// Clamp penumbra size to prevent extreme blur
	penumbraSize = clamp(penumbraSize, 0.0, 0.1);  // Max 10% of shadow space

	// ========================================================================
	// Stage 3: VARIABLE-RADIUS PCF
	// ========================================================================
	// Apply adaptive filtering with penumbra-sized kernel

	float shadow = pcssShadowSample(shadowMap, sampleCoord, receiverDepth,
	                                penumbraSize, 16);  // Adaptive count

	return shadow;
}

// ============================================================================
// SHADOW CASCADES - Distance-based Shadow Quality
// ============================================================================

/**
 * Select which cascade to use based on receiver distance
 * Closer geometry = higher resolution shadow; farther = lower resolution
 */
int selectShadowCascade(float linearDepth) {
	if (linearDepth < 16.0) return 0;   // Near: highest detail
	if (linearDepth < 64.0) return 1;   // Mid-near
	if (linearDepth < 128.0) return 2;  // Mid-far
	return 3;                            // Far: lowest detail (but still visible)
}

/**
 * Blend between cascades for smooth transitions
 */
float cascadeBlendFactor(float linearDepth, int cascade) {
	float cascadeSize = 16.0 * pow(4.0, float(cascade));
	float nextCascadeSize = cascadeSize * 4.0;

	// Smooth blend zone: 2 units before cascade transition
	float blendZone = 2.0;
	float blendStart = cascadeSize - blendZone;

	if (linearDepth < blendStart) {
		return 0.0;  // Fully current cascade
	} else {
		float blendAmount = (linearDepth - blendStart) / (blendZone * 2.0);
		return clamp(blendAmount, 0.0, 1.0);
	}
}

// ============================================================================
// COLORED SHADOWS - Translucent Occluders
// ============================================================================

/**
 * Apply color tint from translucent shadow casters
 * (stained glass, water, ice cast colored shadows)
 *
 * @param shadowColor Tinted shadow color from shadowcolor0
 * @param shadowAmount PCF shadow value (0 = shadowed, 1 = lit)
 * @return Color-tinted shadow
 */
vec3 applyColoredShadow(vec3 shadowColor, float shadowAmount) {
	// Blend between shadow color and white (fully lit)
	// Fully shadowed = shadowColor; fully lit = white
	return mix(shadowColor, vec3(1.0), shadowAmount);
}

#endif // INCLUDED_PCSS

