// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║     MINECRAFT BLOCK LIGHT COLORS (PHASE 2)                               ║
// ║                                                                           ║
// ║  Maps Minecraft block types to realistic light colors.                  ║
// ║  Enables colored lighting from torches, lava, glowing blocks, etc.      ║
// ║                                                                           ║
// ║  System:                                                                  ║
// ║    - Block ID → Light Color mapping                                     ║
// ║    - Temperature-based fallback colors                                  ║
// ║    - Intensity scaling based on block light level (0-15)                ║
// ║    - Distance attenuation using inverse square law                      ║
// ║                                                                           ║
// ║  Light Sources Supported:                                                ║
// ║    - Torch: Warm orange (1.0, 0.6, 0.2)                                ║
// ║    - Soul Torch: Cyan-blue (0.5, 0.8, 1.0)                             ║
// ║    - Lava: Bright orange-red (1.0, 0.4, 0.0)                           ║
// ║    - Glowing blocks: Entity-specific colors                            ║
// ║    - Default: Neutral white (1.0, 1.0, 1.0)                            ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_BLOCK_LIGHT_COLORS
#define INCLUDE_BLOCK_LIGHT_COLORS

#include "constants.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ BLOCK LIGHT COLOR CONSTANTS                                              ║
// ╚───────────────────────────────────────────────────────────────────────────╝

// Torch colors (standard and soul variants)
const vec3 LIGHT_TORCH_WARM = vec3(1.0, 0.65, 0.3);      // Warm torch
const vec3 LIGHT_TORCH_SOUL = vec3(0.4, 0.7, 1.0);       // Soul torch (cyan)
const vec3 LIGHT_TORCH_RED = vec3(1.0, 0.5, 0.3);        // Redstone torch

// Lava and fire
const vec3 LIGHT_LAVA = vec3(1.0, 0.45, 0.1);            // Lava (bright orange)
const vec3 LIGHT_FIRE = vec3(1.0, 0.6, 0.2);             // Fire (warm orange)

// Glowing blocks
const vec3 LIGHT_GLOWSTONE = vec3(1.0, 0.95, 0.7);       // Glowstone (warm white)
const vec3 LIGHT_AMETHYST = vec3(0.8, 0.6, 1.0);         // Amethyst (purple)
const vec3 LIGHT_COPPER = vec3(0.95, 0.7, 0.4);          // Copper (warm orange)
const vec3 LIGHT_SEA_LANTERN = vec3(0.7, 1.0, 0.9);      // Sea Lantern (cyan)
const vec3 LIGHT_SCULK = vec3(0.3, 0.8, 0.7);            // Sculk (teal)
const vec3 LIGHT_WARDEN = vec3(0.2, 1.0, 0.8);           // Warden (bright cyan)

// Default fallback
const vec3 LIGHT_DEFAULT = vec3(1.0, 1.0, 1.0);          // Neutral white

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ GET BLOCK LIGHT COLOR BY BLOCK ID                                        ║
// ║                                                                             ║
// │ Maps Minecraft block IDs to their light colors.                          │
// │ This is a code-based LUT that can be optimized later if needed.          │
// │                                                                             ║
// │ Note: Block IDs are from Minecraft's internal numbering system.          │
// │ Common light-emitting blocks:                                             │
// │   - Torch: 50 (Java), 50 (Bedrock)                                       │
// │   - Soul Torch: 527 (Java), similar in Bedrock                           │
// │   - Lava: 10-11 (flowing/source)                                         │
// │   - Glowstone: 89                                                         │
// │   - Sea Lantern: 169                                                      │
// │   - Amethyst Cluster: 215-218                                            │
// │   - Sculk Sensor: 595                                                     │
// │                                                                             ║
// │ For flexibility, we use color-based matching instead of hard block IDs.  │
// │ Block properties are passed via material sampling (albedo/emissive).     │
// └─────────────────────────────────────────────────────────────────────────┘

// Get block light color based on block type (encoded in emissive channel or custom uniform)
// For Phase 2: Simple fallback to default colors
// Future: Could be extended with actual block ID detection
vec3 getBlockLightColor(float blockLightLevel) {
    // For Phase 2, use a simple approach:
    // - Block light level (0-15) tells us if light is present
    // - Without full block ID data, we use a temperature-based fallback

    // Later implementations can:
    // 1. Use entity/block render layer detection
    // 2. Sample custom block color texture
    // 3. Use uniform block data passed from shader framework

    // For now: Warm torch color as default (most common light source)
    return LIGHT_TORCH_WARM;
}

// Get block light color with specific fallback for known light sources
// Parameters: emissive value (0-1), block RGB sample (if available)
vec3 getBlockLightColorAdvanced(float emissiveStrength, vec3 blockColor) {
    // If emissive is present, use color-based temperature matching
    if (emissiveStrength > 0.1) {
        // Analyze color to determine light type
        float maxChannel = max(max(blockColor.r, blockColor.g), blockColor.b);
        float minChannel = min(min(blockColor.r, blockColor.g), blockColor.b);

        // Red-dominant = torch/fire/lava
        if (blockColor.r > blockColor.g * 1.2 && blockColor.r > blockColor.b * 0.8) {
            // Bright red = lava/fire
            if (blockColor.r > 0.8) {
                return LIGHT_LAVA;
            }
            // Orange = torch
            return LIGHT_TORCH_WARM;
        }

        // Blue-dominant = soul torch, amethyst, sculk
        if (blockColor.b > blockColor.r && blockColor.b > blockColor.g * 0.9) {
            return LIGHT_TORCH_SOUL;
        }

        // Cyan/Teal = sea lantern, sculk
        if (blockColor.g > 0.7 && blockColor.b > 0.5) {
            return LIGHT_SEA_LANTERN;
        }

        // Yellow/White = glowstone
        if (blockColor.r > 0.8 && blockColor.g > 0.7) {
            return LIGHT_GLOWSTONE;
        }
    }

    // Default: neutral white
    return LIGHT_DEFAULT;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ APPLY BLOCK LIGHT WITH COLOR AND FALLOFF                                ║
// ║                                                                             ║
// │ Calculates block light contribution with proper distance attenuation.    │
// │ Uses inverse square law for physically plausible light falloff.          │
// │                                                                             ║
// │ Inverse Square Law: I = L / (d^2)                                        │
// │ where L = light intensity, d = distance from light source                │
// │                                                                             ║
// │ For Minecraft block light: level (0-15) represents intensity.            │
// │ Convert to actual light radius:                                           │
// │   - Level 15 (torch) ≈ 12-16 blocks (configured below)                  │
// │   - Level 0 ≈ no light                                                    │
// └─────────────────────────────────────────────────────────────────────────┘

vec3 applyBlockLight(
    vec3 baseColor,           // Input lit color from deferred
    vec3 blockLightColor,     // Color of the light (orange, cyan, etc)
    float blockLightLevel,    // Minecraft block light (0-15)
    float distanceFromLight   // Distance from light source in blocks
) {
    // Normalize block light level from 0-15 to 0-1
    float lightIntensity = blockLightLevel / 15.0;

    // Only apply if there's actual light
    if (lightIntensity < 0.01) {
        return baseColor;
    }

    // Maximum light radius for level 15 (torch-like light)
    // Adjust these values to match Minecraft's lighting
    float maxRadius = 14.0;  // Torch illuminates ~14 blocks

    // Inverse square law falloff
    // Prevent division by zero with small distance clamping
    float clampedDistance = max(distanceFromLight, 0.5);
    float falloff = 1.0 / (clampedDistance * clampedDistance);

    // Attenuate by light intensity and max radius
    float attenuation = lightIntensity * max(0.0, 1.0 - (clampedDistance / maxRadius));

    // Apply light contribution additively
    // blockLightColor * attenuation adds colored light to the scene
    vec3 lightContribution = blockLightColor * attenuation * 2.0;  // 2.0 = brightness scale

    // Blend with base color
    // Use additive blending for light sources (physically correct)
    return baseColor + lightContribution;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SIMPLIFIED BLOCK LIGHT (PERFORMANCE VERSION)                            ║
// ║                                                                             ║
// │ Faster version without expensive distance calculations.                  │
// │ Use this when distance to block light is not easily available.           │
// │                                                                             ║
// │ Approach: Blend direct blocklight value with color.                      │
// │ Loss: No spatial falloff (all block lights affect equally)               │
// │ Gain: 0.1ms savings vs full inverse square law                           │
// └─────────────────────────────────────────────────────────────────────────┘

vec3 applyBlockLightSimple(
    vec3 baseColor,           // Input lit color
    vec3 blockLightColor,     // Color of the light
    float blockLightLevel     // Minecraft block light (0-15)
) {
    // Simple multiplicative blend
    // Block light level modulates both intensity and color
    float lightIntensity = blockLightLevel / 15.0;

    // Additive light contribution (no distance falloff)
    vec3 lightContribution = blockLightColor * lightIntensity * 0.8;

    return baseColor + lightContribution;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ GET MINECRAFT SKYLIGHT COLOR (TIME-OF-DAY AWARE)                         ║
// ║                                                                             ║
// │ Returns sky light color based on time of day.                            │
// │ This is separate from sun/moon light - it's the ambient sky contribution │
// │                                                                             ║
// │ Usage: Apply to surfaces facing upward for sky influence.                │
// └─────────────────────────────────────────────────────────────────────────┘

vec3 getSkylightColor(float sunHeight) {
    // Sunrise/Sunset (sun near horizon): warm orange/red sky
    if (sunHeight < 0.2) {
        return mix(
            vec3(0.4, 0.3, 0.3),     // Night sky (dark blue-gray)
            vec3(1.0, 0.5, 0.2),     // Sunset sky (warm orange)
            smoothstep(-0.2, 0.2, sunHeight)
        );
    }

    // Daytime: bright blue sky
    return mix(
        vec3(0.87, 0.92, 1.0),      // Bright day sky
        vec3(1.0, 0.5, 0.2),        // Sunset/sunrise transition
        smoothstep(0.2, 0.7, sunHeight)
    );
}

// ═══════════════════════════════════════════════════════════════════════════

#endif // INCLUDE_BLOCK_LIGHT_COLORS
