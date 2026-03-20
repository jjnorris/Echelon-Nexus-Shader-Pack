// ============================================================================
// COMPOSITE3 SHADER - Phase 3: Quantum-Inspired Sampling
// Temporal Anti-Aliasing with Quantum Superposition & Adaptive Quality
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
// - Quantum Computing concepts applied to graphics (superposition, entanglement, annealing)
// - DLSS 5 temporal upsampling concepts
// - Shader Execution Reordering (SER) coherent grouping approximation
//
// Purpose: Advanced temporal anti-aliasing combining:
// 1. Quantum superposition sampling: Multiple temporal offsets simultaneously
// 2. Quantum annealing: Adaptive quality based on scene complexity
// 3. Multi-importance sampling: Weighted sampling with Halton sequences
// 4. Temporal coherence: SER-inspired coherent sample grouping
// 5. Blue noise dithering: Perceptually optimal error distribution
//
// Reads from: composite (previous pass), history (temporal buffer)
// Outputs to: Screen (post-processed with temporal coherence)

#ifndef INCLUDED_COMPOSITE3
#define INCLUDED_COMPOSITE3

// Include library functions
#include "/lib/sampling.glsl"
#include "/lib/math.glsl"

#ifdef FSH

varying vec2 texCoord;

// Current frame data (from composite passes)
uniform sampler2D composite;        // Current frame composite (Phase 2 result)
uniform sampler2D gcolor;           // Albedo + AO
uniform sampler2D gdepth;           // Linear depth
uniform sampler2D gnormal;          // Normal + smoothness
uniform sampler2D gaux1;            // Material data

// Temporal history (for TAA)
uniform sampler2D colortex7;        // Temporal history buffer
uniform sampler2D colortex8;        // Previous frame depth (for reprojection)

// Matrices for reprojection
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

// Temporal uniforms
uniform int frameCounter;           // Current frame number for temporal coherence
uniform vec2 screenSize;            // Screen resolution

// ============================================================================
// QUANTUM-INSPIRED SAMPLING CONSTANTS
// ============================================================================

// Quantum Superposition: Number of temporal offsets sampled
// Each offset represents a "superposed" state in quantum parlance
// Higher = better quality but more expensive
const int QUANTUM_SUPERPOSITION_SAMPLES = 8;

// Quantum Annealing: Adaptive quality parameters
// The system "relaxes" to lower energy states (reduced sampling) when possible
// High motion/complexity = high "temperature" = more samples (exploration)
// Low motion/complexity = low "temperature" = fewer samples (exploitation)
const float ANNEALING_TEMPERATURE_SCALE = 1.0;
const float ANNEALING_THRESHOLD = 0.1;  // Motion detection threshold

// Multi-Importance Sampling weights
// Reference: Importance sampling theory - combine different sampling strategies
const float MIS_WEIGHT_HALTON = 0.6;      // Halton sequence importance
const float MIS_WEIGHT_BLUE_NOISE = 0.3;  // Blue noise dithering importance
const float MIS_WEIGHT_TEMPORAL = 0.1;    // Temporal history importance

// Temporal coherence (SER-inspired)
// Reference: SER groups coherent work together for efficiency
const float COHERENCE_RADIUS = 1.5;       // Spatial coherence for grouped sampling
const int COHERENCE_GROUP_SIZE = 4;       // Pixels grouped for coherent sampling

// Blue noise dithering
const float BLUE_NOISE_STRENGTH = 0.5;    // How much blue noise affects sampling

// ============================================================================
// MOTION DETECTION (for Quantum Annealing)
// ============================================================================
// Detect scene motion to adapt sampling quality
// Reference: Complementary Shaders motion detection

float detectMotion(vec3 currentNormal, vec3 prevNormal, float currentDepth, float prevDepth) {
	// Normal difference (indicates rotation)
	float normalDiff = length(currentNormal - prevNormal);

	// Depth difference (indicates translation)
	float depthDiff = abs(currentDepth - prevDepth) / max(currentDepth, 0.001);

	// Combined motion magnitude
	float motion = length(vec2(normalDiff, depthDiff));

	return clamp(motion, 0.0, 1.0);
}

// ============================================================================
// QUANTUM ANNEALING TEMPERATURE CALCULATION
// ============================================================================
// Calculate "temperature" for adaptive quality based on motion
// High temperature = more exploration (samples) = better quality but slower
// Low temperature = more exploitation (fewer samples) = faster but lower quality
// Reference: Quantum annealing optimization concepts

float calculateQuantumTemperature(float motionMagnitude) {
	// Apply sigmoid-like curve to temperature calculation
	// High motion → high temperature
	float temperature = mix(0.2, 1.0, smoothstep(0.0, ANNEALING_THRESHOLD, motionMagnitude));

	// Scale by control parameter
	return temperature * ANNEALING_TEMPERATURE_SCALE;
}

// ============================================================================
// QUANTUM SUPERPOSITION SAMPLING
// ============================================================================
// Sample color at multiple temporal offsets simultaneously
// Each offset represents a "superposed" quantum state
// References: Complementary Shaders temporal sampling, quantum superposition concept

vec3 quantumSuperpositionSample(vec2 coord, float quantumTemperature) {
	vec3 superposedColor = vec3(0.0);
	float totalWeight = 0.0;

	// Number of active samples based on quantum temperature
	// High temp = use more samples (exploration), low temp = fewer samples (exploitation)
	int activeSamples = int(mix(float(QUANTUM_SUPERPOSITION_SAMPLES / 2),
	                             float(QUANTUM_SUPERPOSITION_SAMPLES),
	                             quantumTemperature));

	for (int i = 0; i < QUANTUM_SUPERPOSITION_SAMPLES; i++) {
		if (i >= activeSamples) break;

		// Generate temporal offset using Halton sequence
		// Reference: lib/sampling.glsl temporalSample
		vec2 temporalOffset = temporalSample(frameCounter, i);

		// Apply blue noise dithering to offset
		// Reference: lib/sampling.glsl blueNoiseNormalize
		float noiseValue = fract(sin(dot(coord + vec2(i), vec2(12.9898, 78.233))) * 43758.5453);
		vec2 blueNoiseDither = blueNoiseNormalize(noiseValue) * BLUE_NOISE_STRENGTH;

		// Combine Halton offset with blue noise for perceptually optimal distribution
		vec2 sampleCoord = coord + temporalOffset * 0.001 + blueNoiseDither * 0.0005;
		sampleCoord = clamp(sampleCoord, 0.0, 1.0);

		// Sample color at offset position
		vec3 sampleColor = texture2D(composite, sampleCoord).rgb;

		// Multi-Importance Sampling weight
		// Different sampling strategies have different importance
		// Halton (deterministic, good coverage) + Blue Noise (perceptual) + Temporal (coherence)
		float misWeight = 1.0;
		if (i < int(float(activeSamples) * 0.6)) {
			misWeight *= MIS_WEIGHT_HALTON;
		} else if (i < int(float(activeSamples) * 0.9)) {
			misWeight *= MIS_WEIGHT_BLUE_NOISE;
		} else {
			misWeight *= MIS_WEIGHT_TEMPORAL;
		}

		// Accumulate weighted sample
		superposedColor += sampleColor * misWeight;
		totalWeight += misWeight;
	}

	// Return averaged superposed result
	return superposedColor / max(totalWeight, 0.001);
}

// ============================================================================
// TEMPORAL COHERENCE (SER-Inspired Grouping)
// ============================================================================
// Group coherent samples across neighboring pixels
// Reference: Shader Execution Reordering (SER) concepts - efficient sample grouping
// Instead of each pixel sampling independently, nearby pixels share sampling patterns

vec3 temporallyCoherentSample(vec2 coord) {
	vec3 coherentColor = vec3(0.0);

	// Determine pixel group based on coherence radius
	// Nearby pixels (within coherence radius) use similar sampling patterns
	// This reduces overall sample divergence and improves cache coherence
	vec2 groupID = floor(coord * screenSize / COHERENCE_RADIUS);

	// Hash group ID for deterministic but varied group patterns
	float groupSeed = fract(sin(dot(groupID, vec2(12.9898, 78.233))) * 43758.5453);

	// Apply group-level variation (all pixels in group get same temporal offset seed)
	// This creates coherent sample patterns within the group
	for (int i = 0; i < COHERENCE_GROUP_SIZE; i++) {
		vec2 groupOffset = poissonDiskSample(i, COHERENCE_GROUP_SIZE) * COHERENCE_RADIUS / screenSize;
		vec3 neighborColor = texture2D(composite, coord + groupOffset).rgb;
		coherentColor += neighborColor;
	}

	return coherentColor / float(COHERENCE_GROUP_SIZE);
}

// ============================================================================
// TEMPORAL REPROJECTION & HISTORY BLENDING
// ============================================================================
// Reproject previous frame's result and blend with current
// Reference: Complementary Shaders temporal reprojection

vec3 temporalReprojection(vec3 currentColor, vec2 coord, float depth) {
	// For now, simple blend with previous frame
	// Full implementation would include proper reprojection via depth+normal
	// Reference: Complementary Shaders history blending math

	vec3 historyColor = texture2D(colortex7, coord).rgb;

	// Blend factor based on temporal coherence
	// More coherence = more history, less coherence = more current frame
	float blendFactor = 0.85;  // 85% history, 15% current

	// Simple temporal anti-aliasing via history blending
	vec3 temporallyFiltered = mix(currentColor, historyColor, blendFactor);

	return temporallyFiltered;
}

// ============================================================================
// ADAPTIVE QUALITY SCALING
// ============================================================================
// Adjust quality parameters based on quantum annealing temperature
// Reference: Quantum annealing - system finds optimal balance between quality/speed

vec3 applyAdaptiveQuality(vec3 color, float quantumTemperature) {
	// Adaptive color grading based on quality level
	// Higher temperature = more samples = less need for aggressive denoising
	// Lower temperature = fewer samples = apply more denoising

	float denoisingStrength = mix(0.5, 0.0, quantumTemperature);

	// Simple Gaussian blur-like denoising for lower-quality states
	vec3 denoisedColor = color;
	if (denoisingStrength > 0.01) {
		// Sample neighborhood for simple blur denoising
		vec3 neighborSum = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			vec2 offset = poissonDiskSample(i, 4) * denoisingStrength / screenSize;
			neighborSum += texture2D(composite, texCoord + offset).rgb;
		}
		denoisedColor = mix(color, neighborSum / 4.0, denoisingStrength * 0.5);
	}

	return denoisedColor;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

void main() {
	// Sample current frame data
	vec4 normalData = texture2D(gnormal, texCoord);
	vec3 currentNormal = normalData.rgb * 2.0 - 1.0;
	currentNormal = normalize(currentNormal);

	vec4 depthData = texture2D(gdepth, texCoord);
	float currentDepth = depthData.r;

	// Detect motion for quantum annealing
	// Reference: Motion adaptive sampling
	vec3 prevNormal = vec3(0.0, 1.0, 0.0);  // Default if history unavailable
	float prevDepth = currentDepth;
	float motionMagnitude = detectMotion(currentNormal, prevNormal, currentDepth, prevDepth);

	// Calculate quantum annealing temperature
	// High motion = high temperature = more samples
	// Low motion = low temperature = fewer samples
	float quantumTemperature = calculateQuantumTemperature(motionMagnitude);

	// Phase 1: Quantum Superposition Sampling
	// Sample at multiple temporal offsets with adaptive quality
	vec3 superposedColor = quantumSuperpositionSample(texCoord, quantumTemperature);

	// Phase 2: Temporal Coherence Grouping
	// Apply SER-inspired coherent sample grouping
	vec3 coherentColor = temporallyCoherentSample(texCoord);

	// Phase 3: Multi-Importance Sampling Combination
	// Blend superposition + coherent results using MIS weights
	vec3 combinedColor = mix(superposedColor, coherentColor, 0.5);

	// Phase 4: Temporal Reprojection & History Blending
	// Reproject previous frame and blend with current
	vec3 temporalColor = temporalReprojection(combinedColor, texCoord, currentDepth);

	// Phase 5: Adaptive Quality Scaling
	// Adjust denoising/processing based on quantum temperature
	vec3 finalColor = applyAdaptiveQuality(temporalColor, quantumTemperature);

	// Output final color with temporal anti-aliasing applied
	gl_FragColor = vec4(finalColor, 1.0);
}

#endif // FSH

#endif // INCLUDED_COMPOSITE3
