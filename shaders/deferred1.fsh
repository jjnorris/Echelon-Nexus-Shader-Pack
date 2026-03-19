// ===================================================================
// Echelon Nexus - Optional Second Deferred Pass Fragment Shader
// ===================================================================

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS                                                            ║
// ║                                                                           ║
// ║ Read from deferred pass output (stored in colortex buffers)              ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;  // Lit scene color from deferred pass
uniform sampler2D colortex1;  // Material/normal data (for future phases)
uniform sampler2D colortex2;  // Additional data (for future phases)

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0_out;

void main() {
    // Pass-through for now; additional lighting in future phases
    colortex0_out = texture(colortex0, vTexCoord);
}
