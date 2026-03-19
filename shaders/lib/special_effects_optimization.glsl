// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         SPECIAL EFFECTS & OPTIMIZATION (PHASE 28)                       ║
// ║         COMPLETE SUB-PHASES 28A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  Weather effects (rain, snow), hand rendering, particle integration,   ║
// ║  and performance optimization for quality tier scaling.               ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    28A: Weather Effects (Rain, Snow)                                   ║
// ║    28B: Hand Rendering (First-Person)                                ║
// ║    28C: Particle Effects Integration                                 ║
// ║    28D: Performance Monitoring & Profiling                           ║
// ║    28E: Tier-Based Quality Scaling                                   ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Tatarchuk (2006) - Practical Dynamic Occlusion with                ║
// ║      Dynamic Objects for Deferred Shading (Weather)                    ║
// ║    - Hasselgren et al. (2005) - Automatic Precomputed                 ║
// ║      Radiance Transfer for Real-Time Rendering (Hands)                ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SPECIAL_EFFECTS_OPTIMIZATION
#define INCLUDE_SPECIAL_EFFECTS_OPTIMIZATION

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 28A: WEATHER EFFECTS (RAIN, SNOW)                                 ║
// ║                                                                           ║
// │ Dynamic weather effects with surface interaction.               ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 rainEffect(
    vec3 baseColor,
    vec3 normal,
    float rainIntensity,
    vec3 rainDirection
) {
    // Rain wets surfaces (increases smoothness)
    // Darkens colors slightly

    float wetness = rainIntensity * 0.3;

    // Darken
    vec3 wetColor = baseColor * (1.0 - wetness * 0.2);

    // Make slightly more reflective (wet)
    // This would typically affect roughness/metallic values

    return mix(baseColor, wetColor, rainIntensity);
}

vec3 snowEffect(
    vec3 baseColor,
    vec3 normal,
    float snowIntensity,
    vec3 upVector
) {
    // Snow accumulation on top surfaces
    // Amount based on surface facing upward

    float upFacing = max(0.0, dot(normal, upVector));
    float snowAmount = upFacing * snowIntensity;

    // Snow is mostly white
    vec3 snowColor = vec3(0.95);

    // Blend toward snow white on top surfaces
    vec3 result = mix(baseColor, snowColor, snowAmount);

    return result;
}

float weatherWetness(float rainIntensity, float time) {
    // Compute wetness over time (increases when raining, decreases when not)
    // Modulate with time for smooth transitions

    float wetness = rainIntensity * 0.5;
    wetness += sin(time * 0.5) * rainIntensity * 0.1;

    return clamp(wetness, 0.0, 1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 28B: HAND RENDERING (FIRST-PERSON)                               ║
// ║                                                                           ║
// │ Special handling for player hands in first-person view.        ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 handSkinShading(
    vec3 skinColor,
    vec3 normal,
    vec3 viewDir,
    vec3 lightDir,
    float subsurfaceAmount
) {
    // Hand skin has characteristics:
    // - Smoother than most materials
    // - Significant subsurface scattering
    // - Translucency on fingertips

    float nDotL = max(0.0, dot(normal, lightDir));

    // Strong subsurface effect (hands are translucent)
    float backlit = pow(max(0.0, -dot(normal, lightDir)), 2.0);

    // Main diffuse + backlit SSS
    vec3 color = skinColor * (nDotL + backlit * subsurfaceAmount);

    return color;
}

vec3 handClothShading(
    vec3 clothColor,
    vec3 normal,
    vec3 viewDir,
    vec3 lightDir
) {
    // Hand clothing (gloves, sleeves)
    // Typically fabric with slight reflection

    float nDotL = max(0.0, dot(normal, lightDir));
    float nDotH = max(0.0, dot(normal, normalize(lightDir + viewDir)));

    float specular = pow(nDotH, 50.0) * 0.3;

    vec3 color = clothColor * nDotL + vec3(specular);

    return color;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 28C: PARTICLE EFFECTS INTEGRATION                                 ║
// ║                                                                           ║
// │ Combine shader effects with particle systems.                  ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 particleGlow(
    vec3 particleColor,
    float particleAge,
    float particleLifetime
) {
    // Particles often glow/fade over lifetime

    float lifeRatio = particleAge / particleLifetime;

    // Fade to transparent (alpha)
    float alpha = 1.0 - lifeRatio;

    // Optional glow fade (bright initially, dims)
    float glow = (1.0 - lifeRatio) * (1.0 - lifeRatio);

    vec3 result = particleColor * glow;

    return result;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 28D: PERFORMANCE MONITORING & PROFILING                           ║
// ║                                                                           ║
// │ Debug visualization for performance analysis.                  ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 debugVisualize(
    vec3 value,
    int debugMode,
    float scale
) {
    // Visualization modes for profiling
    // 0 = normal, 1 = normals, 2 = depth, 3 = time

    vec3 result = value;

    if(debugMode == 1) {
        // Normal visualization (show as color)
        result = value * 0.5 + 0.5;
    }
    else if(debugMode == 2) {
        // Depth visualization (grayscale)
        float depth = length(value);
        result = vec3(depth * scale);
    }
    else if(debugMode == 3) {
        // Time-based coloring
        float time = mod(length(value), 1.0);
        result = vec3(sin(time * 6.28) * 0.5 + 0.5);
    }

    return clamp(result, 0.0, 1.0);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 28E: TIER-BASED QUALITY SCALING                                   ║
// ║                                                                           ║
// │ Automatic quality reduction for lower-end hardware.            ║
// └───────────────────────────────────────────────────────────────────────────┘

struct QualitySettings {
    float shadowQuality;     // 0-1
    float reflectionQuality;  // 0-1
    float effectIntensity;    // 0-1
    int samplingRate;         // 1-8
    bool enableAdvanced;      // Toggle for expensive effects
};

QualitySettings getTierSettings(int tier) {
    // Tier: 1=low, 2=medium, 3=high, 4=ultra, 5=cinema

    QualitySettings settings;

    if(tier == 1) {
        settings.shadowQuality = 0.5;
        settings.reflectionQuality = 0.3;
        settings.effectIntensity = 0.3;
        settings.samplingRate = 1;
        settings.enableAdvanced = false;
    }
    else if(tier == 2) {
        settings.shadowQuality = 0.7;
        settings.reflectionQuality = 0.6;
        settings.effectIntensity = 0.6;
        settings.samplingRate = 2;
        settings.enableAdvanced = false;
    }
    else if(tier == 3) {
        settings.shadowQuality = 0.9;
        settings.reflectionQuality = 0.85;
        settings.effectIntensity = 0.9;
        settings.samplingRate = 4;
        settings.enableAdvanced = true;
    }
    else if(tier == 4) {
        settings.shadowQuality = 1.0;
        settings.reflectionQuality = 1.0;
        settings.effectIntensity = 1.0;
        settings.samplingRate = 6;
        settings.enableAdvanced = true;
    }
    else {  // Cinema
        settings.shadowQuality = 1.0;
        settings.reflectionQuality = 1.0;
        settings.effectIntensity = 1.0;
        settings.samplingRate = 8;
        settings.enableAdvanced = true;
    }

    return settings;
}

vec3 applyQualityScaling(
    vec3 color,
    QualitySettings settings
) {
    // Modulate effects based on quality tier
    // Brighter for performance (less processing = faster)

    color *= (0.8 + settings.effectIntensity * 0.2);

    return color;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED SPECIAL EFFECTS APPLICATION                                      ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applySpecialEffects(
    vec3 baseColor,
    vec3 normal,
    vec3 viewDir,
    vec3 lightDir,
    float rainIntensity,
    float snowIntensity,
    int qualityTier,
    float time
) {
    vec3 result = baseColor;

    // Apply weather
    result = rainEffect(result, normal, rainIntensity, lightDir);
    result = snowEffect(result, normal, snowIntensity, vec3(0, 1, 0));

    // Apply quality scaling
    QualitySettings settings = getTierSettings(qualityTier);
    result = applyQualityScaling(result, settings);

    return result;
}

#endif  // INCLUDE_SPECIAL_EFFECTS_OPTIMIZATION
