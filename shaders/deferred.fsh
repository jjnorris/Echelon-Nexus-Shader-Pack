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

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/lighting_common.glsl"
#include "lib/viewport.glsl"
#include "lib/shadow_sampling.glsl"
#include "lib/blue_noise.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;  // G-buffer 0: Albedo (RGB) + Alpha
uniform sampler2D colortex1;  // G-buffer 1: Material (roughness, metallic, emissive)
uniform sampler2D colortex2;  // G-buffer 2: Normal (oct-encoded) + Depth
uniform sampler2DShadow shadowtex0;  // Shadow map
uniform sampler2D noisetex;   // Blue noise for dithering

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

    vec4 gbuffer0 = texture(colortex0, vTexCoord);   // Albedo + alpha
    vec4 gbuffer1 = texture(colortex1, vTexCoord);   // Material properties
    vec4 gbuffer2 = texture(colortex2, vTexCoord);   // Normal + depth

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

    vec3 f0 = computeF0(metallic, albedo);
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
    // ║ Step 4: Direct Lighting (PHASE 5-6)                                ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    // Initialize light accumulator
    vec3 directLight = vec3(0.0);

    // Sun light (main directional light)
    Light sunlight;
    sunlight.direction = normalize(vec3(0.5, 0.8, 0.2));  // TODO: Get from uniform in Phase 6
    sunlight.radiance = vec3(1.2, 1.15, 1.0) * 1.2;      // Slightly warm daylight

    // Compute shadow factor (PHASE 6: implement proper shadow mapping)
    // For now, use simple distance-based occlusion
    float shadowFactor = 1.0;  // TODO: Call sampleShadowPCF() in Phase 6

    // Compute Cook-Torrance direct lighting
    vec3 sunContrib = computeDirectLighting(mat, sunlight, viewDir, shadowFactor);
    directLight += sunContrib;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 5: Ambient Lighting (PHASE 5, placeholder for Phase 20 IBL)   ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 ambientLight = albedo * 0.15;  // Simple flat ambient
    // TODO Phase 20: Replace with spherical harmonics IBL

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 6: Emissive (PHASE 5)                                         ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 emissiveLight = albedo * emissive * 2.0;

    // ╔─────────────────────────────────────────────────────────────────────╗
    // ║ Step 7: Combine Lighting                                           ║
    // ╚─────────────────────────────────────────────────────────────────────╝

    vec3 finalColor = ambientLight + directLight + emissiveLight;

    // Safety clamp (prevents NaN propagation)
    finalColor = clamp(finalColor, 0.0, 100.0);

    // Output
    colortex0_out = vec4(finalColor, gbuffer0.a);
}
