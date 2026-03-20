# Quick Start Guide - Shader Pack Reference Materials

## Overview
You now have comprehensive reference materials from three professional shader packs:
- **Complementary Shaders V4** - Mature, feature-rich OpenGL implementation
- **Photon Shaders** - Modern GLSL 400+ with advanced physics
- **Shadow Tutorial** - Educational minimal implementation

## Files Generated

### 1. SHADER_REFERENCES.md
**What it contains:**
- Complete file inventory from all 3 packs
- URL references to original repositories
- Detailed function documentation
- Learning progression roadmap
- Comparative analysis tables

**How to use:**
- Search for specific shader names (e.g., "shadow.vsh")
- Follow the learning roadmap (Section 6)
- Compare implementations (Section 4)

### 2. CODE_SNIPPETS.md
**What it contains:**
- Complete, copy-paste-ready code
- Line-by-line explanations
- Key learning points highlighted
- Utility function library
- Configuration patterns

**How to use:**
- Find working code examples
- Understand algorithm implementations
- Learn common patterns and techniques
- Reference for your own implementations

## Quick Reference

### For Learning Shadow Mapping
**Start here:** CODE_SNIPPETS.md § 1.1-1.4
- Basic vertex shader (Tutorial)
- Advanced vertex shader with bias (Complementary)
- Water caustics implementation (Complementary)
- Modern implementation (Photon)

### For Understanding Material Systems
**Check:** SHADER_REFERENCES.md § 1.3 & CODE_SNIPPETS.md § 5.1
- Complementary's COMPBR system
- Material classification patterns
- G-Buffer output structures

### For Shadow Sampling
**Reference:** CODE_SNIPPETS.md § 2.1-2.2 & SHADER_REFERENCES.md § 1.2
- Basic shadow checks (Tutorial)
- Poisson disk filtering (Complementary)
- TAA filtering (Complementary)

### For Modern Techniques
**Study:** CODE_SNIPPETS.md § 4.1-4.2 & SHADER_REFERENCES.md § 2.0
- GLSL 400+ features (Photon)
- Physically-based water (Photon)
- Jacobian transformations (Photon)

## Implementation Priority

### Phase 1: Foundation
- [ ] Set up basic shadow mapping (Tutorial reference)
- [ ] Implement simple shadow sampling
- [ ] Create basic terrain shader

### Phase 2: Enhancement
- [ ] Add shadow filtering (Complementary filtering reference)
- [ ] Implement normal mapping (lib/util/encode.glsl)
- [ ] Create material properties system

### Phase 3: Advanced
- [ ] Water rendering with caustics
- [ ] Advanced lighting calculations
- [ ] Voxel-based lighting (optional, from Photon)

## Key Algorithms at a Glance

### Shadow Bias (Complementary)
```
Purpose: Prevent shadow acne and peter-panning
Method: Angle-aware bias based on NdotL
Formula: bias = (distortBias * biasFactor + 0.05) / shadowMapResolution
Reference: CODE_SNIPPETS.md § 1.3
```

### Poisson Disk Filtering
```
Purpose: Reduce shadow aliasing and banding
Method: 8-tap circular sampling pattern
Reference: CODE_SNIPPETS.md § 2.1
```

### Normal Encoding (Spheremap)
```
Purpose: Compress normals from vec3 to vec2
Method: Stereographic projection with z-scaling
Reference: CODE_SNIPPETS.md § 3.1
```

### Water Caustics (Photon)
```
Purpose: Physically-accurate caustics via Snell's law
Method: Refraction + Jacobian correction
Reference: CODE_SNIPPETS.md § 4.2
```

## Common Block Entity IDs
(From Complementary/Photon analysis)

| ID | Material | Use Case |
|-----|----------|----------|
| 8 | Water | Special shadow handling, caustics |
| 31 | Leaves | Subsurface scattering candidate |
| 79 | Premultiplied | Special alpha blending |
| 138 | (MC 1.19+) | Exclude from shadow mapping |
| 200 | End Gateway Beam | Special rendering |
| 7979 | Ice | Reflective surface |
| 10000+ | Custom | Material mask (Photon) |

## Important Constants

### Lighting
```glsl
sunPathRotation       // Sun rotation angle
timeAngle             // 0.0 = sunrise, 0.5 = sunset
shadowDistance        // Shadow map render distance
shadowMapResolution   // Size of shadow texture
shadowMapBias         // Distortion strength
```

### Colors
```glsl
fogColor              // Fog color
skyColor              // Sky color
lightDay              // Daytime directional light
lightNight            // Nighttime color
```

### Water
```glsl
air_n = 1.000293      // Refractive index
water_n = 1.333       // Water refractive index
```

## Directory Structure to Mimic

```
shaders/
├── program/
│   ├── gbuffers_terrain.glsl
│   ├── gbuffers_textured.glsl
│   └── shadow.glsl
├── lib/
│   ├── lighting/
│   │   ├── shadows.glsl
│   │   ├── brdf.glsl
│   │   └── forward.glsl
│   ├── util/
│   │   ├── encode.glsl
│   │   ├── space_convert.glsl
│   │   └── dither.glsl
│   └── surface/
│       └── material.glsl
└── include/          # (if using Photon style)
    ├── global.glsl
    └── constants.glsl
```

## Testing Checklist

- [ ] Shadow map generates without errors
- [ ] Shadows appear on terrain
- [ ] Colored shadows work (if implemented)
- [ ] Water caustics display correctly
- [ ] Normal mapping doesn't show seams
- [ ] Frame rate stays acceptable
- [ ] No visual artifacts at shadow edges

## Troubleshooting

**Shadows appear black everywhere:**
- Check shadow bias calculation
- Verify shadowPos.z comparison direction
- Ensure shadow depth texture binding

**Shadows have hard edges:**
- Add filtering (use CODE_SNIPPETS.md § 2.1)
- Check shadow map resolution
- Increase sample count

**Water looks wrong:**
- Verify water material ID matching
- Check caustics normal calculation
- Review absorption coefficients

**Normal seams visible:**
- Verify normal encoding/decoding
- Check TBN matrix calculation
- Ensure tangent space consistency

## Performance Tips

1. **Use sampler2DShadow** - Automatic PCF on hardware
2. **Batch includes** - Reduce compilation time
3. **Conditional rendering** - Skip unnecessary passes
4. **Optimize filters** - Fewer taps = faster
5. **Cache calculations** - Store intermediate values

## Next Steps

1. **Read SHADER_REFERENCES.md** for architecture overview
2. **Study CODE_SNIPPETS.md** for implementation details
3. **Clone the repositories** locally for full code access
4. **Start with Phase 1** from the implementation priority list
5. **Reference specific sections** as needed during development

## Repository Links

- **Complementary Shaders V4:** https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
- **Photon Shaders:** https://github.com/sixthsurge/photon
- **Shadow Tutorial:** https://github.com/shaderLABS/Shadow-Tutorial

## License Reminder

Remember to:
- Check each repository's license before use
- Provide proper attribution
- Understand redistribution restrictions
- Don't bundle code without permission
- Reference authors in documentation

---

**Created:** 2026-03-20
**For:** Echelon-Nexus-Shader-Pack
**Status:** Ready for implementation
