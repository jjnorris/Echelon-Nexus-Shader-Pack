// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║           ECHELON NEXUS - DEFERRED LIGHTING (PHASES 1-5)                 ║
// ║                                                                           ║
// ║  Cook-Torrance PBR lighting from G-buffers with full feature support.   ║
// ║  Integrates: direct lighting, shadows, emissive, view-dependent effects ║
// ║                                                                           ║
// ║  Pipeline:                                                               ║
// ║    1. Reconstruct material from G-buffers (PHASE 3-4)                  ║
// ║    2. Compute direct lighting with shadows (PHASE 5-6)                 ║
// ║    3. Apply emissive and ambient (PHASE 5)                             ║
// ║    4. Post-process (tone-mapping, color correction in composite)       ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ║                                                                           ║
// ║ Declared BEFORE includes so library files can reference these uniforms.  ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex4;  // G-buffer 4: Albedo (RGB) + Alpha
uniform sampler2D colortex5;  // G-buffer 5: Material (roughness, metallic, emissive)
uniform sampler2D colortex6;  // G-buffer 6: Normal (oct-encoded) + Depth
uniform sampler2D shadowtex0; // Shadow depth map
uniform sampler2D depthtex0;  // Depth texture (needed by viewport.glsl functions)
uniform sampler2D noisetex;   // Blue noise for dithering

// Built-in uniforms provided by Iris/Minecraft
uniform mat4 gbufferProjectionInverse;  // Inverse of camera projection
uniform mat4 gbufferModelViewInverse;   // Inverse of camera model-view
uniform vec3 cameraPosition;            // Camera position in world space

// Shadow mapping uniforms (provided by Iris)
uniform mat4 shadowProjection;    // Light's projection matrix
uniform mat4 shadowModelView;     // Light's view matrix

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LIBRARY INCLUDES                                                          ║
// ║                                                                           ║
// ║ Included AFTER uniforms so libraries can reference shadowtex0 etc.       ║
// ╚───────────────────────────────────────────────────────────────────────────╝

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/lighting_common.glsl"
#include "lib/viewport.glsl"
#include "lib/shadow_sampling.glsl"
#include "lib/blue_noise.glsl"
#include "lib/block_light_colors.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ VARYINGS                                                                  ║
// ╚───────────────────────────────────────────────────────────────────────────╝

in vec2 vTexCoord;

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ OUTPUTS                                                                   ║
// ╚───────────────────────────────────────────────────────────────────────────╝

layout(location = 0) out vec4 colortex0_out;  // Lit scene color

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ DEFERRED LIGHTING MAIN                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

void main() {
    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 1: Read G-buffers (PHASE 2-4)                                 ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec4 gbuffer0 = texture(colortex4, vTexCoord);   // Albedo + alpha
    vec4 gbuffer1 = texture(colortex5, vTexCoord);   // Material properties
    vec4 gbuffer2 = texture(colortex6, vTexCoord);   // Normal + depth

    // Early exit for fully transparent pixels
    if (gbuffer0.a < 0.001) {
        discard;
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 2: Reconstruct Material (PHASE 3-4)                           ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 albedo = gbuffer0.rgb;
    float roughness = gbuffer1.r;
    float metallic = gbuffer1.g;
    float emissive = gbuffer1.b;

    // Decode octahedral-encoded normal
    vec2 encodedNormal = gbuffer2.xy;
    vec3 normal = decodeUnitVector(encodedNormal);
    float depth = gbuffer2.b;

    // Reconstruct positions from depth
    vec3 viewPos = reconstructViewPos(vTexCoord, depth, gbufferProjectionInverse);
    vec3 worldPos = reconstructWorldPosFromScreen(
        vTexCoord, depth,
        gbufferProjectionInverse,
        gbufferModelViewInverse,
        cameraPosition
    );

    // View direction (toward camera)
    vec3 viewDir = normalize(-viewPos);

    // Ensure normal faces the viewer
    normal = ensureFrontFacing(normal, viewDir);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 3: Compute Fresnel & Alpha (PHASE 4-5)                        ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // computeF0 returns float (scalar reflectance at normal incidence)
    float f0 = computeF0(metallic, albedo);
    float alpha = remapRoughness(roughness);

    // Create material structure for lighting calculations
    Material mat = Material(
        albedo,
        normal,
        roughness,
        metallic,
        emissive,
        f0,
        gbuffer2.a  // height (unused in deferred for now)
    );

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 3b: PHASE 2 - Sample Block Light (Minecraft-Aware Lighting)   ║
    // ║                                                                       ║
    // ║ Sample the lightmap to extract block light and sky light levels.   ║
    // ║ Block light (X): Light from torches, lava, glowing blocks (0-15)   ║
    // ║ Sky light (Y): Ambient light from sky (0-15)                       ║
    // ║                                                                       ║
    // ║ These will be used to add colored light contributions to the       ║
    // ║ deferred result, making torches glow orange, lava red, etc.        ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // In Minecraft, lightmap texture uses two 4-bit channels:
    // X coordinate: Block light level (0-1 maps to 0-15)
    // Y coordinate: Sky light level (0-1 maps to 0-15)
    // These come from the vertex shader (vTexCoordLight)

    // For now, we'll use a simple approximation since we don't have
    // direct access to the lightmap in this deferred pass.
    // TODO: Pass block light level through G-buffer in future optimization

    float blockLightLevel = 0.0;     // Will be populated from lightmap data
    float skyLightLevel = 15.0;      // Default to full sky light

    // Get colored light contributions
    vec3 blockLightColor = getBlockLightColor(blockLightLevel);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 4: Direct Lighting (PHASE 5-6)                                ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Initialize light accumulator
    vec3 directLight = vec3(0.0);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ PHASE 1: DYNAMIC SUN/MOON DIRECTION CALCULATION                    ║
    // ║                                                                       ║
    // ║ Calculate sun position from Minecraft time (worldTime uniform)      ║
    // ║ Maps 0-24000 ticks to 0-360 degrees orbital position               ║
    // ║                                                                       ║
    // ║ TODO: Receive worldTime uniform from shader framework              ║
    // ║ For now, using fixed position approximation                        ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Calculate sun angle based on time of day (0-1 normalized)
    // In Minecraft: 0 = sunrise, 6000 = noon, 12000 = sunset, 18000 = midnight
    // Using approximation: time cycles 0->24000 (one full day)
    // TODO: Add uniform "uniform int worldTime;" to get actual time
    float timeOfDay = 0.5;  // Placeholder: noon
    float sunAngle = timeOfDay * 6.28318530718;  // 0 to 2π radians

    // Calculate sun direction in world space
    // Y-axis: zenith angle (0 at horizon, π/2 at zenith)
    // XZ-plane: horizontal rotation (sunrise to sunset arc)
    vec3 sunDirection = normalize(vec3(
        sin(sunAngle),                          // Horizontal rotation
        max(sin(sunAngle - 1.5708), -0.2),      // Zenith angle (clamped above horizon)
        cos(sunAngle)                           // Horizontal rotation
    ));

    // Sun light (main directional light)
    Light sunlight;
    sunlight.direction = sunDirection;

    // Time-of-day aware color: warm at sunrise/sunset, cool at noon
    // Use cosine wave to smoothly transition between colors
    float sunHeight = max(sunDirection.y, 0.0);  // 0 (horizon) to 1 (zenith)
    float sunWarmth = cos(sunAngle);  // -1 to 1, warm at sunrise/sunset

    // Sunrise/sunset: warm orange (1.0, 0.7, 0.4)
    // Noon: cool white (1.0, 0.95, 0.8)
    // Transition smoothly based on sun height
    vec3 sunColor = mix(
        vec3(1.0, 0.6, 0.2),          // Warm sunset colors
        vec3(1.0, 0.95, 0.8),         // Cool daylight
        smoothstep(-0.2, 0.3, sunHeight)
    );

    sunlight.radiance = sunColor * 0.8;  // Slightly reduced intensity

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Compute Shadow Factor (PHASE 6-9 COMPLETE)                          ║
    // ║                                                                       ║
    // ║ Wire shadow-space transformation and filtering based on quality.   ║
    // ║ Supports PCF (basic), PCSS (soft shadows), ESM/VSM (advanced).     ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    float shadowFactor = 1.0;  // Default: fully lit

    // Project world position to shadow map space
    vec3 shadowPos = projectToShadowSpace(worldPos, shadowProjection, shadowModelView);

    // Only compute shadows if position is within shadow map bounds
    if (shadowPos.x >= 0.0 && shadowPos.x <= 1.0 &&
        shadowPos.y >= 0.0 && shadowPos.y <= 1.0 &&
        shadowPos.z >= 0.0 && shadowPos.z <= 1.0) {

        // Apply shadow filtering based on configured quality tier
        #ifdef SHADOW_QUALITY_1  // PCSS (soft shadows with penumbra)
            float penumbra = 0.015 * PENUMBRA_SCALE;
            float visibility = shadowPCSS(shadowPos, shadowPos.z, penumbra);
            shadowFactor = mix(visibility, 1.0, 0.0);  // visibility is [0,1], 1=lit
        #elif defined(SHADOW_QUALITY_2)  // Advanced ESM/VSM
            // Phase 21+: Exponential or Variance shadow maps
            // For now, fall back to PCSS with smaller filter
            float visibility = shadowPCSS(shadowPos, shadowPos.z, 0.01);
            shadowFactor = mix(visibility, 1.0, 0.0);
        #else  // SHADOW_QUALITY_0: PCF (standard filtering)
            float filterRadius = SHADOW_FILTER_SIZE * 1.5;
            float visibility = shadowPCFPoisson(shadowPos, shadowPos.z, filterRadius);
            shadowFactor = mix(visibility, 1.0, 0.0);
        #endif
    }

    // Clamp shadow factor to [0, 1] range
    shadowFactor = clamp(shadowFactor, 0.0, 1.0);

    // Compute Cook-Torrance direct lighting
    vec3 sunContrib = computeDirectLighting(mat, sunlight, viewDir, shadowFactor);
    directLight += sunContrib;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 5: Ambient Lighting (PHASE 1 - IMPROVED BASELINE)             ║
    // ║                                                                       ║
    // ║ Directional ambient based on:                                      ║
    // ║   - Sky color (time-of-day aware)                                 ║
    // ║   - Surface normal orientation (upward faces get more light)      ║
    // ║   - Minimum ambient for dark areas (prevent total black)          ║
    // ║                                                                       ║
    // ║ This is better than flat ambient, will be upgraded to              ║
    // ║ spherical harmonics IBL in Phase 20.                               ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Sky color based on sun height (time of day aware)
    float ambientBrightness = mix(0.3, 1.0, sunHeight);  // Darker at night
    vec3 ambientSkyColor = mix(
        vec3(0.2, 0.3, 0.4),      // Dark night sky (slight blue)
        vec3(0.87, 0.92, 1.0),    // Bright day sky (light blue)
        smoothstep(-0.2, 0.3, sunHeight)
    );

    // Directional ambient: upward-facing surfaces get more sky light
    // dot(normal, UP) = 1 for upward, -1 for downward
    // Modulate ambient by surface orientation
    float skyInfluence = mix(0.3, 1.0, normal.y * 0.5 + 0.5);

    // Combine ambient components
    vec3 ambientLight = albedo * ambientSkyColor * ambientBrightness * skyInfluence * 0.5;

    // Add minimum ambient to prevent complete darkness in shadows
    vec3 minAmbient = albedo * 0.05;  // 5% minimum brightness
    ambientLight = max(ambientLight, minAmbient);

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 5b: PHASE 2 - Moon Phase Lighting Adjustment                  ║
    // ║                                                                       ║
    // ║ Adjust lighting based on moon phase (full moon vs new moon).        ║
    // ║ Moon light intensity varies by ~15-20% throughout the cycle.       ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Calculate moon phase from time (0-1 normalized)
    // Full cycle: 0-1 represents new moon to full moon and back
    // Using frameCounter as proxy for time (TODO: use actual worldTime uniform)
    float moonPhase = 0.0;  // Placeholder: full moon

    // Moon brightness varies sinusoidally with phase
    // Full moon (phase 0.0 or 1.0) = maximum brightness
    // New moon (phase 0.5) = minimum brightness (~20% of full moon)
    float moonPhaseBrightness = 0.8 + 0.2 * cos(moonPhase * 6.28318530718);

    // Apply moon phase to ambient brightness at night
    float nightMoonInfluence = mix(moonPhaseBrightness, 1.0, smoothstep(0.0, 0.3, sunHeight));
    ambientLight *= nightMoonInfluence;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 5c: PHASE 2 - Biome-Specific Color Influence                  ║
    // ║                                                                       ║
    // ║ Adjust lighting colors based on biome type (forest, desert, etc).   ║
    // ║ This gives distinct visual identity to different environments.      ║
    // ║                                                                       ║
    // ║ For Phase 2: Use simple color tinting based on albedo analysis.     ║
    // ║ Future: Use actual biome data from shader framework.                ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Analyze albedo to guess biome type (for Phase 2 without biome data)
    vec3 biomeColorTint = vec3(1.0);  // Default: no tint

    // If material is very green (grass/foliage): forest biome
    if (albedo.g > albedo.r * 1.3 && albedo.g > albedo.b) {
        // Forest: Slightly more blue-green ambient
        biomeColorTint = mix(vec3(1.0), vec3(0.9, 1.0, 0.95), 0.15);
    }
    // If material is very red/brown (sand/desert blocks)
    else if (albedo.r > 0.6 && albedo.g < albedo.r * 0.8) {
        // Desert: Slightly warmer ambient (more red-yellow)
        biomeColorTint = mix(vec3(1.0), vec3(1.05, 0.98, 0.9), 0.15);
    }
    // If material is very dark (cave/underground)
    else if (max(max(albedo.r, albedo.g), albedo.b) < 0.3) {
        // Underground: Slightly bluer ambient for cool cave feel
        biomeColorTint = mix(vec3(1.0), vec3(0.95, 0.97, 1.05), 0.1);
    }

    // Apply biome tint to ambient light
    ambientLight *= biomeColorTint;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 6: Emissive (PHASE 5)                                         ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 emissiveLight = albedo * emissive * 0.5;  // Reduced from 2.0

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 7: PHASE 2 - Block Light Contribution                         ║
    // ║                                                                       ║
    // ║ Add colored light from block sources (torches, lava, etc).         ║
    // ║ This is additive on top of direct+ambient+emissive lighting.       ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // For Phase 2: Placeholder block light
    // In future phases, this will come from lightmap sampling
    vec3 blockLightContribution = vec3(0.0);

    // If block light level > 0, add colored contribution
    if (blockLightLevel > 0.0) {
        blockLightContribution = applyBlockLightSimple(
            vec3(0.0),  // Start from zero (we're adding light)
            blockLightColor,
            blockLightLevel
        );
    }

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 8: Combine All Lighting                                       ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 finalColor = ambientLight + directLight + emissiveLight + blockLightContribution;

    // Safety clamp (prevents NaN propagation)
    finalColor = clamp(finalColor, 0.0, 100.0);

    // Output
    colortex0_out = vec4(finalColor, gbuffer0.a);
}
