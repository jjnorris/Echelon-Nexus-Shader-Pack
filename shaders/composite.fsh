// ===================================================================
// Echelon Nexus - Composite Post-Processing Fragment Shader
// ===================================================================
// Purpose: Apply post-effects (SSR, TAA, bloom, fog)
// Input:   colortex0 (lit scene)
// Output:  colortex0 (composited scene with post-effects)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0;

void main() {
    // Read lit scene color
    vec3 sceneColor = texture(colortex0, vTexCoord).rgb;

    // For now, pass-through
    // Full post-processing pipeline in Phase 11
    colortex0 = vec4(sceneColor, 1.0);
}
