// ===================================================================
// Airy Disk & Diffraction Spikes (Phase 17)
// ===================================================================
// Airy disk patterns from circular aperture diffraction and
// diffraction spike rendering for bright point light sources.
//
// Theory: Circular aperture creates Airy pattern (series of rings).
// Hexagonal apertures create symmetric spikes.

#ifndef INCLUDE_AIRY_DISK
#define INCLUDE_AIRY_DISK

// ===================================================================
// AIRY PATTERN RENDERING
// ===================================================================

// Simplified Airy disk pattern
// I(r) ≈ [2*J1(x)/x]^2 where x = pi*D*r/(lambda*f)
float airyIntensity(float radius, float apertureDiameter, float wavelength) {
    if (radius < 0.0001) return 1.0;

    float x = 3.14159265359 * apertureDiameter * radius / wavelength;

    // Bessel J1 approximation (high accuracy for x < 10)
    // J1(x) ≈ sin(x)/x for small x
    float j1;
    if (x < 8.0) {
        j1 = sin(x) / (x * x) - cos(x) / x;
    } else {
        j1 = sqrt(2.0 / (3.14159265359 * x)) * sin(x - 3.0 * 3.14159265359 / 4.0);
    }

    float airy = 2.0 * j1 / x;
    return airy * airy;
}

// Complete Airy disk pattern (primary disk + rings)
float airyDiskPattern(vec2 screenCoord, vec2 centerCoord, float apertureDiameter) {
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    // Use green wavelength as reference
    float wavelength = 0.00055;  // 550nm normalized

    float intensity = airyIntensity(radius, apertureDiameter, wavelength);

    // Add ring structure
    // First dark ring at x ≈ 3.83
    // First bright ring at x ≈ 5.14
    float rings = 0.0;
    if (radius > 0.0) {
        rings = 0.3 * sin(radius * 100.0) / (1.0 + radius * 50.0);
    }

    return intensity + rings * 0.1;
}

// ===================================================================
// SPECTRAL AIRY DISK
// ===================================================================

// Separate Airy disks for each spectral channel
struct SpectralAiry {
    float red;
    float green;
    float blue;
};

SpectralAiry spectralAiryDisk(vec2 screenCoord, vec2 centerCoord, float apertureDiameter) {
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    SpectralAiry result;

    // Wavelengths for each channel
    float wavelengthRed = 0.00065;    // 650nm
    float wavelengthGreen = 0.00055;  // 550nm
    float wavelengthBlue = 0.00045;   // 450nm

    // Airy disk for each channel (different size due to wavelength)
    result.red = airyIntensity(radius, apertureDiameter, wavelengthRed);
    result.green = airyIntensity(radius, apertureDiameter, wavelengthGreen);
    result.blue = airyIntensity(radius, apertureDiameter, wavelengthBlue);

    return result;
}

// Convert spectral Airy to RGB
vec3 spectralAiryToRGB(SpectralAiry airy) {
    return vec3(airy.red, airy.green, airy.blue);
}

// ===================================================================
// DIFFRACTION SPIKES (HEXAGONAL APERTURE)
// ===================================================================

// Diffraction spikes from hexagonal aperture (6 spikes)
float hexagonalDiffraction(vec2 screenCoord, vec2 centerCoord) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    // Hexagonal: 6 spikes at 60° intervals
    float spikePattern = 0.0;
    for (int i = 0; i < 6; i++) {
        float spikeAngle = float(i) * 1.0471975512; // 60°
        float angleDiff = abs(angle - spikeAngle);

        // Wrap angle difference to [-pi, pi]
        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        // Narrow spike (approximately sinc function)
        float spikeWidth = 0.02;
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));

        // Radial falloff
        spike *= exp(-radius * 0.5);

        spikePattern += spike;
    }

    return spikePattern / 6.0;
}

// Diffraction spikes from rectangular aperture (4 spikes)
float rectangularDiffraction(vec2 screenCoord, vec2 centerCoord, float aspectRatio) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    // Rectangular: 4 spikes (horizontal/vertical dominant based on aspect ratio)
    float spikePattern = 0.0;

    for (int i = 0; i < 4; i++) {
        float spikeAngle = float(i) * 1.5707963267; // 90°
        float angleDiff = abs(angle - spikeAngle);

        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        // Aspect ratio affects spike width
        float spikeWidth = (i % 2 == 0) ? 0.015 : (0.015 * aspectRatio);
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));

        // Radial falloff (faster for rectangular)
        spike *= exp(-radius * 0.7);

        spikePattern += spike;
    }

    return spikePattern / 4.0;
}

// ===================================================================
// DIFFRACTION CROSS (8-POINTED STAR)
// ===================================================================

// 8-pointed star diffraction pattern (octagonal aperture)
float octagonalDiffraction(vec2 screenCoord, vec2 centerCoord) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    // 8 spikes at 45° intervals
    float spikePattern = 0.0;
    for (int i = 0; i < 8; i++) {
        float spikeAngle = float(i) * 0.7853981634; // 45°
        float angleDiff = abs(angle - spikeAngle);

        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        float spikeWidth = 0.01;
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));
        spike *= exp(-radius * 0.5);

        spikePattern += spike;
    }

    return spikePattern / 8.0;
}

// ===================================================================
// COMPOSITE DIFFRACTION EFFECT
// ===================================================================

// Combine Airy disk with diffraction spikes
float completeDiffractionPattern(
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureDiameter,
    int apertureType
) {
    float result = airyDiskPattern(screenCoord, centerCoord, apertureDiameter);

    // Add spikes based on aperture shape
    if (apertureType == 0) {
        // Circular: no spikes (default)
        // result += 0.0;
    } else if (apertureType == 1) {
        // Hexagonal (typical for telescope/high-end camera)
        result += hexagonalDiffraction(screenCoord, centerCoord) * 0.5;
    } else if (apertureType == 2) {
        // Rectangular (camera sensor)
        result += rectangularDiffraction(screenCoord, centerCoord, 1.5) * 0.4;
    } else if (apertureType == 3) {
        // Octagonal (premium optics)
        result += octagonalDiffraction(screenCoord, centerCoord) * 0.6;
    }

    return result;
}

#endif // INCLUDE_AIRY_DISK
