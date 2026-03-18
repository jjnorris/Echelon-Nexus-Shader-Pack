// ===================================================================
// Information-Theoretic Texture Compression (Phase 25)
// ===================================================================
// Entropy-aware compression and perceptual quantization.

#ifndef INCLUDE_ENTROPY_CODING
#define INCLUDE_ENTROPY_CODING

// ===================================================================
// PERCEPTUAL QUANTIZATION
// ===================================================================

// Quantize colors to lower bit depth with perceptual dithering
vec3 perceptualQuantize(vec3 color, int bitsPerChannel) {
    float levels = pow(2.0, float(bitsPerChannel));

    // Quantize
    vec3 quantized = round(color * (levels - 1.0)) / (levels - 1.0);

    return quantized;
}

// Add ordered dithering for smoother quantization
vec3 ditherQuantize(vec3 color, vec2 screenCoord, int bitsPerChannel) {
    // Bayer matrix 4x4 (0.0-1.0)
    mat4 bayerMatrix = mat4(
        vec4(0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0),
        vec4(12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0),
        vec4(3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0),
        vec4(15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0)
    );

    // Get dither value
    ivec2 coord = ivec2(mod(screenCoord, 4.0));
    float dither = bayerMatrix[coord.x][coord.y];

    float levels = pow(2.0, float(bitsPerChannel));
    float step = 1.0 / levels;

    // Add dither threshold
    vec3 dithered = color + (dither - 0.5) * step * 0.5;

    return perceptualQuantize(dithered, bitsPerChannel);
}

// ===================================================================
// ENTROPY ESTIMATION
// ===================================================================

// Estimate entropy of a color value
float colorEntropy(vec3 color) {
    // Simple entropy: -sum(p * log2(p))
    // Where p = normalized color channel

    float e = 0.0;
    for (int i = 0; i < 3; i++) {
        float p = color[i];
        if (p > 0.0001) {
            e -= p * log2(p);
        }
    }

    return e / 3.0;
}

// Compute per-channel information content
vec3 channelEntropy(vec3 color) {
    return -color * log2(color + 0.0001);
}

// ===================================================================
// ADAPTIVE BIT ALLOCATION
// ===================================================================

// Allocate bits based on channel importance
ivec3 adaptiveBitAllocation(vec3 color, int totalBits) {
    // Entropy for each channel
    vec3 entropies = channelEntropy(color);

    // Normalize
    float totalEntropy = entropies.r + entropies.g + entropies.b;
    if (totalEntropy < 0.0001) totalEntropy = 1.0;

    vec3 normalized = entropies / totalEntropy;

    // Allocate bits proportionally
    ivec3 bits = ivec3(
        int(normalized.r * float(totalBits)),
        int(normalized.g * float(totalBits)),
        int(normalized.b * float(totalBits))
    );

    // Ensure minimum 2 bits per channel
    bits = max(bits, ivec3(2));

    return bits;
}

#endif // INCLUDE_ENTROPY_CODING
