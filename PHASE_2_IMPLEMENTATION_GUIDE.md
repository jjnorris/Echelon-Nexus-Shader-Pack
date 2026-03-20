# PHASE 2: PCSS SHADOWS - IMPLEMENTATION GUIDE

**Status:** Foundation Complete, Core Algorithm Ready
**Estimated Time to Complete:** 2-4 weeks
**Performance Target:** <2ms overhead on HIGH profile
**Quality Target:** Surpass Complementary Shaders V4 shadow quality

---

## OVERVIEW

Phase 2 transforms basic PCF shadows into production-quality PCSS (Percentage-Closer Soft Shadows) with adaptive filtering, cascades, and colored shadows. The core PCSS algorithm is already implemented in `shaders/program/pcss.glsl`.

**What's Done:**
- ✅ Poisson disk sampling patterns (golden angle spacing)
- ✅ Blocker search algorithm (16 samples)
- ✅ Penumbra size estimation (geometric calculation)
- ✅ Variable-radius PCF (4-32 adaptive samples)
- ✅ Shadow cascade framework
- ✅ Colored shadow support
- ✅ composite2.vsh/fsh skeleton

**What Remains:**
- [ ] Depth reconstruction from depth buffer
- [ ] Shadow space matrix transformations
- [ ] Full composite2.fsh implementation
- [ ] BRDF lighting integration
- [ ] Temporal shadow refinement
- [ ] Testing and optimization

---

## ARCHITECTURE

### Composite Pass Pipeline (Phase 1 → Phase 2 → Phase 3+)

```
gbuffers passes (12 programs)
        ↓
     composite.fsh (Phase 1 vanilla lighting)
        ↓
   composite2.fsh (Phase 2 PCSS shadows) ← YOU ARE HERE
        ↓
   composite3.fsh (Phase 3 TAA)
        ↓
     final.fsh (tonemapping + gamma)
        ↓
    Screen output
```

### Data Flow Through Phase 2

```
Input from Phase 1:
├─ colortex0: Base color from gbuffers
├─ depthtex0: Scene depth (0-1 linear)
├─ shadowtex0: Shadow map (directional light)
├─ shadowcolor0: Colored shadow data
└─ Transformation matrices

Processing in composite2.fsh:
├─ Reconstruct world position from depth
├─ Transform to shadow space
├─ Apply PCSS algorithm:
│  ├─ Blocker search (16 samples)
│  ├─ Penumbra estimation (geometry)
│  └─ Variable-radius PCF (4-32 samples)
├─ Select shadow cascade
├─ Blend cascade transitions
├─ Apply colored shadows
└─ Temporal filtering (optional)

Output to Phase 3:
└─ colortex5: Shadowed scene (ready for BRDF)
```

---

## IMPLEMENTATION STEPS

### Step 1: Depth Reconstruction (Week 1)

**Goal:** Convert depth buffer to world position

**Code Pattern:**
```glsl
// In composite2.fsh

// Reconstruct clip-space position from depth
vec3 ndc = vec3(uv * 2.0 - 1.0, depth * 2.0 - 1.0);  // -1 to 1 range

// Transform to view space
vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
viewPos /= viewPos.w;  // Perspective divide

// Transform to world space
vec4 worldPos = gbufferModelViewInverse * viewPos;

// Extract xyz
vec3 fragWorldPos = worldPos.xyz;
```

**Resources:**
- Use `gbufferProjectionInverse` and `gbufferModelViewInverse` uniforms
- Already available in Iris
- Reconstruct world position for shadow calculations

**Testing:**
- Verify world positions make sense (increasing with distance)
- Visualize using debug mode (output as color for inspection)

---

### Step 2: Shadow Space Transformation (Week 1)

**Goal:** Project world position into shadow map coordinates

**Code Pattern:**
```glsl
// Transform world position to shadow space
vec4 shadowPos = shadowProjection * (shadowModelView * vec4(fragWorldPos, 1.0));
shadowPos /= shadowPos.w;  // Perspective divide

// Convert from [-1, 1] to [0, 1] for texture lookup
vec2 shadowCoord = shadowPos.xy * 0.5 + 0.5;
float shadowDepth = shadowPos.z * 0.5 + 0.5;  // Normalize depth
```

**Available Uniforms:**
- `shadowProjection` - Shadow projection matrix
- `shadowModelView` - Shadow model-view matrix
- Both provided by Iris

**Edge Cases:**
- Clamp coordinates to [0, 1] to prevent out-of-bounds sampling
- Handle fragments outside shadow map gracefully (fully lit)

---

### Step 3: PCSS Integration (Week 2)

**Goal:** Call PCSS algorithm functions and compute shadows

**Code Template for composite2.fsh:**
```glsl
#include "/lib/pcss.glsl"

void main() {
	// Load data
	vec4 baseColor = texture(colortex0, uv);
	float depth = texture(depthtex0, uv).r;

	// Sky - no shadow
	if (depth > 0.9999) {
		fragColor = baseColor;
		return;
	}

	// Reconstruct world position (Step 1)
	vec3 worldPos = reconstructWorldPosition(uv, depth);

	// Transform to shadow space (Step 2)
	vec2 shadowCoord = projectToShadowSpace(worldPos);
	float shadowDepth = getShadowDepth(worldPos);

	// ====== PCSS SHADOW COMPUTATION ======

	// PCSS parameters (configurable)
	float lightSize = 0.5;      // Light angular size (0.3-1.0)
	float searchRadius = 3.0;   // Blocker search radius

	// Call PCSS algorithm
	float shadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth,
	                          lightSize, searchRadius);

	// Apply shadow to color
	vec3 shadowed = baseColor.rgb * (0.5 + shadow * 0.5);  // 50-100% brightness in shadow

	// Output for Phase 3
	fragColor = vec4(shadowed, baseColor.a);
}
```

**Key Parameters:**
- **lightSize**: 0.5 is reasonable; higher = softer shadows
- **searchRadius**: 3.0 typical; scales with shadow distance
- Tune based on visual results

---

### Step 4: Shadow Cascades (Week 2)

**Goal:** Use different shadow maps for near/far geometry

**Implementation:**
```glsl
// Select cascade based on fragment distance
float linearDepth = ... // Calculate from depth buffer
int cascade = selectShadowCascade(linearDepth);

// Use appropriate shadow map
// TODO: Implement cascade selection with multiple shadow maps
// For Phase 2.1, use single cascade (shadowtex0)

// Blend cascades at boundaries for smooth transitions
float blendFactor = cascadeBlendFactor(linearDepth, cascade);
float shadow = mix(shadowFromCascade[cascade],
                   shadowFromCascade[cascade + 1],
                   blendFactor);
```

**Note:** Iris provides shadowtex0 and shadowtex1. Cascades are optional for MVP but improve visual quality at distance.

---

### Step 5: Colored Shadows (Week 3)

**Goal:** Apply tinted shadows from translucent blocks

**Implementation:**
```glsl
// Sample colored shadow data
vec4 coloredShadow = texture(shadowcolor0, shadowCoord);

// Apply color tint to shadow
vec3 shadowColor = applyColoredShadow(coloredShadow.rgb, shadow);
vec3 shadowed = baseColor.rgb * shadowColor;
```

**Expected Results:**
- Stained glass casts colored shadows
- Water casts blue-tinted shadows
- Ice casts slight blue-white shadows

---

### Step 6: Temporal Refinement (Week 3-4, Optional)

**Goal:** Reduce shadow flickering across frames

**Concept:**
```glsl
// Get previous frame shadow (from colortex5 history)
vec3 previousShadow = texture(colortex5_prev, reprojectedUV).rgb;

// Blend with current frame
vec3 refinedShadow = mix(previousShadow, currentShadow, 0.2);  // 20% current, 80% history
```

**Note:** Requires motion vector tracking (Phase 3). Optional for Phase 2.

---

## TESTING & VALIDATION

### Visual Testing Checklist

```
Shadow Quality:
├─ [ ] Shadow edges are smooth (not aliased)
├─ [ ] Penumbra varies with distance (close = sharp, far = soft)
├─ [ ] No banding in shadow gradients
├─ [ ] Colored shadows visible from glass
└─ [ ] Shadow direction matches sun position

Performance:
├─ [ ] Frame time < 16.67ms (60 FPS) on HIGH
├─ [ ] PCSS overhead < 2ms measured
├─ [ ] No frame rate stuttering
├─ [ ] Stable GPU memory usage
└─ [ ] No thermal throttling

Cascade Quality:
├─ [ ] Smooth transition between cascades
├─ [ ] No shadow pop/flicker at boundaries
├─ [ ] Far shadows still visible
└─ [ ] Near/far quality difference acceptable

Compatibility:
├─ [ ] Works on RTX 3060 (HIGH profile)
├─ [ ] Works on GTX 1660 (MEDIUM profile)
├─ [ ] Graceful fallback on LOW profile
└─ [ ] No crashes or shader errors
```

### Performance Profiling

**Target Times:**
- Blocker search: < 0.5ms (16 samples)
- Penumbra calc: < 0.1ms (simple math)
- PCF filtering: < 1.0ms (adaptive 4-32 samples)
- Colored shadows: < 0.2ms
- **Total composite2: < 2.0ms**

**Measurement Method:**
- Use Iris profiler (`/debug` command in-game)
- Measure "composite2" pass time
- Compare against Phase 1 baseline

---

## OPTIMIZATION STRATEGIES

### Performance Improvements (If Needed)

**1. Reduce Blocker Search Samples**
```glsl
// Current: 16 samples
// For fast path: 8 samples (still good quality)
// For quality: keep 16
vec3 blockerInfo = pcssBlockerSearch(shadowMap, coord, depth, radius, 8);
```

**2. Reduce PCF Sample Count**
```glsl
// Current: adaptive 4-32
// Aggressive: always 16 (fixed)
// Conservative: always 32 (quality)
// Default: adaptive (best quality/performance trade-off)
```

**3. Reduce Search Radius**
```glsl
// Current: 3.0
// Faster: 2.0 (less soft shadows but faster)
// Higher quality: 4.0 (softer, more expensive)
```

**4. Single Cascade (Skip Cascades)**
```glsl
// Remove cascade selection logic
// Just use shadowtex0 for all depths
// Faster but less quality at distance
```

---

## KNOWN ISSUES & SOLUTIONS

| Issue | Cause | Solution |
|-------|-------|----------|
| Black screen | Incorrect shadow coord bounds | Clamp coordinates to [0,1] |
| Shadow flickering | Precision issues in depth | Use appropriate depth format |
| Overly soft shadows | Light size too large | Reduce lightSize parameter |
| Sharp shadows | Light size too small | Increase lightSize parameter |
| Cascade seams | Wrong blend transition | Adjust cascadeBlendFactor |
| Performance drops | Too many samples | Use adaptive counts |

---

## CONFIGURATION

### Optional shaders.properties Additions

```properties
# Phase 2 PCSS Shadow Settings (when ready)
option.SHADOW_QUALITY=Low Medium High Ultra
value.SHADOW_QUALITY.Low=4
value.SHADOW_QUALITY.Medium=16
value.SHADOW_QUALITY.High=32
value.SHADOW_QUALITY.Ultra=64
```

---

## NEXT PHASES

### Phase 3: Temporal Anti-Aliasing
Will use refined shadows from Phase 2 as input, adding temporal coherence to both shadows and general rendering.

### Phase 4+: Advanced Lighting
Will combine Phase 2 shadows with Cook-Torrance BRDF for full physically-based rendering.

---

## RESOURCES & REFERENCES

**Papers:**
- Fernando, R. et al. (2006). "Percentage-Closer Soft Shadows." ACM SIGGRAPH 2006.
- Wimmer, M., et al. (2004). "Shadow Mapping for Deferred Rendering." Game Developers Conference.

**Code References:**
- `shaders/program/pcss.glsl` - Complete PCSS implementation
- `shaders/composite2.fsh` - Framework for integration
- `shaders/program/math.glsl` - Helper functions

**Related Tools:**
- Iris Profiler (`/debug` in Minecraft)
- RenderDoc (GPU frame capture and analysis)
- GPU-Z (Performance monitoring)

---

## TIMELINE

| Week | Task | Status |
|------|------|--------|
| 1 | Depth reconstruction + Shadow space transform | Not Started |
| 1-2 | PCSS integration in composite2.fsh | Not Started |
| 2 | Shadow cascades | Not Started |
| 3 | Colored shadow support | Not Started |
| 3-4 | Testing, optimization, validation | Not Started |

**Estimated Completion:** 2-4 weeks (with full-time dev effort, 1 week with focused sessions)

---

## SUCCESS CRITERIA

Phase 2 is complete when:

- [ ] PCSS algorithm produces soft shadows
- [ ] Shadow quality visually surpasses Complementary V4
- [ ] Cascades blend smoothly without artifacts
- [ ] Colored shadows work on translucent blocks
- [ ] Performance < 2ms on HIGH profile
- [ ] No crashes or visual glitches
- [ ] Works on all target GPU tiers
- [ ] Temporal stability acceptable (minimal flicker)

---

## COMMIT STRATEGY

Each completed step should have its own commit:

1. `feat: Phase 2 - Depth reconstruction`
2. `feat: Phase 2 - Shadow space transformation`
3. `feat: Phase 2 - PCSS integration in composite2`
4. `feat: Phase 2 - Shadow cascades`
5. `feat: Phase 2 - Colored shadows`
6. `feat: Phase 2 - Temporal refinement (optional)`

---

**Document Updated:** 2026-03-20
**Phase 2 Status:** Foundation Complete, Ready for Implementation
