// ===================================================================
// Echelon Nexus - Entities Vertex Shader
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec3 vaPosition;
in vec3 vaNormal;
in vec2 vaTexCoord;
in vec2 vaTexCoordLight;
in vec4 vaColor;

out vec3 vPosition;
out vec3 vNormal;
out vec2 vTexCoord;
out vec2 vTexCoordLight;
out vec4 vColor;
out float vDepth;

void main() {
    vPosition = vaPosition;
    vNormal = vaNormal;
    vTexCoord = vaTexCoord;
    vTexCoordLight = vaTexCoordLight;
    vColor = vaColor;

    vec4 clipPos = gl_ModelViewProjectionMatrix * vec4(vaPosition, 1.0);
    gl_Position = clipPos;
    vDepth = gl_Position.z;
}
