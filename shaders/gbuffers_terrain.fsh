// ===================================================================
// Echelon Nexus - Terrain Fragment Shader (Solid & Cutout)
// ===================================================================
// Purpose: Capture terrain G-buffers (color, material, normals)
// Output:  colortex0 (lit color / albedo)
//          colortex1 (material: roughness, metallic, emissive)
//          colortex2 (normals + depth)
// ===================================================================

#version 330 compatibility

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/material_sampling.glsl"

// ===================================================================
// FRAGMENT INPUT
// ===================================================================

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;
in float vDepth;

// ===================================================================
// FRAGMENT OUTPUT
// ===================================================================

// G-buffer outputs
layout(location = 0) out vec4 colortex0;  // Lit color
layout(location = 1) out vec4 colortex1;  // Material params
layout(location = 2) out vec4 colortex2;  // Normals + depth

// ===================================================================
// MAIN FRAGMENT SHADER
// ===================================================================

void main() {
    // Step 1: Alpha test
    if (!alphaTest(vTexCoord, 0.5)) {
        discard;
    }

    // Step 2: Sample and decode material
    // Use LabPBR format by default (pbrMode=0)
    // Disable parallax for terrain (Phase 7+)
    Material material = sampleMaterialComplete(
        vTexCoord,
        normalize(vNormal),
        vec3(0.0),  // viewDir not available in gbuffers; compute in deferred
        0,          // pbrMode=0 (LabPBR)
        false       // enableParallax=false for terrain
    );

    // Step 3: Blend with vertex color (for grass, leaves, etc.)
    material = blendWithVertexColor(material, vColor);

    // Step 4: Store in G-buffers

    // colortex0: Albedo (will be lit in deferred pass)
    colortex0 = vec4(material.albedo, 1.0);

    // colortex1: Material properties
    // R = roughness, G = metallic, B = emissive, A = reserved
    colortex1 = vec4(
        material.roughness,
        material.metallic,
        material.emissive,
        1.0
    );

    // colortex2: Normal + depth
    // Encode normal using oct-wrap
    vec2 encodedNormal = encodeUnitVector(material.normal);

    // Linearize depth (simplified; accurate linearization in Phase 4)
    float depthNDC = gl_FragCoord.z;
    float depthLinear = linearizeDepth(depthNDC, NEAR_PLANE, FAR_PLANE);
    float depthNormalized = clamp(depthLinear / FAR_PLANE, 0.0, 1.0);

    colortex2 = vec4(
        encodedNormal.x,
        encodedNormal.y,
        depthNormalized,
        1.0
    );
}

// ===================================================================
// END OF TERRAIN FRAGMENT SHADER
// ===================================================================
