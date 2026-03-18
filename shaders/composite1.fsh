// ===================================================================
// Echelon Nexus - Optional Second Composite Pass Fragment Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 colortex0;

void main() {
    // Pass-through for now
    colortex0 = texture(colortex0, vTexCoord);
}
