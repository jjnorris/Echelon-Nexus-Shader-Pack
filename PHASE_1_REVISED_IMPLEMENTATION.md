# Phase 1 Revised Implementation Plan
## Shadow Tutorial Minimal Approach for Foundation

**Updated:** 2026-03-20
**Based on:** All three reference analyses (Complementary V4, Photon, Shadow Tutorial)
**Key Insight:** Shadow Tutorial Phase 1 uses NO custom material samplers

---

## Strategic Shift

### Original Plan ❌
- Try to add LabPBR material support in Phase 1
- Declare custom samplers with `#ifdef ADV_MAT` guards
- Complex fallback paths

### REVISED Plan ✅
- **Phase 1:** Use ONLY standard Minecraft samplers (Shadow Tutorial approach)
- **Phase 2:** Add LabPBR material support with guards (Complementary V4 approach)
- **Phase 3:** Quantum-inspired TAA (existing plan)

**Why This Works:**
1. ✅ Matches our existing Phase 1, Phase 2, Phase 3 structure
2. ✅ No unbound samplers = no black screen
3. ✅ Proven by Shadow Tutorial (thousands of players)
4. ✅ Material support deferred to Phase 2 (planned already)
5. ✅ Cleaner separation of concerns

---

## Phase 1 Implementation (NOW)

### Step 1: Simplify All gbuffers Shaders to Use Only Standard Samplers

**Pattern (from Shadow Tutorial):**
```glsl
uniform sampler2D tex;           // Standard Minecraft texture atlas
uniform sampler2D lightmap;      // Standard Minecraft lightmap
// NO custom samplers in Phase 1
```

**Files to Update:**
- `shaders/program/gbuffers_basic.fsh`
- `shaders/program/gbuffers_textured.fsh`
- `shaders/program/gbuffers_terrain.fsh`
- `shaders/program/gbuffers_entities.fsh`
- `shaders/program/gbuffers_hand.fsh`
- `shaders/program/gbuffers_clouds.fsh`
- `shaders/program/gbuffers_water.fsh`
- `shaders/program/gbuffers_weather.fsh`
- `shaders/program/gbuffers_sky.fsh`

### Step 2: Remove Material Decoding Logic

**Current (REMOVE):**
```glsl
vec4 normalData = texture2D(normals, texCoord);
vec4 pbrData = texture2D(specular, texCoord);
float smoothness = pbrData.r;
float metallic = pbrData.g / 255.0;
```

**Replacement (USE):**
```glsl
// Phase 1: Basic materials (LabPBR support deferred to Phase 2)
float smoothness = 0.5;  // Default mid-range
float metallic = 0.0;    // Default non-metallic
float emissive = 0.0;    // Default non-emissive
```

### Step 3: Add Include Guards to All Shaders

**Pattern (from references):**
```glsl
#ifdef FSH
#ifndef INCLUDED_GBUFFERS_TEXTURED
#define INCLUDED_GBUFFERS_TEXTURED

// ... shader code ...

#endif  // INCLUDED_GBUFFERS_TEXTURED
#endif  // FSH
```

### Step 4: Update shaders.properties

**Remove:**
- Any `ADV_MAT` references (not needed in Phase 1)
- Any LabPBR configuration options

**Keep:**
- Current shadow quality settings
- Current effect toggles (block emission, AO, etc.)
- Current screen definitions

---

## Implementation Example: gbuffers_textured.fsh

```glsl
#version 130

// GBUFFERS_TEXTURED FRAGMENT SHADER - Phase 1
// Reference: Shadow Tutorial https://github.com/shaderLABS/Shadow-Tutorial
// Purpose: Render textured blocks/entities to G-Buffer

#ifdef FSH
#ifndef INCLUDED_GBUFFERS_TEXTURED
#define INCLUDED_GBUFFERS_TEXTURED

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec3 normal;
varying vec4 vertexColor;
varying vec3 viewPos;

// Standard Minecraft samplers ONLY
uniform sampler2D tex;
uniform sampler2D lightmap;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
  // Step 1: Sample base texture
  vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

  // Step 2: Discard transparent pixels
  if (diffuse.a < 0.5) {
    discard;
  }

  // Step 3: Sample lightmap
  vec2 lightData = texture2D(lightmap, lightCoord).xy;
  float blockLight = lightData.x;
  float skyLight = lightData.y;

  // Step 4: Set default material properties (Phase 1)
  // Material support (LabPBR) will be added in Phase 2
  vec3 worldNormal = normalize(normal);
  float smoothness = 0.5;
  float metallic = 0.0;
  float emissive = 0.0;
  float ambientOcclusion = 1.0;

  // ===== OUTPUT TO G-BUFFERS =====

  // gcolor (colortex0): Color + block light
  gl_FragData[0] = vec4(diffuse.rgb * ambientOcclusion, blockLight);

  // gdepth (colortex1): Depth
  float depth = length(viewPos) / 256.0;
  gl_FragData[1] = vec4(depth, 0.0, 0.0, 1.0);

  // gnormal (colortex2): Normal + smoothness
  gl_FragData[2] = vec4(
    worldNormal * 0.5 + 0.5,
    smoothness
  );

  // gaux1 (colortex4): Material data
  gl_FragData[4] = vec4(
    metallic,
    emissive,
    skyLight,
    1.0
  );

  // colortex3: Unused in Phase 1
  gl_FragData[3] = vec4(0.0);
}

#endif  // INCLUDED_GBUFFERS_TEXTURED
#endif  // FSH
```

---

## What This Phase 1 Achieves

✅ **Renders without black screen** (no unbound samplers)
✅ **Matches Shadow Tutorial foundation** (proven pattern)
✅ **Outputs to G-Buffers properly** (geometry is visible)
✅ **Default materials work** (blocks appear with basic shading)
✅ **Ready for Phase 2** (structure supports material addition)

## What Phase 1 Does NOT Have (Deferred to Phase 2)

❌ LabPBR material sampling
❌ Advanced material properties
❌ Normal mapping
❌ Parallax mapping
❌ Material-specific rendering

---

## Phase 2 Plan (LATER)

Once Phase 1 is working, Phase 2 will:

1. Add `#ifdef ADV_MAT` guards (Complementary V4 pattern)
2. Conditionally declare `normals` and `specular` samplers
3. Add LabPBR decoding logic
4. Provide fallback path if ADV_MAT disabled
5. Update shaders.properties with material flags

**This is EXACTLY what Complementary V4 does in their code.**

---

## Testing Phase 1

### Test 1: Compilation
```
✓ No sampler binding errors
✓ All shaders compile
✓ No "undefined sampler" warnings
```

### Test 2: Rendering
```
✓ World is visible (not black)
✓ All terrain renders
✓ All entities render
✓ Lighting works
```

### Test 3: Comparison
```
✓ Compare to Shadow Tutorial output (should match Phase 1 style)
✓ Basic materials visible
✓ No artifact errors
```

---

## File Changes Summary

| File | Change | Reason |
|------|--------|--------|
| `gbuffers_textured.fsh` | Remove normals/specular sampling | Phase 1 minimal approach |
| `gbuffers_terrain.fsh` | Remove normals/specular sampling | Phase 1 minimal approach |
| `gbuffers_entities.fsh` | Remove normals/specular sampling | Phase 1 minimal approach |
| All `gbuffers_*.fsh` | Add include guards | Match reference pattern |
| `shaders.properties` | Keep as-is | No Phase 1 material flags needed |

---

## Commit Strategy

**Commit 1:** "Phase 1: Remove material samplers for basic rendering"
- Remove all normals/specular declarations
- Add basic material defaults
- Update files to match Shadow Tutorial pattern

**Commit 2:** "Phase 1: Add include guards to all shaders"
- Add `#ifdef FSH` and `#ifndef INCLUDED_*` guards
- Ensures proper include semantics

**Commit 3:** "Phase 1: Simplify composite passes"
- Ensure composite shaders also use only standard samplers
- Verify pass-through rendering works

---

## Success Criteria for Phase 1

✅ All shaders compile without errors
✅ Game world renders (no black screen)
✅ Performance is good (<2ms per pass)
✅ Visual matches Shadow Tutorial baseline
✅ Ready for Phase 2 material support
✅ All commits reference this plan

---

## Why This Revised Plan is Better

| Aspect | Original Plan | Revised Plan |
|--------|---------------|--------------|
| **Phase 1 Scope** | Try to add materials | Keep it simple (Shadow Tutorial) |
| **Risk** | High (unbound samplers) | Low (only standard samplers) |
| **Matching References** | Tries Complementary V4 immediately | Starts with Shadow Tutorial, evolves to Complementary V4 |
| **Alignment with Project** | Misaligns phases | Perfect alignment (Phase 1→2→3) |
| **User Hardware** | Requires material support | Works on all hardware |
| **Complexity** | Complex fallback paths | Clean separation: Phase 1 basic, Phase 2 advanced |

---

## Next Steps

1. ✅ Analysis complete (this document)
2. ⏳ Implement Phase 1 changes
3. ⏳ Test Phase 1 rendering
4. ⏳ Commit Phase 1
5. 📋 Plan Phase 2 material support

Ready to implement Phase 1? 🚀
