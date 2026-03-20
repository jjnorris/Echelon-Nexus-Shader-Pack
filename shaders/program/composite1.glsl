// ============================================================================
// COMPOSITE1 SHADER - Phase 2: PCSS Implementation
// Percentage-Closer Soft Shadows with Blocker Search & Penumbra Estimation
// ============================================================================
//
// References:
// - PCSS Algorithm: Percentage-Closer Soft Shadows (2006)
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
//
// Purpose: Advanced soft shadows using blocker search + penumbra estimation
// Reads from: shadowtex0, shadowtex1, gcolor, gdepth, gnormal, gaux1, composite (prev pass)
// Outputs to: Screen
//
// Algorithm Overview:
// 1. Sample shadow map around fragment position (blocker search)
// 2. Calculate average blocker depth and light-space distance
// 3. Estimate penumbra radius using geometry: (receiver-blocker)/blocker * lightDistance
// 4. Perform variable-radius PCF with estimated radius
// 5. Output softly shadowed result
//
// Optimization: Uses adaptive sampling - fewer samples for small penumbras

#ifndef INCLUDED_COMPOSITE1
#define INCLUDED_COMPOSITE1

// Include library functions
#include "/lib/sampling.glsl"
#include "/lib/math.glsl"

#ifdef FSH

varying vec2 texCoord;

// G-Buffer inputs (from previous passes)
uniform sampler2D gcolor;       // Albedo + AO
uniform sampler2D gdepth;       // Linear depth
uniform sampler2D gnormal;      // Normal + smoothness
uniform sampler2D gaux1;        // Material (metallic, emissive, skyLight)
uniform sampler2D composite;    // Previous composite pass (basic lighting)

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

// ============================================================================
// PCSS CONSTANTS & PARAMETERS
// ============================================================================
// Reference: Complementary Shaders quality settings

const float SHADOW_BIAS = 0.001;           // Shadow depth bias to prevent acne
const float BLOCKER_SEARCH_RADIUS = 3.0;   // How large an area to search for blockers (shadow space)
const int BLOCKER_SAMPLES = 16;            // Number of samples in blocker search (increase for quality)
const float LIGHT_WORLD_SIZE = 0.5;        // Approximate light angular size (for penumbra estimation)
const float MAX_SHADOW_DISTANCE = 1.0;     // Maximum distance light can travel (in shadow space)

// Adaptive PCF settings based on penumbra size
const int MIN_PCF_SAMPLES = 4;             // Minimum samples for very sharp shadows
const int MAX_PCF_SAMPLES = 32;            // Maximum samples for very soft shadows
const float PCF_MIN_RADIUS = 0.5;          // Minimum PCF kernel radius
const float PCF_MAX_RADIUS = 4.0;          // Maximum PCF kernel radius

// ============================================================================
// SHADOW SPACE TRANSFORMATION
// ============================================================================
// References: Shadow Tutorial, Complementary Shaders transformation math

vec3 fragmentToShadowSpace(vec3 fragmentPos, mat4 projInv, mat4 viewInv) {
	// Back-project screen depth to world space
	vec4 viewSpacePos = projInv * vec4(fragmentPos, 1.0);
	vec3 worldPos = (viewInv * viewSpacePos).xyz;

	// Transform to shadow space (light-space projection)
	vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
	shadowPos.xyz /= shadowPos.w;  // Perspective divide

	// Convert from [-1,1] to [0,1] for texture sampling
	shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;

	return shadowPos.xyz;
}

// ============================================================================
// BLOCKER SEARCH PHASE
// ============================================================================
// Reference: PCSS Algorithm - find average depth of occluders
// This is critical for penumbra size estimation
// Returns: vec2(averageBlockerDepth, blockerCount)

vec2 blockerSearch(vec2 shadowCoord, float fragmentDepth) {
	float blockerSum = 0.0;
	float blockerCount = 0.0;

	// Use Poisson disk pattern for better sample distribution
	// Reference: lib/sampling.glsl poissonDiskSample
	// This gives more uniform coverage than grid sampling

	for (int i = 0; i < BLOCKER_SAMPLES; i++) {
		// Poisson disk sample around current position
		vec2 sampleOffset = poissonDiskSample(i, BLOCKER_SAMPLES) * BLOCKER_SEARCH_RADIUS / 2048.0;
		vec2 sampleCoord = shadowCoord + sampleOffset;

		// Sample shadow depth at this position
		float shadowDepth = texture2D(shadowtex0, sampleCoord).r;

		// If fragment is behind shadow depth, it's an occluder (blocker)
		if (fragmentDepth > shadowDepth + SHADOW_BIAS) {
			blockerSum += shadowDepth;
			blockerCount += 1.0;
		}
	}

	// Return average blocker depth and count
	// If no blockers found, return fragment depth (fragment is not shadowed)
	if (blockerCount > 0.0) {
		return vec2(blockerSum / blockerCount, blockerCount);
	} else {
		return vec2(fragmentDepth, 0.0);  // No blockers - fragment is lit
	}
}

// ============================================================================
// PENUMBRA SIZE ESTIMATION
// ============================================================================
// Reference: PCSS Algorithm - estimate soft shadow region size
// Based on: (receiverDistance - blockerDistance) / blockerDistance
// This creates the relationship between object distance and shadow softness
//
// Geometry of penumbra:
//   Light
//     /\
//    /  \  <-- Light angular size = LIGHT_WORLD_SIZE
//   /____\
//   |Blocker| <-- Average blocker distance from light
//   |      |
//   |      |
//   |Receiver| <-- Fragment distance from light (current)
//
// Penumbra = (receiver - blocker) / blocker * lightSize

float estimatePenumbraSize(float blockerDistance, float receiverDistance) {
	// Avoid division by zero or negative distances
	if (blockerDistance <= 0.0) return 0.0;

	// PCSS penumbra size formula
	// Reference: Percentage-Closer Soft Shadows (2006)
	float penumbraSize = (receiverDistance - blockerDistance) / blockerDistance;
	penumbraSize *= LIGHT_WORLD_SIZE * 1000.0;  // Scale by light size and a tuning constant

	// Clamp to reasonable range to prevent extreme softness or sharpness
	return clamp(penumbraSize, PCF_MIN_RADIUS, PCF_MAX_RADIUS);
}

// ============================================================================
// VARIABLE-RADIUS PCF (PERCENTAGE-CLOSER FILTERING)
// ============================================================================
// Reference: Complementary Shaders, Photon Shaders PCF implementation
// Uses estimated penumbra size to determine kernel radius
// Adapts sample count based on penumbra size (more samples = softer shadows)

float variableRadiusPCF(vec2 shadowCoord, float fragmentDepth, float penumbraSize) {
	float shadowValue = 0.0;
	float sampleCount = 0.0;

	// Adaptive sample count based on penumbra size
	// Smaller penumbras = fewer samples (efficiency)
	// Larger penumbras = more samples (quality)
	// Reference: Complementary Shaders adaptive sampling
	int sampleCount_int = int(mix(float(MIN_PCF_SAMPLES), float(MAX_PCF_SAMPLES),
	                                penumbraSize / PCF_MAX_RADIUS));
	sampleCount_int = max(MIN_PCF_SAMPLES, min(MAX_PCF_SAMPLES, sampleCount_int));

	// PCF loop - sample shadow map around fragment position
	for (int i = 0; i < MAX_PCF_SAMPLES; i++) {
		if (i >= sampleCount_int) break;

		// Use Poisson disk pattern for better sample distribution
		// Reference: lib/sampling.glsl - provideslow-discrepancy sampling
		vec2 sampleOffset = poissonDiskSample(i, sampleCount_int);
		sampleOffset *= penumbraSize / 2048.0;  // Scale offset by penumbra size

		vec2 sampleCoord = shadowCoord + sampleOffset;

		// Sample shadow depth at this position
		float shadowDepth = texture2D(shadowtex0, sampleCoord).r;

		// Percentage-closer comparison: if fragment is behind shadow depth, it's shadowed
		if (fragmentDepth - SHADOW_BIAS <= shadowDepth) {
			shadowValue += 1.0;  // Lit
		}

		sampleCount += 1.0;
	}

	// Average PCF samples to get final shadow value (0=fully shadowed, 1=fully lit)
	return shadowValue / sampleCount;
}

// ============================================================================
// MAIN PCSS FUNCTION
// ============================================================================
// Combines blocker search + penumbra estimation + variable-radius PCF

float pcss(vec2 shadowCoord, float fragmentDepth) {
	// Early exit: if already outside shadow map, definitely lit
	if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
	    shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
		return 1.0;
	}

	// Step 1: Blocker search - find average occluder depth
	// Reference: PCSS Algorithm Section 1
	vec2 blockerInfo = blockerSearch(shadowCoord, fragmentDepth);
	float averageBlockerDepth = blockerInfo.x;
	float blockerCount = blockerInfo.y;

	// Early exit: if no blockers found, fragment is fully lit
	if (blockerCount < 0.5) {
		return 1.0;
	}

	// Step 2: Penumbra size estimation
	// Reference: PCSS Algorithm Section 2 - geometrically-based penumbra estimation
	float penumbraSize = estimatePenumbraSize(averageBlockerDepth, fragmentDepth);

	// Early exit: if penumbra is very small, just do basic comparison
	if (penumbraSize < PCF_MIN_RADIUS) {
		float shadowDepth = texture2D(shadowtex0, shadowCoord).r;
		return fragmentDepth - SHADOW_BIAS <= shadowDepth ? 1.0 : 0.0;
	}

	// Step 3: Variable-radius PCF with estimated penumbra size
	// Reference: PCSS Algorithm Section 3 - adaptive filtering
	return variableRadiusPCF(shadowCoord, fragmentDepth, penumbraSize);
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

void main() {
	// Sample previous composite result (basic lighting from Phase 1)
	vec3 color = texture2D(composite, texCoord).rgb;

	// Sample G-Buffer data
	vec4 gcolorData = texture2D(gcolor, texCoord);
	vec3 albedo = gcolorData.rgb;
	float ao = gcolorData.a;

	vec4 depthData = texture2D(gdepth, texCoord);
	float linearDepth = depthData.r;

	vec4 normalData = texture2D(gnormal, texCoord);
	vec3 normal = normalData.rgb * 2.0 - 1.0;  // Decode from [0,1] to [-1,1]
	normal = normalize(normal);
	float smoothness = normalData.a;

	vec4 materialData = texture2D(gaux1, texCoord);
	float metallic = materialData.r;
	float emissive = materialData.g;
	float skyLight = materialData.b;

	// Transform fragment position to shadow space
	// Reference: Shadow Tutorial projection inverse math
	vec3 fragCoord = vec3(texCoord, linearDepth);
	vec3 shadowSpacePos = fragmentToShadowSpace(fragCoord, gbufferProjectionInverse, gbufferModelViewInverse);

	// Apply PCSS - advanced soft shadows
	// This replaces the simple PCF from Phase 1
	float shadowValue = pcss(shadowSpacePos.xy, shadowSpacePos.z);

	// Modulate base color by shadow value
	// Shadows darken the diffuse component while preserving some ambient
	vec3 shadowedColor = color * mix(0.3, 1.0, shadowValue);

	// Apply AO darkening
	shadowedColor *= ao;

	// Output final shadowed color
	gl_FragColor = vec4(shadowedColor, 1.0);
}

#endif // FSH

#endif // INCLUDED_COMPOSITE1
