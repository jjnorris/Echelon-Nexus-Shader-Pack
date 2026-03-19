// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║               IMPORTANCE SAMPLING FOR BRDF (PHASE 19)                    ║
// ║                                                                           ║
// ║  Importance-weighted sampling strategies for Cook-Torrance BRDF.        ║
// ║  Uses GGX microfacet sampling and Fresnel weighting for efficient       ║
// ║  Monte Carlo integration in path tracing and indirect lighting.         ║
// ║                                                                           ║
// ║  Efficiency: Biased sampling toward specular lobes reduces variance,   ║
// ║  enabling fewer samples for same convergence as uniform sampling.      ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_IMPORTANCE_SAMPLING
#define INCLUDE_IMPORTANCE_SAMPLING

#include "halton_sequence.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ BRDF IMPORTANCE SAMPLING                                                 ║
// │                                                                           ║
// │ Cook-Torrance BRDF sampling with GGX microfacet distribution.          │
// │ Produces direction biased toward specular lobe, with PDF and weight    │
// │ for Monte Carlo integration.                                             │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ BRDFSample (struct)                                                     ║
// ║                                                                         ║
// │ Importance-sampled direction with probability and contribution weight │
// │   direction - Sampled outgoing direction (normalized)                 │
// │   pdf       - Probability density of this sample                      │
// │   weight    - Contribution weight (typically 1/pdf for unbiased)     │
// └─────────────────────────────────────────────────────────────────────────┘
struct BRDFSample {
    vec3 direction;  // Sampled direction
    float pdf;       // Probability density
    float weight;    // Contribution weight
};

BRDFSample sampleCookTorranceBRDF(
    vec3 normal,
    vec3 viewDir,
    float roughness,
    vec2 sample2d
) {
    BRDFSample result;

    // Roughness remapping (alpha = roughness^2)
    float alpha = roughness * roughness;

    // Sample half-vector using GGX importance sampling
    vec3 H = ggxSampleHalf(sample2d, alpha);

    // Transform to world space
    vec3 bitangent = (abs(normal.x) < 0.9) ? normalize(cross(normal, vec3(1.0, 0.0, 0.0))) :
                                             normalize(cross(normal, vec3(0.0, 1.0, 0.0)));
    vec3 tangent = cross(bitangent, normal);

    H = normalize(H.x * tangent + H.y * bitangent + H.z * normal);

    // Compute outgoing direction (reflect V about H)
    vec3 outDir = reflect(-viewDir, H);

    // GGX PDF
    float HdotV = max(0.0, dot(H, -viewDir));
    float alpha2 = alpha * alpha;
    float denom = (HdotV * HdotV) * (alpha2 - 1.0) + 1.0;
    float pdfH = alpha2 / (3.14159265359 * denom * denom);

    // Jacobian for half-vector to outgoing direction
    float pdfOut = pdfH / (4.0 * max(0.0001, HdotV));

    result.direction = outDir;
    result.pdf = pdfOut;
    result.weight = max(0.0, dot(outDir, normal)) / pdfOut;

    return result;
}

// Sample diffuse BRDF importance-weighted (cosine hemisphere)
BRDFSample sampleDiffuseBRDF(
    vec3 normal,
    vec2 sample2d
) {
    BRDFSample result;

    // Cosine-weighted hemisphere sample
    result.direction = cosineSampleHemisphere(sample2d);

    // Transform to world space
    vec3 bitangent = (abs(normal.x) < 0.9) ? normalize(cross(normal, vec3(1.0, 0.0, 0.0))) :
                                             normalize(cross(normal, vec3(0.0, 1.0, 0.0)));
    vec3 tangent = cross(bitangent, normal);

    result.direction = normalize(
        result.direction.x * tangent + result.direction.y * normal + result.direction.z * bitangent
    );

    // PDF for cosine distribution: p(w) = cos(theta) / pi
    result.pdf = max(0.0, dot(result.direction, normal)) / 3.14159265359;

    result.weight = 1.0;  // For cosine-weighted, weight is 1.0

    return result;
}

// ===================================================================
// FRESNEL-WEIGHTED IMPORTANCE SAMPLING
// ===================================================================

// Weight samples based on Fresnel term
// High Fresnel contribution -> higher weight
float fresnelWeight(
    vec3 F0,
    float HdotV,
    float metallic
) {
    // Schlick Fresnel
    vec3 F = F0 + (1.0 - F0) * pow(1.0 - HdotV, 5.0);

    // For metals: use luminance
    float fresnel = (metallic > 0.5) ? length(F) : F.g;

    return fresnel;
}

// ===================================================================
// MULTIPLE IMPORTANCE SAMPLING COMBINATION
// ===================================================================

// Combine BRDF and light importance sampling
struct MISSample {
    vec3 direction;
    float weight;
};

MISSample combineBRDFAndLightSampling(
    BRDFSample brdfSample,
    BRDFSample lightSample,
    float brdfWeight,
    float lightWeight
) {
    MISSample result;

    // Use balance heuristic: weight_i = PDF_i / (PDF_1 + PDF_2 + ...)
    float totalPdf = brdfSample.pdf + lightSample.pdf;

    if (totalPdf < 0.0001) {
        result.direction = brdfSample.direction;
        result.weight = 0.0;
    } else {
        // In practice, would choose one based on heuristic
        // For now, blend them
        float brdfContrib = brdfWeight * brdfSample.pdf / totalPdf;
        float lightContrib = lightWeight * lightSample.pdf / totalPdf;

        result.direction = normalize(mix(brdfSample.direction, lightSample.direction, 0.5));
        result.weight = brdfContrib + lightContrib;
    }

    return result;
}

#endif // INCLUDE_IMPORTANCE_SAMPLING
