# Echelon Nexus Shader Pack — Buffer Layout & Data Flow

## Buffer Allocation Strategy

This document defines exact buffer semantics, formats, ownership, and data flow through the rendering pipeline.

---

## Tier-Based Buffer Resolution

Buffer resolution varies by quality profile to optimize performance vs. quality.

### Resolution Scales

```
Screen Resolution   = Main render target (e.g., 1920x1080)
Half-Res            = 0.5x both dimensions (960x540)
Quarter-Res         = 0.25x both dimensions (480x270)
```

### Tier Resolution Table

| Tier | Profile | Screen | Half-Res | Quarter-Res | Strategy |
|------|---------|--------|----------|-------------|----------|
| 1 | LOW | ✓ | ✗ | ✗ | Minimal; screen-res only |
| 2 | MEDIUM | ✓ | ✓ | ✗ | Optional half-res for SSR |
| 3 | HIGH | ✓ | ✓ | ✓ | Half-res SSR, quarter-res bloom |
| 4 | ULTRA | ✓ | ✓ | ✓ | Full bloom pyramid, half-res effects |
| 5 | CINEMATIC | ✓ | ✓ | ✓ | Maximum fidelity; all resolutions |

---

## Color Texture Buffer Allocation

Total available: **16 buffers** (colortex0 through colortex15)

### Primary Buffers (Per-Pixel Data)

#### **colortex0** — Scene Color (Lit or Deferred)
- **Format**: RGBA8 (or RGBA16F for HDR)
- **Resolution**: Screen
- **Ownership**:
  - **Written by**: gbuffers_terrain, gbuffers_entities, gbuffers_hand, gbuffers_weather, gbuffers_water
  - **Read by**: deferred, deferred1, composite, composite1, final
  - **Semantics**:
    - **R, G, B**: Scene color (RGB8 compressed or linear FP16)
    - **A**: Transparency/transmittance (1.0 = opaque, < 1.0 = translucent)

#### **colortex1** — Material Parameters (Roughness, Metallic, Emissive)
- **Format**: RGBA16F (half-precision important for per-pixel precision)
- **Resolution**: Screen
- **Ownership**:
  - **Written by**: gbuffers_terrain, gbuffers_entities, gbuffers_hand, gbuffers_weather, gbuffers_water
  - **Read by**: deferred, deferred1
  - **Semantics** (LabPBR convention):
    - **R**: Smoothness/Roughness (inverted; 1.0 = rough, 0.0 = smooth)
    - **G**: F0 / Metallic (dielectric F0 ≈ 0.04, metals ≈ 0.5–1.0)
    - **B**: Emissive intensity (0–1 range; 0 = non-emissive)
    - **A**: Reserved / Normal map flag (for oldPBR fallback indicator)

#### **colortex2** — Normals & Depth Encoding
- **Format**: RGBA16F (precision needed for depth linearization)
- **Resolution**: Screen
- **Ownership**:
  - **Written by**: gbuffers_terrain, gbuffers_entities, gbuffers_hand, gbuffers_weather, gbuffers_water
  - **Read by**: deferred, deferred1, composite
  - **Semantics**:
    - **R, G**: Encoded surface normal (oct-wrap; see lib/encoding.glsl)
    - **B**: Linearized depth or depth NDC (0–1)
    - **A**: Material type flag / additional data (reserved)

#### **colortex3** — Temporal History Buffer (TAA)
- **Format**: RGBA16F
- **Resolution**: Screen
- **Ownership**:
  - **Written by**: composite (history update)
  - **Read by**: composite (clamping / reprojection), deferred1 (optional)
  - **Semantics**:
    - **R, G, B**: Previous-frame color (for reprojection)
    - **A**: Luminance history / variance (for clamping)

#### **colortex4** — SSR Intermediate / Reflection Data
- **Format**: RGBA16F
- **Resolution**: Half-Res (if SSR_ON && TIER >= 2)
- **Ownership**:
  - **Written by**: composite (SSR trace + prefilter)
  - **Read by**: composite1 (SSR integration)
  - **Semantics**:
    - **R, G, B**: Specular reflection color
    - **A**: Confidence / hit flag (0 = miss, 1 = valid)

#### **colortex5** — Bloom Prefilter
- **Format**: RGBA16F
- **Resolution**: Quarter-Res (if BLOOM_ON && TIER >= 3)
- **Ownership**:
  - **Written by**: composite (bright-pixel extraction)
  - **Read by**: composite1 (bloom upsample chain)
  - **Semantics**:
    - **R, G, B**: Bright pixels (> BLOOM_THRESHOLD)
    - **A**: Bloom intensity (pre-weighted)

### Optional Buffers (Future Extensions)

#### **colortex6** — Lighting Intermediate (Deferred)
- **Format**: RGBA16F
- **Resolution**: Screen
- **Usage**: Optional; for multi-pass lighting (e.g., direct light, GI, specular separately)
- **Reserved for Phase 5+**

#### **colortex7–colortex15** — Available
- Reserved for future effects:
  - Motion vectors (Phase 9)
  - Velocity buffer (Phase 9)
  - Custom user effects
  - Debug buffers

---

## Depth Texture

#### **depthtex0** — Primary Depth Buffer
- **Format**: Automatically managed by Iris (typically DEPTH24_STENCIL8)
- **Resolution**: Screen
- **Ownership**:
  - **Written by**: All gbuffers passes (automatic rasterization)
  - **Read by**: deferred, composite (for linearization)
  - **Semantics**: Standard OpenGL depth (0–1 after NDC transform)

#### **depthtex1** — Optional Opaque-Only Depth (Future)
- **Purpose**: Separate depth for opaque vs. translucent (reserved for Phase 7)

---

## Shadow Texture

#### **shadowtex0** — Shadow Depth Map
- **Format**: R32F or DEPTH24 (managed by Iris)
- **Resolution**: Dynamic (based on SHADOW_DISTANCE)
- **Ownership**:
  - **Written by**: shadow.vsh / shadow.fsh
  - **Read by**: deferred, deferred1 (shadow lookup)
  - **Semantics**: Depth from light perspective; used for PCF/PCSS filtering

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SHADOW PASS                                              │
│    Render from light perspective → shadowtex0               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. GBUFFERS PASSES (Terrain, Entities, Hand, Weather, Water)│
│    INPUT:  Block/entity textures, vertex attributes         │
│    OUTPUT: colortex0 (albedo)                               │
│             colortex1 (roughness, metallic, emissive)       │
│             colortex2 (normal, depth)                       │
│             depthtex0 (automatic Z-buffer)                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. DEFERRED PASS (Main Lighting)                            │
│    INPUT:  colortex0, colortex1, colortex2, shadowtex0      │
│    COMPUTE: Cook-Torrance BRDF per pixel                    │
│    OUTPUT: colortex0 (lit color)                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. DEFERRED1 PASS (Optional; Additional Lighting)           │
│    INPUT:  colortex0-2, auxiliary data                      │
│    OUTPUT: colortex0 (updated with secondary effects)       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. COMPOSITE PASS (Post-Processing)                         │
│    INPUT:  colortex0 (lit scene), colortex1-2 (material)    │
│    COMPUTE: SSR (if enabled), TAA (if enabled)              │
│             Bloom prefilter (if enabled), fog                │
│    OUTPUT: colortex0 (post-processed scene)                 │
│             colortex3 (history for TAA)                      │
│             colortex4 (SSR intermediate)                     │
│             colortex5 (bloom prefilter)                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. COMPOSITE1 PASS (Optional; Post-Effects)                 │
│    INPUT:  colortex0-5 (intermediate data)                  │
│    COMPUTE: Bloom upsampling, SSR integration                │
│    OUTPUT: colortex0 (final composited scene)               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. FINAL PASS (Framebuffer Output)                          │
│    INPUT:  colortex0 (composited scene)                     │
│    COMPUTE: Tonemapping, color grading                       │
│    OUTPUT: gl_FragColor (screen output)                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Per-Pass Data Written

### Shadow Pass
| Buffer | Data |
|--------|------|
| shadowtex0 | Depth (from light perspective) |

### GBuffers Passes (terrain, entities, hand, weather, water)
| Buffer | Data |
|--------|------|
| colortex0 | Albedo RGB + Alpha (transparency) |
| colortex1 | Roughness (R), Metallic (G), Emissive (B), Flag (A) |
| colortex2 | Normal XY (oct-wrap) + Depth (B), Type Flag (A) |
| depthtex0 | Depth (automatic) |

### Deferred Pass
| Buffer | Data |
|--------|------|
| colortex0 | Lit scene color (RGB) + Alpha (A) |

### Deferred1 Pass (if enabled)
| Buffer | Data |
|--------|------|
| colortex0 | Additional lighting contributions |

### Composite Pass
| Buffer | Data |
|--------|------|
| colortex0 | Post-processed scene (before final effects) |
| colortex3 | TAA history (if TAA_ON) |
| colortex4 | SSR reflection data (if SSR_ON) |
| colortex5 | Bloom bright pixels (if BLOOM_ON) |

### Composite1 Pass (if enabled)
| Buffer | Data |
|--------|------|
| colortex0 | Final composited scene (bloom upsampled, SSR integrated) |

### Final Pass
| Output | Data |
|--------|------|
| gl_FragColor | Tonemapped + color-graded framebuffer output |

---

## Special Textures & Samplers

### Read-Only Textures (From Minecraft)

| Sampler | Unit | Content | Usage |
|---------|------|---------|-------|
| tex | 1 | Block/entity texture atlas | Albedo sampling |
| specularTex | 2 | PBR specular atlas (mod-dependent) | Material properties |
| shadowtex0 | N/A | Shadow depth map | Shadow lookups |
| depthtex0 | N/A | Depth buffer | Depth-based effects |

### Optional Custom Textures

| Name | Unit | Content | Used By | Gated By |
|------|------|---------|---------|----------|
| BlueNoise | Custom | 128×128 blue-noise texture | SSR, TAA, PCSS | Phase 9 |
| ColorGradingLUT | Custom | 3D color grading LUT (32×32×32) | final.fsh | Phase 11 |

---

## Buffer Precision & Compression Notes

### Compression Strategy

| Buffer | Precision | Rationale | Cost |
|--------|-----------|-----------|------|
| colortex0 | RGBA8 | Display output; 8-bit sufficient | Minimal |
| colortex1 | RGBA16F | Per-pixel material; precision important | +8 MB (1920×1080) |
| colortex2 | RGBA16F | Normal precision + depth; need FP | +8 MB |
| colortex3 | RGBA16F | History filtering; FP needed | +8 MB (if TAA_ON) |
| colortex4 | RGBA16F | Reflection color; FP preferred | +2 MB (half-res) |
| colortex5 | RGBA16F | Bloom prefilter; can be R11G11B10 | +0.5 MB (quarter-res) |

### Example Memory Usage (1920×1080, all buffers enabled)

```
colortex0: 1920 × 1080 × 4 bytes = 8.3 MB (RGBA8)
colortex1: 1920 × 1080 × 8 bytes = 16.6 MB (RGBA16F)
colortex2: 1920 × 1080 × 8 bytes = 16.6 MB (RGBA16F)
colortex3: 1920 × 1080 × 8 bytes = 16.6 MB (RGBA16F, TAA history)
colortex4: 960 × 540 × 8 bytes = 4.1 MB (RGBA16F, half-res SSR)
colortex5: 480 × 270 × 8 bytes = 1.0 MB (RGBA16F, quarter-res bloom)
depthtex0: 1920 × 1080 × 4 bytes = 8.3 MB (DEPTH24_STENCIL8)
shadowtex0: Variable (typically 2048² × 4 = 16.7 MB)

Total (worst-case, all features): ~88 MB
Typical (HIGH tier, SSR + bloom): ~65 MB
Minimal (LOW tier, no effects): ~35 MB
```

---

## Validation Rules

1. **No Read-Write Conflicts**: A buffer cannot be read and written in the same pass.
2. **Clear at Pass Boundaries**: Buffers used as history (colortex3) should be cleared or explicitly managed between frames.
3. **Depth-Only Reads**: shadowtex0 and depthtex0 are read-only; never written to in fragment shaders.
4. **Tier-Based Availability**: Buffers colortex4+ are only available if TIER >= 2.

---

## Future Expansions (Phase 6+)

### Motion Vectors & Velocity
- **Buffer**: colortex6 (half-res)
- **Data**: Screen-space velocity (per-pixel motion)
- **Purpose**: Advanced reprojection, blur synthesis
- **Phase**: 9 (TAA enhancements)

### Indirect Lighting Cache
- **Buffer**: colortex7
- **Data**: Cached diffuse indirect light (per pixel)
- **Purpose**: Reduce per-frame GI computation
- **Phase**: 12+ (future)

---

## Summary

| Aspect | Decision |
|--------|----------|
| Primary color output | colortex0 (RGBA8) |
| Material encoding | colortex1 (LabPBR: roughness, F0, emissive) |
| Normal + Depth | colortex2 (oct-encoded normal + linear depth) |
| TAA history | colortex3 (full-res temporal buffer) |
| SSR intermediate | colortex4 (half-res reflection data) |
| Bloom prefilter | colortex5 (quarter-res bright pixels) |
| Shadow mapping | shadowtex0 (light-space depth) |
| Resolution scaling | Tier-based (LOW: screen-only, CINEMATIC: full pyramid) |
| Total buffers used | 6 primary + optional shadowtex0, depthtex0 |
| Memory overhead | 35–88 MB depending on tier and features |

This layout supports all planned features through Phase 14 without buffer conflicts or structural changes.
