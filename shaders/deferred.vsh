// ===================================================================
// Echelon Nexus - Deferred Lighting Vertex Shader
// ===================================================================
// Purpose: Full-screen quad for deferred lighting pass
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

out vec2 vTexCoord;

void main() {
    // Standard full-screen quad
    vTexCoord = gl_MultiTexCoord0.xy;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
