# Implementation Priority Guide: Echelon Nexus Advanced Techniques

**Target**: Execute Phase 6-29 library code integration with focus on highest ROI features

---

## QUICK START: Pick Your Priorities

### If You Have 4 Weeks
**Goal**: Visually distinct from competitors

1. **Contact Shadows** (1-2 weeks)
   - File: `shaders/lib/shadow_sampling.glsl` (already has code)
   - Integration: `shaders/deferred.fsh` line ~150
   - Expected: Shadow artifacts gone

2. **Bent Normals** (1 week)
   - File: Add bent normal computation to `ssao.glsl` (new or existing)
   - Integration: Store bentNormal in G-buffer alpha channel
   - Expected: +40% better indirect lighting perception

3. **Temporal Jitter** (3-4 days)
   - File: `shaders/lib/halton_sequence.glsl` (already coded)
   - Integration: Apply to projection matrix in gbuffers
   - Expected: 8x MSAA visual quality

### If You Have 12 Weeks
**Goal**: Market leader quality

Add to above:
1. **Parallax-Corrected Reflections** (2 weeks)
   - New file: `shaders/lib/probe_reflections.glsl`
   - Integration: Blend with existing SSR in deferred.fsh
   - Expected: Off-screen reflections work correctly

2. **Soft-Body SSS** (1.5 weeks)
   - File: Use existing `subsurface_scattering.glsl` code
   - Integration: Deferred lighting, bind shadow map
   - Expected: Skin/foliage glow

3. **Volumetric Clouds v2** (3 weeks)
   - Enhancement to existing `volumetric.glsl`
   - Add Guerrilla Games multi-level detail
   - Integration: cloud.fsh
   - Expected: Horizon-like quality

### If You Have 24 Weeks
**Goal**: Complete dominance

Add to above:
1. **Compute Shader Deferred** (4 weeks)
   - Major rewrite of deferred.fsh → compute shader
   - Tile-based light culling
   - Expected: 3x faster lighting

2. **Radiance Probes** (2 weeks)
   - Implementation of world-space caching
   - Probe update shader
   - Expected: Smooth, stable GI

3. **Optimization Pass** (2 weeks)
   - Profile all features on each tier
   - SIMD where possible
   - Expected: 60 FPS on more hardware

---

## DETAILED INTEGRATION CHECKLIST

### PHASE 1: Contact Shadows (Week 1-2)

**File**: `/home/user/Echelon-Nexus-Shader-Pack/shaders/lib/shadow_sampling.glsl`

**Current Status**: Contains PCF/PCSS code

**What to Add**:
```glsl
// File: shadow_sampling.glsl - ADD THIS FUNCTION

vec4 sampleContactShadow(vec3 worldPos, vec3 normal, vec3 lightDir) {
    // Convert to screen space
    vec4 screenPos = gl_ProjectionMatrix * vec4(worldPos, 1.0);
    vec3 screenCoord = screenPos.xyz / screenPos.w;
    screenCoord.xy = screenCoord.xy * 0.5 + 0.5;

    // Jitter direction
    vec3 rayDir = normalize(lightDir);
    vec3 rayScreenDir = normalize(mul(rayDir, mat3(gl_ModelViewMatrix)).xyz);
    rayScreenDir.z = 0.0;  // Project to screen plane
    rayScreenDir = normalize(rayScreenDir);

    float shadow = 1.0;
    float stepSize = 1.0 / float(CONTACT_SHADOW_STEPS);

    // Ray march
    for (int i = 1; i < CONTACT_SHADOW_STEPS; i++) {
        vec3 sampleCoord = screenCoord + rayScreenDir * stepSize * float(i);

        // Bounds check
        if (sampleCoord.x < 0.0 || sampleCoord.x > 1.0 ||
            sampleCoord.y < 0.0 || sampleCoord.y > 1.0) {
            break;
        }

        float depthSample = texture(depthtex0, sampleCoord.xy).r;
        float surfaceDepth = sampleCoord.z;

        // If behind: occluded
        if (surfaceDepth > depthSample) {
            shadow = 0.0;
            break;
        }
    }

    return vec4(vec3(shadow), 1.0);
}
```

**Integration in deferred.fsh**:
```glsl
// Find this line in deferred.fsh (~line 150)
// float shadowFactor = shadowPCF(...);

// Replace with:
float shadowFactor;
if (SHADOW_QUALITY == 2) {  // Contact shadows enabled
    shadowFactor = sampleContactShadow(worldPos, normal, sunlight).r;
} else {
    shadowFactor = shadowPCF(...);  // Fallback
}
```

**Testing Checklist**:
- [ ] Recompile shader (should take ~2-3 seconds)
- [ ] Load in Minecraft, set SHADOW_QUALITY=2
- [ ] Check shadows on foliage/terrain near camera
- [ ] Verify no hard shadows at edges
- [ ] Test on all quality tiers (LOW should disable)
- [ ] Measure FPS impact (should be -0.3ms on GTX 1660)
- [ ] Check for visual artifacts (banding, shimmer)

---

### PHASE 2: Bent Normals (Week 2)

**File**: `/home/user/Echelon-Nexus-Shader-Pack/shaders/lib/ssao.glsl` (create if missing)

**Create New Function**:
```glsl
// Compute bent normal from SSAO sampling
vec3 computeBentNormal(vec3 normal, vec3 worldPos, sampler2D depthTex) {
    vec3 bentNormal = vec3(0.0);
    float aoSum = 0.0;

    // Sample hemisphere around normal
    for (int i = 0; i < BENT_NORMAL_SAMPLES; i++) {
        vec3 sampleDir = getHemisphereDir(i, normal);  // Fibonacci sphere
        float visibility = testVisibility(worldPos, sampleDir, depthTex);

        // Accumulate unoccluded directions
        if (visibility > 0.5) {
            bentNormal += sampleDir * visibility;
            aoSum += visibility;
        }
    }

    bentNormal = normalize(bentNormal);
    return bentNormal;
}

// Store alongside AO in G-buffer
void storeBentNormalAO(vec3 bentNormal, float ao) {
    // Pack bent normal into RG11B10F (11 bits R, 11 bits G, 10 bits B)
    // ao in alpha (8 bits)

    vec3 packed = bentNormal * 0.5 + 0.5;  // [-1,1] → [0,1]
    fragColor = vec4(packed.xy, ao, packed.z);
}
```

**Integration Points**:
1. Call in main rendering pass where AO is computed
2. Modify G-buffer layout to include bent normal
3. In deferred lighting, use bent normal instead of surface normal for indirect light

**Modified deferred.fsh**:
```glsl
// Where indirect lighting calculated:
vec3 bentNorm = decodeBentNormal(bentNormalAOData);
float ao = decodeBentAO(bentNormalAOData);

// Apply bent normal
vec3 indirectLight = sampleEnvironmentMap(bentNorm) * ao;
```

---

### PHASE 3: Parallax-Corrected Reflections (Week 2-3)

**New File**: `shaders/lib/probe_reflections.glsl`

```glsl
// Parallax-corrected cubemap reflection
struct ReflectionProbe {
    vec3 position;      // World position
    float radius;       // Influence radius
    samplerCube cubemap; // Reflection cubemap
    float weight;       // Blend weight
};

vec3 parallaxCorrectedReflection(vec3 reflectionDir, vec3 worldPos,
                                  ReflectionProbe probe) {
    // Ray from world position in reflection direction
    vec3 rayStart = worldPos - probe.position;
    vec3 rayDir = reflectionDir;

    // Find intersection with probe sphere
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayStart, rayDir);
    float c = dot(rayStart, rayStart) - probe.radius * probe.radius;

    float discriminant = b * b - 4.0 * a * c;
    float t = (-b + sqrt(discriminant)) / (2.0 * a);

    // Corrected sample direction on probe surface
    vec3 intersectionPoint = rayStart + rayDir * t;
    vec3 sampleDir = normalize(intersectionPoint);

    // Sample probe cubemap
    return textureCube(probe.cubemap, sampleDir).rgb;
}

// Blend multiple probes
vec3 getProbeReflection(vec3 reflectionDir, vec3 worldPos, int probeCount) {
    vec3 reflection = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < probeCount; i++) {
        ReflectionProbe probe = probes[i];
        float distance = distance(worldPos, probe.position);
        float weight = 1.0 / (1.0 + distance / probe.radius);

        reflection += parallaxCorrectedReflection(reflectionDir, worldPos, probe) * weight;
        totalWeight += weight;
    }

    return reflection / totalWeight;
}
```

**Integration in deferred.fsh**:
```glsl
// Blend probe reflections with screen-space reflections
vec3 probeReflection = getProbeReflection(reflectionDir, worldPos, PROBE_COUNT);
vec3 ssrReflection = sampleSSR(...);

// Blend based on confidence
float ssrConfidence = calculateSSRConfidence(...);  // 0-1
vec3 finalReflection = mix(probeReflection, ssrReflection, ssrConfidence);
```

**Setup Probes** (in shaders.properties):
```
# Reflection probe positions (world-space)
option.PROBE_0_POS = 0.0 64.0 0.0       # x, y, z
option.PROBE_0_RADIUS = 64.0
option.PROBE_1_POS = 256.0 64.0 256.0
option.PROBE_1_RADIUS = 64.0
```

---

### PHASE 4: Temporal Supersampling (3-4 days)

**Enhance**: `shaders/lib/halton_sequence.glsl`

**Add Jitter to Projection**:
```glsl
// In gbuffers shader:

// Get frame jitter
vec2 jitter = haltonJitter(frameCounter);
jitter *= (1.0 / screenSize);  // Normalize to pixel size

// Apply to projection
gl_Position = projection * viewMatrix * (worldPos + jitter);
```

**In composite.fsh (Post-processing)**:
```glsl
// Temporal accumulation
vec3 currentFrame = texture(colortex0, uv).rgb;
vec3 prevFrame = texture(colortex1, uv - motionVector).rgb;

// Disocclusion detection
float colorDiff = length(currentFrame - prevFrame);
float alpha = mix(0.05, 0.15, smoothstep(0.0, 0.5, colorDiff));

vec3 accumulated = mix(prevFrame, currentFrame, alpha);

fragColor = vec4(accumulated, 1.0);
```

---

## TIER-SPECIFIC CONFIGURATION

### Template: shaders.properties additions

```properties
# ===== CONTACT SHADOWS =====
option.CONTACT_SHADOW_QUALITY=0 1 2
0 = Disabled
1 = Basic (8 steps)
2 = High (16 steps)

option.CONTACT_SHADOW_DISTANCE=16 64

# Profile defaults
profile.LOW.CONTACT_SHADOW_QUALITY=0
profile.MEDIUM.CONTACT_SHADOW_QUALITY=1
profile.HIGH.CONTACT_SHADOW_QUALITY=2
profile.ULTRA.CONTACT_SHADOW_QUALITY=2
profile.CINEMA.CONTACT_SHADOW_QUALITY=2

# ===== BENT NORMALS =====
option.BENT_NORMAL_ON=true
option.BENT_NORMAL_SAMPLES=8 16 32

profile.LOW.BENT_NORMAL_SAMPLES=8
profile.MEDIUM.BENT_NORMAL_SAMPLES=16
profile.HIGH.BENT_NORMAL_SAMPLES=16
profile.ULTRA.BENT_NORMAL_SAMPLES=32
profile.CINEMA.BENT_NORMAL_SAMPLES=32

# ===== REFLECTIONS =====
option.PARALLAX_PROBE_COUNT=1 2 4

profile.LOW.PARALLAX_PROBE_COUNT=0
profile.MEDIUM.PARALLAX_PROBE_COUNT=1
profile.HIGH.PARALLAX_PROBE_COUNT=2
profile.ULTRA.PARALLAX_PROBE_COUNT=4
profile.CINEMA.PARALLAX_PROBE_COUNT=4

# ===== TEMPORAL =====
option.TEMPORAL_ACCUMULATION_ON=true
option.TEMPORAL_ALPHA=0.05 0.1

profile.LOW.TEMPORAL_ACCUMULATION_ON=false
profile.MEDIUM.TEMPORAL_ACCUMULATION_ON=true
profile.MEDIUM.TEMPORAL_ALPHA=0.1
profile.HIGH.TEMPORAL_ACCUMULATION_ON=true
profile.HIGH.TEMPORAL_ALPHA=0.08
```

---

## PERFORMANCE VERIFICATION

### Frame Time Budget (Updated)

| Feature | LOW | MEDIUM | HIGH | ULTRA | CINEMA |
|---------|-----|--------|------|-------|--------|
| Contact Shadows | - | 0.3ms | 0.4ms | 0.5ms | 0.6ms |
| Bent Normals | - | 0.1ms | 0.1ms | 0.1ms | 0.1ms |
| Parallax Probes | - | 0.15ms | 0.2ms | 0.35ms | 0.35ms |
| Temporal Accum | - | 0.1ms | 0.1ms | 0.1ms | 0.1ms |
| **New Total** | 16ms | **16.75ms** | **16.8ms** | **17.15ms** | **18ms** |
| **FPS @ 1440p** | 60 | 59 | 59 | 58 | 55 |

**Optimization if needed**:
- Reduce contact shadow steps on lower tiers
- Limit bent normal samples (8 instead of 16)
- Disable probes on LOW tier entirely

---

## QUALITY ASSURANCE CHECKLIST

### Before Commit
- [ ] All shaders compile without warnings
- [ ] No visual artifacts (banding, shimmer, color shifts)
- [ ] All quality tiers tested (LOW, MEDIUM, HIGH, ULTRA, CINEMA)
- [ ] All hardware tested (iGPU, GTX 1050, GTX 1660, RTX 3080)
- [ ] Frame time within budget on all tiers
- [ ] No memory leaks or buffer overflows
- [ ] Configuration properly exposed in shaders.properties

### Performance Verification
```bash
# Profile shadow quality
- Contact Shadow OFF: 60 FPS
- Contact Shadow ON: 59 FPS (expected -1 FPS)

- Bent Normal OFF: 59 FPS
- Bent Normal ON: 58.9 FPS (expected -0.1 FPS)

- Parallax Probes: 0-4 probes = linear cost, max -0.35 FPS
```

---

## COMMON PITFALLS & SOLUTIONS

### 1. Contact Shadows Show as Black Squares
**Cause**: Screen space coordinates out of bounds
**Fix**: Add bounds check before sampling depth texture

### 2. Bent Normals Cause Banding
**Cause**: Too few samples (< 8)
**Fix**: Increase BENT_NORMAL_SAMPLES, use better hemisphere distribution

### 3. Probes Show Hard Transitions
**Cause**: Linear blending between probes
**Fix**: Use smoothstep() for smoother weight transitions

### 4. Temporal Ghosting on Movement
**Cause**: Motion vector inaccuracy or too-high accumulation alpha
**Fix**: Disocclusion detection + reduce alpha to 0.05

### 5. Performance Regression
**Cause**: Feature compilation overhead
**Fix**: Use #ifdef guards, disable on LOW tier, profile first

---

## NEXT STEPS AFTER IMPLEMENTATION

1. **Benchmark across hardware**
   - Integrated GPU (iGPU), GTX 1050, GTX 1660, RTX 3080
   - Record baseline vs. with features

2. **Gather community feedback**
   - Encourage beta testing
   - Collect FPS reports + visual preference

3. **Iterate based on data**
   - If FPS drops too much: optimize algorithms
   - If users like feature: expand to other systems

4. **Plan Phase 2** (if Phase 1 successful)
   - Volumetric clouds (higher complexity)
   - Compute shaders (major rewrite)

---

**Success Criteria**:
- ✅ Visual quality match/exceed Complementary & Photon
- ✅ Performance match/exceed MakeUp
- ✅ No artifacts on any hardware
- ✅ 100% backward compatible (old configs still work)
- ✅ 60 FPS on MEDIUM tier (GTX 1660)

