// ===================================================================
// Echelon Nexus - Shadow Vertex Shader
// ===================================================================
// Purpose: Render geometry from light perspective for shadow mapping
// Output:  Depth to shadowcolor0 (implicit, handled by Iris)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"

// ===================================================================
// VERTEX INPUT
// ===================================================================

in vec3 vaPosition;
in vec3 vaNormal;
in vec2 vaTexCoord;
in vec2 vaTexCoordLight;

// ===================================================================
// VERTEX OUTPUT
// ===================================================================

out vec3 vPosition;
out vec3 vNormal;
out vec2 vTexCoord;
out vec2 vTexCoordLight;

// ===================================================================
// MAIN VERTEX SHADER
// ===================================================================

void main() {
    // Pass through vertex data to fragment shader
    vPosition = vaPosition;
    vNormal = vaNormal;
    vTexCoord = vaTexCoord;
    vTexCoordLight = vaTexCoordLight;

    // Transform to clip space
    // Iris handles the shadow projection matrix automatically
    gl_Position = gl_ModelViewProjectionMatrix * vec4(vaPosition, 1.0);
}

// ===================================================================
// END OF SHADOW VERTEX SHADER
// ===================================================================
