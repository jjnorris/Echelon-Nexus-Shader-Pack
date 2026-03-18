// ===================================================================
// Diffraction-Based Effects (Phase 17)
// ===================================================================
// Wave-based diffraction patterns for caustics, god rays, and
// diffraction spike effects using Fresnel diffraction.
//
// Theory: Fresnel diffraction occurs when waves spread around edges.
// In rendering, we simulate this with sine waves and interference.
//
// References:
//   - The Fresnel Equations and Rayleigh Scattering (Born & Wolf, 1999)
//   - Caustics and Refraction by Precomputing Light Field Analysis
//     (Wyman, 2011)

#ifndef INCLUDE_DIFFRACTION
#define INCLUDE_DIFFRACTION

// ===================================================================
// FRESNEL DIFFRACTION SIMULATION
// ===================================================================

// Compute Fresnel diffraction intensity at a point
// Uses Fresnel integral approximation for fast computation
float fresnelDiffraction(vec2 screenCoord, float wavelength, float obstacleDistance) {
    // Fresnel number: F = a^2 / (lambda * z)
    // where a = obstacle size, lambda = wavelength, z = distance
    float fresnelNum = pow(obstacleDistance, 2.0) / (wavelength * 10.0);

    // Approximate Fresnel integral using oscillating term
    float phase = 3.14159265359 * fresnelNum * dot(screenCoord, screenCoord);
    float diffraction = 0.5 + 0.5 * cos(phase);

    return diffraction;
}

// Single-slit diffraction pattern (Fraunhofer approximation)
// Returns intensity distribution for light passing through slit
float singleSlitDiffraction(float angle, float slitWidth, float wavelength) {
    // Single-slit diffraction: I = sinc^2(pi * a * sin(theta) / lambda)
    float beta = 3.14159265359 * slitWidth * sin(angle) / wavelength;

    if (abs(beta) < 0.001) return 1.0;

    float sinc = sin(beta) / beta;
    return sinc * sinc;
}

// Double-slit interference pattern
float doubleSlitInterference(float angle, float slitSeparation, float wavelength) {
    // Phase difference between two slits
    float delta = 3.14159265359 * slitSeparation * sin(angle) / wavelength;

    // Intensity: I = cos^2(delta/2) * sinc^2(delta/2)
    float interference = cos(delta * 0.5);
    return interference * interference;
}

// ===================================================================
// DIFFRACTION GRATING
// ===================================================================

// Diffraction grating: periodic array of slits
// Used for spectral dispersion effects
float diffractionGrating(
    float angle,
    float gratingSpacing,
    float wavelengthNorm,
    int order
) {
    // Grating equation: d * sin(theta) = m * lambda
    // We compute whether given angle satisfies the equation
    float expectedAngle = asin(float(order) * wavelengthNorm / gratingSpacing);

    // Narrow peak around expected angle
    float angleDiff = abs(angle - expectedAngle);
    float peakWidth = 0.01;  // Narrow spectral line

    return exp(-(angleDiff * angleDiff) / (peakWidth * peakWidth));
}

// ===================================================================
// SPECTRAL DECOMPOSITION
// ===================================================================

// Map wavelength to RGB color (visible spectrum)
// wavelength: normalized wavelength (0.4-0.7um range, normalized to 0-1)
vec3 wavelengthToColor(float wavelength) {
    vec3 color = vec3(0.0);

    // Visible spectrum: violet < blue < cyan < green < yellow < orange < red
    if (wavelength < 0.25) {
        // Violet (380-420nm)
        color = mix(vec3(0.5, 0.0, 1.0), vec3(0.0, 0.0, 1.0), wavelength / 0.25);
    } else if (wavelength < 0.35) {
        // Blue (420-495nm)
        color = mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 0.5, 1.0), (wavelength - 0.25) / 0.1);
    } else if (wavelength < 0.5) {
        // Cyan to Green (495-570nm)
        color = mix(vec3(0.0, 0.5, 1.0), vec3(0.0, 1.0, 0.0), (wavelength - 0.35) / 0.15);
    } else if (wavelength < 0.6) {
        // Yellow (570-590nm)
        color = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0), (wavelength - 0.5) / 0.1);
    } else if (wavelength < 0.75) {
        // Orange to Red (590-700nm)
        color = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), (wavelength - 0.6) / 0.15);
    } else {
        // Deep Red
        color = vec3(1.0, 0.0, 0.0);
    }

    return color;
}

// Compute spectral response for given angle
// Returns RGB decomposition of spectral power
vec3 spectralResponse(float angle, float wavelengthMin, float wavelengthMax) {
    // Compute grating equation for each order
    vec3 color = vec3(0.0);

    // Primary spectral lines (first few orders)
    for (int order = -2; order <= 2; order++) {
        // Effective wavelengths for each channel (approximate)
        vec3 wavelengths = vec3(650.0, 550.0, 450.0) / 1000.0;  // Normalized to 0-1 range

        for (int ch = 0; ch < 3; ch++) {
            float w = (ch == 0) ? wavelengths.r : ((ch == 1) ? wavelengths.g : wavelengths.b);
            float grating = diffractionGrating(angle, 0.1, w, order);
            if (ch == 0) color.r += grating;
            else if (ch == 1) color.g += grating;
            else color.b += grating;
        }
    }

    return color / 3.0;
}

// ===================================================================
// CHROMATIC ABERRATION FROM DIFFRACTION
// ===================================================================

// Simulate chromatic aberration as dispersion through grating/lens
// Different wavelengths refract at slightly different angles
vec3 chromaticAberration(vec2 screenCoord, vec2 centerCoord, float strength) {
    // Distance from center
    vec2 dir = normalize(screenCoord - centerCoord);
    float dist = length(screenCoord - centerCoord);

    // Sample each channel at slightly different positions
    // Red: less aberration
    // Green: moderate aberration
    // Blue: most aberration (shorter wavelength)

    vec2 offsetR = centerCoord + dir * (dist * (1.0 - strength * 0.02));
    vec2 offsetG = centerCoord + dir * (dist * (1.0 - strength * 0.01));
    vec2 offsetB = centerCoord + dir * (dist * (1.0 - strength * 0.03));

    // Return offsets (to be applied to texture sampling)
    return vec3(length(offsetR - screenCoord), length(offsetG - screenCoord), length(offsetB - screenCoord));
}

// ===================================================================
// AIRY DISK DIFFRACTION
// ===================================================================

// Airy disk: circular diffraction pattern from circular aperture
// Used for bright source blooms (point lights, sun)
float airyDisk(vec2 screenCoord, vec2 centerCoord, float apertureDiameter, float wavelength) {
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    // Airy pattern: I(r) = [2*J1(x)/x]^2 where x = pi*d*r/(f*lambda)
    // Simplified: use Bessel function approximation
    float x = 3.14159265359 * apertureDiameter * radius / wavelength;

    if (x < 0.001) return 1.0;

    // Bessel J1 approximation
    float j1 = sin(x) / (x * x) - cos(x) / x;
    float airy = 2.0 * j1 / x;

    return airy * airy;
}

// Airy disk spike pattern (diffraction spikes from hexagonal aperture)
float diffractospike(vec2 screenCoord, vec2 centerCoord, float wavelength, int spikes) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    // Create spike pattern
    float spikeAngleStep = 3.14159265359 / float(spikes);
    float angleToNearest = abs(mod(angle, spikeAngleStep) - spikeAngleStep * 0.5);

    // Narrow spike
    float spike = exp(-(angleToNearest * angleToNearest) / 0.01);

    // Modulate by distance (falloff)
    float falloff = 1.0 / (1.0 + radius * radius * 0.1);

    return spike * falloff;
}

#endif // INCLUDE_DIFFRACTION
