// ===================================================================
// Echelon Nexus - Atmospheric & Sky Rendering
// ===================================================================
// Provides sky dome, fog, and atmospheric effects.
// ===================================================================

#ifndef INCLUDE_ATMOSPHERE
#define INCLUDE_ATMOSPHERE

#include "constants.glsl"
#include "functions.glsl"

// ===================================================================
// SKY COLOR COMPUTATION
// ===================================================================

// Simple Rayleigh scattering sky (approximation)
vec3 computeSkyColor(vec3 rayDir, vec3 sunDir) {
    float sunDot = dot(rayDir, sunDir);
    sunDot = clamp(sunDot, -0.1, 1.0);

    // Sky gradient: blue at horizon, darker at zenith
    float upness = rayDir.y * 0.5 + 0.5;
    vec3 skyColor = mix(
        vec3(0.5, 0.7, 1.0),  // Horizon: light blue
        vec3(0.1, 0.3, 0.8),  // Zenith: darker blue
        upness
    );

    // Sun disc
    float sunIntensity = smoothstep(0.1, 0.0, distance(rayDir, sunDir));
    vec3 sunColor = vec3(1.0, 0.9, 0.7);

    return mix(skyColor, sunColor, sunIntensity * 0.8);
}

// ===================================================================
// FOG COMPUTATION
// ===================================================================

// Linear fog
vec3 applyLinearFog(vec3 color, vec3 fogColor, float distance, float fogStart, float fogEnd) {
    float fogFactor = clamp((fogEnd - distance) / (fogEnd - fogStart), 0.0, 1.0);
    return mix(fogColor, color, fogFactor);
}

// Exponential fog (more realistic)
vec3 applyExponentialFog(vec3 color, vec3 fogColor, float distance, float fogDensity) {
    float fogFactor = exp(-distance * distance * fogDensity);
    return mix(fogColor, color, fogFactor);
}

// Height-based fog (fog density varies with height)
vec3 applyHeightFog(vec3 color, vec3 fogColor, vec3 worldPos, float fogDensity) {
    float heightFactor = clamp(worldPos.y * 0.01, 0.0, 1.0);
    float effectiveDensity = fogDensity * (1.0 - heightFactor);
    float distance = length(worldPos);
    return applyExponentialFog(color, fogColor, distance, effectiveDensity);
}

// ===================================================================
// VOLUMETRIC FOG
// ===================================================================

// Simple volumetric fog with raymarch
vec3 volumetricFog(
    vec3 rayOrigin,
    vec3 rayDir,
    float maxDistance,
    int numSteps
) {
    vec3 fogAccum = vec3(0.0);
    float stepSize = maxDistance / float(numSteps);

    for (int i = 0; i < numSteps; i++) {
        vec3 samplePos = rayOrigin + rayDir * float(i) * stepSize;

        // Fog density at this position
        float density = 0.1 * (1.0 - samplePos.y * 0.01);
        density = max(density, 0.0);

        // Accumulate fog
        fogAccum += density * stepSize;
    }

    return vec3(fogAccum);
}

// ===================================================================
// TIME-OF-DAY LIGHTING
// ===================================================================

// Compute sun/moon direction and brightness based on time
void computeSunMoonState(
    float timeOfDay,
    out vec3 sunDir,
    out float sunBrightness,
    out vec3 moonDir,
    out float moonBrightness
) {
    // timeOfDay: [0, 1] where 0.25 = sunrise, 0.5 = noon, 0.75 = sunset, 0 = midnight

    // Sun arc (rises at 0.25, sets at 0.75)
    float sunAngle = (timeOfDay - 0.25) * PI;
    sunDir = normalize(vec3(
        sin(sunAngle),
        max(0.0, cos(sunAngle)),
        0.0
    ));

    // Sun brightness (dimmer at sunrise/sunset, brightest at noon)
    float noonness = 1.0 - abs(timeOfDay - 0.5) * 2.0;
    sunBrightness = max(0.0, noonness);

    // Moon: opposite of sun
    moonDir = -sunDir;
    moonBrightness = 1.0 - noonness;
}

// ===================================================================
// ATMOSPHERIC SCATTERING (Simple approximation)
// ===================================================================

// Apply simple atmospheric haze
vec3 applyAtmosphericHaze(vec3 color, float distance, vec3 skyColor) {
    float hazeFactor = 1.0 - exp(-distance * 0.001);
    return mix(color, skyColor, hazeFactor * 0.3);
}

// ===================================================================
// WEATHER EFFECTS
// ===================================================================

// Apply rain/storm darkening
vec3 applyRainDarkening(vec3 color, float rainIntensity) {
    return color * mix(1.0, 0.6, rainIntensity);
}

// Apply thunder flash
vec3 applyThunderFlash(vec3 color, float flashIntensity) {
    return mix(color, vec3(1.0), flashIntensity * 0.5);
}

// ===================================================================
// HORIZON BLENDING
// ===================================================================

// Smooth blend between water and sky at horizon
vec3 blendSkyWater(vec3 skyColor, vec3 waterColor, float horizonDot) {
    // horizonDot: dot product between ray direction and horizon plane normal
    float horizonBlend = smoothstep(-0.1, 0.1, horizonDot);
    return mix(waterColor, skyColor, horizonBlend);
}

// ===================================================================
// AERIAL PERSPECTIVE
// ===================================================================

// Distance-based color desaturation (aerial perspective)
vec3 applyAerialPerspective(vec3 color, float distance, float perspectiveDistance) {
    float perspectiveFactor = clamp(distance / perspectiveDistance, 0.0, 1.0);
    vec3 gray = vec3(luminance(color));
    return mix(color, gray, perspectiveFactor * 0.3);
}

// ===================================================================
// END OF ATMOSPHERE MODULE
// ===================================================================

#endif // INCLUDE_ATMOSPHERE
