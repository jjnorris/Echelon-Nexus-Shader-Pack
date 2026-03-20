# COMPOSITE PASS ARCHITECTURE ANALYSIS
## Research on Complementary Shaders V4 & Photon Shaders

---

## PART 1: COMPLEMENTARY SHADERS V4 (ESTABLISHED REFERENCE)

### File Structure
```
composite.fsh          → Wrapper shader loader
  ↓
program/composite.glsl → Actual implementation (FSH + VSH in one file)

composite1.fsh         → Wrapper shader loader  
  ↓
program/composite1.glsl → Actual implementation (FSH + VSH in one file)
```

### Naming Convention Insight
- **Wrapper files (world1/)**: Contain only:
  - Version declaration
  - A single #define (OVERWORLD, END, NETHER, etc.)
  - One #define for shader type (FSH or VSH)
  - One #include pointing to /program/

- **Program files**: Contain BOTH vertex and fragment shaders:
  - `#ifdef FSH` ... `#endif` blocks
  - `#ifdef VSH` ... `#endif` blocks
  - Unified varyings, uniforms, and common code

### COMPOSITE.GLSL (Phase 1: Main Rendering)
**Purpose**: Primary color and depth processing

**Uniforms (Fragment Shader):**
```glsl
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldDay;

uniform float isEyeInCave;
uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight, aspectRatio;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef LIGHT_SHAFTS
    uniform sampler2DShadow shadowtex0;
    uniform sampler2DShadow shadowtex1;
    uniform sampler2D shadowcolor0;
#endif
```

**Output (DRAWBUFFERS)**: None specified in composite phase (uses default colortex0)

---

### COMPOSITE1.GLSL (Phase 2: Light Shafts Post-Processing)
**Purpose**: Volumetric light shafts and atmospheric effects

**Main Function Signature:**
```glsl
void main() {
    vec4 color = texture2D(colortex0, texCoord.xy);
    // ... light shaft calculations using colortex1 (volumetric data)
    gl_FragColor = color;
}
```

**Uniforms (Fragment Shader):**
```glsl
uniform int isEyeInWater;

uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D colortex0;      // ← Input: Result from composite phase
uniform sampler2D colortex1;      // ← Input: Volumetric lighting data
#ifdef VL_CLOUDS
    uniform sampler2D colortex5;  // ← Optional: Cloud render target
#endif
```

**Key Reading Pattern:**
```glsl
vec4 color = texture2D(colortex0, texCoord.xy);        // Read composite result
vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb; // Read VL data
vl *= vl;  // Brightness adjustment
// ... Apply light shaft effects to color
color.rgb += vl * lightShaftTime;
gl_FragColor = color;
```

**Output:**
```glsl
/*DRAWBUFFERS:0*/
gl_FragData[0] = color;  // Write back to colortex0
```

**Critical Uniforms Architecture:**
- colortex0 = Input from previous pass (composite)
- colortex1 = Stores volumetric/shadow data (pre-computed)
- colortex5 = Cloud layer (optional)

**Vertex Shader (VSH):**
```glsl
void main() {
    texCoord = gl_MultiTexCoord0.xy;
    
    gl_Position = ftransform();
    
    // Calculate sun/moon direction vectors
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), 
                                       -sin(sunPathRotation * 0.01745329251994));
    float ang = fract(timeAngleM - 0.25);
    ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
    sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
    
    upVec = normalize(gbufferModelView[1].xyz);
}
```

---

## PART 2: PHOTON SHADERS (MODERN REFERENCE)

### File Structure
```
composite1.fsh    → Wrapper (minimal)
composite1.vsh    → Wrapper (minimal)
  ↓
program/c1_blend_layers.fsh
program/c1_blend_layers.vsh
```

### COMPOSITE1 Implementation (c1_blend_layers.fsh/vsh)
**Purpose**: Blend multiple rendering layers (solid, translucent, fog, clouds)

**Output Declaration:**
```glsl
layout(location = 0) out vec3 fragment_color;

#ifdef BLOOMY_FOG
layout(location = 1) out float bloomy_fog;
/* RENDERTARGETS: 0,3 */
#else
/* RENDERTARGETS: 0 */
#endif
```

**Key Uniforms (Fragment Shader):**
```glsl
uniform sampler2D noisetex;

uniform sampler2D colortex0;   // scene color
uniform sampler2D colortex3;   // refraction data
uniform sampler2D colortex4;   // sky map
uniform sampler2D colortex5;   // scene history
uniform sampler2D colortex6;   // volumetric fog scattering
uniform sampler2D colortex7;   // volumetric fog transmittance
uniform sampler2D colortex11;  // clouds history
uniform sampler2D colortex12;  // clouds data
uniform sampler2D colortex13;  // rendered translucent layer

#ifdef SHADOW
#ifdef AIR_FOG_COLORED_LIGHT_SHAFTS
    uniform sampler2D shadowcolor0;
    uniform sampler2D shadowtex0;
#endif
    uniform sampler2D shadowtex1;
#endif

uniform sampler2D depthtex0;   // front depth
uniform sampler2D depthtex1;   // back depth

// Matrices for space conversions
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// World parameters
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;
uniform int worldTime;
uniform int moonPhase;
uniform int frameCounter;
uniform int isEyeInWater;
uniform float eyeAltitude;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;
uniform vec3 light_dir, sun_dir, moon_dir;
uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;
uniform float eye_skylight;
```

**Main Function Pattern:**
```glsl
void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    
    // Sample depth and layer data
    float front_depth = texelFetch(depthtex0, texel, 0).x;
    float back_depth = texelFetch(depthtex1, texel, 0).x;
    
    vec4 refraction_data = texelFetch(colortex3, texel, 0);
    vec4 translucent_color = texelFetch(colortex13, texel, 0);
    
    // Fog sampling (optional, for VL)
    #if defined VL || defined LPV_VL
        vec3 fog_transmittance = smooth_filter(colortex6, uv).rgb;
        vec3 fog_scattering = smooth_filter(colortex7, uv).rgb;
    #endif
    
    // Determine if translucent
    bool is_translucent = front_depth != back_depth;
    bool is_sky = back_depth == 1.0 && back_depth_lod == 1.0;
    
    // Convert to world space
    vec3 front_position_screen = vec3(uv, front_depth);
    vec3 front_position_view = screen_to_view_space(front_position_screen, true, false);
    vec3 front_position_scene = view_to_scene_space(front_position_view);
    vec3 front_position_world = front_position_scene + cameraPosition;
    
    // Blend function
    vec3 result = blend_layers_with_fog(
        background_color,
        translucent_color,
        front_position_world,
        back_position_world,
        is_translucent,
        is_sky,
        front_is_hand,
        back_is_hand
    );
    
    fragment_color = result;
    #ifdef BLOOMY_FOG
        bloomy_fog = calculate_bloomy_fog(...);
    #endif
}
```

**Vertex Shader Pattern:**
```glsl
void main() {
    uv = gl_MultiTexCoord0.xy;
    
    // Fetch lighting colors from sky map (pre-computed palette)
    light_color = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
    ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
    
    #if defined WORLD_OVERWORLD
        fog_params = get_fog_parameters(get_weather());
    #endif
    
    // Simple full-screen quad with TAA offset
    vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
    gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
```

---

## CRITICAL ARCHITECTURAL INSIGHTS

### 1. **INPUT TEXTURE PIPELINE**
```
Composite Phase:
  gbuffers (G-Buffer) → composite.glsl → colortex0 (final color)
                                      → colortex1 (lighting data)

Composite1 Phase:
  colortex0 (color)  ─┐
  colortex1 (VL)     ├─→ composite1.glsl → colortex0 (final color + effects)
  colortex5 (clouds) ─┘
```

### 2. **TEXTURE ROLES**
- **colortex0**: Scene color (INPUT to composite1, OUTPUT from composite)
- **colortex1**: Lighting/volumetric data (OUTPUT from composite, INPUT to composite1)
- **colortex5**: Cloud/fog data (pre-computed, INPUT to composite1)
- **depthtex0**: Front depth (translucent layer depth)
- **depthtex1**: Back depth (opaque layer depth)

### 3. **OUTPUT SPECIFICATION**
Complementary Shaders V4:
```glsl
/*DRAWBUFFERS:0*/
gl_FragData[0] = color;  // Single target
```

Photon Shaders:
```glsl
layout(location = 0) out vec3 fragment_color;  // Modern layout syntax
#ifdef BLOOMY_FOG
    layout(location = 1) out float bloomy_fog;
    /* RENDERTARGETS: 0,3 */
#else
    /* RENDERTARGETS: 0 */
#endif
```

### 4. **COMPOSITE1 PURPOSE DIFFERENCES**

**Complementary Shaders V4:**
- Primary purpose: Light shaft/volumetric effect post-processing
- Reads: colortex0 (scene color), colortex1 (volumetric data)
- Writes: colortex0 (modified with light shafts)
- Configuration: `program.composite1.enabled=LIGHT_SHAFTS`

**Photon Shaders:**
- Primary purpose: Layer blending (solid, translucent, fog, clouds)
- Reads: Multiple colortex (refraction, VL, translucents, etc.)
- Writes: colortex0 (with optional bloomy fog to colortex3)
- Configuration: Always enabled (no explicit toggle for composite1)

### 5. **STRUCTURE COMPARISON**

| Feature | Complementary V4 | Photon |
|---------|------------------|--------|
| Version | 130 (legacy) | 400 compatibility (modern) |
| Shader Combination | Both in one .glsl file | Both in one .glsl file |
| Output Syntax | `gl_FragData[0]` | `layout(location = 0) out` |
| Wrapper Approach | Minimal (version + #include) | Minimal (version + #include) |
| Vertex Calculation | Sun/moon angle vectors | Fog parameter fetching |
| Fragment Main | Direct GL color operations | Advanced blending functions |
| Texture Sampling | texture2D/texture2DLod | texelFetch/smooth_filter |
| Space Conversion | Inline calculations | Separate utility functions |

---

## ECHELON-NEXUS SHADER ISSUES IDENTIFIED

### Problems in Current composite1.glsl:

1. **Wrong Input Texture**:
   - Currently uses: `uniform sampler2D composite;`
   - Should use: `uniform sampler2D colortex0;` (and other textures)
   - Iris/OptiFine expects standard colortex naming

2. **No Output Specification**:
   - Missing DRAWBUFFERS comment
   - Should be: `/*DRAWBUFFERS:0*/`

3. **Missing Uniforms**:
   - No: isEyeInWater, blindFactor, rainStrengthS, screenBrightness, viewWidth, viewHeight
   - No: eyeBrightnessSmooth, skyColor, gbufferProjectionInverse
   - These are REQUIRED for proper composite pass

4. **Incomplete Vertex Shader**:
   - Currently doesn't set up varyings (sunVec, upVec)
   - Doesn't compute sun/moon directions
   - Should follow Complementary pattern

5. **Missing Optional Features**:
   - No conditional includes for LIGHT_SHAFTS
   - No support for VL_CLOUDS
   - No shadowtex0/shadowtex1 uniforms for shadow features

### Required Changes:

**composite1.glsl should define:**
```glsl
// Varyings (shared)
varying vec2 texCoord;
varying vec3 sunVec, upVec;  // For light direction calculations

// FSH Uniforms (minimum required)
uniform int isEyeInWater;
uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform mat4 gbufferProjectionInverse;

// Textures
uniform sampler2D colortex0;      // Input color
uniform sampler2D colortex1;      // Volumetric/VL data
// Optional for shadow/VL support
uniform sampler2D colortex5;      // Clouds

// Output
/*DRAWBUFFERS:0*/
gl_FragData[0] = finalColor;
```

**composite1.vsh should:**
```glsl
void main() {
    texCoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
    
    // Calculate sun direction based on time
    float ang = ... // time-based angle
    sunVec = normalize(...);  // Sun position
    upVec = normalize(...);   // View up direction
}
```

---

## SUMMARY

Iris/Optifine composite1 expects:
1. ✓ Proper texture naming (colortex0, colortex1, etc.)
2. ✓ DRAWBUFFERS specification
3. ✓ Standard uniforms for time, eye position, brightness
4. ✓ Full VSH + FSH implementation
5. ✓ Varyings for screen coordinates and lighting vectors

Your current composite1 is too simplified and uses non-standard naming.
