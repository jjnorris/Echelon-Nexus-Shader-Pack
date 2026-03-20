# MINECRAFT JAVA 1.21.11 SHADER CONSTRAINTS & CAPABILITIES
## Hard Limits, Soft Limits, and Workarounds

**CRITICAL: Know these constraints BEFORE designing features. They affect every implementation decision.**

---

## RENDERING PIPELINE ARCHITECTURE

### Iris 1.6.0+ Architecture (Our Target)
```
Vertex Processing
    ↓
G-Buffer Rendering (geometry)
    ├─ gbuffers_terrain (blocks)
    ├─ gbuffers_entities (mobs/items)
    ├─ gbuffers_hand (held items)
    ├─ gbuffers_water (fluid)
    ├─ gbuffers_sky (sky dome)
    ├─ gbuffers_clouds (clouds)
    ├─ gbuffers_weather (rain/snow)
    └─ gbuffers_textured (other)
    ↓
Shadow Pass (sun view)
    └─ shadow.fsh/vsh
    ↓
Composite Passes (post-processing)
    ├─ composite.fsh/vsh  (Phase 1)
    ├─ composite1.fsh/vsh (Phase 2)
    ├─ composite2.fsh/vsh (Phase 3)
    └─ composite3.fsh/vsh (Phase 4)
    ↓
Final Pass (tonemapping)
    └─ final.fsh/vsh
    ↓
Screen Output
```

---

## HARDWARE CAPABILITIES & LIMITS

### Guaranteed Capabilities (All Minecraft Java 1.21.11 systems)
| Capability | Spec | Notes |
|-----------|------|-------|
| GLSL Version | 1.20 minimum (1.30 supported) | Use #version 130 |
| Texture Units | 16+ | Usually 32+ |
| Render Targets | 8 custom colortex buffers | colortex0-8 |
| Texture Size | 2048x2048 to 16384x16384 | Depends on GPU |
| Shadow Map Size | 2048x2048 default (configurable) | Iris allows up to 8192x8192 |
| Framebuffer | Full screen resolution | Typically 1080p-4K |
| Compute Shaders | NOT supported in Iris | Use fragment shaders only |
| Ray Tracing | NOT supported | Use screen-space approximations |

### GPU-Dependent Capabilities
| Capability | Minimum | Target | Ultra |
|-----------|---------|--------|-------|
| Memory (VRAM) | 2GB | 4GB | 8GB+ |
| Texture Fill-rate | 10 GT/s | 50+ GT/s | 100+ GT/s |
| Compute (FP32) | 1 TFLOPS | 10+ TFLOPS | 50+ TFLOPS |

---

## TEXTURE & BUFFER LIMITS

### Custom Color Buffers (colortex)
| Buffer | Format | Use Case | Notes |
|--------|--------|----------|-------|
| colortex0 | RGBA (fixed) | G-Buffer albedo | Cannot customize |
| colortex1 | RGBA (fixed) | G-Buffer normal | Cannot customize |
| colortex2 | RGBA (fixed) | G-Buffer material | Cannot customize |
| colortex3 | Customizable | G-Buffer auxiliary | Custom format allowed |
| colortex4 | Customizable | AO/misc data | RGBA16F recommended |
| colortex5 | Customizable | SSR/reflections | RGBA16F or RGBA32F |
| colortex6 | Customizable | Deferred accumulation | RGBA32F recommended |
| colortex7 | Customizable | Temporal history | RGBA16F (for TAA) |
| colortex8 | Customizable | Extra buffer | RGBA16F or RGBA (for depth) |

**Total VRAM for all colortex**: resolution × 3 × (4 + 4 + 4 + 8 + 8 + 8 + 8 + 8) bytes
- 1920×1080: ~40 MB
- 3840×2160: ~160 MB
- 7680×4320: ~640 MB

### Shadow Maps
| Parameter | Default | Min | Max | Cost |
|-----------|---------|-----|-----|------|
| Shadow Resolution | 2048 | 512 | 8192 | 4× increase = 16× VRAM |
| Shadow Cascades | 3 | 1 | 4 | Each cascade = extra depth read |
| Colored Shadows | No | - | Yes | Extra shadowcolor0 texture |

---

## SHADER PASS CAPABILITIES

### Shadow Pass
**Available Uniforms:**
- ✅ Shadow matrices (shadowProjection, shadowModelView)
- ✅ View/projection (gbufferProjection, gbufferModelView)
- ✅ Lighting (sunPosition, upPosition, moonPosition)
- ✅ Time/frame (gameTime, frameCounter)
- ❌ G-Buffer textures (not available)
- ❌ Previous frame data (not available)

**Render Target:** shadowtex0 (depth texture)

**Cost Budget:** ~1-2ms (must fit in shadow rendering time)

**Constraints:**
- Cannot sample G-Buffer here
- Cannot do complex screen-space effects
- Must complete before composite passes

---

### Composite Pass (Phase 1 - Shadows)
**Available Uniforms:**
- ✅ shadowtex0, shadowtex1, shadowcolor0 (shadow maps)
- ✅ gcolor, gdepth, gnormal, gaux1 (G-Buffer)
- ✅ Shadow matrices
- ✅ View/projection matrices
- ✅ Lighting uniforms
- ✅ colortex buffers (for reading)
- ❌ composite1+ outputs (not available yet)
- ❌ Previous frame data (not for reprojection)

**Render Target:** Screen (or custom colortex via writeBuffer)

**Available Texture Units:** ~8-12 for sampling

**Cost Budget:** ~2-3ms

---

### Composite1 Pass (Phase 2 - Effects)
**Available Uniforms:**
- ✅ composite (Phase 1 output)
- ✅ gcolor, gdepth, gnormal, gaux1 (G-Buffer still available)
- ✅ colortex buffers (read/write)
- ⚠️  Shadow textures (may NOT be available - avoid)
- ✅ View/projection matrices
- ❌ Shadow matrices (not guaranteed)
- ❌ Lighting uniforms (not guaranteed)
- ❌ composite2+ outputs

**Render Target:** Screen (or colortex via writeBuffer)

**Available Texture Units:** ~8-12

**Cost Budget:** ~1-2ms

**CRITICAL:** This pass may run after shadow maps are freed from memory. Do NOT assume shadowtex availability.

---

### Composite2 Pass (Phase 3 - Post-Processing)
**Available Uniforms:**
- ✅ composite1 (previous output)
- ✅ colortex buffers (read/write)
- ✅ frameCounter, gameTime
- ✅ gbufferProjectionInverse, gbufferModelViewInverse
- ⚠️  G-Buffer (may NOT be available)
- ❌ Shadow textures (definitely not available)
- ❌ Lighting uniforms
- ❌ Shadow matrices

**Render Target:** Screen (or colortex)

**Available Texture Units:** ~6-8 (more limited)

**Cost Budget:** ~1-2ms

**CRITICAL:** Post-processing pass. Minimize dependencies on earlier data.

---

### Composite3+ Passes
**Available Uniforms:** Minimal (only generic frame/time data)

**Cost Budget:** ~0.5-1ms per pass

**Use For:** Final tone mapping, color grading, UI overlays only

---

## GLSL LANGUAGE CONSTRAINTS

### Supported Features
✅ GLSL 1.20+ (version 130 recommended)
✅ Texture sampling (texture2D, textureCube, etc.)
✅ Float and int operations
✅ Vector math (vec2, vec3, vec4, mat4)
✅ Branches (if/else)
✅ Loops (for, while)
✅ User-defined functions
✅ #define and preprocessor directives
✅ #include for shader libraries

### NOT Supported
❌ Compute shaders (GLSL 4.3+)
❌ Geometry shaders
❌ Tesselation shaders
❌ Atomic operations
❌ Image load/store (some variants)
❌ Indirect compute
❌ Ray tracing extensions
❌ Shared memory (compute-specific)
❌ Double precision floating point

### Performance Considerations
| Feature | Cost | Recommendation |
|---------|------|-----------------|
| Float division | Expensive | Use multiplication by inverse |
| pow() function | Very expensive | Use squared terms instead |
| sin/cos | Expensive | Pre-compute or use approximations |
| sqrt() | Expensive | Use squared values or approximations |
| Branches | Can be expensive | Avoid branching in hot loops |
| Loops | Expensive | Keep iteration count low (< 32) |
| Texture sampling | Can miss cache | Use coherent memory access patterns |

---

## PRECISION & NUMERICAL LIMITS

### Floating Point Precision
| Type | Bits | Precision | Range | Use For |
|------|------|-----------|-------|---------|
| lowp float | 16 | ~3 digits | ~6 magnitudes | Colors, normals |
| mediump float | 24 | ~6 digits | ~9 magnitudes | Most calculations |
| highp float | 32 | ~7 digits | ~38 magnitudes | Positions, matrices |

**Recommendation for Minecraft:**
- Colors: lowp (8-bit per channel)
- Surface normals: mediump
- Positions/matrices: highp
- Depth values: mediump (linear depth is ~[0,1])

### Integer Precision
| Type | Bits | Range | Use For |
|------|------|-------|---------|
| lowp int | 8 | -128 to 127 | Loop counters (< 256) |
| mediump int | 16 | -32k to 32k | Texture coords, sample counts |
| highp int | 32 | Standard | General integer math |

---

## MEMORY & BANDWIDTH LIMITS

### Memory Bandwidth Requirement Example
For a 60 FPS shader at 1920×1080:

```
Per-frame budget: 16.67ms

Reading 8 textures per pixel:
- 1920 × 1080 = 2,073,600 pixels
- 8 samples × 4 bytes = 32 bytes/pixel
- Total bandwidth: 66 GB/s required

GPU bandwidth (RTX 3060): 360 GB/s ✅ OK
GPU bandwidth (RX 6600): 432 GB/s ✅ OK
GPU bandwidth (GTX 1660): 192 GB/s ⚠️  Tight
GPU bandwidth (GTX 1050): 112 GB/s ❌ Exceeded
```

**Implication:** On lower-end hardware, sample count must be reduced.

### Cache Considerations
- Texture sampling is most efficient with:
  - Linear memory access (no jumps)
  - Square tile patterns (2×2 or 4×4)
  - Coherent UV coordinates
- Avoid:
  - Random texture access patterns
  - Dependent texture reads in loops
  - Loading more texels than needed

---

## MINECRAFT-SPECIFIC CONSTRAINTS

### Block Rendering
| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| Opaque blocks only in G-Buffer | No transparency in deferred pass | Use forward rendering for transparent blocks |
| Fixed G-Buffer format | Can't customize colortex0-2 | Use colortex3+ for extra data |
| Block normals in texture | Normal maps not in geometry | Must sample from texture (LabPBR format) |
| Limited vertex attributes | Can't pass extra per-vertex data | Use texture lookup instead |

### Lighting Constraints
| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| No per-light data | Must approximate all lights | Store light data in texture or compute |
| No light list | Can't iterate over lights | Pre-compute skylight + simple sun model |
| No subsurface scattering data | Must approximate | Use normal-based falloff |
| Limited emissive support | Emissive is just color | Use post-process bloom instead |

### Time & Motion Constraints
| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| Blocky voxel grid | Natural 1-block artifacts | TAA and smoothing |
| Limited camera info | No motion vectors directly | Compute from matrix differences |
| Frame-locked updates | No smooth animation in shaders | Use sin(gameTime) for movement |

---

## FEATURE FEASIBILITY MATRIX

### Can We Do This in Minecraft 1.21.11?

| Feature | Possible | Difficulty | Cost | Workaround if No |
|---------|----------|-----------|------|-----------------|
| Cook-Torrance PBR | ✅ Yes | Easy | 1-2ms | Use Blinn-Phong |
| PCSS Shadows | ✅ Yes | Medium | 2-3ms | Use basic PCF |
| Temporal AA | ✅ Yes | Hard | 1-2ms | Use FXAA |
| Screen-space Reflections | ✅ Yes | Hard | 2-3ms | Use screen color |
| Volumetric Fog | ✅ Yes | Medium | 2-3ms | Use depth fog |
| Volumetric Clouds | ✅ Yes | Hard | 2-3ms | Use 2D cloud layer |
| Refractions | ✅ Yes | Medium | 1-2ms | Use distortion map |
| Caustics | ✅ Yes | Easy | 0.5-1ms | Use static texture |
| Bloom | ✅ Yes | Easy | 0.5-1ms | Use color glow |
| Ambient Occlusion | ✅ Yes | Medium | 1-2ms | Use normal-based AO |
| Global Illumination | ❌ No | - | - | Approximate with vertex lighting |
| Real Raytracing | ❌ No | - | - | Use screen-space approximations |
| Neural Rendering | ⚠️ Maybe | Very Hard | 3-5ms | Fallback to heuristic |

---

## PERFORMANCE BUDGET BREAKDOWN

For 60 FPS (16.67ms per frame):

```
Frame Budget Distribution (RTX 3060 class):

Shadow Pass:        1-2 ms (6-12%)
  - Depth rendering
  - Shadow map writes

Composite Pass:     2-3 ms (12-18%)
  - Shadow PCF/PCSS
  - Lighting calculation
  - G-Buffer combination

Composite1 Pass:    1-2 ms (6-12%)
  - Effects (bloom, AO)
  - Extra processing

Composite2 Pass:    1-2 ms (6-12%)
  - Post-processing
  - TAA/upsampling

Final Pass:         0.5-1 ms (3-6%)
  - Tonemapping
  - Color grading

Margin (overhead):  ~8-10 ms (48-60%)
  - CPU overhead
  - Memory stalls
  - Driver overhead

Total:              16.67 ms (100%)
```

---

## KNOWN ISSUES & LIMITATIONS

### Iris/Iris-Specific Limitations
1. **Shadow distance capping** - Max 256 blocks (configurable)
2. **G-Buffer availability** - May be freed after composite pass
3. **Texture unit limitations** - Not all units available in all passes
4. **No dynamic shadow resolution** - Must be set before compile
5. **No dynamic render target** - Can't change colortex format at runtime

### Minecraft-Specific Quirks
1. **Block boundaries** - Visible artifacts at chunk borders
2. **Water surface** - Flat grid, no wave simulation in geometry
3. **Mob deformation** - Complex animation system, hard to match
4. **Item rendering** - Uses different matrix transforms
5. **Transparency** - Rendered separately, after composite passes

### Common Pitfalls
1. ❌ Using shadow textures in composite1+ (not guaranteed to exist)
2. ❌ Sampling G-Buffer after it's been freed
3. ❌ Exceeding texture unit limits in a single pass
4. ❌ Using expensive operations in tight loops
5. ❌ Ignoring precision loss in mediump math
6. ❌ Creating temporal artifacts with screen jitter

---

## HARD LIMITS (DO NOT EXCEED)

| Limit | Maximum | Consequence |
|-------|---------|-------------|
| Texture samples per pixel | 32 (practical) | Frame drops on low-end |
| Loop iterations | 64 (practical) | Driver timeout |
| Function nesting | 10 levels | Compiler stack overflow |
| #include depth | 10 levels | Include cycle detection |
| Total uniforms | ~256 floats | Uniform buffer overflow |
| Pass count | 8 composites | GPU pipeline limits |

---

## VERSION NOTES

**Valid For:**
- Minecraft Java 1.21.11
- Iris 1.6.0+
- OptiFine D6+
- GLSL 1.20+

**Updates Required If:**
- Minecraft updates to 1.22+
- Iris changes its shader specification
- GPU architectures change significantly

---

## IMPLEMENTATION GUIDELINES

Before implementing any feature:

1. ✅ Check this document for constraints
2. ✅ Verify in the feasibility matrix
3. ✅ Allocate from performance budget
4. ✅ Test on target GPU tier
5. ✅ Verify backward compatibility
6. ✅ Document any limitations

---

**Last Updated:** 2026-03-20
**Session:** 011dF8GgqCQiK6k2xENRJixC

**MANDATORY: Consult this before designing any feature. Constraints should be understood BEFORE implementation starts.**
