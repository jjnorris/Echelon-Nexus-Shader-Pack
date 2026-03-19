// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         WATER SYSTEMS (PHASE 18)                                         ║
// ║         COMPLETE SUB-PHASES 18A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Realistic water simulation including Gerstner waves, foam,             ║
// ║  shoreline effects, wave propagation, and underwater volumetrics.      ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    18A: Gerstner Waves (realistic wave simulation)                      ║
// ║    18B: Wave Foam (white caps)                                          ║
// ║    18C: Shoreline Effects (water-land transition)                       ║
// ║    18D: Wave Propagation (interference patterns)                        ║
// ║    18E: Underwater Volumetrics (optional tier 4+)                       ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Ocean waves with realistic curvature                               ║
// ║    - Wave foam on crests and breakers                                   ║
// ║    - Shoreline foam and splash effects                                  ║
// ║    - Wave interference patterns                                         ║
// ║    - Underwater light and caustics                                      ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Gerstner (1802) - Trochoid Wave Theory                            ║
// ║    - Tessendorf (1999) - Simulating Ocean Water                        ║
// ║    - Jeschke et al. (2001) - Water Wave Animation                      ║
// ║    - Fournier & Reeves (1986) - Ocean Waves                            ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_WATER_SYSTEMS
#define INCLUDE_WATER_SYSTEMS

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 18A: GERSTNER WAVES                                               ║
// ║                                                                           ║
// │ Realistic ocean wave simulation using trochoidal wave theory.         ║
// │ Proper wave curvature and particle motion.                            ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gerstnerWavePosition()                                                  ║
// ║                                                                         ║
// │ Calculate wave-displaced position using Gerstner wave equation.     │
// │                                                                       │
// │ Physics: Gerstner waves create trochoid particles paths.           │
// │ Particle motion: circular trajectory in XZ plane, varying with Y  │
// │                                                                       │
// │ Equation: P(t) = P₀ + Q × A × ω × t × direction                  │
// │           Y(t) = Y₀ + A × sin(k·x - ω·t + φ)                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - Original position (XYZ)                             │
// │   waveData - Wave parameters (amplitude, wavelength, speed)    │
// │   time - Animation time                                       │
// │   waveCount - Number of wave components                      │
// │                                                                       │
// │ Returns: Displaced position                                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 gerstnerWavePosition(
    vec3 position,
    vec4 waveData[4],  // Max 4 waves per implementation
    float time,
    int waveCount
) {
    vec3 displaced = position;

    for (int i = 0; i < waveCount && i < 4; i++) {
        // Wave parameters
        float amplitude = waveData[i].x;
        float wavelength = waveData[i].y;
        float speed = waveData[i].z;
        float phase = waveData[i].w;

        // Wave number and frequency
        float k = 2.0 * PI / wavelength;
        float omega = sqrt(9.81 * k);  // Gravity wave dispersion

        // Gerstner steepness (Q parameter)
        // Higher Q = sharper wave peaks, broader troughs
        float Q = 0.25 * amplitude * k;  // Typical Q = 0.25

        // Wave direction (XZ plane)
        vec2 direction = normalize(vec2(1.0, 0.5));

        // Phase at this position
        float phase_local = k * dot(direction, position.xz) - omega * time + phase;

        // Horizontal displacement (circular motion)
        displaced.x += direction.x * Q * amplitude * cos(phase_local);
        displaced.z += direction.y * Q * amplitude * cos(phase_local);

        // Vertical displacement (sine wave)
        displaced.y += amplitude * sin(phase_local);
    }

    return displaced;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gerstnerWaveNormal()                                                    ║
// ║                                                                         ║
// │ Calculate surface normal from wave gradients.                      │
// │ Proper normal pointing based on wave derivatives.                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   waveData - Wave parameters                                    │
// │   time - Animation time                                        │
// │   waveCount - Number of waves                                 │
// │                                                                       │
// │ Returns: Surface normal (normalized)                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 gerstnerWaveNormal(
    vec3 position,
    vec4 waveData[4],
    float time,
    int waveCount
) {
    // Use finite differences for normal calculation
    float delta = 0.1;

    vec3 pos1 = gerstnerWavePosition(position + vec3(delta, 0, 0), waveData, time, waveCount);
    vec3 pos2 = gerstnerWavePosition(position - vec3(delta, 0, 0), waveData, time, waveCount);
    vec3 pos3 = gerstnerWavePosition(position + vec3(0, 0, delta), waveData, time, waveCount);
    vec3 pos4 = gerstnerWavePosition(position - vec3(0, 0, delta), waveData, time, waveCount);

    vec3 dx = pos1 - pos2;
    vec3 dz = pos3 - pos4;

    vec3 normal = cross(dz, dx);
    return normalize(normal);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 18B: WAVE FOAM                                                    ║
// ║                                                                           ║
// │ White caps on wave crests and wave breaking regions.                  ║
// │ Physically based on water curvature and wave steepness.              ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ calculateFoamIntensity()                                                ║
// ║                                                                         ║
// │ Determine foam amount based on wave properties.                    │
// │                                                                       │
// │ Physics: Foam occurs where:                                       │
// │   1. Wave curvature is high (crest regions)                     │
// │   2. Water velocity exceeds threshold                          │
// │   3. Wave steepness exceeds breaking threshold                │
// │                                                                       │
// │ Inputs:                                                              │
// │   waveHeight - Vertical displacement from wave                 │
// │   waveNormal - Surface normal                                  │
// │   curvature - Local surface curvature                        │
// │   velocity - Water particle velocity                         │
// │                                                                       │
// │ Returns: Foam intensity (0.0-1.0)                            │
// └─────────────────────────────────────────────────────────────────────────┘
float calculateFoamIntensity(
    float waveHeight,
    vec3 waveNormal,
    float curvature,
    float velocity
) {
    // Crest detection: normal pointing mostly up
    float crestStrength = max(0.0, waveNormal.y - 0.7);
    crestStrength = pow(crestStrength, 2.0);  // Sharpen peaks

    // Height threshold: foam appears near crests
    float heightFactor = smoothstep(-0.5, 0.5, waveHeight);

    // Curvature: higher curvature = more foam
    float curvatureFactor = clamp(curvature * 5.0, 0.0, 1.0);

    // Wave breaking: when velocity is high
    float breakingFactor = smoothstep(0.5, 2.0, velocity);

    // Combine factors
    float foam = crestStrength * heightFactor * 0.4 +
                 curvatureFactor * 0.3 +
                 breakingFactor * 0.3;

    return clamp(foam, 0.0, 1.0);
}

vec3 foamColor(float foamIntensity, float time) {
    // Base white foam
    vec3 foamBase = vec3(1.0, 1.0, 1.0);

    // Add subtle color variation
    float variation = sin(time * 0.5) * 0.1;
    foamBase *= (0.95 + variation);

    // Modulate by intensity with soft falloff
    return foamBase * foamIntensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 18C: SHORELINE EFFECTS                                            ║
// ║                                                                           ║
// │ Water-land transition with foam, spray, and shallow water effects.    ║
// │ Creates beach and rocky shore appearance.                             ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ shorelineDistance()                                                     ║
// ║                                                                         ║
// │ Calculate distance from shoreline with gradient.                   │
// │                                                                       │
// │ Inputs:                                                              │
// │   worldPos - World position                                      │
// │   shoreNormal - Shoreline normal direction                    │
// │   shoreDistance - Perpendicular distance to shore            │
// │                                                                       │
// │ Returns: Normalized shoreline distance (0=deep, 1=shore)    │
// └─────────────────────────────────────────────────────────────────────────┘
float shorelineDistance(vec3 worldPos, vec3 shoreNormal, float baseDistance) {
    // Distance from shore point
    float dist = length(worldPos);

    // Normalized: 0 at far distance, 1 at shore
    float shoreFactor = exp(-dist / 50.0);

    // Add wave-based variation
    float waveVariation = sin(worldPos.x * 0.1 + worldPos.z * 0.15) * 0.2;
    shoreFactor += waveVariation;

    return clamp(shoreFactor, 0.0, 1.0);
}

vec3 shorelineColor(
    vec3 baseWaterColor,
    float shoreFactor,
    float waveHeight,
    float time
) {
    // Shallow water: lighter, more transparent
    vec3 shallowColor = vec3(0.2, 0.4, 0.6);
    vec3 sandColor = vec3(0.8, 0.7, 0.5);

    // Blend based on distance to shore
    vec3 result = mix(baseWaterColor, shallowColor, shoreFactor * 0.5);
    result = mix(result, sandColor, shoreFactor * 0.3);

    // Foam on shoreline
    float shoreFoam = shoreFactor * abs(sin(waveHeight * 5.0 + time));
    result = mix(result, vec3(1.0), shoreFoam * 0.3);

    return result;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 18D: WAVE PROPAGATION                                             ║
// ║                                                                           ║
// │ Wave interference patterns and wave-wave interactions.              ║
// │ Multiple frequency components create realistic ocean surfaces.      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ waveInterference()                                                      ║
// ║                                                                         ║
// │ Calculate interference between multiple wave components.            │
// │ Creates complex, natural-looking wave patterns.                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position (XZ)                                 │
// │ time - Animation time                                            │
// │   frequency1, frequency2 - Wave frequencies                   │
// │   amplitude1, amplitude2 - Wave amplitudes                    │
// │                                                                       │
// │ Returns: Combined wave height with interference              │
// └─────────────────────────────────────────────────────────────────────────┘
float waveInterference(
    vec2 position,
    float time,
    float freq1,
    float freq2,
    float amp1,
    float amp2
) {
    // Wave 1
    float wave1 = amp1 * sin(position.x * freq1 + position.y * freq1 * 0.3 - time * 1.5);

    // Wave 2 (perpendicular direction)
    float wave2 = amp2 * sin(position.x * freq2 * 0.7 - position.y * freq2 - time * 2.0);

    // Interference: constructive/destructive based on phase
    float interference = wave1 + wave2;

    // Add beat frequency (modulation)
    float beatFreq = abs(freq1 - freq2);
    float envelope = sin(beatFreq * time * 0.5) * 0.5 + 0.5;

    return interference * (0.5 + envelope * 0.5);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ wavePropagationPattern()                                                ║
// ║                                                                         ║
// │ Create radial wave propagation from point source.                 │
// │ Simulates waves created by splashes or rock impacts.             │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   sourcePos - Point source location                            │
// │   time - Animation time                                        │
// │   speed - Wave propagation speed                              │
// │                                                                       │
// │ Returns: Wave height from propagating disturbance            │
// └─────────────────────────────────────────────────────────────────────────┘
float wavePropagationPattern(
    vec3 position,
    vec3 sourcePos,
    float time,
    float speed
) {
    // Distance from source
    float dist = length(position - sourcePos);

    // Wave front: sharp moving peak
    float phase = dist - speed * time;

    // Radial wave with damping
    float wave = sin(phase * 3.0) * exp(-dist * 0.05);

    // Secondary rings
    wave += sin(phase * 6.0) * 0.5 * exp(-dist * 0.08);

    return wave;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 18E: UNDERWATER VOLUMETRICS                                       ║
// ║                                                                           ║
// │ Underwater lighting, god rays, and volumetric effects.              ║
// │ Creates realistic underwater atmosphere (Tier 4+).                 ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ underwaterAttenuation()                                                 ║
// ║                                                                         ║
// │ Calculate light attenuation with water depth.                     │
// │ Different wavelengths attenuate at different rates.              │
// │                                                                       │
// │ Physics: Seawater absorption coefficients (per meter):          │
// │   Red: ~0.6 m⁻¹ (absorbed quickly)                             │
// │   Green: ~0.05 m⁻¹ (penetrates deeper)                         │
// │   Blue: ~0.02 m⁻¹ (most penetrating)                           │
// │                                                                       │
// │ Inputs:                                                              │
// │   depth - Water depth (meters)                                  │
// │   waterType - 0=clear, 1=coastal, 2=turbid                    │
// │                                                                       │
// │ Returns: Light attenuation (0.0-1.0)                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 underwaterAttenuation(float depth, int waterType) {
    // Absorption coefficients per meter
    float redAbsorb = 0.6;
    float greenAbsorb = 0.05;
    float blueAbsorb = 0.02;

    // Adjust for water type
    if (waterType == 1) {  // Coastal
        redAbsorb = 1.0;
        greenAbsorb = 0.15;
        blueAbsorb = 0.05;
    }
    else if (waterType == 2) {  // Turbid
        redAbsorb = 2.0;
        greenAbsorb = 0.5;
        blueAbsorb = 0.3;
    }

    // Exponential attenuation: e^(-α × d)
    vec3 attenuation = vec3(
        exp(-redAbsorb * depth),
        exp(-greenAbsorb * depth),
        exp(-blueAbsorb * depth)
    );

    return attenuation;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ underwaterCausticsIntensity()                                           ║
// ║                                                                         ║
// │ Modulate caustics by depth and viewing angle.                    │
// │ Creates realistic underwater light patterns.                     │
// │                                                                       │
// │ Inputs:                                                              │
// │   depth - Water depth                                            │
// │   normalDotLight - Angle between normal and light              │
// │                                                                       │
// │ Returns: Caustic intensity (0.0-1.0)                           │
// └─────────────────────────────────────────────────────────────────────────┘
float underwaterCausticsIntensity(float depth, float normalDotLight) {
    // Base caustic visibility decreases with depth
    float depthFactor = exp(-depth * 0.1);

    // Angle dependency: stronger with direct light
    float angleFactor = normalDotLight * normalDotLight;

    return depthFactor * angleFactor;
}

vec3 underwaterColor(
    vec3 baseColor,
    float depth,
    int waterType,
    float normalDotLight,
    float time
) {
    // Get attenuation per channel
    vec3 attenuation = underwaterAttenuation(depth, waterType);

    // Apply depth color shift
    vec3 depthColor = vec3(0.1, 0.3, 0.5);

    // Blend base color with depth
    vec3 result = baseColor * attenuation;
    result = mix(result, depthColor, (1.0 - attenuation));

    // Add modulated caustics
    float causticsIntensity = underwaterCausticsIntensity(depth, normalDotLight);
    vec3 caustics = vec3(0.2, 0.3, 0.4) * sin(time) * causticsIntensity;
    result += caustics;

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED WATER SYSTEM APPLICATION                                         ║
// └───────────────────────────────────────────────────────────────────────────┘

vec4 applyWaterSystem(
    vec3 baseColor,
    vec3 worldPos,
    float time,
    int systemType,
    float intensity
) {
    vec4 result = vec4(baseColor, 1.0);

    if (systemType == 0) {
        // Gerstner waves (18A)
        vec4 waveData[4];
        waveData[0] = vec4(0.5, 10.0, 2.0, 0.0);
        waveData[1] = vec4(0.3, 6.0, 1.5, PI / 4.0);
        waveData[2] = vec4(0.2, 4.0, 1.0, PI / 2.0);
        waveData[3] = vec4(0.1, 2.0, 0.8, 3.0 * PI / 4.0);

        vec3 wavePos = gerstnerWavePosition(worldPos, waveData, time, 4);
        vec3 waveNormal = gerstnerWaveNormal(worldPos, waveData, time, 4);

        result.rgb = mix(baseColor, baseColor + waveNormal * 0.1, intensity);
    }
    else if (systemType == 1) {
        // Wave foam (18B)
        float foamAmount = calculateFoamIntensity(worldPos.y, normalize(vec3(0, 1, 0)), 0.5, 1.0);
        result.rgb = mix(baseColor, vec3(1.0), foamAmount * intensity);
    }
    else if (systemType == 2) {
        // Shoreline effects (18C)
        float shore = shorelineDistance(worldPos, vec3(0, 0, 1), length(worldPos));
        result.rgb = shorelineColor(baseColor, shore, worldPos.y, time);
    }
    else if (systemType == 3) {
        // Wave propagation (18D)
        float interference = waveInterference(worldPos.xz, time, 0.3, 0.2, 0.5, 0.3);
        result.rgb = baseColor + vec3(interference * 0.2);
    }
    else if (systemType == 4) {
        // Underwater volumetrics (18E)
        vec3 underwater = underwaterColor(baseColor, worldPos.y, 0, 0.5, time);
        result.rgb = underwater;
    }

    return result;
}

#endif  // INCLUDE_WATER_SYSTEMS
