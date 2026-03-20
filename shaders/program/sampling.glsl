/* =============================================================================
   Low-Discrepancy Sampling Library

   Generates sample patterns for:
   - Percentage-Closer Soft Shadows (PCSS) - Phase 2
   - Temporal Anti-Aliasing (TAA) - Phase 3
   - Spectral rendering - Phase 6

   Low-discrepancy sequences minimize clustering and gaps, producing
   higher-quality results than random sampling with fewer samples.

   References:
   - Halton Sequences: Halton, "On the efficiency of certain quasi-random sequences"
   - Poisson Disk: Bridson, "Fast Poisson disk sampling in arbitrary dimensions"
   - Blue Noise: Heitz & Belcour, "A Low-Distortion Map Between Disk and Square"

   ============================================================================= */

#ifndef INCLUDED_SAMPLING
#define INCLUDED_SAMPLING

// ============================================================================
// Pseudorandom Number Generation
// ============================================================================

/**
 * Hash function for procedural randomness
 * Used as basis for other sampling methods
 *
 * @param p 2D position or seed
 * @return Pseudorandom float in range [0, 1)
 */
float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

/**
 * Hash function (2 components)
 * Produces 2D random vector
 */
vec2 random2(vec2 p) {
	vec2 r = vec2(
		sin(dot(p, vec2(12.9898, 78.233))),
		sin(dot(p, vec2(62.4156, 94.673)))
	);
	return fract(r * 43758.5453);
}

// ============================================================================
// Halton Sequence (Low-Discrepancy)
// ============================================================================

/**
 * Halton sequence - base 2
 * Generates evenly-distributed numbers in [0, 1)
 * Used for temporal sampling in TAA (Phase 3)
 *
 * @param index Sequence index (0, 1, 2, ...)
 * @return Value in [0, 1)
 */
float haltonBase2(int index) {
	float result = 0.0;
	float f = 0.5;
	int i = index;
	while (i > 0) {
		result += f * float(i & 1);
		i >>= 1;
		f *= 0.5;
	}
	return result;
}

/**
 * Halton sequence - base 3
 * Complements base 2 for 2D sampling
 */
float haltonBase3(int index) {
	float result = 0.0;
	float f = 1.0 / 3.0;
	int i = index;
	while (i > 0) {
		result += f * float(i % 3);
		i /= 3;
		f /= 3.0;
	}
	return result;
}

/**
 * 2D Halton sequence sample
 * Generates Halton(2,3) pair for quasi-random 2D sampling
 *
 * @param sampleIndex Which sample in the sequence (0, 1, 2, ...)
 * @return 2D sample in unit square [0,1) x [0,1)
 */
vec2 haltonSequence(int sampleIndex) {
	return vec2(haltonBase2(sampleIndex), haltonBase3(sampleIndex));
}

// ============================================================================
// Poisson Disk Sampling (Structured Randomness)
// ============================================================================

/**
 * Poisson disk sample pattern with golden angle
 * Produces a disk-shaped pattern that avoids clustering
 * Used for shadow sampling (PCSS in Phase 2)
 *
 * Golden angle = 2 /   2.39996... radians
 * This angle ensures even spacing around a circle
 *
 * @param sampleIndex Which sample (0 to numSamples-1)
 * @param numSamples Total number of samples
 * @param radius Radius of the disk pattern
 * @return 2D offset vector on the disk
 */
vec2 poissonDiskSample(int sampleIndex, int numSamples, float radius) {
	float angle = float(sampleIndex) * 2.399963229728653;  // Golden angle
	float r = radius * sqrt(float(sampleIndex + 1.0) / float(numSamples));
	return vec2(cos(angle), sin(angle)) * r;
}

/**
 * Rotated Poisson disk pattern
 * Adds randomness to the pattern to avoid banding across pixels
 *
 * @param sampleIndex Which sample in pattern
 * @param numSamples Total samples
 * @param radius Disk radius
 * @param rotation Random rotation angle
 * @return Rotated 2D offset
 */
vec2 rotatedPoissonDisk(int sampleIndex, int numSamples, float radius, float rotation) {
	vec2 sample = poissonDiskSample(sampleIndex, numSamples, radius);
	float c = cos(rotation);
	float s = sin(rotation);
	return vec2(
		sample.x * c - sample.y * s,
		sample.x * s + sample.y * c
	);
}

// ============================================================================
// Blue Noise (Perceptually Optimized)
// ============================================================================

/**
 * Dither matrix for blue noise (Phase 6)
 * Creates perceptually pleasing noise pattern
 * Values modulate sample intensity based on pixel position
 */
float blueNoiseDither(vec2 pixelCoord) {
	// Placeholder for Phase 6 - would use precomputed blue noise texture
	// For now, use simple pattern
	return fract(sin(dot(pixelCoord, vec2(12.9898, 78.233))));
}

// ============================================================================
// Sampling Patterns for Different Use Cases
// ============================================================================

/**
 * Generate N samples for shadow filtering
 * Optimized for PCSS blocker search and PCF
 *
 * Pattern: Poisson disk with random rotation per pixel
 *
 * @param sampleIndex Which sample (0 to numSamples-1)
 * @param numSamples Total samples (typically 8, 16, or 32)
 * @param radius Filtering radius in texture space
 * @param pixelCoord Current pixel coordinates (for random rotation)
 * @return 2D texture offset for shadow sample
 */
vec2 shadowSampleOffset(int sampleIndex, int numSamples, float radius, vec2 pixelCoord) {
	float rotation = random(pixelCoord) * 6.28318;  // 2 radians
	return rotatedPoissonDisk(sampleIndex, numSamples, radius, rotation);
}

/**
 * Generate temporal offset for TAA
 * Uses Halton sequence for stable convergence over frames
 *
 * @param frameIndex Current frame number
 * @return 2D temporal jitter in clip space (-0.5 to 0.5)
 */
vec2 temporalJitter(int frameIndex) {
	vec2 halton = haltonSequence(frameIndex % 8);
	return (halton - 0.5) * 0.5;  // Scale to [-0.25, 0.25]
}

/**
 * Multi-sample for anti-aliasing
 * Combines Halton sequence with random rotation
 *
 * @param sampleIndex Which AA sample (0 to numSamples-1)
 * @param numSamples Total AA samples
 * @param pixelCoord Current pixel coordinate
 * @return Jittered sample offset in screen space
 */
vec2 antiAliasSample(int sampleIndex, int numSamples, vec2 pixelCoord) {
	vec2 base = haltonSequence(sampleIndex);
	float noise = random(pixelCoord + float(sampleIndex));
	return (base - 0.5) + vec2(cos(noise * 6.28), sin(noise * 6.28)) * 0.1;
}

#endif // INCLUDED_SAMPLING

