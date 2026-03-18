// ===================================================================
// Spectral Bloom & Chromatic Aberration (Phase 17)
// ===================================================================
// Spectral decomposition-based bloom for wavelength-dependent
// light dispersion and realistic chromatic aberration.

#ifndef INCLUDE_SPECTRAL_BLOOM
#define INCLUDE_SPECTRAL_BLOOM

#include "diffraction.glsl"

// ===================================================================
// SPECTRAL BLOOM GENERATION
// ===================================================================

// Compute spectral bloom by decomposing light by wavelength
// Returns bloom intensity for each spectral band
struct SpectralBloom {
    float red;      // 650nm
    float green;    // 550nm
    float blue;     // 450nm
};

SpectralBloom computeSpectralBloom(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    vec3 lightColor,
    float bloomStrength
) {
    vec2 delta = screenCoord - lightSourceCoord;
    float distance = length(delta);

    SpectralBloom bloom;

    // Compute bloom for each wavelength
    // Longer wavelengths (red) disperse more
    // Shorter wavelengths (blue) disperse less

    float dispersionRed = 0.3 * bloomStrength;
    float dispersionGreen = 0.2 * bloomStrength;
    float dispersionBlue = 0.1 * bloomStrength;

    // Gaussian falloff for each channel with different widths
    bloom.red = lightColor.r * exp(-(distance * distance) / (2.0 * dispersionRed * dispersionRed));
    bloom.green = lightColor.g * exp(-(distance * distance) / (2.0 * dispersionGreen * dispersionGreen));
    bloom.blue = lightColor.b * exp(-(distance * distance) / (2.0 * dispersionBlue * dispersionBlue));

    return bloom;
}

// Convert spectral bloom to RGB
vec3 spectralBloomToRGB(SpectralBloom bloom) {
    return vec3(bloom.red, bloom.green, bloom.blue);
}

// ===================================================================
// CHROMATIC ABERRATION
// ===================================================================

// Simulate lens chromatic aberration: wavelength-dependent refraction
// Different channels refract at different angles through lens
vec3 chromaticAberrationOffset(
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureAmount
) {
    vec2 delta = screenCoord - centerCoord;
    vec2 direction = normalize(delta);
    float distance = length(delta);

    // Aberration amount increases with distance from center (radial)
    // Wavelength-dependent: red < green < blue (shorter = more)

    float aberrationRed = distance * apertureAmount * 0.8;
    float aberrationGreen = distance * apertureAmount * 1.0;
    float aberrationBlue = distance * apertureAmount * 1.2;

    // Return as offsets (in screen space)
    return vec3(aberrationRed, aberrationGreen, aberrationBlue);
}

// Apply chromatic aberration by sampling RGB channels at offset positions
vec3 applyChromaticAberration(
    sampler2D colorTexture,
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureAmount,
    vec2 invResolution
) {
    // Compute aberration offsets
    vec3 aberration = chromaticAberrationOffset(screenCoord, centerCoord, apertureAmount);

    // Direction from center to current pixel
    vec2 delta = screenCoord - centerCoord;
    vec2 direction = normalize(delta);

    // Sample each channel with offset
    vec2 offsetR = screenCoord - direction * aberration.r * invResolution;
    vec2 offsetG = screenCoord - direction * aberration.g * invResolution;
    vec2 offsetB = screenCoord - direction * aberration.b * invResolution;

    vec3 color;
    color.r = texture(colorTexture, offsetR).r;
    color.g = texture(colorTexture, offsetG).g;
    color.b = texture(colorTexture, offsetB).b;

    return color;
}

// ===================================================================
// MULTI-ORDER SPECTRAL BLOOM
// ===================================================================

// Bloom with multiple spectral orders (higher order = fainter)
struct MultiOrderBloom {
    vec3 primary;    // First order
    vec3 secondary;  // Second order
    vec3 tertiary;   // Third order
};

MultiOrderBloom computeMultiOrderSpectralBloom(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    vec3 lightColor,
    float bloomStrength
) {
    MultiOrderBloom result;
    vec2 delta = screenCoord - lightSourceCoord;
    float distance = length(delta);

    // Primary order (strongest)
    SpectralBloom primary = computeSpectralBloom(
        screenCoord, lightSourceCoord, lightColor, bloomStrength
    );
    result.primary = spectralBloomToRGB(primary);

    // Secondary order (weaker, shifted outward)
    float secondaryDist = distance * 1.5;
    vec2 secondaryCoord = lightSourceCoord + normalize(delta) * secondaryDist;
    SpectralBloom secondary = computeSpectralBloom(
        screenCoord, secondaryCoord, lightColor * 0.3, bloomStrength * 0.5
    );
    result.secondary = spectralBloomToRGB(secondary);

    // Tertiary order (very weak)
    float tertiaryDist = distance * 2.5;
    vec2 tertiaryCoord = lightSourceCoord + normalize(delta) * tertiaryDist;
    SpectralBloom tertiary = computeSpectralBloom(
        screenCoord, tertiaryCoord, lightColor * 0.1, bloomStrength * 0.2
    );
    result.tertiary = spectralBloomToRGB(tertiary);

    return result;
}

// Combine multi-order blooms
vec3 combineMultiOrderBloom(MultiOrderBloom bloom) {
    return bloom.primary + bloom.secondary + bloom.tertiary;
}

// ===================================================================
// SPECTRAL LENS EFFECTS
// ===================================================================

// Lens distortion with spectral variation
vec2 spectralLensDistortion(
    vec2 screenCoord,
    vec2 lensCenter,
    float distortionStrength
) {
    vec2 delta = screenCoord - lensCenter;
    float radius = length(delta);

    // Distortion increases outward (barrel)
    float distortion = 1.0 + radius * distortionStrength * 0.1;

    // Spectral variation: different wavelengths distort differently
    // Red distorts least, blue distorts most
    vec2 newCoord = lensCenter + delta / distortion;

    return newCoord;
}

// ===================================================================
// LENS FLARE ARTIFACTS
// ===================================================================

// Simulate lens flare with spectral components
vec3 lensFlarePrincipal(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    float strength
) {
    vec2 delta = screenCoord - lightSourceCoord;
    float distance = length(delta);

    // Main lens reflection (opposite side of light source)
    vec2 flareCoord = lightSourceCoord * (-0.5);
    float flareDist = length(screenCoord - flareCoord);

    // Glow around flare
    float flareBrightness = exp(-(flareDist * flareDist) / 0.02) * strength;

    // Spectral variation in flare
    vec3 flareColor = vec3(1.0, 0.8, 0.6) * flareBrightness;

    return flareColor;
}

// Lens flare rays (diffraction spikes)
vec3 lensFlareRays(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    float rayStrength
) {
    vec2 delta = screenCoord - lightSourceCoord;
    float angle = atan(delta.y, delta.x);
    float distance = length(delta);

    // Create ray pattern (typically 6 or 8 rays)
    float rayPattern = 0.0;
    for (int i = 0; i < 6; i++) {
        float rayAngle = float(i) * 3.14159265359 / 3.0;  // 60° spacing
        float angleDiff = abs(angle - rayAngle);
        angleDiff = min(angleDiff, 2.0 * 3.14159265359 - angleDiff);  // Wrap around

        // Narrow ray
        rayPattern += exp(-(angleDiff * angleDiff) / 0.01) * exp(-distance * 0.1);
    }

    // Spectral coloration of rays
    vec3 rayColor = vec3(1.0, 0.8, 0.6) * rayPattern * rayStrength;

    return rayColor;
}

#endif // INCLUDE_SPECTRAL_BLOOM
