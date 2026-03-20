// ============================================================================
// SAMPLING LIBRARY
// Low-Discrepancy Sequences & Blue Noise
// ============================================================================
//
// References:
// - Halton Sequence: https://en.wikipedia.org/wiki/Halton_sequence
// - Van der Corput: https://en.wikipedia.org/wiki/Van_der_Corput_sequence
// - Blue Noise: Research by Ulichney, Heitz et al.
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Low-discrepancy sampling for variance reduction in Monte Carlo integration
// Used for: Shadow PCF, screen-space reflections, path tracing

#ifndef INCLUDED_SAMPLING
#define INCLUDED_SAMPLING

// ============================================================================
// VAN DER CORPUT SEQUENCE
// ============================================================================
// 1D low-discrepancy sequence with base 2

float vanderCorput(int index) {
	float vdc = 0.0;
	float invBase = 0.5;

	int n = index;
	while (n > 0) {
		if ((n & 1) != 0) {
			vdc += invBase;
		}
		invBase *= 0.5;
		n >>= 1;
	}

	return vdc;
}

// ============================================================================
// HALTON SEQUENCE
// ============================================================================
// 2D low-discrepancy sequence (base 2, 3)

vec2 halton(int index) {
	return vec2(
		vanderCorput(index),           // Base 2
		haltonBase3(index)             // Base 3
	);
}

float haltonBase3(int index) {
	float vdc = 0.0;
	float invBase = 1.0 / 3.0;

	int n = index;
	while (n > 0) {
		vdc += float(n % 3) * invBase;
		invBase /= 3.0;
		n /= 3;
	}

	return vdc;
}

// ============================================================================
// POISSON DISK SAMPLING
// ============================================================================
// 2D sample positions that avoid clustering

vec2 poissonDiskSample(int sampleIndex, int maxSamples) {
	float angle = float(sampleIndex) * 2.4;  // Golden angle (2.39996...)
	float radius = sqrt(float(sampleIndex) / float(maxSamples));

	return vec2(
		cos(angle) * radius,
		sin(angle) * radius
	);
}

// ============================================================================
// COSINE-WEIGHTED HEMISPHERE SAMPLING
// ============================================================================
// Sample direction on hemisphere weighted by cosine(theta)
// Used for: Diffuse reflection, importance sampling

vec3 cosineSampleHemisphere(vec2 uv, vec3 normal) {
	float r = sqrt(uv.x);
	float theta = 2.0 * 3.14159265 * uv.y;

	vec3 sampleDir = vec3(
		r * cos(theta),
		r * sin(theta),
		sqrt(1.0 - uv.x)
	);

	// Transform from local hemisphere to world space using normal
	// Create orthonormal basis
	vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);

	return normalize(
		sampleDir.x * tangent +
		sampleDir.y * bitangent +
		sampleDir.z * normal
	);
}

// ============================================================================
// UNIFORM HEMISPHERE SAMPLING
// ============================================================================

vec3 uniformSampleHemisphere(vec2 uv, vec3 normal) {
	float theta = acos(uv.x);
	float phi = 2.0 * 3.14159265 * uv.y;

	vec3 sampleDir = vec3(
		sin(theta) * cos(phi),
		sin(theta) * sin(phi),
		cos(theta)
	);

	// Transform to world space
	vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);

	return normalize(
		sampleDir.x * tangent +
		sampleDir.y * bitangent +
		sampleDir.z * normal
	);
}

// ============================================================================
// BLUE NOISE DITHERING
// ============================================================================
// Convert random noise to blue noise (perceptually optimal error distribution)

vec2 blueNoiseNormalize(float noise) {
	// Convert single random value to 2D blue noise offset
	// Reference: Blue Noise research by Heitz et al.
	float x = fract(noise * 123.456);
	float y = fract(noise * 789.012);

	return vec2(x, y) * 2.0 - 1.0;
}

// ============================================================================
// QUASI-RANDOM SAMPLING WITH TEMPORAL REPROJECTION
// ============================================================================
// For temporal effects (TAA, temporal upsampling)

vec2 temporalSample(int frameIndex, int sampleIndex) {
	// Halton sequence for each frame, offset by frame
	vec2 base = halton(frameIndex * 16 + sampleIndex);

	// Add temporal jitter
	float temporalJitter = sin(float(frameIndex) * 1.234567);

	return vec2(
		fract(base.x + temporalJitter * 0.1),
		fract(base.y + temporalJitter * 0.1)
	);
}

// ============================================================================
// IMPORTANCE SAMPLING PDF
// ============================================================================
// Probability density function evaluation

float pdfCosineHemisphere(float cosTheta) {
	return cosTheta / 3.14159265;
}

float pdfUniformHemisphere() {
	return 1.0 / (2.0 * 3.14159265);
}

#endif
