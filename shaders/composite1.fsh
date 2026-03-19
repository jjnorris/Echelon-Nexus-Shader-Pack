// ===================================================================
// Echelon Nexus - Optional Second Composite Pass Fragment Shader
// ===================================================================

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ║                                                                           ║
// ║ Read from composite pass output (stored in colortex buffers)             ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;  // Composited scene color from composite pass

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0_out;

void main() {
    // Pass-through for now
    colortex0_out = texture(colortex0, vTexCoord);
}
