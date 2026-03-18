// ===================================================================
// Dynamic Sky Dome (Phase 24)
// ===================================================================
// Physical sky rendering with Rayleigh and Mie scattering.

#ifndef INCLUDE_SKY_DOME
#define INCLUDE_SKY_DOME

// ===================================================================
// RAYLEIGH SCATTERING
// ===================================================================

// Compute Rayleigh scattering for sky color
vec3 rayleighScattering(
    vec3 lightDir,
    vec3 viewDir,
    float rayleighCoeff
) {
    // Optical depth increases with zenith angle
    float zenith = acos(viewDir.y);
    float opticalDepth = 1.0 / (cos(zenith) + 0.50949);

    // Rayleigh coefficient (stronger for blue light)
    vec3 rayleighWavelengths = vec3(
        1.0 / pow(0.65, 4.0),  // Red
        1.0 / pow(0.55, 4.0),  // Green
        1.0 / pow(0.45, 4.0)   // Blue (stronger)
    );

    // Phase function
    float cosTheta = dot(lightDir, viewDir);
    float phase = 0.75 * (1.0 + cosTheta * cosTheta);

    vec3 extinction = exp(-rayleighWavelengths * rayleighCoeff * opticalDepth);

    return (1.0 - extinction) * phase * rayleighCoeff;
}

// ===================================================================
// MIE SCATTERING
// ===================================================================

// Henyey-Greenstein phase function (Mie)
float miePhaseFunction(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265359 * pow(denom, 1.5));
}

// Mie scattering (aerosol particles)
vec3 mieScattering(
    vec3 lightDir,
    vec3 viewDir,
    float mieCoeff,
    float aerosolDensity
) {
    float cosTheta = dot(lightDir, viewDir);
    float phase = miePhaseFunction(cosTheta, 0.8);

    // Mie is more white than Rayleigh
    vec3 scatterColor = vec3(1.0);

    return scatterColor * mieCoeff * aerosolDensity * phase;
}

// ===================================================================
// COMPLETE SKY COLOR
// ===================================================================

vec3 computeSkyColor(
    vec3 lightDir,
    vec3 viewDir,
    float rayleighCoeff,
    float mieCoeff,
    float aerosolDensity
) {
    vec3 sky = rayleighScattering(lightDir, viewDir, rayleighCoeff);
    sky += mieScattering(lightDir, viewDir, mieCoeff, aerosolDensity);

    return sky;
}

// ===================================================================
// SUN DISK
// ===================================================================

vec3 sunDisk(
    vec3 viewDir,
    vec3 lightDir,
    vec3 sunColor
) {
    float angle = acos(dot(viewDir, lightDir));
    float sunSize = 0.01;  // Angular size

    if (angle < sunSize) {
        // Sharp sun disk
        return sunColor * (1.0 - angle / sunSize);
    }

    return vec3(0.0);
}

#endif // INCLUDE_SKY_DOME
