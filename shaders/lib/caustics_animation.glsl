// ===================================================================
// Animated Caustics Field (Phase 17)
// ===================================================================
// Real-time animated caustic patterns for water surfaces using
// diffraction-based simulation with smooth temporal continuity.

#ifndef INCLUDE_CAUSTICS_ANIMATION
#define INCLUDE_CAUSTICS_ANIMATION

#include "noise.glsl"

// ===================================================================
// CAUSTIC PATTERN GENERATION
// ===================================================================

// Generate animated caustic pattern using overlaid sine waves
// Simulates wave interference patterns at water surface
float causticPattern(vec2 uv, float time, float scale, float speed) {
    vec2 scaledUv = uv * scale;

    // Multiple wave frequencies for complexity
    float wave1 = sin(scaledUv.x * 1.0 + time * speed * 0.5) * 0.5;
    float wave2 = sin(scaledUv.y * 0.7 + time * speed * 0.6) * 0.5;
    float wave3 = sin((scaledUv.x + scaledUv.y) * 0.8 + time * speed * 0.4) * 0.5;

    // Combined pattern
    float pattern = wave1 + wave2 + wave3;

    // Normalize to [0, 1]
    return 0.5 + 0.5 * pattern;
}

// Layered caustic: multiple scales for more detail
float layeredCaustic(vec2 uv, float time, float speed) {
    float caustic = 0.0;

    // Layer 1: Large features
    caustic += causticPattern(uv, time, 2.0, speed) * 0.5;

    // Layer 2: Medium features
    caustic += causticPattern(uv, time, 4.0, speed * 1.3) * 0.3;

    // Layer 3: Fine details
    caustic += causticPattern(uv, time, 8.0, speed * 1.7) * 0.2;

    return caustic;
}

// ===================================================================
// PERLIN-BASED CAUSTICS
// ===================================================================

// Smooth caustics using Perlin noise (requires noise library)
float perlintCaustic(vec2 uv, float time, float speed) {
    vec2 flowUv = uv + vec2(time * speed * 0.1, time * speed * 0.15);

    // Multi-octave noise for caustic texture
    float n1 = fnoise(flowUv * 2.0);
    float n2 = fnoise(flowUv * 4.0 + vec2(time * speed * 0.2, 0.0));
    float n3 = fnoise(flowUv * 8.0 + vec2(0.0, time * speed * 0.2));

    // Combine with varying weights
    float caustic = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

    // Remap to more interesting range
    caustic = smoothstep(0.3, 0.7, caustic);

    return caustic;
}

// ===================================================================
// REALISTIC CAUSTIC FROM WAVE SIMULATION
// ===================================================================

// Simplified shallow-water wave equation
// Returns displacement field for caustic generation
vec2 waveDisplacement(vec2 position, float time, float wavelength, float amplitude) {
    // Wave parameters
    float k = 2.0 * 3.14159265359 / wavelength;
    float omega = 2.0 * 3.14159265359 * 0.8;  // Wave frequency

    // Primary wave
    float wave1 = sin(k * position.x - omega * time) * amplitude;
    float wave2 = sin(k * position.y - omega * time * 0.7) * amplitude * 0.8;

    // Secondary wave (interference)
    float wave3 = sin(k * (position.x + position.y) * 0.7 - omega * time * 1.2) * amplitude * 0.5;

    return vec2(wave1 + wave3 * 0.5, wave2 + wave3 * 0.3);
}

// Compute caustic intensity from wave-displaced surface
float causticFromWaves(vec2 screenUv, float time) {
    // Apply wave displacement
    vec2 displace = waveDisplacement(screenUv, time, 0.5, 0.1);
    vec2 displaceUv = screenUv + displace;

    // Compute intensity modulation from wave slopes (gradient)
    vec2 d1 = waveDisplacement(displaceUv + vec2(0.001, 0.0), time, 0.5, 0.1);
    vec2 d2 = waveDisplacement(displaceUv + vec2(0.0, 0.001), time, 0.5, 0.1);

    // Numerical gradient (wave slopes)
    vec2 gradient = vec2(length(d1 - displace), length(d2 - displace)) / 0.001;

    // Intensity from slope magnitude (focusing/defocusing light)
    float intensity = 1.0 / (1.0 + length(gradient) * 0.5);

    return intensity;
}

// ===================================================================
// CAUSTIC WITH DIRECTIONAL LIGHT
// ===================================================================

// Caustics modulated by light direction (proper refraction)
float causticWithLight(
    vec2 screenUv,
    float time,
    vec3 lightDir,
    float waterDepth,
    float speed
) {
    // Base caustic pattern
    float caustic = layeredCaustic(screenUv, time, speed);

    // Light-based modulation
    // Caustics are stronger when light is more parallel to surface
    float lightGraze = abs(lightDir.y);  // Assume y is vertical
    float lightFocus = (1.0 - lightGraze) * 0.7 + 0.3;

    // Depth-based attenuation (caustics fade with depth)
    float depthAttenuation = exp(-waterDepth * 0.5);

    return caustic * lightFocus * depthAttenuation;
}

// ===================================================================
// TEMPORAL COHERENCE
// ===================================================================

// Smooth caustic transitions using temporal filtering
float temporalCausticSmoothing(
    float currentCaustic,
    float previousCaustic,
    float temporalSmoothing
) {
    // Exponential moving average for smooth transitions
    return mix(currentCaustic, previousCaustic, temporalSmoothing);
}

// Limit caustic animation speed (prevent flickering)
float dampedCausticAnimation(float caustic, float maxSpeed) {
    // Simple damping: limit rate of change
    // In practice, use temporal history buffer for this
    return clamp(caustic, 0.0, 1.0);
}

#endif // INCLUDE_CAUSTICS_ANIMATION
