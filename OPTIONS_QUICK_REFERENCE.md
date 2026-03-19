# Echelon Nexus Shaders - Options Quick Reference

**Total Options: 238** | **Visible: 24** | **Hidden: 214**

---

## Categories & Counts

| Category | Count | Type Mix | Screen Visibility |
|----------|-------|----------|------------------|
| Rendering/Performance | 13 | 5 bool, 2 range, 6 numeric | 1 visible |
| Materials/PBR | 24 | 14 bool, 3 range, 7 numeric | 2 visible |
| Lighting | 46 | 16 bool, 8 range, 22 numeric | 2 visible |
| Atmosphere/Sky/Clouds | 26 | 7 bool, 5 range, 14 numeric | 2 visible |
| Water | 28 | 10 bool, 4 range, 14 numeric | 3 visible |
| Post-Processing/Tonemap | 46 | 14 bool, 6 range, 26 numeric | 6 visible |
| Advanced/Debug | 12 | 7 bool, 2 range, 3 numeric | 0 visible |
| Other (Ray Tracing, SSS, etc.) | 37 | 14 bool, 9 range, 14 numeric | 1 visible |
| **TOTAL** | **238** | **87 bool / 39 range / 104 numeric / 4 selector** | **24 visible** |

---

## Current UI Screens (24 options only)

### 1. PROFILE (1 option)
- `PROFILE` - Choose: LOW, MEDIUM, HIGH, ULTRA, CINEMATIC

### 2. RENDERING (5 options)
- `PBR_MODE` - LabPBR vs oldPBR
- `SHADOW_QUALITY` - PCF, PCSS, Advanced
- `WATER_QUALITY` - Basic, Animated, Advanced+Physics
- `CLOUD_QUALITY` - Simple, Volumetric, High-Quality
- `FOG_QUALITY` - Low, Medium, High

### 3. EFFECTS (6 options)
- `SSR_ON` - Screen-Space Reflections
- `TAA_ON` - Temporal Anti-Aliasing
- `BLOOM_ON` - Bloom/Glare
- `PARALLAX_ON` - Parallax Mapping
- `CAUSTICS_ON` - Water Caustics
- `WETNESS_ON` - Wetness Effects

### 4. ADVANCED (5 options)
- `INDIRECT_ON` - Global Illumination
- `IBL_ON` - Image-Based Lighting
- `SSS_ON` - Subsurface Scattering
- `DIFFRACTION_ON` - Diffraction Effects
- `INTERFERENCE_ON` - Thin-Film Interference

### 5. TONEMAP (2 options)
- `TONEMAP_OPERATOR` - ACES, Filmic, Reinhard
- `COLOR_GRADE_PRESET` - Default, Warm, Cool, Saturated

---

## Top Hidden Options (Most Impactful)

### Shadow System (ALL HIDDEN - 13 options)
- `SHADOW_ALGORITHM` - PCF, ESM, VSM
- `SHADOW_DISTANCE` - 64-512 blocks
- `SHADOW_FILTER_SIZE` - 1.0-3.5
- `PENUMBRA_SCALE` - Soft shadow size
- `BLUE_NOISE_DITHER` - Dithering quality
- + 8 more shadow control options

### Bloom Enhancement (HIDDEN - 8 options)
- `BLOOM_STRENGTH` - 0.0-1.0 intensity
- `BLOOM_THRESHOLD` - Brightness trigger
- `BLOOM_QUALITY` - Fast/Balanced/High
- `BLOOM_SUBPHASES_ON` - Advanced features
- `SPECTRAL_BLOOM_ON` - Wavelength-separated bloom
- `AIRY_DISK_ON` - Diffraction spikes
- `LENS_FLARE_ON` - Lens flare artifacts

### Global Illumination (5 VISIBLE + 30+ HIDDEN)
**Visible:**
- `INDIRECT_ON` (boolean)
- `IBL_ON` (boolean)

**Hidden (30+ options):**
- `INDIRECT_SAMPLES` - 4, 8, or 16
- `INDIRECT_BOUNCES` - 1, 2, or 3
- `GI_SYSTEM_TYPE` - Path, Probes, LPV, Enhanced AO, Screen-Space
- `SSGI_METHOD` - Ray March, Cone Trace, HBAO
- `REFLECTION_PROBES_ON` - Dynamic probes
- `IBL_INTENSITY` - 0.0-2.0
- `IBL_SH_BANDS` - 9 or 16 coefficients
- + 23 more GI options

### TAA Anti-Aliasing (1 VISIBLE + 8 HIDDEN)
**Visible:**
- `TAA_ON` (boolean)

**Hidden (8 options):**
- `TAA_QUALITY` - Halton, Hammersley, Adaptive
- `TAA_FILTER_TYPE` - Box, Lanczos, Catmull-Rom
- `TAA_SHARPEN` - 0.0-1.0
- `TAA_JITTER_SCALE` - 0.5-2.0
- `TAA_SAMPLE_WEIGHT` - 0.5-0.95
- `TAA_CLAMP_STRENGTH` - 0.5-2.0
- `TAA_ADAPTIVITY` - 0.0-1.0

### Water Physics (3 VISIBLE + 18 HIDDEN)
**Visible:**
- `WATER_QUALITY` (selector)
- `CAUSTICS_ON` (boolean)
- `WETNESS_ON` (boolean)

**Hidden (18 options):**
- `WATER_GERSTNER_WAVES` - Trochoidal physics
- `WATER_FOAM` - White caps
- `WATER_PROPAGATION` - Wave interference
- `WATER_WAVE_AMPLITUDE` - 0.1-5.0
- `WATER_WAVE_FREQUENCY` - 0.5-2.0
- `CAUSTICS_SPEED` - 0.5-2.0
- `CAUSTICS_SCALE` - 0.5-10.0
- `WATER_REFRACTION_STRENGTH` - 0.0-2.0
- + 10 more water options

### Ray Tracing (ALL HIDDEN - 15 options)
- `RAYTRACING_ENABLED` - Full RT
- `RAYTRACING_TYPE` - Specular, Specular+Diffuse, Full path
- `RAYTRACING_MAX_BOUNCES` - 1-4
- `RAYTRACING_SAMPLES_PER_PIXEL` - 1, 2, 4
- `RAYTRACING_HYBRID_MODE` - Raster + RT
- `RAYTRACING_OPTICAL_FLOW` - Motion denoising
- + 9 more RT options

### Sky & Atmosphere (2 VISIBLE + 20+ HIDDEN)
**Visible:**
- `CLOUD_QUALITY` (selector)
- `FOG_QUALITY` (selector)

**Hidden (20+ options):**
- `ATMOSPHERE_ENABLED` - Rayleigh/Mie scattering
- `CLOUDS_ON` - Cloud rendering
- `CLOUD_SCATTERING_ORDER` - Single, Double, Triple
- `CLOUD_RAYMARCH_STEPS` - 8-48
- `CLOUD_SELF_SHADOW` - Cloud shadows
- `SKY_QUALITY` - Gradient, Rayleigh, Rayleigh+Mie
- `RAYLEIGH_COEFFICIENT` - 0.5-2.0
- `MIE_COEFFICIENT` - 0.1-1.0
- `AEROSOL_DENSITY` - 0.5-2.0
- `HAZE_AMOUNT` - 0.0-1.0
- + 10 more atmosphere options

---

## Option Type Breakdown

### Boolean Toggles (87 total)
- Simplest type: true/false switches
- Examples: `TAA_ON`, `BLOOM_ON`, `RAYTRACING_ENABLED`
- Can be expensive or enable/disable entire systems

### Numeric Sliders (104 total)
- Continuous floating-point values
- Range: typically 0.0-2.0, sometimes 0.0-100.0
- Examples: `BLOOM_STRENGTH=0.5`, `SHADOW_DISTANCE=128`
- Fine-tuned quality control

### Range Selectors (39 total)
- Discrete choices between specific values
- Common: `0 1 2` for quality tiers, `0 1 2 3 4` for algorithm choice
- Examples: `SHADOW_QUALITY=0 1 2`, `TAA_QUALITY=0 1 2`
- Balanced preset options

### Selector (4 total)
- Special multi-value options
- Examples: `PROFILE` (5 values), `DEBUG_VIEW` (9 values)
- Rarer than other types

---

## Hidden Gems (Most Valuable But Invisible)

### Advanced Color Grading
- `SATURATION_FACTOR` - Color vibrancy control
- `CONTRAST_FACTOR` - S-curve contrast punch
- `GAMMA_MIDTONES` - Midtone brightness
- `GAIN_HIGHLIGHTS` - Highlight lift
- `LIFT_SHADOWS` - Shadow brightening
- `VIGNETTE_AMOUNT` - Edge darkening
- `SHARPEN_AMOUNT` - Post-processing sharpening

### Advanced TAA Control
- `TAA_QUALITY` - Sampling method (Halton/Hammersley/Adaptive)
- `TAA_FILTER_TYPE` - Reconstruction (Box/Lanczos/Catmull-Rom)
- `TAA_SHARPEN` - Post-TAA sharpening
- `TAA_JITTER_SCALE` - Temporal variation
- `TAA_SAMPLE_WEIGHT` - Frame blending

### Global Illumination Fine-Tuning
- `GI_INTENSITY` - Overall GI brightness
- `INDIRECT_SAMPLES` - Quality levels (4/8/16)
- `INDIRECT_BOUNCES` - Bounce count (1/2/3)
- `IBL_INTENSITY` - IBL contribution
- `PROBE_SPACING` - Probe grid density
- `SSGI_RAY_STEPS` - Screen-space ray quality

### Material Properties (Phase 16)
- `MATERIAL_THICKNESS` - 100-1000 nm (thin-film)
- `MATERIAL_IOR` - Refractive index (1.0-2.5)
- `MATERIAL_ABBE` - Dispersion amount
- `INTERFERENCE_STRENGTH` - Effect intensity
- `IRIDESCENCE_ON` - Color shift with viewing angle

### Atmospheric Science (Phase 24)
- `RAYLEIGH_COEFFICIENT` - Blue sky scattering
- `MIE_COEFFICIENT` - Haze/aerosol amount
- `AEROSOL_DENSITY` - Aerosol particles
- `ATMOSPHERE_TURBIDITY` - Overall haze
- `CLOUD_SCATTERING_ORDER` - Multiple scattering

---

## Quality Profile Feature Sets

### LOW (Integrated GPU)
```
Essentials only: TAA disabled, SSR disabled, Indirect disabled
Shadow: PCF only
Water: Basic
Clouds: Simple gradient
23 option overrides
```

### MEDIUM (GTX 960)
```
Balanced features: TAA enabled, IBL enabled, Caustics enabled
Shadow: PCF
Water: Animated
Clouds: Volumetric
26 option overrides
```

### HIGH (GTX 1060)
```
Advanced: SSR enabled, Indirect disabled, SSS enabled
Shadow: PCSS (soft shadows)
Water: Advanced physics
Clouds: Volumetric with detail
32 option overrides
```

### ULTRA (RTX 2060)
```
Most advanced: Indirect GI enabled, SSR quality 2, SSS + skin
Shadow: PCSS with penumbra
Water: Full Gerstner waves
Clouds: High-quality with self-shadowing
Airy disk & lens flare enabled
43 option overrides
```

### CINEMATIC (RTX 4080)
```
MAXIMUM QUALITY: All features enabled
Shadow: PCSS with 3.5× penumbra
Water: Full physics, 1.0 amplitude
Clouds: 48 raymarch steps with triple scattering
Indirect GI: 16 samples, 3 bounces
SSR: Quality 3, 64 steps
Ray Tracing: Optional full path tracing
46 option overrides
```

---

## Research Phases Reference

| Phase | Feature | Category | Implementation Status |
|-------|---------|----------|----------------------|
| 14 | Bloom Sub-phases | Post-Processing | Optional (BLOOM_SUBPHASES_ON) |
| 15 | Advanced Sampling | Rendering | Integrated (TAA, SSGI) |
| 16 | Interference/Materials | Materials | Integrated |
| 17 | Optical Effects | Post-Processing | Integrated (Caustics, Airy Disk) |
| 18 | Water Systems | Water | Integrated (Gerstner waves) |
| 19 | Indirect Lighting | Lighting | Integrated (GI systems) |
| 20 | Image-Based Lighting | Lighting | Integrated (IBL, probes) |
| 21 | Screen-Space GI | Lighting | Integrated (SSGI) |
| 22 | Ray Tracing | Advanced | Integrated (RAYTRACING_*) |
| 23 | Atmospheric Scattering | Atmosphere | Integrated (Rayleigh, Mie) |
| 24 | Tone Mapping | Post-Processing | Integrated |
| 25 | Texture Compression | Optimization | Integrated (TEXTURE_COMPRESSION) |
| 26 | Texture Synthesis | Optimization | Optional (TEXTURE_SYNTHESIS) |
| 28 | Market Features | Advanced | Integrated (DOF, Film grain, etc.) |

---

## Common Tweaking Patterns

### For Photorealism
1. `PROFILE=HIGH` or `ULTRA`
2. Enable: `TAA_ON`, `BLOOM_ON`, `SSR_ON`, `CAUSTICS_ON`
3. Tune: `BLOOM_STRENGTH=0.7`, `TONEMAP_EXPOSURE=1.1`
4. Adjust: Sky quality, water quality, indirect bounces

### For Performance
1. `PROFILE=LOW` or `MEDIUM`
2. Disable: `TAA_ON=false`, `SSR_ON=false`, `RAYTRACING_ENABLED=false`
3. Reduce: `SHADOW_DISTANCE=64`, `CLOUD_QUALITY=0`
4. Set: `SAMPLING_MODE=0` (fast Halton)

### For Stylized Looks
1. Start: `PROFILE=MEDIUM`
2. Adjust: `COLOR_GRADE_PRESET`, `SATURATION_FACTOR`
3. Modify: `TONEMAP_OPERATOR`, `CONTRAST_FACTOR`
4. Add: `FILM_GRAIN`, `VIGNETTE_AMOUNT`

### For Water Showcase
1. `WATER_QUALITY=2`
2. `WATER_GERSTNER_WAVES=true`
3. `CAUSTICS_ON=true`, `CAUSTICS_SPEED=1.0`
4. `WATER_FOAM_INTENSITY=0.8`
5. `FOAM_AT_SHORES=true`

---

## File Locations

- **Main Config:** `/home/user/Echelon-Nexus-Shader-Pack/shaders/shaders.properties`
- **This Analysis:** `/home/user/Echelon-Nexus-Shader-Pack/SHADERS_PROPERTIES_ANALYSIS.md`
- **Quick Reference:** `/home/user/Echelon-Nexus-Shader-Pack/OPTIONS_QUICK_REFERENCE.md`

---

## Next Steps for UI Design

1. **Create expanded screens** for each major category (Shadows, GI, Water, etc.)
2. **Build collapsible groups** within screens for related options
3. **Add search functionality** to find options by name
4. **Implement tooltips** from the `.comment` fields in properties
5. **Add slider ranges** shown visually (e.g., "0.0 ← 1.0 → 2.0")
6. **Create preset manager** for saving custom configurations
7. **Add expert/beginner mode** toggle for UI complexity
8. **Implement performance indicators** (impact on FPS)

---

**Last Updated:** 2025 Analysis
**Total Lines of Config:** 2048
**Feature Density:** ~0.12 options per line (238 options across 2048 lines)
