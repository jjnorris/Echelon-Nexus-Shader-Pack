# Complete Working Code Snippets - Reference Implementation

This document contains actual, complete code from reference shader packs that can be studied and adapted.

---

## SECTION 1: SHADOW MAPPING IMPLEMENTATION

### 1.1 Shadow Tutorial - Basic Shadow Vertex Shader
**Source:** Shadow Tutorial `shadow.vsh`
**Complexity:** Beginner
**Lines:** 27

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

    #ifdef EXCLUDE_FOLIAGE
        if (mc_Entity.x == 10000.0) {
            gl_Position = vec4(10.0);
        }
        else {
    #endif
            gl_Position = ftransform();
            gl_Position.xyz = distort(gl_Position.xyz);
    #ifdef EXCLUDE_FOLIAGE
        }
    #endif
}
```

**Key Learning Points:**
1. `ftransform()` converts to clip space (equivalent to `gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex`)
2. `distort()` function handles shadow map sampling coordinate distortion
3. `mc_Entity.x` used for material identification and conditional rendering
4. Lightmap coordinate retrieval with `gl_TextureMatrix[1]`

---

### 1.2 Shadow Tutorial - Basic Shadow Fragment Shader
**Source:** Shadow Tutorial `shadow.fsh`
**Complexity:** Beginner
**Lines:** 14

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

**Key Points:**
- Minimal computation in shadow pass
- Simple texture sampling and coloring
- No depth comparisons here (done in post-processing)

---

### 1.3 Complementary V4 - Advanced Shadow Vertex Shader
**Source:** Complementary Shaders V4 `shadow.glsl` (VSH section)
**Complexity:** Intermediate
**Key Section:** Lines 158-268

```glsl
//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float rainStrengthS;

uniform vec3 cameraPosition;

uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 gbufferModelView;

#if WORLD_TIME_ANIMATION < 2
    uniform float frameTimeCounter;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
    float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
    float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

vec2 lmCoord = vec2(0.0);

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
    #include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
    texCoord = gl_MultiTexCoord0.xy;
    color = gl_Color;

    lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

    position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

    mat = 0;
    if (mc_Entity.x == 79) mat = 1; //premult
    if (mc_Entity.x == 7979) mat = 3; //ice
    if (mc_Entity.x == 8) {  //water
        #ifdef WATER_DISPLACEMENT
            position.y += WavingWater(position.xyz, lmCoord.y);
        #endif
        mat = 2;
    }

    float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
    position.xyz += WavingBlocks(position.xyz, istopv, lmCoord.y);

    #ifdef WORLD_CURVATURE
        position.y -= WorldCurvature(position.xz);
    #endif

    gl_Position = shadowProjection * shadowModelView * position;

    // SHADOW DISTORTION
    float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
    float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);

    if (mc_Entity.x == 31 || mc_Entity.x == 6 || mc_Entity.x == 59 ||
        mc_Entity.x == 175 || mc_Entity.x == 176 || mc_Entity.x == 83 ||
        mc_Entity.x == 104 || mc_Entity.x == 105 || mc_Entity.x == 11019) { // Foliage

        #if !defined NO_FOLIAGE_SHADOWS && SHADOW_SUBSURFACE > 0
            // Counter Shadow Bias for foliage
            #ifdef OVERWORLD
                float timeAngleM = timeAngle;
            #else
                #if !defined SEVEN && !defined SEVEN_2
                    float timeAngleM = 0.25;
                #else
                    float timeAngleM = 0.5;
                #endif
            #endif

            const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994),
                                              -sin(sunPathRotation * 0.01745329251994));
            float ang = fract(timeAngleM - 0.25);
            ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
            vec3 sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

            #ifdef OVERWORLD
                vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
            #else
                vec3 lightVec = sunVec;
            #endif

            vec3 upVec = normalize(gbufferModelView[1].xyz);
            float NdotLm = clamp(dot(upVec, lightVec) * 1.01 - 0.01, 0.0, 1.0) * 0.99 + 0.01;

            float distortBias = distortFactor * shadowDistance / 256.0;
            distortBias *= 8.0 * distortBias;
            float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
            float bias = (distortBias * biasFactor + 0.05) / shadowMapResolution;

            #if PIXEL_SHADOWS > 0
                bias += 0.0025 / PIXEL_SHADOWS;
            #endif

            gl_Position.z -= bias * 11.0;  // Apply bias to z
        #else
            mat = 4;
        #endif
    }

    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;
}

#endif
```

**Critical Learning Points:**

1. **Shadow Space Transformation:**
   ```glsl
   position = shadowModelViewInverse * shadowProjectionInverse * ftransform();
   // ... animations ...
   gl_Position = shadowProjection * shadowModelView * position;
   ```

2. **Shadow Distortion for Alias Reduction:**
   ```glsl
   float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
   float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
   gl_Position.xy *= 1.0 / distortFactor;
   gl_Position.z = gl_Position.z * 0.2;  // Compress z-range
   ```

3. **Angle-Aware Bias Calculation:**
   - Uses surface normal (upVec) dot light direction (lightVec)
   - Bias increases when surface is grazing to light
   - Prevents shadow acne and peter-panning

4. **Material Classification:**
   - mc_Entity.x ranges identify blocks (water=8, leaves=31, etc.)
   - Different materials get different shadow treatment

---

### 1.4 Complementary V4 - Advanced Shadow Fragment Shader
**Source:** Complementary Shaders V4 `shadow.glsl` (FSH section)
**Complexity:** Intermediate
**Key Section:** Lines 17-155

```glsl
//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform int blockEntityId;

uniform vec3 cameraPosition;

uniform sampler2D tex;
uniform sampler2D noisetex;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
#else
uniform float frameTimeCounter;
#endif

#if WORLD_TIME_ANIMATION >= 2
    float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
    float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/util/dither.glsl"

//Common Functions//
void doWaterShadowCaustics(float dither) {
    #if defined WATER_CAUSTICS && defined OVERWORLD
        vec3 worldPos = position.xyz + cameraPosition.xyz;
        worldPos *= 0.5;
        float noise = 0.0;
        float mult = 0.5;

        vec2 wind = vec2(frametime) * 0.3; //speed
        float verticalOffset = worldPos.y * 0.2;

        if (mult > 0.01) {
            float lacunarity = 1.0 / 750.0, persistance = 1.0, weight = 0.0;

            for(int i = 0; i < 8; i++) {
                float windSign = mod(i,2) * 2.0 - 1.0;
                vec2 noiseCoord = worldPos.xz + wind * windSign - verticalOffset;
                if (i < 7) noise += texture2D(noisetex, noiseCoord * lacunarity).r * persistance;
                else {
                    noise += texture2D(noisetex, noiseCoord * lacunarity * 0.125).r * persistance * 10.0;
                    noise = -noise;
                    float noisePlus = 1.0 + 0.125 * -noise;
                    noisePlus *= noisePlus;
                    noisePlus *= noisePlus;
                    noise *= noisePlus;
                }

                if (i == 0) noise = -noise;

                weight += persistance;
                lacunarity *= 1.50;
                persistance *= 0.60;
            }
            noise *= mult / weight;
        }
        float noiseFactor = 1.1 + noise;
        noiseFactor = pow(noiseFactor, 10.0);
        if (noiseFactor > 1.0 - dither * 0.5) discard;
    #else
        discard;
    #endif
}

//Program//
void main() {
    #if MC_VERSION >= 11300
        if (blockEntityId == 138) discard;
    #endif

    vec4 albedo = vec4(0.0);

    #ifdef WRONG_MIPMAP_FIX
        #if !defined COLORED_SHADOWS || !defined OVERWORLD
            albedo.a = texture2DLod(tex, texCoord.xy, 0).a;
        #else
            albedo = texture2DLod(tex, texCoord.xy, 0);
        #endif
    #else
        #if !defined COLORED_SHADOWS || !defined OVERWORLD
            albedo.a = texture2D(tex, texCoord.xy).a;
        #else
            albedo = texture2D(tex, texCoord.xy);
        #endif
    #endif

    if (blockEntityId == 200) { // End Gateway Beam Fix
        if (color.r > 0.1) discard;
    }

    if (albedo.a < 0.0001) discard;

    float premult = float(mat > 0.95 && mat < 1.05);
    float water = float(mat > 1.95 && mat < 2.05);
    float ice = float(mat > 2.95 && mat < 3.05);

    #ifdef NO_FOLIAGE_SHADOWS
        if (mat > 3.95 && mat < 4.05) discard;
    #endif

    vec4 albedo0 = albedo;
    if (water > 0.5) {
        if (isEyeInWater < 0.5) {
            albedo0 = vec4(1.0, 1.0, 1.0, 1.0);
            albedo = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            float dither = Bayer64(gl_FragCoord.xy);
            doWaterShadowCaustics(dither);
        }
    } else albedo0.rgb = vec3(0.0);

    #if !defined COLORED_SHADOWS || !defined OVERWORLD
    if (premult > 0.5) {
        if (albedo.a < 0.51) discard;
    }
    #endif

    gl_FragData[0] = clamp(albedo0, vec4(0.0), vec4(1.0));

    #if defined COLORED_SHADOWS && defined OVERWORLD
        vec4 albedoCS = albedo;
        albedoCS.rgb *= 1.0 - albedo.a * albedo.a;

        #if defined PROJECTED_CAUSTICS && defined OVERWORLD
            if (ice > 0.5) albedoCS = (albedo * albedo) * (albedo * albedo);
        #else
            if (ice > 0.5) albedoCS = vec4(0.0, 0.0, 0.0, 1.0);
        #endif

        gl_FragData[1] = clamp(albedoCS, vec4(0.0), vec4(1.0));
    #endif
}

#endif
```

**Key Techniques:**

1. **Material-Based Rendering:**
   - Water gets special caustics treatment
   - Ice blocks handled separately
   - Foliage can be excluded entirely

2. **Caustics Generation:**
   - Fractal Brownian Motion (FBM) with 8 noise octaves
   - Lacunarity = 1.5 (frequency increase per octave)
   - Persistence = 0.6 (amplitude decrease per octave)
   - Temporal animation via frametime

3. **Colored Shadow Storage:**
   - Two output buffers for complex shadows
   - Pre-multiplied alpha for translucent blocks
   - Ice blocks squared twice for intensity

---

## SECTION 2: SHADOW SAMPLING FUNCTIONS

### 2.1 Complementary V4 - Shadow Sampling Library
**Source:** Complementary Shaders V4 `lib/lighting/shadows.glsl`
**Complexity:** Intermediate-Advanced
**Key Functions:** Lines 1-98

```glsl
uniform sampler2DShadow shadowtex0;

#if defined COLORED_SHADOWS && defined OVERWORLD
uniform sampler2D shadowcolor1;
#endif

#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
uniform sampler2D shadowcolor0;
#endif

vec2 shadowoffsets[8] = vec2[8](    vec2( 0.0   , 1.0   ),
                                    vec2( 0.7071, 0.7071),
                                    vec2( 1.0   , 0.0   ),
                                    vec2( 0.7071,-0.7071),
                                    vec2( 0.0   ,-1.0   ),
                                    vec2(-0.7071,-0.7071),
                                    vec2(-1.0   , 0.0   ),
                                    vec2(-0.7071, 0.7071));

vec2 offsetDist(float x, float s) {
    float n = fract(x * 1.414) * 3.1415;
    return vec2(cos(n), sin(n)) * 1.4 * x / s;
}

// BASIC SHADOW SAMPLING
vec3 SampleBasicShadow(vec3 shadowPos, inout float water) {
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    #if (defined COLORED_SHADOWS || (defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && !defined GBUFFERS_WATER)) && defined OVERWORLD
        vec3 shadowcol = vec3(0.0);
        if (shadow0 < 1.0) {
            float shadow1 = shadow2D(shadowtex1, vec3(shadowPos.st, shadowPos.z)).x;
            if (shadow1 > 0.9999) {
                #if defined COLORED_SHADOWS && defined OVERWORLD
                    shadowcol = texture2D(shadowcolor1, shadowPos.st).rgb * shadow1;
                #endif
                #if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
                    water = texture2D(shadowcolor0, shadowPos.st).r * shadow1;
                #endif
            }
        }

        return shadowcol * (1.0 - shadow0) + shadow0;
    #else
        return vec3(shadow0);
    #endif
}

// POISSON DISK FILTERED SHADOW
vec3 SampleFilteredShadow(vec3 shadowPos, float offset, inout float water) {
    vec3 shadow = SampleBasicShadow(vec3(shadowPos.st, shadowPos.z), water) * 2.0;

    for(int i = 0; i < 8; i++) {
        shadow += SampleBasicShadow(vec3(offset * 1.2 * shadowoffsets[i] + shadowPos.st, shadowPos.z), water);
    }

    return shadow * 0.1;  // 1.0 / (2.0 + 8.0) = 0.1
}

// TEMPORAL ANTI-ALIASING AWARE SHADOW FILTER
float InterleavedGradientNoise() {
    float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
    return fract(n + 1.61803398875 * mod(float(frameCounter), 3600.0));
}

vec3 SampleTAAFilteredShadow(vec3 shadowPos, float offset, inout float water, int doSubsurface) {
    float noise = InterleavedGradientNoise();
    vec3 shadow = vec3(0.0);
    offset = offset * (2.0 - 0.5 * (0.85 + 0.25 * (3072.0 / shadowMapResolution)));
    if (shadowMapResolution < 400.0) offset *= 30.0;

    #if SHADOW_SUBSURFACE < 3
        int sampleCount = 2;
    #else
        int sampleCount = 2 + doSubsurface;
    #endif

    for(int i = 0; i < sampleCount; i++) {
        vec2 offset = offsetDist(noise + i, sampleCount) * offset;
        shadow += SampleBasicShadow(vec3(shadowPos.st + offset, shadowPos.z), water);
        shadow += SampleBasicShadow(vec3(shadowPos.st - offset, shadowPos.z), water);
    }

    shadow /= sampleCount * 2;

    return shadow;
}

// MAIN SHADOW RETRIEVAL
vec3 GetShadow(vec3 shadowPos, float offset, inout float water, int doSubsurface) {
    #ifdef SHADOW_FILTER
        #if AA > 1
            vec3 shadow = SampleTAAFilteredShadow(shadowPos, offset, water, doSubsurface);
        #else
            vec3 shadow = SampleFilteredShadow(shadowPos, offset, water);
        #endif
    #else
       vec3 shadow = SampleBasicShadow(shadowPos, water);
    #endif

    return shadow;
}
```

**Key Concepts:**

1. **Poisson Disk Pattern:**
   - 8-tap circular distribution
   - Better visual quality than grid-based sampling
   - Reduces shadow banding artifacts

2. **Temporal Noise:**
   - Interleaved gradient noise for frame-to-frame variation
   - Enables TAA (Temporal Anti-Aliasing) to converge shadows smoothly
   - Formula: `52.9829189 * fract(0.06711056 * x + 0.00583715 * y)`

3. **Adaptive Sampling:**
   - Offset scaled based on shadow map resolution
   - Lower resolutions get more aggressive filtering
   - Subsurface scattering increases sample count

---

### 2.2 Shadow Tutorial - Simple Shadow Check
**Source:** Shadow Tutorial `gbuffers_terrain.fsh`
**Complexity:** Beginner
**Key Function:** Lines 29-61

```glsl
void main() {
    vec4 color = texture2D(texture, texcoord) * glcolor;
    vec2 lm = lmcoord;

    if (shadowPos.w > 0.0) {
        //surface is facing towards shadowLightPosition
        #if COLORED_SHADOWS == 0
            //for normal shadows, only consider the closest thing to the sun,
            //regardless of whether or not it's opaque.
            if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
        #else
            //for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
            if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
        #endif
            //surface is in shadows. reduce light level.
            lm.y *= SHADOW_BRIGHTNESS;
        }
        else {
            //surface is in direct sunlight. increase light level.
            lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
            #if COLORED_SHADOWS == 1
                //when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
                //perform a 2nd check to see if there's anything translucent between us and the sun.
                if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
                    //surface has translucent object between it and the sun. modify its color.
                    //if the block light is high, modify the color less.
                    vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
                    //make colors more intense when the shadow light color is more opaque.
                    shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
                    //also make colors less intense when the block light level is high.
                    shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);
                    //apply the color.
                    color.rgb *= shadowLightColor.rgb;
                }
            #endif
        }
    }

    color *= texture2D(lightmap, lm);

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = color; //gcolor
}
```

**Learning Points:**

1. **Simple Depth Test:**
   ```glsl
   if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
       // In shadow
   }
   ```

2. **Shadow Brightness Control:**
   - Configurable `SHADOW_BRIGHTNESS` constant
   - Multiplied directly into lightmap y-channel

3. **Colored Shadow Logic:**
   - Two-layer check: opaque then translucent
   - Color mixing based on shadow color opacity
   - Block light reduces colored shadow intensity

---

## SECTION 3: NORMAL ENCODING/DECODING

### 3.1 Complementary V4 - Spheremap Normal Encoding
**Source:** Complementary Shaders V4 `lib/util/encode.glsl`
**Complexity:** Beginner
**Reference:** Aras Pranckevicius - Compact Normal Storage

```glsl
//Spheremap Transform from https://aras-p.info/texts/CompactNormalStorage.html
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

**How It Works:**

1. **Encoding:**
   - Projects 3D normal onto 2D plane
   - Uses z-component to scale (sphere "latitude")
   - Packs into vec2 (8 bytes vs 12 for vec3)

2. **Decoding:**
   - Reconstructs sphere coordinate from 2D
   - Recovers z via Pythagorean theorem
   - Restores normalized 3D normal

3. **Precision:**
   - Stores as 16-bit or 32-bit floats
   - Excellent for G-Buffer compression
   - Minimal visual quality loss

---

## SECTION 4: PHOTON - MODERN IMPLEMENTATION

### 4.1 Photon - Shadow Vertex Shader
**Source:** Photon Shaders `program/shadow.vsh`
**Complexity:** Advanced
**Lines:** 127

```glsl
/*
--------------------------------------------------------------------------------
  Photon Shader by SixthSurge
  program/shadow:
  Render shadow map
--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out uint material_mask;
flat out vec3 tint;

#ifdef WATER_CAUSTICS
out vec3 scene_pos;
#endif

// Attributes
attribute vec3 at_midBlock;
attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// Uniforms
uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;

uniform vec2 taa_offset;
uniform vec3 light_dir;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;
uniform float biome_temperature;
uniform float biome_humidity;

#ifdef COLORED_LIGHTS
writeonly uniform uimage3D voxel_img;

uniform int renderStage;
#endif

// Includes
#include "/include/lighting/shadows/distortion.glsl"
#include "/include/vertex/displacement.glsl"

#ifdef COLORED_LIGHTS
#include "/include/lighting/lpv/voxelization.glsl"
#endif

void main() {
    uv = gl_MultiTexCoord0.xy;
    material_mask = uint(mc_Entity.x - 10000.0);
    tint = gl_Color.rgb;

#if defined COLORED_LIGHTS && !defined PROGRAM_SHADOW_ENTITIES
    update_voxel_map(material_mask);
#endif

#if defined WORLD_NETHER
    // No shadows, discard vertices now
    gl_Position = vec4(-1.0);
    return;
#endif

    bool is_top_vertex = uv.y < mc_midTexCoord.y;

    vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#if !defined PROGRAM_SHADOW_ENTITIES
    // Animations
    pos = transform(shadowModelViewInverse, pos);
    pos = pos + cameraPosition;
    pos = animate_vertex(
        pos,
        is_top_vertex,
        clamp01(rcp(240.0) * gl_MultiTexCoord1.y),
        material_mask
    );
    pos = pos - cameraPosition;

#ifdef WATER_CAUSTICS
    scene_pos = pos;
#endif

    pos = transform(shadowModelView, pos);
#endif

    vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, pos);
    shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

    gl_Position = vec4(shadow_clip_pos, 1.0);
}
```

**Modern GLSL 400 Features:**

1. **Helper Functions:**
   - `transform()` - Matrix multiplication helper
   - `animate_vertex()` - Modular animation system
   - `project_ortho()` - Orthographic projection
   - `distort_shadow_space()` - Custom distortion

2. **Voxelization Support:**
   - Optional colored lighting voxel updates
   - Uses `writeonly uimage3D` for atomic operations

3. **Material Classification:**
   - `material_mask` encodes block type
   - Selective rendering based on world type (WORLD_NETHER)

---

### 4.2 Photon - Shadow Fragment Shader (Water Caustics)
**Source:** Photon Shaders `program/shadow.fsh` (Lines 1-146)
**Complexity:** Advanced
**Physics-Based:** Yes

```glsl
// WATER PHYSICS CONSTANTS
const float air_n = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333; // for 20°C

const vec3 water_absorption_coeff =
    vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) *
    rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff =
    water_absorption_coeff + water_scattering_coeff;

const float distance_through_water = 5.0; // m

// Safe Refraction (avoids Intel NaN issues)
vec3 refract_safe(vec3 I, vec3 N, float eta) {
    float NoI = dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) {
        return vec3(0.0);
    } else {
        return eta * I - (eta * NoI + sqrt(k)) * N;
    }
}

// BIOME-DEPENDENT WATER ABSORPTION
vec3 biome_water_coeff(vec3 biome_water_color) {
    const float density_scale = 0.15;
    const float biome_color_contribution = 0.33;

    const vec3 base_absorption_coeff =
        vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) *
        rec709_to_working_color;
    const vec3 forest_absorption_coeff =
        -density_scale * log(vec3(0.1245, 0.1797, 0.7108));

#ifdef BIOME_WATER_COLOR
    vec3 biome_absorption_coeff =
        -density_scale * log(biome_water_color + eps) - forest_absorption_coeff;

    return max0(
        base_absorption_coeff +
        biome_absorption_coeff * biome_color_contribution
    );
#else
    return base_absorption_coeff;
#endif
}

// WATER CAUSTICS WITH JACOBIAN CORRECTION
float get_water_caustics() {
#ifndef WATER_CAUSTICS
    return 1.0;
#else
    // TBN matrix for a face pointing directly upwards
    const mat3 tbn = mat3(-1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0);

    const bool flowing_water = false;
    const vec2 flow_dir = vec2(0.0);

    vec3 world_pos = scene_pos + cameraPosition;

    vec2 coord = -world_pos.xz;
    vec3 normal =
        tbn *
        get_water_normal(
            world_pos,
            tbn[2],
            coord,
            flow_dir,
            1.0,
            flowing_water
        );

    // Apply Snell's law for light refraction
    vec3 old_pos = world_pos;
    vec3 new_pos = world_pos +
        refract_safe(light_dir, normal, air_n / water_n) *
            (distance_through_water * WATER_CAUSTICS_INTENSITY);

    // JACOBIAN CORRECTION: Account for area distortion
    float old_area =
        length_squared(dFdx(old_pos)) * length_squared(dFdy(old_pos));
    float new_area =
        length_squared(dFdx(new_pos)) * length_squared(dFdy(new_pos));

    if (old_area == 0.0 || new_area == 0.0) {
        return 1.0;
    }

    return 0.25 * inversesqrt(old_area / new_area);
#endif
}
```

**Physics Concepts:**

1. **Refractive Index:**
   - Air: 1.000293 (essentially 1.0)
   - Water: 1.333 (bends light ~25% toward normal)

2. **Snell's Law Application:**
   ```glsl
   refracted_direction = refract(incident, normal, eta_in / eta_out)
   // Where eta_in = air_n, eta_out = water_n
   ```

3. **Jacobian Transformation:**
   - Accounts for area stretching/compression
   - Without it: caustics would be dimensionally wrong
   - Uses `dFdx()` and `dFdy()` for partial derivatives

---

## SECTION 5: COMPLETE TERRAIN SHADER

### 5.1 Complementary V4 - Complete Terrain Shader
**Source:** Complementary Shaders V4 `program/gbuffers_terrain.glsl`
**Complexity:** Advanced
**Lines:** 830 (Complete file)

**File Structure:**
```
Line 1-60:    Includes and common setup
Line 61-205:  Fragment shader (FSH) section
    Line 64-168:   Uniforms and variable declarations
    Line 169-204:  Library includes
    Line 206-673:  Main fragment shader program
Line 678-830:  Vertex shader (VSH) section
    Line 680-732:  Uniforms and includes
    Line 734-828:  Main vertex shader program
```

**Key Fragment Shader Features (lines 206-673):**

1. **Albedo Fetching:**
   ```glsl
   vec4 albedo = vec4(0.0);
   if (mipmapDisabling < 0.25) {
       #if defined END && defined COMPATIBILITY_MODE && !defined SEVEN
           albedo.rgb = texture2D(texture, texCoord).rgb;
           albedo.a = texture2DLod(texture, texCoord, 0).a;
       #else
           albedo = texture2D(texture, texCoord);
       #endif
   } else {
       albedo = texture2DLod(texture, texCoord, 0);
   }
   ```

2. **Material Classification:**
   ```glsl
   float material = floor(mat);
   float foliage = float(material == 1.0);
   float leaves  = float(material == 2.0);
   ```

3. **Advanced Material System:**
   ```glsl
   #ifdef COMPBR
       // COMPBR system handles:
       // - Integrated emission from specularity
       // - Luminance-based smoothness calculation
       // - Metalness from color channels
       // - Complex material remapping
   #endif
   ```

4. **G-Buffer Output:**
   ```glsl
   #if defined ADV_MAT && defined REFLECTION_SPECULAR
       /* DRAWBUFFERS:0361 */
       gl_FragData[0] = albedo;
       gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
       gl_FragData[2] = vec4(EncodeNormal(newNormal), 0.0, 1.0);
       gl_FragData[3] = vec4(rawAlbedo, 1.0);
   #endif
   ```

**Key Vertex Shader Features (lines 734-828):**

1. **Position Transformation:**
   ```glsl
   vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
   ```

2. **Waving Animation:**
   ```glsl
   float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
   vec3 wave = WavingBlocks(position.xyz, istopv, lmCoord.y);
   position.xyz += wave;
   ```

3. **Sun Vector Calculation:**
   ```glsl
   const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994),
                                     -sin(sunPathRotation * 0.01745329251994));
   float ang = fract(timeAngleM - 0.25);
   ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
   sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
   ```

---

## SECTION 6: UTILITY FUNCTIONS

### 6.1 Common Helper Functions

**Luminance Calculation:**
```glsl
float GetLuminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}
```

**Quantization Check:**
```glsl
float premult = float(mat > 0.95 && mat < 1.05);
```

**Smoothstep Alternative:**
```glsl
float smoothLighting = clamp(0.25 * fullNdotU + 0.75, 0.5, 1.0);
smoothLighting *= smoothLighting;  // Squared for smoother falloff
```

**Vector Length Squared (Photon):**
```glsl
float length_squared(vec3 v) {
    return dot(v, v);
}
```

**Reciprocal (Photon):**
```glsl
float rcp(float x) {
    return 1.0 / x;
}
```

---

## SECTION 7: CONFIGURATION PATTERNS

### 7.1 Conditional Compilation Examples

**Version-Based Features:**
```glsl
#if MC_VERSION >= 11900
    uniform float darknessLightFactor;
#endif
```

**Quality Settings:**
```glsl
#if AA == 2 || AA == 3
    #include "/lib/util/jitter.glsl"
#endif

#if AA == 4
    #include "/lib/util/jitter2.glsl"
#endif
```

**Feature Toggles:**
```glsl
#ifdef SHADOWS
    vec3 shadow = GetShadow(shadowPos, offset, water, doSubsurface);
#endif

#ifdef WATER_CAUSTICS
    if (isEyeInWater == 1) specularColor *= underwaterColor.rgb * 8.0;
#endif
```

---

**End of Code Snippets Document**

All code in this document is extracted directly from the referenced repositories and provided for educational and reference purposes.
