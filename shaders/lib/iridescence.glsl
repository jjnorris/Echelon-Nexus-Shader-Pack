// ===================================================================
// Iridescence Effects (Phase 16)
// ===================================================================
// Viewing-angle dependent color variation for iridescent materials
// (oil slicks, butterfly wings, soap bubbles, mother-of-pearl).

#ifndef INCLUDE_IRIDESCENCE
#define INCLUDE_IRIDESCENCE

// ===================================================================
// IRIDESCENT COLOR MAPPING
// ===================================================================

// Generate iridescent color based on viewing angle
// Returns HSV-space color that varies smoothly with angle
vec3 iridsentColor(float angle, float saturation, float brightness) {
    // Normalize angle to [0, 1]
    float t = angle / 1.5707963; // Divide by pi/2

    // Hue rotation: blue (240°) -> green (120°) -> red (0°) -> magenta (300°) -> blue
    float hue = 240.0 - t * 240.0;  // 240° to 0°
    if (hue < 0.0) hue += 360.0;

    // Saturation: peaks at ~45° (glancing angle), lower at normal
    float satMod = sin(angle) * saturation;

    // Brightness: dips at certain angles due to interference
    float brightMod = 0.5 + 0.5 * cos(angle * 4.0) * brightness;

    // Convert HSV to RGB
    return hsv2rgb(vec3(hue / 360.0, satMod, brightMod));
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// RGB to HSV conversion (for texture analysis)
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// ===================================================================
// LAYERED IRIDESCENCE
// ===================================================================

// Multi-layer iridescence with phase interference
// Returns color and intensity for multiple interference orders
struct IridescenceResult {
    vec3 color;      // Final iridescent color
    float intensity; // Intensity modifier
    float order;     // Interference order (useful for feedback)
};

IridescenceResult computeLayeredIridescence(
    float viewAngle,
    float thickness,
    float n_film,
    float strength,
    int orders
) {
    IridescenceResult result = IridescenceResult(vec3(0.0), 0.0, 0.0);

    // Compute iridescence color (primary effect)
    vec3 baseColor = iridsentColor(viewAngle, strength, 0.5);

    // Compute intensity modulation from optical path
    // Simulates multiple scattering orders
    float totalIntensity = 0.0;
    for (int i = 1; i <= orders; i++) {
        float opd = float(i) * 2.0 * thickness;
        float phase = 2.0 * 3.14159265359 * opd / 0.55;  // Green wavelength
        float orderIntensity = (1.0 + cos(phase)) * 0.5;
        totalIntensity += orderIntensity / float(i);  // Dim higher orders
    }
    totalIntensity /= float(orders);

    result.color = baseColor;
    result.intensity = totalIntensity;
    result.order = float(orders);

    return result;
}

// ===================================================================
// PEACOCK-FEATHER STYLE IRIDESCENCE
// ===================================================================

// Mimics the sharp color transitions seen in peacock feathers
// Uses discontinuous colorspace transitions for distinct bands
vec3 peacockIridescence(float angle) {
    // Create distinct color bands with smooth transitions between them
    float t = angle / 1.5707963;

    vec3 color;
    if (t < 0.25) {
        // Deep blue band
        color = mix(vec3(0.0, 0.0, 0.3), vec3(0.0, 0.3, 0.8), t / 0.25);
    } else if (t < 0.5) {
        // Cyan to green transition
        color = mix(vec3(0.0, 0.3, 0.8), vec3(0.0, 0.8, 0.4), (t - 0.25) / 0.25);
    } else if (t < 0.75) {
        // Green to yellow transition
        color = mix(vec3(0.0, 0.8, 0.4), vec3(0.8, 0.8, 0.0), (t - 0.5) / 0.25);
    } else {
        // Yellow to red transition
        color = mix(vec3(0.8, 0.8, 0.0), vec3(0.8, 0.1, 0.0), (t - 0.75) / 0.25);
    }

    return color;
}

// ===================================================================
// SOAP-BUBBLE STYLE IRIDESCENCE
// ===================================================================

// Creates the characteristic color progression of thin films
// Produces gradual transitions from blue/violet through all colors
vec3 soapBubbleIridescence(float angle, float thickness) {
    float t = angle / 1.5707963;

    // Phase calculation for true thin-film colors
    float opd = 2.0 * thickness * cos(angle);
    vec3 wavelengths = vec3(650.0, 550.0, 450.0);  // R, G, B wavelengths in nm
    vec3 phases = (2.0 * 3.14159265359 * opd) / wavelengths;

    // Compute intensity for each channel (thin-film interference)
    vec3 intensities = vec3(
        0.5 + 0.5 * cos(phases.r),
        0.5 + 0.5 * cos(phases.g),
        0.5 + 0.5 * cos(phases.b)
    );

    return intensities;
}

#endif // INCLUDE_IRIDESCENCE
