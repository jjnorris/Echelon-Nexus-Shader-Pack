# Echelon Nexus vs Reference Shaders: Sampler Binding Analysis

**Session:** 011dF8GgqCQiK6k2xENRJixC
**Date:** 2026-03-20
**Task:** Compare shader pack implementations against industry standards

---

## Executive Summary

Our shader pack **violates established patterns** used by all major reference implementations. The critical issue: **declaring samplers without conditional compilation guards**.

### The Problem
```glsl
// ❌ OUR CURRENT CODE (WRONG)
uniform sampler2D tex;
uniform sampler2D normals;      // Will fail if not available!
uniform sampler2D specular;     // Will fail if not available!
uniform sampler2D lightmap;
```

### The Correct Pattern (All 3 References)
```glsl
// ✅ COMPLEMENTARY SHADERS V4
#ifdef ADV_MAT
  #ifndef COMPBR
    uniform sampler2D specular;
    uniform sampler2D normals;
  #endif
#endif

// ✅ PHOTON SHADERS
#if defined NORMAL_MAPPING || defined POM
  uniform sampler2D normals;
#endif

#if defined SPECULAR_MAPPING
  uniform sampler2D specular;
#endif

// ✅ SHADOW TUTORIAL
// Only declares samplers that always exist: tex, lightmap
```

---

## Detailed Comparison Table

| Aspect | Echelon Nexus (Current) | Complementary V4 | Photon Shaders | Shadow Tutorial |
|--------|------------------------|------------------|-----------------|-----------------|
| **Sampler Strategy** | Unconditional declaration | Conditional (`ADV_MAT`) | Conditional (feature flags) | Minimal (only `tex`, `lightmap`) |
| **Custom Samplers** | `normals`, `specular` without guards | Same, but guarded by `ADV_MAT` | Same, but guarded by feature flags | None (vanilla only) |
| **Material Support** | LabPBR (assumed available) | LabPBR OR CustomPBR (configurable) | LabPBR + old format (both supported) | No materials (Phase 1) |
| **GLSL Version** | 130 (old) | 150+ (modern) | 450+ (modern) | 130 (minimal) |
| **Compilation Guards** | None ❌ | Yes (`#ifdef ADV_MAT`) ✅ | Yes (`#if defined`) ✅ | Yes (minimal) ✅ |
| **Include Structure** | Wrapper files include `/program/` | Complex include hierarchy | Modular includes | Simple, linear |
| **Fallback Support** | None - fails if samplers missing ❌ | Yes - disables features ✅ | Yes - dual format support ✅ | Yes - runs on any HW ✅ |
| **shaders.properties** | Basic definitions only | Extensive feature flags | Extensive settings | Minimal |
| **LabPBR Implementation** | Attempted (but samplers unbound) | Full support with guards | Full support with decoding | N/A (Phase 1) |

---

## Reference Implementation Details

### 1. COMPLEMENTARY SHADERS V4 Pattern

**Source:** https://github.com/ComplementaryDevelopment/ComplementaryShadersV4

#### Sampler Declaration (gbuffers_terrain.glsl)
```glsl
uniform sampler2D texture;

#ifdef ADV_MAT
  #ifndef COMPBR
    uniform sampler2D specular;
    uniform sampler2D normals;
  #endif
#endif

#ifdef NOISE_MODE
  uniform sampler2D noisetex;
#endif
```

**Key Pattern:**
- Always declare base samplers (`texture`, `lightmap`)
- Advanced samplers wrapped in **double guard**: `#ifdef ADV_MAT` AND `#ifndef COMPBR`
- Each feature toggle separately controls sampler availability
- Fallback: if ADV_MAT disabled, code path uses base texture only

#### shaders.properties Configuration
```properties
# Feature toggles that gate sampler availability
#define ADV_MAT              // Enables advanced material samplers
#define COMPBR               // Alternative material format (uses different samplers)

# Only if ADV_MAT enabled:
const int colortex2Format = RGBA32F;  // Material buffer
const bool colortex2Mipmap = true;    // Used by material samplers
```

#### Material Decoding (only if ADV_MAT enabled)
```glsl
#ifdef ADV_MAT
  #ifndef COMPBR
    vec4 normalData = texture2D(normals, texCoord);
    vec4 pbrData = texture2D(specular, texCoord);
    // ... decode LabPBR format
  #else
    // Alternative path: COMPBR format uses different samplers
  #endif
#else
  // Fallback: use default material properties
  float smoothness = 0.5;
  float metallic = 0.0;
#endif
```

**Why This Works:**
- If `ADV_MAT` disabled → samplers never declared → no binding errors
- If `ADV_MAT` enabled → custom samplers declared conditionally
- Resource pack determines format → code path follows that choice

---

### 2. PHOTON SHADERS Pattern

**Source:** https://github.com/sixthsurge/photon

#### Sampler Declaration (gbuffers_all_solid.fsh)
```glsl
uniform sampler2D noisetex;
uniform sampler2D gtexture;

#if defined NORMAL_MAPPING || defined POM
  uniform sampler2D normals;
#endif

#if defined SPECULAR_MAPPING
  uniform sampler2D specular;
#endif

#ifdef SHADOW
  uniform sampler2D shadowtex0;
  uniform sampler2DShadow shadowtex1;
  #ifdef SHADOW_COLOR
    uniform sampler2D shadowcolor0;
  #endif
#endif
```

**Key Pattern:**
- Each sampler guarded by **feature-specific flag**
- `NORMAL_MAPPING` OR `POM` → declares `normals`
- `SPECULAR_MAPPING` → declares `specular`
- `SHADOW` → declares shadow textures (with nested `SHADOW_COLOR`)
- Base samplers (`noisetex`, `gtexture`) always available

#### Deferred Pass (d4_deferred_shading.fsh)
```glsl
uniform sampler2D colortex0;  // skytextured output
uniform sampler2D colortex1;  // gbuffer 0
#ifdef NORMAL_MAPPING
  uniform sampler2D colortex2;  // normal data (only if enabled)
#endif

#ifdef COLORED_LIGHTS
  uniform sampler3D light_sampler_a;
  uniform sampler3D light_sampler_b;
#endif
```

**Why This Works:**
- Feature flags control sampler lifetime
- Deferred pass reads from different buffers depending on enabled features
- Dual material format support (LabPBR + custom)
- Hardcoded materials reduce sampler pressure

#### Material Decoding Strategy
```glsl
#define TEXTURE_FORMAT_LAB 0      // LabPBR
#define TEXTURE_FORMAT_OLD 1      // Old format

#define TEXTURE_FORMAT TEXTURE_FORMAT_LAB  // Choose one

void decode_specular_map(vec4 specular_map, inout Material material) {
  #if TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
    // LabPBR decoding (more complex)
    material.roughness = sqr(1.0 - specular_map.r);
    // ... additional LabPBR logic
  #else
    // Old format decoding (simpler)
    material.roughness = sqr(1.0 - specular_map.r);
    material.is_metal = specular_map.g > 0.5;
  #endif
}
```

**Why This Works:**
- Compile-time selection of material format
- No runtime branching (performance)
- Different decoding paths for different resources

---

### 3. SHADOW TUTORIAL Pattern

**Source:** https://github.com/shaderLABS/Shadow-Tutorial

#### Sampler Declaration (gbuffers_basic.fsh)
```glsl
uniform sampler2D tex;      // ✅ Always exists
uniform sampler2D lightmap; // ✅ Always exists

// NO custom samplers declared
// NO material samplers
// NO LabPBR support (Phase 1 only)
```

#### Minimal Approach
```glsl
void main() {
  // Simple texture sampling only
  vec4 diffuse = texture2D(tex, texCoord) * vertexColor;

  // No material decoding
  // No PBR properties
  // Just basic color output

  gl_FragData[0] = vec4(diffuse.rgb, blockLight);
}
```

**Why This Works (Phase 1 Strategy):**
- Only declare samplers that **definitely exist** in Minecraft
- `tex` = always available (block texture atlas)
- `lightmap` = always available (brightness lightmap)
- NO assumptions about resource pack format
- Fallback to basic materials only

---

## Our Implementation Violations

### Violation #1: Unconditional Custom Sampler Declaration

**File:** `shaders/program/gbuffers_textured.fsh` (Lines 18-20)
```glsl
uniform sampler2D tex;           // ✅ OK
uniform sampler2D normals;       // ❌ NOT GUARDED
uniform sampler2D specular;      // ❌ NOT GUARDED
uniform sampler2D lightmap;      // ✅ OK
```

**Expected (based on references):**
```glsl
uniform sampler2D tex;
uniform sampler2D lightmap;

#ifdef ADV_MAT  // Complementary V4 pattern
  #ifndef COMPBR
    uniform sampler2D normals;
    uniform sampler2D specular;
  #endif
#endif
```

OR

```glsl
uniform sampler2D tex;
uniform sampler2D lightmap;

#if defined NORMAL_MAPPING
  uniform sampler2D normals;
#endif

#if defined SPECULAR_MAPPING
  uniform sampler2D specular;
#endif
```

OR (Shadow Tutorial approach)

```glsl
uniform sampler2D tex;
uniform sampler2D lightmap;
// NO custom samplers - use basic materials only
```

### Violation #2: Unconditional Material Decoding

**File:** `shaders/program/gbuffers_textured.fsh` (Lines 50-89)
```glsl
// UNCONDITIONAL: Assumes samplers exist
vec4 normalData = texture2D(normals, texCoord);
vec4 pbrData = texture2D(specular, texCoord);

// Try to decode LabPBR without checking if supported
float smoothness = pbrData.r;
float metallic = pbrData.g / 255.0;
```

**Expected (based on references):**
```glsl
#ifdef ADV_MAT
  #ifndef COMPBR
    vec4 normalData = texture2D(normals, texCoord);
    vec4 pbrData = texture2D(specular, texCoord);

    float smoothness = pbrData.r;
    float metallic = pbrData.g / 255.0;
  #else
    // Alternative format handling
    float smoothness = 0.5;
    float metallic = 0.0;
  #endif
#else
  // Fallback: basic materials
  float smoothness = 0.5;
  float metallic = 0.0;
#endif
```

### Violation #3: No Feature Flag Configuration

**File:** `shaders/shaders.properties`
- NO `ADV_MAT` flag definition
- NO material format selection
- NO feature gates for samplers
- NO fallback paths documented

**Expected:**
```properties
// Based on Complementary V4 pattern
#define ADV_MAT                    // Enable advanced materials
#define COMPBR                     // Select COMPBR format OR remove for LabPBR

// Based on Photon pattern
#define NORMAL_MAPPING             // Enable normal map sampling
#define SPECULAR_MAPPING           // Enable specular map sampling

// Based on Shadow Tutorial pattern
// (No special flags - everything is basic)
```

### Violation #4: Missing Conditional Include Guards

**Files:** All `/program/*.glsl` files
```glsl
// Missing: #ifdef FSH guards
// Missing: #ifndef INCLUDED_* guards for library files

void main() {
  // No guards = if included multiple times, main() defined twice
}
```

**Expected (all references):**
```glsl
#ifdef FSH  // Only compile fragment shaders

#ifndef INCLUDED_COMPOSITE
#define INCLUDED_COMPOSITE

// ... shader code ...

#endif  // INCLUDED_COMPOSITE
#endif  // FSH
```

---

## Root Cause Analysis

### Why The Black Screen Happened

1. **Our shaders declare:** `uniform sampler2D normals, specular`
2. **Iris doesn't provide these samplers** (they're not standard Minecraft)
3. **Shader compilation fails silently** because samplers are unbound
4. **Iris falls back to fixed-pipeline rendering** or disables shader pass
5. **Result:** Black screen (no geometry rendered)

### Why References Don't Have This Problem

**Complementary V4:**
- Guarded by `#ifdef ADV_MAT` → If not enabled, samplers never declared
- Resource packs indicate material support → Flag is set automatically
- Fallback path: if not enabled, uses basic materials

**Photon Shaders:**
- Guarded by feature flags → If disabled, samplers don't exist
- Deferred pass reads different buffers per configuration
- Dual-format support: can read LabPBR OR old format

**Shadow Tutorial:**
- Simple: only uses samplers that **always exist**
- No assumptions about resource pack
- Graceful degradation

---

## Implementation Requirements (From Checklist)

**From PRE_TASK_CHECKLIST.md:**

✅ **Step 3: Reference Implementations** - COMPLETED
- [x] Fetched Complementary Shaders V4
- [x] Fetched Photon Shaders
- [x] Fetched Shadow Tutorial
- [x] Studied architecture patterns
- [x] Documented differences

✅ **Step 4: Minecraft 1.21.11 Compatibility** - COMPLETED
- [x] Verified passes available in Iris 1.6.0+
- [x] Checked uniform availability per pass
- [x] Confirmed backward compatibility requirements

📋 **Step 5: Implementation Plan** (NEXT)
- [ ] List mathematical steps
- [ ] Map to GLSL operations
- [ ] Identify all functions needed
- [ ] Identify all uniforms needed
- [ ] Plan optimization points

---

## Conclusion

**Our current implementation is non-functional because:**

1. Declares samplers Iris doesn't provide ❌
2. Uses no conditional compilation guards ❌
3. Has no fallback for missing features ❌
4. Violates all three reference implementations ❌

**The fix requires:**

1. Guard custom samplers with feature flags ✅
2. Provide fallback material paths ✅
3. Add feature flags to shaders.properties ✅
4. Follow reference pattern exactly ✅
5. Test against all three reference packs ✅

---

**Next Steps:**
1. Create detailed implementation plan
2. Implement sampler guards following Complementary V4 pattern (most comprehensive)
3. Test rendering
4. Compare against reference outputs
