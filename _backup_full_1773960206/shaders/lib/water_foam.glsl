// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║               WATER FOAM GENERATION & RENDERING (PHASE 18)               ║
// ║                                                                           ║
// ║  Physics-based foam generation from wave curvature and shore breaks.   ║
// ║  Produces foam intensity from surface curvature variations and         ║
// ║  white-water effects at wave crests and collisions.                    ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_WATER_FOAM
#define INCLUDE_WATER_FOAM

#include "water_physics.glsl"
#include "noise.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ FOAM GENERATION                                                          ║
// │                                                                           ║
// │ Generates foam from wave curvature, depth, and edge proximity.         │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ FoamData (struct)                                                       ║
// ║                                                                         ║
// │ Foam rendering parameters                                             │
// │   intensity:  Foam amount [0,1] from wave curvature                   │
// │   depthFade:  Exponential depth attenuation (deeper = less foam)      │
// │   edgeFade:   Boundary softening at foam edges                        │
// │   foamColor:  Color with blue tint at depth                          │
// └─────────────────────────────────────────────────────────────────────────┘
struct FoamData {
    float intensity;        // Foam amount (0-1)
    float depthFade;        // Depth attenuation
    float edgeFade;         // Edge smoothing
    vec3 foamColor;         // Foam color with depth tint
};

FoamData generateWaveFoam(
    vec3 worldPosition,
    WaveSpectrum spectrum,
    float time,
    float waterDepth
) {
    FoamData foam;

    // Base foam from wave curvature
    foam.intensity = computeWaveFoamIntensity(worldPosition, spectrum, time);

    // Depth fade (foam less visible deeper)
    foam.depthFade = exp(-waterDepth * 0.5);

    // Edge fade (smooth falloff at foam boundaries)
    foam.edgeFade = smoothstep(0.0, 0.3, foam.intensity);

    // Foam is white with slight blue tint underwater
    foam.foamColor = mix(
        vec3(1.0),                  // Pure white at surface
        vec3(0.8, 0.9, 1.0),       // Bluish underwater
        clamp(waterDepth / 5.0, 0.0, 1.0)
    );

    return foam;
}

// ===================================================================
// SHORE FOAM
// ===================================================================

// Generate foam at shore/collision boundaries
float shoreFoamIntensity(
    vec3 worldPosition,
    float distanceToShore,
    float waveHeight,
    float time
) {
    // Foam increases as waves approach shore and crash
    float shoalFactor = 1.0 / (1.0 + distanceToShore * 0.1);

    // Wave energy at shore
    float waveEnergy = waveHeight * shoalFactor;

    // Pulsing foam as waves crash
    float crashPulse = sin(waveHeight * 10.0 + time * 3.0) * 0.5 + 0.5;

    return waveEnergy * (0.5 + crashPulse * 0.5);
}

// Detailed shore foam pattern with texture variation
float shoreFoamPattern(
    vec3 worldPosition,
    float distanceToShore,
    float time
) {
    // Animated noise pattern for foam appearance
    vec2 foamUv = worldPosition.xz * 0.5 + vec2(time * 0.3, 0.0);

    // Multi-scale foam pattern
    float pattern1 = fnoise(foamUv * 1.0);
    float pattern2 = fnoise(foamUv * 2.5 + vec2(time * 0.5, 0.0));
    float pattern3 = fnoise(foamUv * 5.0 + vec2(0.0, time * 0.3));

    float pattern = pattern1 * 0.5 + pattern2 * 0.3 + pattern3 * 0.2;

    // Limit to near-shore region
    float shoreMask = exp(-distanceToShore * 0.5);

    return pattern * shoreMask;
}

// ===================================================================
// FOAM RENDERING
// ===================================================================

// Compute foam opacity for blending with water surface
float foamOpacity(
    float foamIntensity,
    float depthFade,
    float alpha
) {
    // Foam is opaque at surface, transparent below
    return foamIntensity * depthFade * alpha;
}

// Apply foam to water surface
vec3 applyWaterFoam(
    vec3 waterColor,
    FoamData foam,
    float foamCoverage
) {
    // Blend foam color over water
    return mix(
        waterColor,
        foam.foamColor,
        foam.intensity * foamCoverage
    );
}

// ===================================================================
// FOAM MOVEMENT
// ===================================================================

// Offset foam texture coordinates with wave motion
vec2 foamTextureCoordinate(
    vec2 baseCoord,
    vec3 waveDisplacement,
    float time
) {
    // Move foam coordinates with wave motion
    vec2 foamCoord = baseCoord + waveDisplacement.xz * 0.1;

    // Add drift from current
    foamCoord += vec2(time * 0.05, time * 0.02);

    return foamCoord;
}

// ===================================================================
// PARTICLE FOAM (OPTIONAL)
// ===================================================================

// Foam particle system simulation (simple version)
// In practice, would use compute shader or particle buffer
struct FoamParticle {
    vec3 position;
    vec3 velocity;
    float lifetime;
};

// Update foam particle
FoamParticle updateFoamParticle(
    FoamParticle particle,
    float deltaTime,
    vec3 waveVelocity
) {
    FoamParticle updated = particle;

    // Inherit wave velocity
    updated.velocity = waveVelocity;

    // Gravity
    updated.velocity.y -= 9.8 * deltaTime;

    // Position update
    updated.position += updated.velocity * deltaTime;

    // Lifetime
    updated.lifetime -= deltaTime;

    // Fade with lifetime
    if (updated.lifetime < 0.0) {
        updated.lifetime = 0.0;
    }

    return updated;
}

// Compute foam particle visibility
float foamParticleVisibility(FoamParticle particle) {
    float age = 1.0 - clamp(particle.lifetime / 2.0, 0.0, 1.0);

    // Fade in and out
    float visibility = sin(age * 3.14159265359) * smoothstep(0.0, 0.2, particle.lifetime);

    return visibility;
}

#endif // INCLUDE_WATER_FOAM
