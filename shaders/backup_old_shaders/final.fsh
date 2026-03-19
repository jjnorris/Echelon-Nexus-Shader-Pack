// ===================================================================
// Echelon Nexus - Final Output Fragment Shader
// ===================================================================
// Purpose: Output to framebuffer with tonemapping & color grading
// Input:   colortex0 (composited scene)
// Output:  Framebuffer (gl_FragColor)
// ===================================================================

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;  // Composited scene color from composite pass

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

// ===================================================================
// TONEMAPPING OPERATORS
// ===================================================================

// ACES tonemapping (industry-standard)
vec3 toneMapACES(vec3 color) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
}

// Filmic tonemapping (balanced, realistic)
vec3 toneMapFilmic(vec3 color) {
    vec3 x = max(vec3(0.0), color - 0.004);
    return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

// Reinhard simple tonemapping (fast, basic)
vec3 toneMapReinhard(vec3 color) {
    return color / (1.0 + color);
}

// Apply exposure adjustment
vec3 applyExposure(vec3 color, float exposure) {
    return color * pow(2.0, exposure);
}

// ===================================================================
// COLOR GRADING
// ===================================================================

// Simple color grading via RGB shifts
vec3 colorGrade(vec3 color, vec3 shadows, vec3 midtones, vec3 highlights) {
    // Separate into brightness ranges
    float lum = luminance(color);

    // Blend color adjustments based on brightness
    vec3 result = color;
    if (lum < 0.33) {
        result *= mix(vec3(1.0), shadows, 0.3);
    } else if (lum < 0.66) {
        result *= mix(vec3(1.0), midtones, 0.3);
    } else {
        result *= mix(vec3(1.0), highlights, 0.3);
    }

    return result;
}

// Saturation adjustment
vec3 adjustSaturation(vec3 color, float saturation) {
    float lum = luminance(color);
    vec3 gray = vec3(lum);
    return mix(gray, color, saturation);
}

// Contrast adjustment
vec3 adjustContrast(vec3 color, float contrast) {
    return mix(vec3(0.5), color, contrast);
}

// ===================================================================
// MAIN FINAL PASS
// ===================================================================

void main() {
    // Read composited scene color
    vec3 sceneColor = texture(colortex0, vTexCoord).rgb;

    // Step 1: Apply exposure adjustment
    // (Will be controlled by TONEMAP_EXPOSURE option in Phase 6+)
    vec3 exposed = applyExposure(sceneColor, 0.0);  // Default exposure = 0.0 (no change)

    // Step 2: Apply tonemapping
    // (Will cycle through TONEMAP_OPERATOR option in Phase 6+)
    // For now, use ACES (best perceptual result)
    vec3 tonemapped = toneMapACES(exposed);

    // Step 3: Apply color grading
    // (Will use LUT or color grading parameters in Phase 11)
    // For now, apply simple saturation boost
    vec3 colorGraded = adjustSaturation(tonemapped, 1.1);  // 10% saturation boost

    // Step 4: Final output (linear to sRGB for display)
    vec3 finalColor = linearToSrgb(colorGraded);

    gl_FragColor = vec4(finalColor, 1.0);
}
