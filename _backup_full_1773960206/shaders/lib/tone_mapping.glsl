// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         TONE MAPPING & COLOR GRADING (PHASE 24)                         ║
// ║         COMPLETE SUB-PHASES 24A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  HDR to LDR conversion, color grading, filmic curves, and post-       ║
// ║  processing finalization for professional visual polish and artistic ║
// ║  control over final image appearance.                                ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    24A: Tone Mapping Operators                                        ║
// ║    24B: Color Grading & LUT Application                             ║
// ║    24C: Bloom & Glow Integration                                    ║
// ║    24D: Filmic Curves & Control                                    ║
// ║    24E: Post-Processing Finalization                               ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Professional color grading                                    ║
// ║    - Cinematic look and feel                                      ║
// ║    - HDR to SDR conversion                                        ║
// ║    - Artistic control over mood                                  ║
// ║    - Final visual polish                                         ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Reinhard et al. (2002) - Tone Mapping                       ║
// ║    - Krawczyk et al. (2005) - Tone Mapping Review               ║
// ║    - Grimes (2016) - Modern Filmic Tone Mapping                 ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_TONE_MAPPING
#define INCLUDE_TONE_MAPPING

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 24A: TONE MAPPING OPERATORS                                       ║
// ║                                                                           ║
// │ Convert HDR values to displayable LDR range.                      ║
// │ Multiple algorithms for different visual styles.                ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ toneMappingReinhard()                                                   ║
// ║                                                                         ║
// │ Reinhard tone mapping (local and global variants).             │
// │ Photographic compression with good color preservation.        │
// │                                                                       │
// │ Physics: Simulates photographic response                      │
// │   L_world = L_hdr × f_exposure / (1 + L_hdr × f_exposure)   │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - HDR color (can exceed 1.0)                          │
// │   exposure - Exposure factor (typically 1.0)                  │
// │   whitePoint - Whitepoint for compression                    │
// │                                                                       │
// │ Returns: Tone-mapped LDR color (0-1)                        │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 toneMappingReinhard(vec3 color, float exposure, float whitePoint) {
    // Simple Reinhard tone mapping
    vec3 exposed = color * exposure;

    // Compression curve
    vec3 compressed = exposed / (1.0 + exposed);

    // Whitepoint adjustment
    vec3 result = compressed / (whitePoint / (1.0 + whitePoint));

    return clamp(result, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ toneMappingFilmic()                                                     ║
// ║                                                                         ║
// │ Filmic tone mapping (Naughty Dog curve).                       │
// │ More aggressive compression for cinematic look.               │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - HDR color                                                │
// │   exposure - Exposure compensation                            │
// │                                                                       │
// │ Returns: Filmic tone-mapped color                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 toneMappingFilmic(vec3 color, float exposure) {
    vec3 exposed = color * exposure;

    // Filmic curve (approximation)
    vec3 result = exposed * (1.0 + exposed * 0.175);
    result = result / (1.0 + exposed);

    return clamp(result, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ toneMappingACES()                                                       ║
// ║                                                                         ║
// │ ACES (Academy Color Encoding System) tone mapping.            │
// │ Industry-standard for professional color grading.            │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - HDR color                                                │
// │   exposure - Exposure factor                                  │
// │                                                                       │
// │ Returns: ACES tone-mapped color                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 toneMappingACES(vec3 color, float exposure) {
    // ACES color space conversion (simplified)
    vec3 exposed = color * exposure;

    // RRT (Reference Rendering Transform)
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    vec3 result = (exposed * (a * exposed + b)) /
                  (exposed * (c * exposed + d) + e);

    return clamp(result, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ toneMappingLogarithmic()                                                ║
// ║                                                                         ║
// │ Logarithmic tone mapping (perceptually linear).               │
// │ Good for preserving detail across wide ranges.               │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - HDR color                                                │
// │   exposure - Exposure factor                                  │
// │                                                                       │
// │ Returns: Log tone-mapped color                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 toneMappingLogarithmic(vec3 color, float exposure) {
    // Logarithmic compression
    vec3 exposed = color * exposure + 1.0;

    // log1p for numerical stability
    vec3 result = log(exposed) / log(2.0) * 0.5;

    return clamp(result, 0.0, 1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 24B: COLOR GRADING & LUT APPLICATION                             ║
// ║                                                                           ║
// │ Apply color grading via lookup table.                             ║
// │ 3D LUT for complete color transformation.                     ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ colorGradingLUT()                                                       ║
// ║                                                                         ║
// │ Sample 3D lookup table for color grading.                    │
// │                                                                       │
// │ Physics: Arbitrary color transformation via LUT             │
// │   C_graded = LUT3D[C_input.r, C_input.g, C_input.b]         │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color (0-1)                                    │
// │   lutTexture - 3D LUT texture (512×512 typically)           │
// │   lutSize - LUT dimensions (usually 16 or 32)               │
// │                                                                       │
// │ Returns: Color-graded output                              │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 colorGradingLUT(vec3 color, sampler2D lutTexture, int lutSize) {
    // Normalize to LUT coordinates
    vec3 lutCoord = clamp(color * float(lutSize - 1), 0.0, float(lutSize - 1));

    // Compute LUT position
    // 3D LUT is typically packed into 2D texture
    float blueSlice = floor(lutCoord.b);
    float xCoord = (lutCoord.r + blueSlice * float(lutSize)) / float(lutSize * lutSize);
    float yCoord = lutCoord.g / float(lutSize);

    // Sample with trilinear interpolation
    vec3 result = texture(lutTexture, vec2(xCoord, yCoord)).rgb;

    // Interpolate blue slices if needed
    if (lutCoord.b < float(lutSize - 1)) {
        float nextBlueSlice = blueSlice + 1.0;
        float nextXCoord = (lutCoord.r + nextBlueSlice * float(lutSize)) / float(lutSize * lutSize);

        vec3 nextSlice = texture(lutTexture, vec2(nextXCoord, yCoord)).rgb;
        float blueFrac = fract(lutCoord.b);

        result = mix(result, nextSlice, blueFrac);
    }

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ whiteBalance()                                                          ║
// ║                                                                         ║
// │ Adjust white balance (color temperature).                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   temperature - Color temperature shift (-1 to 1)             │
// │                 -1 = bluer, 0 = neutral, 1 = warmer         │
// │                                                                       │
// │ Returns: White-balanced color                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 whiteBalance(vec3 color, float temperature) {
    // Temperature shift
    if (temperature > 0.0) {
        // Warm (increase red, decrease blue)
        color.r *= 1.0 + temperature * 0.5;
        color.b *= 1.0 - temperature * 0.3;
    } else {
        // Cool (decrease red, increase blue)
        color.r *= 1.0 + temperature * 0.3;
        color.b *= 1.0 - temperature * 0.5;
    }

    return clamp(color, 0.0, 1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 24C: BLOOM & GLOW INTEGRATION                                    ║
// ║                                                                           ║
// │ Bloom extraction and application to final image.              ║
// │ Realistic light bloom for luminous areas.                    ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomThreshold()                                                        ║
// ║                                                                         ║
// │ Extract bloom-eligible pixels.                                │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Tone-mapped color                                      │
// │   threshold - Luminance threshold for bloom                   │
// │   softKnee - Soft transition width                           │
// │                                                                       │
// │ Returns: Bloom mask (0-1)                                  │
// └─────────────────────────────────────────────────────────────────────────┘
float bloomThreshold(vec3 color, float threshold, float softKnee) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Soft threshold for smooth transition
    float lower = threshold - softKnee;
    float upper = threshold + softKnee;

    float bloom = smoothstep(lower, upper, luminance);

    return bloom;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ bloomIntensity()                                                        ║
// ║                                                                         ║
// │ Scale bloom intensity.                                         │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   bloomMask - Bloom contribution mask                        │
// │   bloomIntensity - Bloom strength (0-2 typical)             │
// │                                                                       │
// │ Returns: Bloom-applied color                            │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 bloomIntensity(vec3 color, float bloomMask, float bloomIntensity) {
    // Apply bloom multiplicatively
    vec3 result = color + (color * bloomMask * bloomIntensity);

    return clamp(result, 0.0, 2.0);  // Allow slight overbright for bloom
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 24D: FILMIC CURVES & CONTROL                                     ║
// ║                                                                           ║
// │ Filmic-style response curves for color grading.               ║
// │ S-curves for contrast, lift/gamma/gain for tones.           ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ filmicSCurve()                                                          ║
// ║                                                                         ║
// │ Apply S-curve for cinematic contrast.                        │
// │                                                                       │
// │ Inputs:                                                              │
// │   value - Input value (0-1)                                      │
// │   midpoint - Curve midpoint (0.5 typical)                    │
// │   contrast - Curve strength (0-2 typical)                   │
// │                                                                       │
// │ Returns: S-curved value                                   │
// └─────────────────────────────────────────────────────────────────────────┘
float filmicSCurve(float value, float midpoint, float contrast) {
    // Parametric S-curve
    float adjusted = (value - midpoint) * contrast;
    float curve = adjusted / (1.0 + abs(adjusted)) + midpoint;

    return clamp(curve, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ liftGammaGain()                                                         ║
// ║                                                                         ║
// │ Apply lift, gamma, and gain corrections.                      │
// │ Industrial color grading controls.                           │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   lift - Shadows lift (0.0-1.0)                               │
// │   gamma - Midtones gamma (0.5-2.0)                          │
// │   gain - Highlights gain (0.5-2.0)                          │
// │                                                                       │
// │ Returns: Corrected color                                  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 liftGammaGain(vec3 color, float lift, float gamma, float gain) {
    // Lift affects shadows
    vec3 result = color + vec3(lift) * (1.0 - color);

    // Gamma affects midtones (power curve)
    result = pow(result, vec3(gamma));

    // Gain affects overall (linear)
    result *= gain;

    return clamp(result, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ saturation()                                                            ║
// ║                                                                         ║
// │ Adjust color saturation.                                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   saturation - Saturation factor (0=gray, 1=normal, 2=vivid)   │
// │                                                                       │
// │ Returns: Saturated color                                  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 saturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));

    // Blend between grayscale and saturated
    vec3 result = mix(vec3(luminance), color, saturation);

    return result;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 24E: POST-PROCESSING FINALIZATION                                ║
// ║                                                                           ║
// │ Final gamma correction, dithering, and output preparation.    ║
// │ Complete post-processing pipeline closure.                  ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gammaCorrection()                                                       ║
// ║                                                                         ║
// │ Apply gamma correction for output.                          │
// │                                                                       │
// │ Physics: sRGB transfer function                            │
// │   Linear to sRGB: x^(1/2.2)                                │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Linear color                                          │
// │   gamma - Gamma exponent (2.2 typical for sRGB)            │
// │                                                                       │
// │ Returns: Gamma-corrected color                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 gammaCorrection(vec3 color, float gamma) {
    // Power law gamma correction
    return pow(clamp(color, 0.0, 1.0), vec3(1.0 / gamma));
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ dithering()                                                             ║
// ║                                                                         ║
// │ Apply dithering to reduce banding artifacts.                │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   screenPos - Screen position for noise                      │
// │   ditherAmount - Dither strength (0-0.01 typical)           │
// │                                                                       │
// │ Returns: Dithered color                                   │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 dithering(vec3 color, vec2 screenPos, float ditherAmount) {
    // Simple blue noise dither
    float noise = sin(dot(screenPos.xy, vec2(12.9898, 78.233))) * 43758.5453;
    noise = fract(noise);

    // Normalize to [-0.5, 0.5]
    noise = noise - 0.5;

    vec3 dither = color + (noise * ditherAmount);

    return clamp(dither, 0.0, 1.0);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ vignette()                                                              ║
// ║                                                                         ║
// │ Add vignette darkening at screen edges.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   color - Input color                                            │
// │   screenPos - Normalized screen position (0-1)                │
// │   vignetteAmount - Vignette strength (0-1)                   │
// │                                                                       │
// │ Returns: Vignetted color                                  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 vignette(vec3 color, vec2 screenPos, float vignetteAmount) {
    // Radial distance from center
    vec2 centered = screenPos - 0.5;
    float distance = length(centered) * 2.0;

    // Smooth fade at edges
    float vignetteMask = 1.0 - smoothstep(0.5, 1.5, distance);

    // Apply vignette
    vec3 result = color * mix(1.0, vignetteMask, vignetteAmount);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED TONE MAPPING & GRADING APPLICATION                              ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyToneMappingAndGrading(
    vec3 hdrColor,
    vec2 screenPos,
    float exposure,
    int toneMapType,  // 0=Reinhard, 1=Filmic, 2=ACES, 3=Log
    float saturationFactor,
    float contrastFactor,
    float vignetteAmount,
    bool applyDither
) {
    // Tone mapping
    vec3 toneMapped = vec3(0.0);

    if (toneMapType == 0) {
        toneMapped = toneMappingReinhard(hdrColor, exposure, 2.0);
    }
    else if (toneMapType == 1) {
        toneMapped = toneMappingFilmic(hdrColor, exposure);
    }
    else if (toneMapType == 2) {
        toneMapped = toneMappingACES(hdrColor, exposure);
    }
    else {
        toneMapped = toneMappingLogarithmic(hdrColor, exposure);
    }

    // Color grading
    vec3 graded = saturation(toneMapped, saturationFactor);
    graded = liftGammaGain(graded, 0.05, 1.0 / (1.0 + contrastFactor * 0.1), 1.0);

    // Vignette
    vec3 vignetted = vignette(graded, screenPos, vignetteAmount);

    // Dithering
    vec3 final = vignetted;
    if (applyDither) {
        final = dithering(vignetted, screenPos, 0.005);
    }

    // Gamma correction
    final = gammaCorrection(final, 2.2);

    return final;
}

#endif  // INCLUDE_TONE_MAPPING
