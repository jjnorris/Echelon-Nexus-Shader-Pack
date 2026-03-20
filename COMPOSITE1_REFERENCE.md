# COMPOSITE1 REFERENCE IMPLEMENTATIONS
## Exact Code Patterns from Established Shaders

---

## COMPLEMENTARY SHADERS V4 - COMPLETE composite1.glsl

### Fragment Shader Structure (Abbreviated Key Section)

```glsl
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D colortex0;  // INPUT: color from composite pass
uniform sampler2D colortex1;  // INPUT: volumetric lighting data
#ifdef VL_CLOUDS
    uniform sampler2D colortex5;
#endif

//Optifine Constants//
#if !(LIGHT_SHAFT_QUALITY == 3)
    const bool colortex1MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

void main() {
    vec4 color = texture2D(colortex0, texCoord.xy);
    
    #ifdef VL_CLOUDS
        float offsetC = 2.0;
        float lodC = 1.5;
        vec4 clouds1 = texture2DLod(colortex5, texCoord.xy + vec2(0.0, offsetC / viewHeight), lodC);
        vec4 clouds2 = texture2DLod(colortex5, texCoord.xy + vec2(0.0, -offsetC / viewHeight), lodC);
        vec4 clouds3 = texture2DLod(colortex5, texCoord.xy + vec2(offsetC / viewWidth, 0.0), lodC);
        vec4 clouds4 = texture2DLod(colortex5, texCoord.xy + vec2(-offsetC / viewWidth, 0.0), lodC);
        vec4 clouds = (clouds1 + clouds2 + clouds3 + clouds4) * 0.25;
        clouds *= clouds;
    #endif
    
    #ifdef END
        vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb;
        vl *= vl;
    #else
        #if LIGHT_SHAFT_QUALITY == 1
            float lod = 1.0;
        #elif LIGHT_SHAFT_QUALITY == 2
            float lod = 0.5;
        #else
            float lod = 0.0;
        #endif
        
        float offset = 1.0;
        vec3 vl1 = texture2DLod(colortex1, texCoord.xy + vec2(0.0, offset / viewHeight), lod).rgb;
        vec3 vl2 = texture2DLod(colortex1, texCoord.xy + vec2(0.0, -offset / viewHeight), lod).rgb;
        vec3 vl3 = texture2DLod(colortex1, texCoord.xy + vec2(offset / viewWidth, 0.0), lod).rgb;
        vec3 vl4 = texture2DLod(colortex1, texCoord.xy + vec2(-offset / viewWidth, 0.0), lod).rgb;
        vec3 vlSum = (vl1 + vl2 + vl3 + vl4) * 0.25;
        vec3 vl = vlSum;
        
        vl *= vl;
    #endif
    
    #ifdef OVERWORLD
        if (isEyeInWater == 0) {
            // Apply directional modulation
            vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
            vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
            viewPos /= viewPos.w;
            vec3 nViewPos = normalize(viewPos.xyz);
            
            float NdotU = dot(nViewPos, upVec);
            NdotU = max(NdotU, 0.0);
            NdotU = 1.0 - NdotU;
            if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
            NdotU *= NdotU;
            NdotU *= NdotU;
            NdotU = mix(NdotU, 1.0, rainStrengthS * rainStrengthS * 0.75);
            vl *= NdotU * NdotU;
            
            // Apply color tinting
            vec3 vlColor = mix(nightLightCol, dayLightCol, sunVisibility);
            vl *= vlColor;
            
            // Apply strength multipliers
            vl *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor);
        }
    #endif
    
    // Composite the effect back to color
    vec3 addedColor = color.rgb + vl * lightShaftTime;
    vec3 mixedColor = mix(color.rgb, vl / max(vlP, 0.01), vlMixBlend * mixedTime);
    color.rgb = mix(mixedColor, addedColor, sunVisibility * (1.0 - rainStrengthS));
    
    #ifdef VL_CLOUDS
        clouds.a *= CLOUD_OPACITY;
        color.rgb = mix(color.rgb, clouds.rgb, clouds.a);
    #endif
    
    /*DRAWBUFFERS:0*/
    gl_FragData[0] = color;
}

#endif
```

### Vertex Shader Structure

```glsl
#ifdef VSH

uniform mat4 gbufferModelView;

// Common Variables
#ifdef OVERWORLD
    float timeAngleM = timeAngle;
#else
    #if !defined SEVEN && !defined SEVEN_2
        float timeAngleM = 0.25;
    #else
        float timeAngleM = 0.5;
    #endif
#endif

void main() {
    texCoord = gl_MultiTexCoord0.xy;
    
    gl_Position = ftransform();
    
    // Calculate sun/moon direction
    const vec2 sunRotationData = vec2(
        cos(sunPathRotation * 0.01745329251994), 
        -sin(sunPathRotation * 0.01745329251994)
    );
    float ang = fract(timeAngleM - 0.25);
    ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
    sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
    
    upVec = normalize(gbufferModelView[1].xyz);
}

#endif
```

---

## PHOTON SHADERS - c1_blend_layers.fsh (Excerpt)

### Modern Layout Syntax & Output

```glsl
layout(location = 0) out vec3 fragment_color;

#ifdef BLOOMY_FOG
    layout(location = 1) out float bloomy_fog;
    /* RENDERTARGETS: 0,3 */
#else
    /* RENDERTARGETS: 0 */
#endif
```

### Texture Sampling Pattern

```glsl
void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    
    // Sample key textures
    float front_depth = texelFetch(depthtex0, texel, 0).x;
    float back_depth = texelFetch(depthtex1, texel, 0).x;
    
    vec4 refraction_data = texelFetch(colortex3, texel, 0);
    vec4 translucent_color = texelFetch(colortex13, texel, 0);
    
    // Conditional fog sampling
    #if defined VL || defined LPV_VL
        vec3 fog_transmittance = smooth_filter(colortex6, uv).rgb;
        vec3 fog_scattering = smooth_filter(colortex7, uv).rgb;
    #endif
    
    // Determine layer type
    bool is_translucent = front_depth != back_depth;
    bool is_sky = back_depth == 1.0 && back_depth_lod == 1.0;
    
    // Space conversions
    vec3 front_position_screen = vec3(uv, front_depth);
    vec3 front_position_view = screen_to_view_space(front_position_screen, true, false);
    vec3 front_position_world = view_to_scene_space(front_position_view) + cameraPosition;
    
    // Blend with fog
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

### Vertex Shader Pattern

```glsl
void main() {
    uv = gl_MultiTexCoord0.xy;
    
    // Fetch precomputed colors from sky map
    light_color = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
    #if defined WORLD_OVERWORLD && defined SH_SKYLIGHT
        ambient_color = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
    #else
        ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
    #endif
    
    #if defined WORLD_OVERWORLD
        fog_params = get_fog_parameters(get_weather());
    #endif
    
    // Simple full-screen quad with TAA offset
    vec2 vertex_pos = gl_Vertex.xy * taau_render_scale;
    gl_Position = vec4(vertex_pos * 2.0 - 1.0, 0.0, 1.0);
}
```

---

## SHADERS.PROPERTIES CONFIGURATION

### Complementary Shaders V4

```properties
program.composite1.enabled=LIGHT_SHAFTS
```

This means composite1 only compiles when the LIGHT_SHAFTS feature is enabled.

### Photon Shaders

No explicit `program.composite1.enabled` line found. This suggests:
- composite1 is ALWAYS enabled
- It's a core blending pass, not optional
- The architecture is different (layer blending vs. light shaft effects)

---

## CRITICAL TAKEAWAYS FOR YOUR IMPLEMENTATION

### 1. Texture Pipeline
```
Phase 1 (composite.glsl):
  Input:  gbuffers (G-Buffer data)
  Output: colortex0 (scene color)
          colortex1 (volumetric lighting)

Phase 2 (composite1.glsl):
  Input:  colortex0 (from composite)
          colortex1 (for VL data)
          colortex5 (optional clouds)
  Output: colortex0 (final composited color)
```

### 2. Required Uniforms (Minimum)
```glsl
// Scene state
uniform int isEyeInWater;
uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness;

// Screen properties
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;

// Lighting
uniform vec3 skyColor;

// Transforms
uniform mat4 gbufferProjectionInverse;

// Textures
uniform sampler2D colortex0;  // mandatory
uniform sampler2D colortex1;  // mandatory for VL
```

### 3. Varyings (Must Be Set in VSH)
```glsl
varying vec2 texCoord;        // Screen UVs
varying vec3 sunVec;          // Sun direction
varying vec3 upVec;           // View up direction
```

### 4. Output Format
```glsl
/*DRAWBUFFERS:0*/
gl_FragData[0] = finalColor;  // Legacy (GL 1.2-1.3)
```
OR
```glsl
layout(location = 0) out vec3 fragment_color;  // Modern (GL 4.0+)
/* RENDERTARGETS: 0 */
```

### 5. What Your Current Code Is Missing
- ❌ Uses `uniform sampler2D composite;` (non-standard)
- ❌ No DRAWBUFFERS specification
- ❌ Missing 8 required uniforms
- ❌ No varying varyings defined
- ❌ VSH doesn't compute sun/moon vectors
- ❌ No conditional compilation for features

---

## NEXT STEPS FOR ECHELON-NEXUS

1. **Replace sampler2D composite with colortex0 and colortex1**
2. **Add all missing uniforms** (copy from Complementary V4)
3. **Define varyings** (texCoord, sunVec, upVec)
4. **Implement VSH** to compute sun direction
5. **Add DRAWBUFFERS:0** comment before output
6. **Add optional VL_CLOUDS support**
7. **Test with shaders.properties enabled composite1**

Your composite1 currently reads from a non-existent "composite" sampler that Iris doesn't provide.
Iris provides colortex0, colortex1, etc. - use those!
