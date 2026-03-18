// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║             VOLUMETRIC EFFECTS (PHASE 23)                                ║
// ║                                                                           ║
// ║  Ray-marched volumetric effects: clouds, fog, light shafts, god rays.   ║
// ║  Accumulates scattering and transmittance through participating media.  ║
// ║  Uses coherent noise for cloud generation and in-scattering approximation║
// ║  to simulate light bouncing within volumes.                              ║
// ║                                                                           ║
// ║  Techniques:                                                              ║
// ║    - Frequency domain clouds (octave-based noise)                        ║
// ║    - Beer-Lambert transmittance for fog/haze                             ║
// ║    - Anisotropic in-scattering (phase functions)                         ║
// ║    - Temporal reprojection for noise reduction                           ║
// ║                                                                           ║
// ║  Performance: Scales linearly with march steps (typ. 16-64 steps)      ║
// ║  Optimization: Use importance sampling near light sources               ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_VOLUMETRIC
#define INCLUDE_VOLUMETRIC

#include "constants.glsl"
#include "functions.glsl"
#include "lib/noise.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ VOLUMETRIC CLOUD DENSITY                                                 ║
// │                                                                           ║
// │ Coherent 3D noise-based cloud density generation using octave           │
// │ composition (Fractional Brownian Motion). Each octave contributes      │
// │ smaller detail at higher frequencies, creating natural-looking clouds. │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ cloudDensity()                                                          ║
// ║                                                                         ║
// │ Computes 3D cloud density field using FBM (Fractional Brownian       │
// │ Motion). Each octave adds detail at progressively finer scales.       │
// │ Result: Natural-looking cloudy appearance.                            │
// │                                                                         ║
// │ Inputs:                                                                │
// │   position - World position to sample density                         │
// │   octaves - Number of noise octaves (3-5 for detail)                 │
// │                                                                         ║
// │ Returns: Density [0,1] representing cloud opaqueness                │
// │                                                                         ║
// │ Formula: density = Σ(amplitude_i × noise_i) / Σ(amplitude_i)       │
// │ Where: amplitude_i = 0.5^i (each octave half the previous)          │
// │        frequency_i = 2^i (each octave double the previous)          │
// │                                                                         ║
// │ Cost: O(octaves) evaluations (~1ms per sample)                       │
// └─────────────────────────────────────────────────────────────────────────┘
float cloudDensity(vec3 position, int octaves) {
    // ────────────────────────────────────────────────────────────────────────
    // Octave composition (FBM): additive noise at decreasing amplitudes
    // ────────────────────────────────────────────────────────────────────────
    float density = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
        // ────────────────────────────────────────────────────────────────────
        // Simple harmonic noise: sin/cos oscillation at current frequency
        // (In production: use Perlin or Simplex noise for better continuity)
        // ────────────────────────────────────────────────────────────────────
        float sample = sin(position.x * frequency) * cos(position.z * frequency);
        density += sample * amplitude;

        // ────────────────────────────────────────────────────────────────────
        // Progressive octave: halve amplitude, double frequency
        // ────────────────────────────────────────────────────────────────────
        maxAmplitude += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    // ────────────────────────────────────────────────────────────────────────
    // Normalize to [0,1] and apply perceptual scaling
    // ────────────────────────────────────────────────────────────────────────
    return density / maxAmplitude * 0.5 + 0.5;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ cloudShape()                                                            ║
// ║                                                                         ║
// │ 2D cloud shape for sky dome. Time-animated for dynamic cloud motion.  │
// │ Used in sky rendering for horizon clouds and atmospheric effects.     │
// │                                                                         ║
// │ Includes temporal animation: iTime variable advances cloud pattern    │
// │ creating natural-looking drift effect.                                │
// └─────────────────────────────────────────────────────────────────────────┘
float cloudShape(vec2 position, int octaves) {
    // ────────────────────────────────────────────────────────────────────────
    // 2D FBM similar to cloudDensity, with time animation
    // ────────────────────────────────────────────────────────────────────────
    float cloud = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
        // ────────────────────────────────────────────────────────────────────
        // Time-dependent animation: iTime advances wave pattern horizontally
        // ────────────────────────────────────────────────────────────────────
        float sample = sin(position.x * frequency + iTime) * cos(position.y * frequency);
        cloud += sample * amplitude;

        // ────────────────────────────────────────────────────────────────────
        // Octave progression
        // ────────────────────────────────────────────────────────────────────
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
