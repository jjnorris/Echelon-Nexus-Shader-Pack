// ===================================================================
// Reflection Probes (Phase 20)
// ===================================================================
// Localized reflection probes for dynamic IBL.

#ifndef INCLUDE_REFLECTION_PROBES
#define INCLUDE_REFLECTION_PROBES

// ===================================================================
// REFLECTION PROBE DEFINITION
// ===================================================================

struct ReflectionProbe {
    vec3 position;
    float radius;
    vec3 reflectionColor;
    float intensity;
};

// ===================================================================
// PROBE SAMPLING
// ===================================================================

// Find closest probe and compute weight
vec3 sampleNearestProbe(
    vec3 worldPosition,
    ReflectionProbe probes[4],
    int probeCount,
    out float weight
) {
    vec3 reflection = vec3(0.0);
    weight = 0.0;

    float minDistance = 1e10;
    int nearestProbe = -1;

    // Find closest probe
    for (int i = 0; i < probeCount; i++) {
        float dist = length(worldPosition - probes[i].position);
        if (dist < minDistance) {
            minDistance = dist;
            nearestProbe = i;
        }
    }

    if (nearestProbe >= 0) {
        ReflectionProbe probe = probes[nearestProbe];
        float influenceDistance = probe.radius;

        // Weight decreases with distance from probe center
        weight = max(0.0, 1.0 - minDistance / influenceDistance);
        weight *= weight;  // Smooth falloff

        reflection = probe.reflectionColor * probe.intensity * weight;
    }

    return reflection;
}

// Blend contributions from multiple probes
vec3 sampleMultipleProbes(
    vec3 worldPosition,
    ReflectionProbe probes[4],
    int probeCount
) {
    vec3 totalReflection = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < probeCount; i++) {
        float dist = length(worldPosition - probes[i].position);
        float w = max(0.0, 1.0 - dist / probes[i].radius);
        w *= w;

        totalReflection += probes[i].reflectionColor * probes[i].intensity * w;
        totalWeight += w;
    }

    if (totalWeight > 0.0) {
        return totalReflection / totalWeight;
    }

    return vec3(0.0);
}

// ===================================================================
// PARALLAX-CORRECTED CUBEMAPS
// ===================================================================

// Apply parallax correction to probe reflection
vec3 parallaxCorrectedProbeReflection(
    vec3 worldPosition,
    vec3 reflectionDir,
    ReflectionProbe probe
) {
    // Box projection: compute intersection with probe influence box
    vec3 rayDir = reflectionDir;
    vec3 rayOrigin = worldPosition;

    // Simple AABB intersection
    vec3 boxMin = probe.position - vec3(probe.radius);
    vec3 boxMax = probe.position + vec3(probe.radius);

    // Ray-box intersection (simplified)
    vec3 firstPlane = (boxMin - rayOrigin) / (rayDir + 0.0001);
    vec3 secondPlane = (boxMax - rayOrigin) / (rayDir + 0.0001);

    vec3 furthest = max(firstPlane, secondPlane);
    float distance = min(min(furthest.x, furthest.y), furthest.z);

    // Corrected reflection direction
    vec3 intersectionPoint = rayOrigin + rayDir * distance;
    vec3 correctedDir = intersectionPoint - probe.position;

    return correctedDir;
}

// ===================================================================
// PROBE UPDATES
// ===================================================================

// Update probe reflection color (dynamic)
ReflectionProbe updateProbe(
    ReflectionProbe probe,
    vec3 newReflectionColor,
    float blend
) {
    probe.reflectionColor = mix(probe.reflectionColor, newReflectionColor, blend);
    return probe;
}

// Initialize probe at position
ReflectionProbe initializeProbe(
    vec3 position,
    float radius,
    vec3 initialColor,
    float intensity
) {
    return ReflectionProbe(position, radius, initialColor, intensity);
}

#endif // INCLUDE_REFLECTION_PROBES
