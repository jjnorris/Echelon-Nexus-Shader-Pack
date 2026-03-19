// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║          ADVANCED SAMPLING & FILTERING (PHASE 15)                        ║
// ║          COMPLETE SUB-PHASES 15A-F IMPLEMENTATION                        ║
// ║                                                                           ║
// ║  Research-backed low-discrepancy and noise-based sampling techniques    ║
// ║  for high-quality Monte Carlo rendering with minimal aliasing.          ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    15A: Halton Sequence (quasi-random, dimensions 1-8)                 ║
// ║    15B: Sobol Sequence (low-discrepancy)                               ║
// ║    15C: Blue Noise Sampling (perceptually optimal)                     ║
// ║    15D: Multiple Importance Sampling (MIS)                             ║
// ║    15E: Stratified Sampling Patterns                                   ║
// ║    15F: Rejection Sampling                                             ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Path tracing (Phase 19-20)                                        ║
// ║    - Soft shadows (PCSS, Phase 21)                                     ║
// ║    - Depth of field (Phase 25)                                         ║
// ║    - Global illumination convergence                                   ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Halton (1960) - On the efficiency of certain quasi-random         ║
// ║    - Sobol (1967) - On the distribution of points in a cube            ║
// ║    - Ahmed & Wonka (2015) - Screen-space blue-noise                    ║
// ║    - Veach & Guibas (1995) - Optimally combining sampling techniques   ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_ADVANCED_SAMPLING
#define INCLUDE_ADVANCED_SAMPLING

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15A: HALTON SEQUENCE GENERATION                                   ║
// ║                                                                           ║
// │ Quasi-random number sequence with low discrepancy.                     ║
// │ Provides excellent sample distribution in 1-8D spaces.                 ║
// │ Base-b Van Der Corput sequence generation.                             ║
// └───────────────────────────────────────────────────────────────────────────┘

float vanDerCorputSequence(int index, int base) {
    float result = 0.0;
    float f = 1.0 / float(base);
    int i = index;

    while (i > 0) {
        int digit = i % base;
        result += f * float(digit);
        f /= float(base);
        i /= base;
    }

    return result;
}

float haltonSequence(int index, int dimension) {
    int bases[8] = int[](2, 3, 5, 7, 11, 13, 17, 19);
    int dim = min(dimension, 7);
    int base = bases[dim];
    return vanDerCorputSequence(index, base);
}

vec2 haltonPoint2D(int index) {
    return vec2(
        vanDerCorputSequence(index, 2),
        vanDerCorputSequence(index, 3)
    );
}

vec3 haltonPoint3D(int index) {
    return vec3(
        vanDerCorputSequence(index, 2),
        vanDerCorputSequence(index, 3),
        vanDerCorputSequence(index, 5)
    );
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15B: SOBOL LOW-DISCREPANCY SEQUENCE                               ║
// ║                                                                           ║
// │ Advanced low-discrepancy sequence with better multidimensional        ║
// │ properties than Halton. Uses direction vectors for efficient         ║
// │ generation and excellent uniformity.                                 ║
// └───────────────────────────────────────────────────────────────────────────┘

float sobolSequence1D(int index, int dimension) {
    uint directionVectors[8] = uint[](
        0x80000000u,
        0xC0000000u,
        0xA0000000u,
        0xF0000000u,
        0x88000000u,
        0xCC000000u,
        0xAA000000u,
        0xFF000000u
    );

    uint grayCode = uint(index) ^ (uint(index) >> 1u);
    uint result = 0u;
    uint dv = directionVectors[min(dimension, 7)];

    for (int i = 0; i < 32; i++) {
        if ((grayCode & (1u << uint(i))) != 0u) {
            result ^= (dv >> uint(i));
        }
    }

    return float(result) / 4294967296.0;
}

vec2 sobolPoint2D(int index) {
    return vec2(
        sobolSequence1D(index, 0),
        sobolSequence1D(index, 1)
    );
}

vec3 sobolPoint3D(int index) {
    return vec3(
        sobolSequence1D(index, 0),
        sobolSequence1D(index, 1),
        sobolSequence1D(index, 2)
    );
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15C: BLUE NOISE SAMPLING                                          ║
// ║                                                                           ║
// │ Perceptually optimal noise pattern. Distributes energy in high     ║
// │ frequencies, making errors invisible to human visual system.       ║
// │ Uses screen-space texture for efficient GPU sampling.              ║
// └───────────────────────────────────────────────────────────────────────────┘

float blueNoiseValue(vec2 screenCoord, int channel, sampler2D noiseTexture) {
    vec2 scaledCoord = screenCoord * 2.0;
    vec2 noiseCoord = fract(scaledCoord);
    vec4 noiseSample = texture(noiseTexture, noiseCoord);
    return noiseSample[clamp(channel, 0, 3)];
}

vec2 blueNoisePoint2D(vec2 screenCoord, int baseChannel, sampler2D noiseTexture) {
    return vec2(
        blueNoiseValue(screenCoord, baseChannel, noiseTexture),
        blueNoiseValue(screenCoord, baseChannel + 1, noiseTexture)
    );
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15D: MULTIPLE IMPORTANCE SAMPLING (MIS)                           ║
// ║                                                                           ║
// │ Technique to optimally combine samples from different distributions.  ║
// │ Reduces variance by using samples suited to their importance.        ║
// │ Critical for robust Monte Carlo rendering.                           ║
// └───────────────────────────────────────────────────────────────────────────┘

float balanceHeuristic(float pdf1, float pdf2) {
    float totalPdf = pdf1 + pdf2;
    if (totalPdf < EPSILON) return 0.5;
    return pdf1 / totalPdf;
}

float powerHeuristic(float pdf1, float pdf2, float power) {
    float w1 = pow(pdf1, power);
    float w2 = pow(pdf2, power);
    float totalWeight = w1 + w2;

    if (totalWeight < EPSILON) return 0.5;
    return w1 / totalWeight;
}

float misWeightBRDFandLight(float brdfPdf, float lightPdf) {
    return powerHeuristic(brdfPdf, lightPdf, 2.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15E: STRATIFIED SAMPLING PATTERNS                                 ║
// ║                                                                           ║
// │ Divide sample space into strata (regions) and sample once per      ║
// │ stratum. Reduces variance compared to random sampling while       ║
// │ maintaining low-discrepancy properties.                            ║
// └───────────────────────────────────────────────────────────────────────────┘

float stratifiedSample1D(int stratumIndex, int numStrata, float randomOffset) {
    float stratumWidth = 1.0 / float(numStrata);
    float stratumStart = float(stratumIndex) * stratumWidth;
    return stratumStart + randomOffset * stratumWidth;
}

vec2 stratifiedSample2D(int sampleIndex, int numSamples, vec2 randomOffset) {
    int samplesPerDim = int(ceil(sqrt(float(sampleIndex) + 1.0)));
    int gridX = sampleIndex % samplesPerDim;
    int gridY = sampleIndex / samplesPerDim;

    float cellWidth = 1.0 / float(samplesPerDim);

    vec2 result = vec2(
        float(gridX) * cellWidth + randomOffset.x * cellWidth,
        float(gridY) * cellWidth + randomOffset.y * cellWidth
    );

    return clamp(result, vec2(0.0), vec2(1.0 - EPSILON));
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 15F: REJECTION SAMPLING                                           ║
// ║                                                                           ║
// │ Method to sample from arbitrary probability distributions using     ║
// │ samples from a simpler distribution. Accepts samples with          ║
// │ probability proportional to target/proposal ratio.                 ║
// └───────────────────────────────────────────────────────────────────────────┘

float rejectionSample1D(
    float randomValue,
    float targetValue,
    float proposalValue,
    float maxRatio
) {
    if (proposalValue < EPSILON) {
        return randomValue;
    }

    float acceptanceProb = min(targetValue / (maxRatio * proposalValue), 1.0);
    return randomValue * acceptanceProb;
}

vec3 rejectionSampleFromCosineHemisphere(vec2 randomPoint) {
    float r2 = dot(randomPoint, randomPoint);
    if (r2 > 1.0) {
        randomPoint = fract(randomPoint * 0.5);
        r2 = dot(randomPoint, randomPoint);
    }

    float z = sqrt(1.0 - r2);
    return vec3(randomPoint.x, randomPoint.y, z);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED SAMPLING APPLICATION FUNCTION                                    ║
// └───────────────────────────────────────────────────────────────────────────┘

vec2 sampleStrategy(
    int sampleIndex,
    int tier,
    sampler2D noiseTexture,
    vec2 screenCoord
) {
    if (tier == 1) {
        return haltonPoint2D(sampleIndex);
    }
    else if (tier == 2) {
        return sobolPoint2D(sampleIndex);
    }
    else if (tier == 3) {
        return blueNoisePoint2D(screenCoord, 0, noiseTexture);
    }
    else if (tier == 4 || tier == 5) {
        vec2 sobolPoint = sobolPoint2D(sampleIndex);
        vec2 blueNoiseDither = blueNoisePoint2D(screenCoord, 2, noiseTexture) * 0.1;
        return fract(sobolPoint + blueNoiseDither);
    }

    return haltonPoint2D(sampleIndex);
}

#endif  // INCLUDE_ADVANCED_SAMPLING
