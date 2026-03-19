// ===================================================================
// Echelon Nexus - Shadow Fragment Shader
// ===================================================================
// Purpose: Output depth for shadow mapping
// Output:  shadowcolor0 (RGBA); typically depth in R channel
// ===================================================================

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D tex;  // Block texture for alpha masking

#include "lib/constants.glsl"
#include "lib/functions.glsl"

// ===================================================================
// FRAGMENT INPUT
// ===================================================================

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;

// ===================================================================
// FRAGMENT OUTPUT
// ===================================================================

out vec4 shadowColor;

// ===================================================================
// MAIN FRAGMENT SHADER
// ===================================================================

void main() {
    // Sample alpha from block texture for alpha masking
    float alpha = texture(tex, vTexCoord).a;

    // Discard fully transparent pixels
    if (alpha < 0.5) {
        discard;
    }

    // Output depth (simplified; Iris handles depth via gl_FragDepth if needed)
    // For most cases, the depth is implicit in the rasterized depth buffer
    shadowColor = vec4(1.0);  // Placeholder; actual shadow depth is handled by Iris
}

// ===================================================================
// END OF SHADOW FRAGMENT SHADER
// ===================================================================
