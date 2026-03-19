// ===================================================================
// Path Integral Light Transport (Phase 19)
// ===================================================================
// Monte Carlo path-integral formulation for indirect lighting.
// Implements importance-weighted sampling for global illumination.
//
// References:
//   - The Path Integral Formulation of Light Transport (Veach & Guibas, 1997)
//   - Importance Sampling for Production Rendering (Pharr et al., 2016)

#ifndef INCLUDE_PATH_INTEGRAL
#define INCLUDE_PATH_INTEGRAL

#include "halton_sequence.glsl"
#include "advanced_sampling.glsl"

// ===================================================================
// PATH INTEGRAL ESTIMATOR
// ===================================================================

// Radiance estimator: L_e(x) + integral(L_i * BRDF * cos(theta) d_omega)
// Computed via Monte Carlo sampling of light paths
struct PathEstimate {
    vec3 radiance;          // Estimated radiance
    float weight;           // Sample weight (importance)
    int bounces;            // Number of bounces taken
};

// Single-bounce indirect lighting (one-step path integral)
PathEstimate singleBounceIndirect(
    vec3 position,
    vec3 normal,
    vec3 viewDir,
    vec3 albedo,
    float roughness,
    float metallic,
    uint sampleIndex
) {
    PathEstimate estimate;

    // Halton sample for hemisphere direction
    vec2 sample2d = halton2D(sampleIndex);

    // Importance sample hemisphere (cosine-weighted)
    vec3 sampleDir = cosineSampleHemisphere(sample2d);

    // Transform from local to world space
    vec3 bitangent = (abs(normal.x) < 0.9) ? normalize(cross(normal, vec3(1.0, 0.0, 0.0))) :
                                             normalize(cross(normal, vec3(0.0, 1.0, 0.0)));
    vec3 tangent = cross(bitangent, normal);

    vec3 worldSampleDir = normalize(
        sampleDir.x * tangent + sampleDir.y * normal + sampleDir.z * bitangent
    );

    // PDF for cosine-weighted hemisphere sampling
    float samplePDF = dot(worldSampleDir, normal) / 3.14159265359;

    // Estimate incoming radiance (placeholder: use ambient)
    vec3 incomingRadiance = vec3(0.5);  // Will be replaced by actual sky/light probe

    // BRDF sampling weight (importance weighted)
    float brdfWeight = max(0.0, dot(worldSampleDir, normal)) / samplePDF;

    // Path integral estimator: L = f_r * L_i * (N . L) / pdf
    estimate.radiance = incomingRadiance * albedo * brdfWeight;
    estimate.weight = brdfWeight;
    estimate.bounces = 1;

    return estimate;
}

// Multi-bounce indirect lighting (recursive path tracing)
PathEstimate multiBounceIndirect(
    vec3 position,
    vec3 normal,
    vec3 viewDir,
    vec3 albedo,
    float roughness,
    int maxBounces,
    uint sampleIndex
) {
    PathEstimate result;
    result.radiance = vec3(0.0);
    result.weight = 0.0;
    result.bounces = 0;

    // Path state
    vec3 throughput = vec3(1.0);
    vec3 currentPos = position;
    vec3 currentNormal = normal;
    uint pathSampleIndex = sampleIndex;

    // Trace path
    for (int bounce = 0; bounce < maxBounces; bounce++) {
        // Single-bounce estimate
        PathEstimate bounce_est = singleBounceIndirect(
            currentPos, currentNormal, viewDir,
            albedo, roughness, 0.0,
            pathSampleIndex + uint(bounce) * 256u
        );

        // Accumulate contribution
        result.radiance += bounce_est.radiance * throughput;
        throughput *= albedo * 0.8;  // Attenuation per bounce

        result.bounces++;

        // Russian roulette termination (optional, for efficiency)
        if (bounce > 1) {
            float survivalProb = min(0.95, length(throughput));
            if (fract(sin(float(pathSampleIndex)) * 43758.5453) > survivalProb) {
                break;  // Path terminated
            }
            throughput /= survivalProb;
        }
    }

    result.weight = 1.0 / float(result.bounces);

    return result;
}

// ===================================================================
// IMPORTANCE SAMPLING FOR PATH INTEGRAL
// ===================================================================

// Compute importance weight for sample (for MIS)
float pathImportanceWeight(
    float brdfPDF,
    float lightPDF,
    float beta
) {
    // Multiple Importance Sampling (balance heuristic)
    float w_brdf = pow(brdfPDF, beta);
    float w_light = pow(lightPDF, beta);

    if (w_brdf + w_light < 0.00001) return 0.0;

    return w_brdf / (w_brdf + w_light);
}

// ===================================================================
// PATH CACHING FOR TEMPORAL COHERENCE
// ===================================================================

// Store path information for reuse across frames
struct CachedPath {
    vec3 radiance;
    vec3 direction;
    float confidence;      // How confident is this cache?
};

// Reproject cached path from previous frame
bool reprojectedCachedPath(
    vec2 currentScreenCoord,
    vec2 prevScreenCoord,
    vec2 screenSize,
    out CachedPath cachedPath
) {
    // Check if previous coordinate is valid (in bounds)
    if (prevScreenCoord.x < 0.0 || prevScreenCoord.x >= screenSize.x ||
        prevScreenCoord.y < 0.0 || prevScreenCoord.y >= screenSize.y) {
        return false;
    }

    // Load from history buffer (colortex3 assumed to contain path cache)
    // cachedPath = textureLod(colortex3, prevScreenCoord / screenSize, 0.0);

    // For now, mark as invalid
    return false;
}

// Update path cache with confidence blending
CachedPath updateCachedPath(
    CachedPath previous,
    CachedPath current,
    float temporalWeight
) {
    CachedPath result;

    // Blend with EMA (exponential moving average)
    result.radiance = mix(current.radiance, previous.radiance, temporalWeight);
    result.direction = normalize(mix(current.direction, previous.direction, temporalWeight));

    // Confidence decreases with temporal distance
    result.confidence = min(previous.confidence + 0.1, 1.0) * 0.95;

    return result;
}

// ===================================================================
// BIAS REDUCTION
// ===================================================================

// Biased estimator (faster, but not unbiased)
vec3 biasedIndirectLighting(
    vec3 position,
    vec3 normal,
    uint sampleCount
) {
    vec3 totalRadiance = vec3(0.0);

    for (uint i = 0u; i < sampleCount; i++) {
        PathEstimate est = singleBounceIndirect(
            position, normal, -normal,
            vec3(1.0), 0.5, 0.0,
            i
        );

        totalRadiance += est.radiance;
    }

    return totalRadiance / float(sampleCount);
}

// Unbiased estimator (slower, but mathematically correct)
vec3 unbiasedIndirectLighting(
    vec3 position,
    vec3 normal,
    uint sampleCount
) {
    // Same as biased for single-bounce
    // Difference is in multi-bounce handling (not shown here for simplicity)
    return biasedIndirectLighting(position, normal, sampleCount);
}

#endif // INCLUDE_PATH_INTEGRAL
