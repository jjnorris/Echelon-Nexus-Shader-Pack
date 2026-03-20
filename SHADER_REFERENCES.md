# Shader Code References - Research Documentation

This document provides comprehensive references to actual shader implementations from three major Minecraft shader packs for learning and reference purposes.

---

## 1. COMPLEMENTARY SHADERS V4
**Repository:** https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
**License:** Check repository for license terms
**Version:** Latest from master branch

### 1.1 Core Shader Files

#### gbuffers_terrain.glsl
**Path:** `/shaders/program/gbuffers_terrain.glsl` (830 lines)
**URL:** https://raw.githubusercontent.com/ComplementaryDevelopment/ComplementaryShadersV4/master/shaders/program/gbuffers_terrain.glsl

**Purpose:** Main terrain rendering shader combining vertex and fragment processing

**Key Features:**
- Includes both VSH (Vertex Shader) and FSH (Fragment Shader) in single file
- Handles terrain material properties (foliage, leaves, etc.)
- Advanced material system with COMPBR integration
- Normal mapping and parallax occlusion mapping
- Snow mode support with dynamic texture coating
- Subsurface scattering for vegetation

**Key Functions:**
- Material classification (foliage, leaves, snow detection)
- Lighting calculations with GetLighting()
- Normal mapping with TBN matrix transforms
- Parallax shadow computation for self-shadowing effects
- Specular highlights with GGX BRDF

**Fragment Shader Outputs:**
- DRAWBUFFERS:0 - Albedo color
- DRAWBUFFERS:0361 - Smoothness, metallic data, skymap modification, raw albedo
- Optional light albedo (COLORED_LIGHT feature)

---

#### gbuffers_textured.glsl
**Path:** `/shaders/program/gbuffers_textured.glsl` (347 lines)
**URL:** https://raw.githubusercontent.com/ComplementaryDevelopment/ComplementaryShadersV4/master/shaders/program/gbuffers_textured.glsl

**Purpose:** Rendering for textured entities and special objects

**Key Features:**
- Particle effect handling
- Dynamic lighting support
- Simple lighting model for moving objects
- Minimal material properties compared to terrain

**Vertex Shader Features:**
- Sun vector calculation with rotation matrices
- Up vector from model view matrix
- Optional entity position tracking (WORLD_CURVATURE)
- Animation/waving disabled for standard rendering

---

#### shadow.glsl
**Path:** `/shaders/program/shadow.glsl` (269 lines)
**URL:** https://raw.githubusercontent.com/ComplementaryDevelopment/ComplementaryShadersV4/master/shaders/program/shadow.glsl

**Purpose:** Shadow map generation for dynamic lighting

**Key Features:**
- Water caustics with Perlin noise implementation
- Material identification (water, ice, foliage)
- Shadow bias calculation based on surface angle
- Colored shadow support for water/translucent blocks

**Vertex Shader - Key Calculations:**
```glsl
// Shadow bias computation
float distortBias = distortFactor * shadowDistance / 256.0;
distortBias *= 8.0 * distortBias;
float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
float bias = (distortBias * biasFactor + 0.05) / shadowMapResolution;
gl_Position.z -= bias * 11.0;
```

**Fragment Shader - Key Logic:**
- Discard transparent fragments
- Water shadow handling with caustics
- Colored shadow generation
- Material-based alpha testing

---

### 1.2 Library Files

#### lib/lighting/shadows.glsl
**Path:** `/shaders/lib/lighting/shadows.glsl`
**URL:** https://raw.githubusercontent.com/ComplementaryDevelopment/ComplementaryShadersV4/master/shaders/lib/lighting/shadows.glsl

**Purpose:** Shadow sampling and filtering functions

**Key Functions:**

1. **SampleBasicShadow()** - Single shadow sample with optional color
   - Reads shadow2D() with depth comparison
   - Handles colored shadows from translucent blocks
   - Supports water caustics

2. **SampleFilteredShadow()** - Poisson disk filtered shadow sampling
   - 8-tap shadow filtering with circular offset pattern
   - Reduces shadow aliasing and banding

3. **SampleTAAFilteredShadow()** - TAA-aware temporal shadow filtering
   - Interleaved gradient noise for temporal stability
   - Variable sample counts based on subsurface requirements
   - Adaptive offset based on shadow map resolution

4. **GetShadow()** - Main shadow retrieval function
   - Dispatches to appropriate filtering based on quality settings
   - Handles anti-aliasing modes

**Shadow Offset Pattern:**
```glsl
vec2 shadowoffsets[8] = vec2[8](
    vec2( 0.0   , 1.0   ),    vec2( 0.7071, 0.7071),
    vec2( 1.0   , 0.0   ),    vec2( 0.7071,-0.7071),
    vec2( 0.0   ,-1.0   ),    vec2(-0.7071,-0.7071),
    vec2(-1.0   , 0.0   ),    vec2(-0.7071, 0.7071)
);
```

---

#### lib/util/encode.glsl
**Path:** `/shaders/lib/util/encode.glsl`
**URL:** https://raw.githubusercontent.com/ComplementaryDevelopment/ComplementaryShadersV4/master/shaders/lib/util/encode.glsl

**Purpose:** Normal vector compression/decompression using spheremap encoding

**Implementation Details:**
- Based on Aras Pranckevicius spheremap method
- Encodes 3D normal into 2D coordinates (reduces bandwidth)
- Suitable for G-Buffer storage

**Key Code:**
```glsl
// Spheremap Transform
vec2 EncodeNormal(vec3 n) {
    float f = sqrt(n.z * 8.0 + 8.0);
    return n.xy / f + 0.5;
}

vec3 DecodeNormal(vec2 enc) {
    vec2 fenc = enc * 4.0 - 2.0;
    float f = dot(fenc,fenc);
    float g = sqrt(1.0 - f / 4.0);
    vec3 n;
    n.xy = fenc * g;
    n.z = 1.0 - f / 2.0;
    return n;
}
```

---

#### lib/lighting/forwardLighting.glsl
**Path:** `/shaders/lib/lighting/forwardLighting.glsl`

**Purpose:** Main forward lighting computation

**Key Features:**
- Directional light calculation with shadow testing
- Block light (point light) contribution
- Sky light ambient occlusion
- Material property integration

---

#### lib/color/blocklightColor.glsl, lib/color/dimensionColor.glsl
**Purpose:** Color grading and dimension-specific lighting adjustments

---

### 1.3 Configuration System

**Settings Location:** `/shaders/lib/common.glsl`

**Key Configuration Options:**
- Shader quality levels (RP_SUPPORT)
- Lighting features (shadows, caustics, subsurface scattering)
- Visual effects (normal mapping, parallax, snow mode)
- Animation speeds and intensities
- Debug modes

---

## 2. PHOTON SHADERS
**Repository:** https://github.com/sixthsurge/photon
**License:** Check repository for license terms
**Version:** Latest from master branch
**Version Support:** GLSL 400+ (Modern)

### 2.1 Core Program Files

#### program/shadow.vsh (127 lines)
**Path:** `/shaders/program/shadow.vsh`
**URL:** https://raw.githubusercontent.com/sixthsurge/photon/master/shaders/program/shadow.vsh

**Purpose:** Shadow map generation vertex shader

**Key Features:**
- Advanced vertex displacement and animation
- Material masking for selective rendering
- Voxel map updates for colored lighting (LPV)
- Water caustics support with scene position tracking

**Key Uniforms:**
- shadowModelView, shadowModelViewInverse
- World transformation matrices
- Per-frame time and animation data

**Animation System:**
- Dedicated animate_vertex() function for materials
- Block entity ID-based behavior
- Top-vertex detection for correct waving

---

#### program/shadow.fsh (172 lines)
**Path:** `/shaders/program/shadow.fsh`
**URL:** https://raw.githubusercontent.com/sixthsurge/photon/master/shaders/program/shadow.fsh

**Purpose:** Shadow map fragment shader with advanced features

**Key Features:**
- Water caustics using refraction calculations
- Physically-based water absorption coefficients
- Biome-dependent water coloring
- Advanced refraction with safe refract() to avoid NaN errors

**Water Physics Constants:**
```glsl
const float air_n = 1.000293;        // Refractive index of air
const float water_n = 1.333;          // Refractive index of water
const float distance_through_water = 5.0; // meters
```

**Water Caustics Calculation:**
- Uses water surface normal from procedural generation
- Computes refracted light path through water
- Applies Jacobian transformation for area distortion
- Returns caustics intensity factor

**Safe Refraction Implementation:**
```glsl
vec3 refract_safe(vec3 I, vec3 N, float eta) {
    float NoI = dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) {
        return vec3(0.0);
    } else {
        return eta * I - (eta * NoI + sqrt(k)) * N;
    }
}
```

---

### 2.2 Include Files Structure

**Key Directories:**
- `/include/global.glsl` - Version checks, extensions, settings
- `/include/lighting/shadows/` - Advanced shadow sampling
  - `distortion.glsl` - Shadow map distortion
  - `pcss.glsl` - Percentage-closer soft shadows
  - `ssrt.glsl` - Screen-space ray tracing
  - `common.glsl` - Shared shadow functions
- `/include/lighting/` - Lighting models
  - `bsdf.glsl` - BRDF implementations
  - `specular_lighting.glsl`
  - `diffuse_lighting.glsl`
- `/include/lighting/lpv/` - Light propagation volume (voxel-based lighting)
  - `voxelization.glsl`
  - `blocklight.glsl`
- `/include/lighting/ao/` - Ambient occlusion
  - `gtao.glsl` - Ground-truth ambient occlusion
  - `ssao.glsl` - Screen-space AO

**Version Management:**
- MC_VERSION checks for Minecraft version compatibility
- Separate implementations for different feature levels
- Fallback shaders for lower-end hardware

---

## 3. SHADOW TUTORIAL
**Repository:** https://github.com/shaderLABS/Shadow-Tutorial
**License:** Check repository for license terms
**Version:** Latest from master branch
**Target:** Educational - Minimal shadow implementation

### 3.1 Minimal Shadow Implementation

#### shadow.vsh (27 lines)
**Path:** `/shaders/shadow.vsh`
**URL:** https://raw.githubusercontent.com/shaderLABS/Shadow-Tutorial/master/shaders/shadow.vsh

**Purpose:** Simple shadow mapping vertex shader

**Key Features:**
- Basic shadow space transformation
- Shadow distortion via distort.glsl include
- Foliage exclusion option

**Code Structure:**
```glsl
#version 120
attribute vec4 mc_Entity;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#include "/distort.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    gl_Position = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
}
```

**Learning Value:** Demonstrates minimal vertex shader required for shadow mapping

---

#### shadow.fsh (14 lines)
**Path:** `/shaders/shadow.fsh`
**URL:** https://raw.githubusercontent.com/shaderLABS/Shadow-Tutorial/master/shaders/shadow.fsh

**Purpose:** Minimal shadow fragment shader

**Implementation:**
```glsl
#version 120
uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

void main() {
    vec4 color = texture2D(texture, texcoord) * glcolor;
    gl_FragData[0] = color;
}
```

**Learning Points:**
- No complex shadow calculations in fragment stage
- Simple alpha blending via texture sampling
- Direct color output

---

#### gbuffers_terrain.fsh (66 lines)
**Path:** `/shaders/gbuffers_terrain.fsh`
**URL:** https://raw.githubusercontent.com/shaderLABS/Shadow-Tutorial/master/shaders/gbuffers_terrain.fsh

**Purpose:** Terrain rendering with shadow integration

**Key Features:**
- Shadow position calculation from shadowPos varying
- Colored shadow support
- Configurable shadow brightness (SHADOW_BRIGHTNESS)
- Separate opaque/translucent shadow checks

**Shadow Sampling Logic:**
```glsl
if (shadowPos.w > 0.0) {
    // Surface faces towards sun
    #if COLORED_SHADOWS == 0
        // Check closest to sun (any opacity)
        if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
    #else
        // Check closest OPAQUE to sun
        if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
    #endif
        // Surface is in shadow
        lm.y *= SHADOW_BRIGHTNESS;
    }
}
```

**Configuration Options:**
```glsl
#define COLORED_SHADOWS 1  // [0 1 2]
#define SHADOW_BRIGHTNESS 0.75
```

---

#### gbuffers_textured.fsh (60 lines)
**Path:** `/shaders/gbuffers_textured.fsh`
**URL:** https://raw.githubusercontent.com/shaderLABS/Shadow-Tutorial/master/shaders/gbuffers_textured.fsh

**Purpose:** Entity/particle rendering with shadows

**Differences from terrain:**
- No normal vector (uses screenPos instead)
- Simpler shadow position calculation
- Particle-specific handling

---

### 3.2 Educational Value

This tutorial shader pack is ideal for learning:

1. **Shadow Mapping Fundamentals**
   - Basic shadow space transformation
   - Depth comparison techniques
   - Colored shadow implementation

2. **Optifine Shader Framework**
   - Standard directory structure
   - Light map coordinate handling
   - Material properties system

3. **Progression Path**
   - Start: Simple shadow rendering (shadow.fsh)
   - Intermediate: Terrain integration (gbuffers_terrain.fsh)
   - Advanced: Add complexity from Complementary/Photon

---

## 4. COMPARATIVE ANALYSIS

### Complexity Levels

| Feature | Complementary | Photon | Tutorial |
|---------|---------------|--------|----------|
| Shader Version | 130-140 | 400+ | 120 |
| Lines per file | 200-830 | 127-172 | 14-66 |
| Material system | Advanced (COMPBR) | Modular | Basic |
| Normal mapping | Yes | Yes | No |
| Parallax mapping | Yes | No | No |
| GGX BRDF | Yes | Yes | No |
| Water caustics | Yes | Yes (advanced) | No |
| LPV/Voxel lighting | No | Yes | No |
| TAA filtering | Yes | Yes | No |

---

### Shadow Implementation Comparison

**Tutorial Approach:**
- Direct depth comparison
- Single or dual shadow texture
- Hardcoded SHADOW_BRIGHTNESS
- Simple conditional logic

**Complementary Approach:**
- Poisson disk filtering
- TAA-aware temporal filtering
- Material-specific bias calculations
- Subsurface scattering support
- Colored shadow integration

**Photon Approach:**
- PCSS (Percentage-Closer Soft Shadows)
- Screen-space ray tracing integration
- Advanced water physics modeling
- Voxel-based light propagation
- Modern GLSL 400 features

---

## 5. TECHNICAL CONCEPTS EXPLAINED

### Shadow Distortion (Complementary)
Shadow map distortion reduces aliasing at distance:
```glsl
float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
gl_Position.xy *= 1.0 / distortFactor;
gl_Position.z = gl_Position.z * 0.2;
```

### Shadow Bias Calculation (Complementary)
Prevents shadow acne (z-fighting artifacts):
```glsl
// Based on surface angle relative to light
float NdotLm = clamp(dot(upVec, lightVec) * 1.01 - 0.01, 0.0, 1.0);
float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
float bias = (distortBias * biasFactor + 0.05) / shadowMapResolution;
```

### Water Caustics Physics (Photon)
Applies Snell's law and Jacobian transformation:
```glsl
// Refracted light path
vec3 new_pos = world_pos +
    refract_safe(light_dir, normal, air_n / water_n) *
    (distance_through_water * WATER_CAUSTICS_INTENSITY);

// Area scaling for brightness
float old_area = length_squared(dFdx(old_pos)) * length_squared(dFdy(old_pos));
float new_area = length_squared(dFdx(new_pos)) * length_squared(dFdy(new_pos));
return 0.25 * inversesqrt(old_area / new_area);
```

### Normal Encoding (Complementary)
Spheremap reduces normal storage from 3 floats to 2:
```glsl
// Encoding reduces from vec3 (12 bytes) to vec2 (8 bytes)
vec2 encoded = encodeNormal(normal);
// Compact representation: 2 components preserve full 3D information
```

---

## 6. LEARNING PROGRESSION ROADMAP

### Stage 1: Foundation (Shadow Tutorial)
- Understand shader file structure
- Learn shadow mapping basics
- Grasp Optifine framework
- Time: 1-2 weeks

### Stage 2: Intermediate (Complementary)
- Study advanced filtering techniques
- Learn material properties system
- Implement normal mapping
- Add GGX specular highlights
- Study shadow bias calculations
- Time: 2-3 weeks

### Stage 3: Advanced (Photon)
- Modern GLSL 400+ patterns
- Voxel-based lighting systems
- Physically-based water rendering
- Screen-space ray tracing
- Temporal stability techniques
- Time: 3-4 weeks

---

## 7. IMPLEMENTATION CHECKLIST

For your Echelon-Nexus shader pack:

- [ ] Basic shadow mapping (Tutorial reference)
- [ ] Shadow filtering optimization (Complementary reference)
- [ ] Material-based properties (Complementary COMPBR system)
- [ ] Normal encoding/decoding (Complementary utilities)
- [ ] GGX BRDF lighting (Complementary lib/lighting/ggx.glsl)
- [ ] Water rendering (Photon advanced water physics)
- [ ] Colored shadows (Both Complementary and Tutorial)
- [ ] TAA shadow filtering (Complementary temporal stability)
- [ ] Performance optimization (Photon modular approach)

---

## 8. FILE ORGANIZATION REFERENCE

**Recommended Structure for Echelon-Nexus:**
```
shaders/
├── program/          # Main shader programs
│   ├── gbuffers_terrain.glsl
│   ├── gbuffers_textured.glsl
│   ├── shadow.glsl
│   └── composite.glsl
├── lib/              # Library/utility files
│   ├── lighting/
│   │   ├── brdf.glsl
│   │   ├── shadows.glsl
│   │   └── forward.glsl
│   ├── util/
│   │   ├── encode.glsl
│   │   ├── dither.glsl
│   │   └── space_convert.glsl
│   └── surface/
│       └── material.glsl
└── include/          # For modular includes
    ├── global.glsl
    └── constants.glsl
```

---

## 9. REFERENCES & CREDITS

**Complementary Shaders V4**
- Author: EminGT
- Based on: BSL Shaders by Capt Tatsu
- Repository: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4

**Photon Shaders**
- Author: SixthSurge
- Repository: https://github.com/sixthsurge/photon

**Shadow Tutorial**
- Author: ShaderLABS
- Repository: https://github.com/shaderLABS/Shadow-Tutorial
- Purpose: Educational resource

**Technical References Used:**
- Aras Pranckevicius - Compact Normal Storage: https://aras-p.info/texts/CompactNormalStorage.html
- Minecraft Optifine Shader Framework documentation

---

## 10. LEGAL NOTICE

This document contains references to and excerpts from third-party shader code. All referenced shader packs maintain their own licenses as specified in their respective repositories. Please review the license terms of each project before using code or techniques from these implementations.

For educational and research purposes, this document provides:
- File location references
- Algorithm descriptions
- Key function signatures
- Conceptual explanations

Always refer to original repositories for complete, up-to-date implementations and licensing information.

---

**Document Version:** 1.0
**Last Updated:** 2026-03-20
**Created for:** Echelon-Nexus-Shader-Pack
**Reference Set:** Complementary V4, Photon, Shadow Tutorial
