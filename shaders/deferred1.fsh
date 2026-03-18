// ===================================================================
// Echelon Nexus - Optional Second Deferred Pass Fragment Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0;

void main() {
    // Pass-through for now; additional lighting in future phases
    colortex0 = texture(colortex0, vTexCoord);
}
