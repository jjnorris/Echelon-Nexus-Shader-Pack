// ===================================================================
// Echelon Nexus - Volumetric Effects (Clouds, Fog, Volumetrics)
// ===================================================================
// Ray-marched volumetric effects with approximated scattering.
// ===================================================================

#ifndef INCLUDE_VOLUMETRIC
#define INCLUDE_VOLUMETRIC

#include "constants.glsl"
#include "functions.glsl"
#include "lib/noise.glsl"

// ===================================================================
// VOLUMETRIC CLOUDS
// ===================================================================

// Simple Perlin-like noise-based cloud density
float cloudDensity(vec3 position, int octaves) {
    float density = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
        float sample = sin(position.x * frequency) * cos(position.z * frequency);
        density += sample * amplitude;

        maxAmplitude += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return density / maxAmplitude * 0.5 + 0.5;
}

// 2D cloud shape (for sky dome)
float cloudShape(vec2 position, int octaves) {
    float cloud = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
        float sample = sin(position.x * frequency + iTime) * cos(position.y * frequency);
        cloud += sample * amplitude;

        maxAmplitude += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return cloud / maxAmplitude * 0.5 + 0.5;
}

// Cloud rendering with volumetric scattering (simplified)
vec3 renderVolumetricClouds(
    vec3 rayOrigin,
    vec3 rayDir,
    float maxDistance,
    int marchSteps,
    int octaves
) {
    vec3 cloudColor = vec3(0.0);
    float transmittance = 1.0;

    float stepSize = maxDistance / float(marchSteps);

    for (int i = 0; i < marchSteps; i++) {
        vec3 samplePos = rayOrigin + rayDir * (float(i) + 0.5) * stepSize;

        // Cloud density at this position
        float density = cloudDensity(samplePos, octaves);
        density = max(0.0, density - 0.4);  // Threshold

        if (density > 0.0) {
            // Simple in-scattering from sun
            float sunLight = max(0.0, dot(rayDir, vec3(0.5, 0.8, 0.2)));
            vec3 cloudSample = vec3(1.0) * density * sunLight;

            // Accumulate
            cloudColor += cloudSample * transmittance * stepSize;
            transmittance *= exp(-density * stepSize);

            if (transmittance < 0.01) {
                break;  // Early exit if fully opaque
            }
        }
    }

    return cloudColor;
}

// ===================================================================
// VOLUMETRIC FOG
// ===================================================================

// Volumetric fog with light attenuation
vec3 volumetricFog(
    vec3 rayOrigin,
    vec3 rayDir,
    vec3 lightDir,
    vec3 lightColor,
    float maxDistance,
    int marchSteps
) {
    vec3 fogColor = vec3(0.0);
    float transmittance = 1.0;

    float stepSize = maxDistance / float(marchSteps);
    float density = 0.05;

    for (int i = 0; i < marchSteps; i++) {
        vec3 samplePos = rayOrigin + rayDir * (float(i) + 0.5) * stepSize;

        // Light attenuation at this sample point
        float lightDistance = length(samplePos);
        float lightAtt = exp(-lightDistance * 0.001);

        // In-scattering
        float sunLight = max(0.0, dot(rayDir, lightDir)) * lightAtt;
        vec3 scattering = lightColor * sunLight * density * stepSize;

        // Accumulate
        fogColor += scattering * transmittance;
        transmittance *= exp(-density * stepSize);

        if (transmittance < 0.01) {
            break;
        }
    }

    return fogColor;
}

// ===================================================================
// GODRAYS / CREPUSCULAR RAYS
// ===================================================================

// Simple godray effect (sun shafts)
float godrays(
    vec2 rayOrigin,
    vec3 sunDir,
    float maxDistance,
    int samples
) {
    float godray = 0.0;
    float decay = 0.96;
    float weight = 0.5;
    float illuminationDecay = 1.0;

    for (int i = 0; i < samples; i++) {
        float sampleDistance = float(i) / float(samples) * maxDistance;
        vec2 samplePos = rayOrigin + sunDir.xy * sampleDistance;

        // Sample scene depth or light intensity
        float depth = texture(depthtex0, samplePos).r;
        float lightness = 1.0 - depth;

        godray += lightness * weight * illuminationDecay;
        illuminationDecay *= decay;
    }

    return godray / float(samples);
}

// ===================================================================
// WATER SIMULATION
// ===================================================================

// Simple wave height calculation
float waveHeight(vec3 position, float time) {
    float wave1 = sin(position.x * 0.1 + time) * 0.1;
    float wave2 = cos(position.z * 0.15 + time * 0.7) * 0.08;
    float wave3 = sin((position.x + position.z) * 0.08 + time * 1.3) * 0.06;

    return wave1 + wave2 + wave3;
}

// Animated water normal
vec3 waterNormal(vec3 position, float time) {
    float epsilon = 0.01;

    float h0 = waveHeight(position, time);
    float hx = waveHeight(position + vec3(epsilon, 0.0, 0.0), time);
    float hz = waveHeight(position + vec3(0.0, 0.0, epsilon), time);

    float dx = (hx - h0) / epsilon;
    float dz = (hz - h0) / epsilon;

    return normalize(vec3(-dx, 1.0, -dz));
}

// ===================================================================
// DUST/PARTICLE EFFECTS
// ===================================================================

// Dust particle density at position
float dustDensity(vec3 position, float time) {
    vec3 posTime = position + vec3(time) * 0.1;

    // Use simple sine-based "noise"
    float dust = sin(posTime.x * 5.0) * sin(posTime.y * 3.0) * sin(posTime.z * 4.0);
    dust = dust * 0.5 + 0.5;

    // Fade with height
    dust *= (1.0 - position.y * 0.01);

    return dust;
}

// ===================================================================
// LIGHT SHAFTS
// ===================================================================

// Compute light shaft contribution (reserved for advanced effects)
vec3 lightShafts(vec3 rayDir, vec3 lightDir, float intensity) {
    // Placeholder for advanced light shaft computation
    return vec3(0.0);
}

// ===================================================================
// END OF VOLUMETRIC MODULE
// ===================================================================

#endif // INCLUDE_VOLUMETRIC
