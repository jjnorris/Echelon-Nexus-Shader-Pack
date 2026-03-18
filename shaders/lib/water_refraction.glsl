// ===================================================================
// Water Refraction & Underwater Effects (Phase 18)
// ===================================================================
// Depth-aware refraction and underwater volumetric scattering.

#ifndef INCLUDE_WATER_REFRACTION
#define INCLUDE_WATER_REFRACTION

// ===================================================================
// UNDERWATER REFRACTION
// ===================================================================

// Compute refraction offset for viewing underwater
// Uses depth-based distortion for perspective correction
vec2 underwaterRefraction(
    vec2 screenCoord,
    vec2 normalMapUv,
    vec3 waterNormal,
    float waterDepth,
    float refractStrength
) {
    // Refraction strength decreases with depth (caustic effect)
    float depthFactor = exp(-waterDepth * 0.3);

    // Normal-based distortion
    vec2 distortion = waterNormal.xz * refractStrength * depthFactor;

    // Screen-space bounds checking
    vec2 refractedCoord = screenCoord + distortion;

    return refractedCoord;
}

// ===================================================================
// UNDERWATER EXTINCTION
// ===================================================================

// Compute color shift due to water absorption
// Different wavelengths penetrate different distances
vec3 waterAbsorption(
    vec3 objectColor,
    float waterDepth,
    float visibility
) {
    // Water absorption: deeper = more blue-shifted
    // Beer-Lambert law: transmission = exp(-mu * depth)

    // Absorption coefficients for water (approximate)
    vec3 absorptionCoeff = vec3(
        0.15,  // Red (absorbed first)
        0.08,  // Green
        0.04   // Blue (penetrates furthest)
    );

    // Compute transmission for each channel
    vec3 transmission = exp(-absorptionCoeff * waterDepth / visibility);

    // Apply to object color
    vec3 absorbedColor = objectColor * transmission;

    // Add water color influence (blue-green)
    vec3 waterColor = vec3(0.2, 0.6, 0.8);
    absorbedColor = mix(absorbedColor, waterColor, 1.0 - clamp(transmission, vec3(0.0), vec3(1.0)));

    return absorbedColor;
}

// ===================================================================
// UNDERWATER FOG
// ===================================================================

// Compute underwater fog based on distance and depth
float underwaterFogDensity(
    float distance,
    float waterDepth,
    float visibility
) {
    // Fog increases with depth
    float depthFog = 1.0 - exp(-waterDepth / visibility);

    // Distance fog
    float distanceFog = 1.0 - exp(-distance / (visibility * 2.0));

    // Combined fog (max of both)
    return max(depthFog, distanceFog);
}

// Apply underwater fog to scene
vec3 applyUnderwaterFog(
    vec3 sceneColor,
    float fogDensity,
    vec3 underwaterFogColor
) {
    return mix(sceneColor, underwaterFogColor, fogDensity);
}

// ===================================================================
// CAUSTIC REFRACTION
// ===================================================================

// Project caustic pattern onto underwater surfaces
vec3 causticProjection(
    vec3 worldPosition,
    vec3 waterSurfaceNormal,
    float waterDepth,
    float causticIntensity
) {
    // Simplified caustic: use sine wave pattern
    float causticX = sin(worldPosition.x * 2.0 + worldPosition.z) * 0.5 + 0.5;
    float causticY = sin(worldPosition.z * 1.8 + worldPosition.x) * 0.5 + 0.5;
    float caustic = causticX * causticY;

    // Fade with depth
    float causticFade = exp(-waterDepth * 0.5);

    // Apply to brightness
    return vec3(1.0) + caustic * causticIntensity * causticFade;
}

// ===================================================================
// UNDERWATER SCATTERING
// ===================================================================

// Volumetric scattering underwater (light shafts, god rays)
vec3 underwaterVolumetricScattering(
    vec3 lightDir,
    float lightIntensity,
    float waterDepth,
    float visibility
) {
    // Light penetration decreases with depth
    float lightPenetration = exp(-waterDepth / (visibility * 3.0));

    // Scattering intensity
    float scattering = 0.0;

    // More scattering when light is more parallel to water surface
    float lightGraze = abs(lightDir.y);
    scattering = (1.0 - lightGraze) * lightPenetration;

    // Scattered light color (bluish from water)
    vec3 scatteredLight = vec3(0.4, 0.7, 1.0) * scattering * lightIntensity;

    return scatteredLight;
}

// ===================================================================
// UNDERWATER CAUSTIC ANIMATION
// ===================================================================

// Animated caustic pattern for moving light under water
float animatedCaustic(
    vec3 worldPosition,
    float time,
    float speed,
    float scale
) {
    float caustic = 0.0;

    // Multiple wave frequencies
    float wave1 = sin((worldPosition.x + worldPosition.z) * scale + time * speed) * 0.5 + 0.5;
    float wave2 = sin((worldPosition.x - worldPosition.z) * scale * 0.7 + time * speed * 0.8) * 0.5 + 0.5;
    float wave3 = sin(worldPosition.y * scale * 0.5 + time * speed * 0.5) * 0.5 + 0.5;

    caustic = wave1 * wave2 * wave3;

    return caustic;
}

// ===================================================================
// REFRACTION WITH FRESNEL
// ===================================================================

// Combine Fresnel effect with refraction
// Surface reflects more at grazing angles
vec3 fresnelRefraction(
    vec3 sceneColor,
    vec3 reflectionColor,
    vec3 normalizedNormal,
    vec3 viewDir,
    float ior
) {
    // Fresnel (Schlick's approximation)
    float fresnel = pow(1.0 - max(0.0, dot(normalizedNormal, -viewDir)), 5.0);

    // Base Fresnel for water (~0.02 at normal incidence)
    float baseFresnelWater = 0.02;
    fresnel = baseFresnelWater + (1.0 - baseFresnelWater) * fresnel;

    // Blend between refracted scene and reflected
    return mix(sceneColor, reflectionColor, fresnel);
}

#endif // INCLUDE_WATER_REFRACTION
