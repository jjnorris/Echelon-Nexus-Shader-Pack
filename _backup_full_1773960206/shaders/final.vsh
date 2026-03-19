// ===================================================================
// Echelon Nexus - Final Output Vertex Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

out vec2 vTexCoord;

void main() {
    vTexCoord = gl_MultiTexCoord0.xy;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
