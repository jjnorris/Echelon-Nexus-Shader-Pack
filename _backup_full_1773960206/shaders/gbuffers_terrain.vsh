// ===================================================================
// Echelon Nexus - Terrain Vertex Shader (Solid & Cutout)
// ===================================================================
// Purpose: Render terrain blocks with PBR material support
// Output:  G-buffers (colortex0, colortex1, colortex2)
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
in vec4 vaColor;

// ===================================================================
// VERTEX OUTPUT
// ===================================================================

out vec3 vPosition;
out vec3 vNormal;
out vec2 vTexCoord;
out vec2 vTexCoordLight;
out vec4 vColor;
out float vDepth;

// ===================================================================
// MAIN VERTEX SHADER
// ===================================================================

void main() {
    // Interpolate vertex attributes
    vPosition = vaPosition;
    vNormal = vaNormal;
    vTexCoord = vaTexCoord;
    vTexCoordLight = vaTexCoordLight;
    vColor = vaColor;

    // Transform to clip space
    vec4 clipPos = gl_ModelViewProjectionMatrix * vec4(vaPosition, 1.0);
    gl_Position = clipPos;

    // Compute linear depth for deferred pass
    // This is a placeholder; actual linearization happens in fragment shader
    vDepth = gl_Position.z;
}

// ===================================================================
// END OF TERRAIN VERTEX SHADER
// ===================================================================
