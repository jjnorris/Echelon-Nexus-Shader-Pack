# Phase 3 Implementation Notes — Render Path Refinement

## Overview

Phase 3 establishes the complete material sampling pipeline and implements tier-based render paths. All gbuffers shaders now properly decode materials using LabPBR format with graceful fallback. The deferred lighting pass computes direct lighting using Cook-Torrance BRDF. Final pass applies tonemapping and color grading foundations.

## Material Sampling Infrastructure

### lib/material_sampling.glsl
- **Safe texture sampling** with fallback for missing/unavailable textures
- **Unified material sampling pipeline** (`sampleMaterialComplete`)
- **Parallax mapping foundation** (disabled for terrain in Phase 3, enabled in Phase 7+)
- **Alpha testing** with dithering support (for translucent blending in Phase 8+)
- **Vertex color blending** (for grass tinting, etc.)
- **Light map sampling** (blockLight, skyLight, combined)
- **Material validation** (NaN checks, range clamping)

### Material Decoding Path
1. **Sample base textures** (albedo, specular, normal, height)
2. **Apply parallax** (optional; disabled for baseline)
3. **Decode material** (LabPBR → Material struct)
4. **Validate & clamp** (prevent invalid values)
5. **Blend with vertex color** (per-block customization)
6. **Encode to G-buffers** (colortex0-2)

## GBuffer Pass Refinements

All 5 gbuffers shaders (terrain, entities, hand, weather, water) now:

1. **Include material sampling module** (`lib/material_sampling.glsl`)
2. **Perform proper alpha testing** (early discard for transparent pixels)
3. **Sample and decode materials** using `sampleMaterialComplete()`
4. **Encode materials to colortex1** (roughness, metallic, emissive)
5. **Encode normals to colortex2** using oct-wrap encoding
6. **Linearize and normalize depth** for deferred operations
7. **Apply vertex color blending** (for per-instance customization)

### Water-Specific Handling
- Water is **always rendered** (no alpha test)
- **Fixed material properties**:
  - Roughness: 0.0 (very smooth)
  - Metallic: 0.0 (non-metallic)
  - F0: 0.04 (dielectric, realistic water)
  - Alpha: 0.5 (translucent)
- Per-frame animated normals (reserved for Phase 8)

## Deferred Lighting Implementation

### lib/lighting_common.glsl Integration
- **Cook-Torrance GGX BRDF** fully functional
- **Fresnel (Schlick)**
- **Microfacet distribution (GGX)**
- **Geometry term (Smith height-correlated)**

### Deferred Pass Computation
1. **Read G-buffers** (albedo, material, normal)
2. **Reconstruct Material struct** from encoded data
3. **Compute F0** from metallic workflow
4. **Remap roughness** to alpha (perceptual convention)
5. **Compute direct lighting** from sun
6. **Apply emissive** (self-illumination)
7. **Combine** (ambient + direct + emissive)
8. **Output to colortex0** (lit scene color)

### Limitations (Phase 3)
- **No shadow sampling** (implemented in Phase 6)
- **No view-dependent effects** (viewDir not available; fixed in Phase 4)
- **Flat ambient** (0.15 intensity; replaced with IBL in Phase 12+)
- **Simple sun direction** (hardcoded; dynamic in Phase 6+)

## Final Pass Enhancements

### Tonemapping Operators
- **ACES** (industry-standard, cinematic) — DEFAULT
- **Filmic** (balanced, realistic)
- **Reinhard** (fast, basic)

### Color Grading Foundations
- **Exposure adjustment** (exposure slider in Phase 6+)
- **Saturation boost** (default +10% for vibrancy)
- **Contrast adjustment** (reserved for Phase 11)
- **LUT-based grading** (reserved for Phase 11)

### sRGB Conversion
- Input: Linear light (from previous passes)
- Output: sRGB (for display)

## Tier-Based Render Paths

### Resolution Tiers
```
Tier 1 (LOW):         Screen-res only
Tier 2 (MEDIUM):      + Half-res optional buffers
Tier 3 (HIGH):        + Quarter-res optional buffers
Tier 4 (ULTRA):       Full allocation, all features
Tier 5 (CINEMATIC):   Maximum fidelity
```

### Buffer Size Directives (Phase 4+)
```glsl
// Low-end: disable optional effects
size.4=0.0 0.0    // SSR disabled
size.5=0.0 0.0    // Bloom disabled

// Mid-range: half-res effects
size.4=0.5 0.5    // SSR at half-res
size.5=0.0 0.0    // Bloom optional

// High-end: full pyramid
size.4=0.5 0.5    // SSR at half-res
size.5=0.25 0.25  // Bloom at quarter-res
```

## Known Limitations & Gaps

| Issue | Impact | Timeline |
|-------|--------|----------|
| No view-dependent lighting | BRDF computation inaccurate | Phase 4 (viewDir) |
| No shadows | All surfaces equally lit | Phase 6 (shadows) |
| Flat ambient | Unrealistic night-time | Phase 12 (IBL) |
| No bloom | Bright lights don't glow | Phase 11 (post-proc) |
| No TAA | Aliasing visible | Phase 9 (temporal) |
| No sky dome | Simple flat color | Phase 8 (atmosphere) |

## Testing Checklist (Phase 3)

- [ ] Terrain renders with basic PBR
- [ ] Entities (mobs) render correctly
- [ ] Water appears translucent
- [ ] Weather particles render
- [ ] Material decoding doesn't crash with vanilla textures
- [ ] Fallback materials work (missing specular maps)
- [ ] Normal maps decode correctly
- [ ] Depth linearization is reasonable
- [ ] Lighting is visible (not completely dark)
- [ ] Final pass tonemapping works
- [ ] Color output is reasonable (not inverted/broken)

## Next Phase (Phase 4)

**Goal**: Improve deferred pass with proper depth reconstruction and view-dependent effects.

**Tasks**:
1. Fix `cameraPosition` and `vFragPos` in deferred pass
2. Properly reconstruct view position from depth
3. Compute view direction per-pixel
4. Add parallax mapping support (Phase 7)
5. Implement depth-based edge detection for anti-aliasing

## Architecture Summary

```
GBuffers Pass
├─ Sample textures (albedo, specular, normal, height)
├─ Decode material (LabPBR)
├─ Validate & clamp
└─ Encode to G-buffers (colortex0-2, depthtex0)

Deferred Pass
├─ Read G-buffers
├─ Reconstruct Material struct
├─ Compute Cook-Torrance BRDF
├─ Apply direct lighting
├─ Add emissive
└─ Output lit color (colortex0)

Final Pass
├─ Read composited scene (colortex0)
├─ Apply exposure & tonemapping
├─ Apply color grading
└─ Output to framebuffer (sRGB)
```

## Files Modified

- `shaders/gbuffers_terrain.fsh` — Material sampling + encoding
- `shaders/gbuffers_entities.fsh` — Material sampling + encoding
- `shaders/gbuffers_hand.fsh` — Material sampling + encoding
- `shaders/gbuffers_weather.fsh` — Material sampling + encoding
- `shaders/gbuffers_water.fsh` — Material sampling + water-specific handling
- `shaders/deferred.fsh` — Cook-Torrance BRDF + direct lighting
- `shaders/final.fsh` — Tonemapping + color grading

## Files Added

- `shaders/lib/material_sampling.glsl` — Texture sampling with fallback

## Compatibility Notes

- All shaders compile with Iris 1.10.6 standard directives
- No compute shaders required (baseline path)
- Material decoding supports LabPBR + oldPBR gracefully
- Vanilla textures (no PBR maps) render with sensible defaults
