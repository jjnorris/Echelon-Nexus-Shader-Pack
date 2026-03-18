// ===================================================================
// Echelon Nexus - Final Output Fragment Shader
// ===================================================================
// Purpose: Output to framebuffer with final tonemapping & color grading
// Input:   colortex0 (composited scene)
// Output:  Framebuffer (gl_FragColor)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

void main() {
    // Read final composited color
    vec3 finalColor = texture(colortex0, vTexCoord).rgb;

    // Placeholder: just output the color as-is
    // Full tonemapping & color grading in Phase 11
    gl_FragColor = vec4(finalColor, 1.0);
}
