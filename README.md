# Echelon Nexus Shader Pack

A production-oriented, high-fidelity shaderpack for Minecraft Java Edition 1.21.11, designed with rigorous physically-based rendering, modular architecture, and scalable quality tiers.

## Installation

### Requirements
- **Minecraft Java Edition**: 1.21.11
- **Loader**: NeoForge 21.11 or Fabric 1.21.11
- **Shaderpack Loader**: Iris Shaders 1.10.6+
- **Optimization Mod**: Sodium 0.8.4+ (NeoForge) or 0.8.6+ (Fabric)
- **GPU**: OpenGL 4.5+ (integrated graphics supported for LOW tier)

### Installation Steps

1. Install **NeoForge 21.11** (recommended) or **Fabric 1.21.11**
2. Install **Iris Shaders 1.10.6** for your loader
3. Install **Sodium 0.8.4** (NeoForge) or **Sodium 0.8.6** (Fabric)
4. Place `Echelon-Nexus-Shader-Pack` in your `shaderpacks/` folder
5. Launch Minecraft and open Shader Options to select this pack
6. Start with the **MEDIUM** or **HIGH** profile; adjust based on your GPU

## Quality Tiers

The shaderpack includes five configurable quality profiles:

| Profile | Target GPU | Target FPS | Key Features |
|---------|-----------|-----------|--------------|
| **LOW** | Integrated GPU / iGPU | 60 | Basic lighting, simple clouds, no SSR/bloom |
| **MEDIUM** | GTX 960 / RX 470 | 60 | Full PBR, soft shadows, volumetric clouds, optional bloom |
| **HIGH** | GTX 1060 / RX 580 | 60 | Enhanced shadows (PCSS), SSR, TAA, advanced clouds |
| **ULTRA** | RTX 2060 / RX 5700 XT | 50+ | Full feature set, compute-assisted effects |
| **CINEMATIC** | RTX 4080 / RX 7900 XTX | 30–40 | Maximum visual fidelity; all premium paths active |

## Configuration

### Main Options

**Profile Selection**
- Choose a starting profile from **Shader Options → Echelon Nexus**
- Profiles lock sample counts, raymarch steps, and effect toggles for consistent performance

**Render Quality**
- **PBR Mode**: Select between LabPBR (preferred) or oldPBR material decoding
- **Shadow Quality**: PCF (baseline), PCSS (enhanced), or advanced filtering
- **Cloud Quality**: Simple, volumetric, or high-quality with multiple scattering

**Post-Processing**
- **Bloom**: Toggle fullscreen bloom; adjust strength
- **Screen-Space Reflections**: Optional; disabled on low-end hardware
- **Temporal Anti-Aliasing**: Reduces aliasing; may show minor ghosting
- **Color Grading**: LUT-based color correction; multiple presets available
- **Tonemapping**: Choice of filmic operators

**Advanced**
- **Parallax Mapping**: Optional height-based displacement (enhanced path)
- **Wetness Response**: Modulate material properties based on rain
- **Caustics**: Animated water caustics (optional; premium path)
- **Debug Views**: Visualize intermediates (normals, roughness, depth, etc.)

## Architecture & Design

### Rendering Pipeline

The shaderpack uses a **deferred G-buffer architecture**:

1. **GBuffer Pass**: Render terrain, entities, weather, water → capture albedo, normals, material parameters, depth
2. **Shadow Pass**: Render from light perspective → shadow map with soft filtering
3. **Deferred Lighting Pass**: Read G-buffers → compute per-pixel Cook-Torrance GGX lighting
4. **Composite & Post-Processing**: Apply SSR, temporal AA, bloom, fog, atmospheric effects
5. **Final Pass**: Tonemap, color-grade → output to framebuffer

### Material System (PBR)

**Preferred Format: LabPBR**
- **Red Channel (Smoothness)**: 0 = rough, 1 = smooth (inverted roughness)
- **Green Channel (F0/Metallic)**: Reflectance or metallic specular property
- **Blue Channel (Emissive)**: Optional self-illumination intensity
- **Normal Map**: Per-texel geometric normal
- **Height Map** (optional): For parallax displacement

**Legacy Support: oldPBR**
- Normal map: RGB = normal, A = height
- Specular map: R = smoothness, G = metallic, B = emissive

**Graceful Degradation**:
- Missing specular → treated as diffuse (roughness=1, metallic=0)
- Missing normals → use geometric normal
- Missing height → parallax disabled automatically

### Lighting Model

**Cook-Torrance GGX (Physically-Based)**:
- Fresnel term (Schlick approximation with roughness modulation)
- Microfacet normal distribution (GGX/Trowbridge-Reitz)
- Geometry term (Smith height-correlated variant)
- Energy conservation + multiple-scatter compensation for rough surfaces

**Light Sources**:
1. **Directional Sun/Moon**: Strongest light; dynamic; casts shadows
2. **Sky/Environment**: Diffuse + specular; time-of-day driven
3. **Emissive Materials**: Self-illuminated blocks (lava, glowstone, etc.)
4. **Torch/Local**: Approximate point lights from block brightness

**Shadows**:
- **Baseline (LOW)**: PCF (percentage-closer filtering)
- **Enhanced (MEDIUM–HIGH)**: PCSS (contact-hardened shadows)
- **Premium (ULTRA+)**: Advanced blue-noise filtering

### Optional Advanced Features

**Baseline Path** (Always Active):
- Full PBR material decoding (labPBR + oldPBR)
- Directional lighting + soft shadows
- Atmospheric sky + fog
- Water rendering (animated waves, Fresnel, refraction)
- Dynamic clouds
- Filmic tonemapping + color grading

**Enhanced Path** (Optional, Iris-Exclusive):
- Compute shader acceleration (bloom chain, helpers)
- PCSS shadow filtering with blue-noise
- Screen-space reflections (SSR) with stochastic sampling
- Temporal anti-aliasing (TAA) with history clamping
- Parallax/height-based displacement mapping
- Advanced volumetric clouds
- Animated water caustics

**Premium Path** (Future, Optional):
- SSBO-accelerated SSR with depth hierarchy
- Compute-assisted temporal filtering
- Advanced multi-scattering cloud approximations
- Complex history buffer management
- (Not in initial release; reserved for future iterations)

All enhanced and premium features gracefully fall back to baseline on unsupported hardware.

## Dimension-Specific Behavior

**Overworld**:
- Full sky rendering with time-of-day transitions
- Weather fog response
- Realistic lighting and shadows

**Nether**:
- Lava glow and heat distortion (optional, performance-dependent)
- Darker overall ambience
- Reduced sky contribution

**End**:
- Void darkness
- Ender crystal glow response
- Minimal sky rendering

## Known Limitations & Caveats

1. **No Hardware Ray Tracing**: Iris is OpenGL 4.5; RTX/DXR features are unavailable. SSR is the reflection method.
2. **TAA Ghosting**: Temporal anti-aliasing may show minor ghosting on fast motion; adjust clamping if needed.
3. **Motion Vectors**: Iris doesn't expose engine motion data; TAA uses custom jitter tracking and reprojection math.
4. **Compute Shader Support**: Compute shaders are optional and require compatible GPU driver; graceful fallback exists.
5. **SSBO Limits**: Storage buffers limited to 8 indices + 128 MB guaranteed allocation.
6. **Integrated Graphics**: LOW tier is optimized for iGPU (Intel Iris, AMD Vega APU); higher tiers require discrete GPU.
7. **Resource Pack Compatibility**: Pack assumes LabPBR-compatible material textures; will gracefully degrade for vanilla textures.

## Performance Tips

1. **For Weak Hardware (60 FPS target)**:
   - Use **LOW** profile
   - Disable: SSR, Bloom, TAA, advanced clouds
   - Set Shadow Distance to 64 blocks

2. **For Mid-Range Hardware (60 FPS target)**:
   - Use **MEDIUM** or **HIGH** profile
   - Optional: Enable SSR and Bloom; keep cloud quality at volumetric
   - Shadow Distance: 128 blocks

3. **For High-End Hardware (50+ FPS target)**:
   - Use **ULTRA** or **CINEMATIC** profile
   - Enable all optional features
   - Shadow Distance: 256+ blocks; increase sample counts

4. **General**:
   - Render Distance: 12–20 chunks (farther = more terrain rasterization)
   - Sodium settings: Enable chunk culling, use smooth lighting
   - Disable conflicting mods (OptiFine, other shader loaders)

## Troubleshooting

**Pack fails to load**:
- Check that Iris 1.10.6+ is installed
- Verify Minecraft version is 1.21.11
- Check Sodium compatibility (0.8.4 for NeoForge, 0.8.6 for Fabric)
- Review game log for shader compilation errors

**Extreme performance loss**:
- Reduce quality profile (MEDIUM → LOW)
- Disable SSR, Bloom, or advanced clouds
- Reduce shadow distance
- Check GPU drivers are up-to-date

**Visual artifacts**:
- TAA ghosting: Reduce TAA sharpening slider
- Shadow banding: Increase shadow quality tier
- Flickering clouds: Reduce cloud quality; enable temporal stability option
- Color shifts: Disable color grading; reset to default LUT

**Debug Mode**:
- Enable **Debug Views** in options
- Cycle through debug visualizations (normals, roughness, depth, etc.)
- Check that G-buffer data is correct

## Development & Architecture Notes

### Modular Structure

The shaderpack is organized for scalability and maintainability:

```
shaders/
├── lib/              # Shared utilities (constants, math, encoding)
├── options/          # Profile & tier configuration
├── materials/        # PBR material decoding
├── lighting/         # Lighting models & brdf
├── shadow/           # Shadow rendering & filtering
├── sky/              # Sky, atmosphere, stars
├── fog/              # Fog, aerial perspective
├── clouds/           # Volumetric cloud rendering
├── water/            # Water surface, refraction, caustics
├── post/             # Post-processing pipeline
└── [entry-points]    # Shader program entry points
```

### Buffer Ownership

See `shaders/lib/constants.glsl` for detailed buffer semantics and color texture allocation.

### Feature Gating

Features are gated via `shaders.properties` directives and compile-time flags, enabling graceful fallback on unsupported hardware.

## License & Attribution

Echelon Nexus Shader Pack — designed as a production-oriented implementation following modern rendering best practices adapted for the Minecraft Iris shaderpack environment.

## Changelog

### Version 0.1.0 (Initial Release)
- Pack scaffold and directory structure
- Basic entry-point programs
- Foundation libraries (math, constants, encoding)
- Feature gates and profile scaffolding
- PBR material decoding framework (labPBR + oldPBR)
- Basic lighting and shadow structure

---

**Last Updated**: Phase 1 Scaffold
**For Issues & Feedback**: Report via GitHub or community channels
