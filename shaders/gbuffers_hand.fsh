// ===================================================================
// MINIMAL HAND G-BUFFER (Clean Foundation)
// ===================================================================

#version 330 compatibility
/* RENDERTARGETS: 4,5,6 */

uniform sampler2D tex;
uniform sampler2D specularTex;
uniform sampler2D lightmap;

#include "lib/constants.glsl"
#include "lib/functions.glsl"

in vec3 vPosition;
in vec3 vNormal;
in vec2 vTexCoord;
in vec2 vTexCoordLight;
in vec4 vColor;

layout(location = 0) out vec4 colortex0;  // Albedo
layout(location = 1) out vec4 colortex1;  // Material
layout(location = 2) out vec4 colortex2;  // Normal + depth

void main() {
    // Alpha test (critical for hand - must reject transparent pixels)
    float alpha = texture(tex, vTexCoord).a;
    if (alpha < 0.5) discard;

    // Sample hand texture - THIS IS CRITICAL
    // Hand texture is usually skin-tone colored (peachy/tan), NOT yellow
    vec3 handTexColor = texture(tex, vTexCoord).rgb;

    // Blend with vertex color (applies additional tint if any)
    // This should NOT produce yellow unless the texture or vColor is yellow
    vec3 albedo = handTexColor * vColor.rgb;

    // Normalize normal
    vec3 normal = normalize(vNormal);

    // Hand material: usually matte, non-metallic
    float roughness = 0.8;   // Skin is somewhat rough
    float metallic = 0.0;    // Never metallic
    float emissive = 0.0;    // Never emissive

    // Encode normal (octahedral)
    vec2 encodedNormal = encodeUnitVector(normal);

    // Normalize depth
    float depthNormalized = clamp(gl_FragCoord.z / FAR_PLANE, 0.0, 1.0);

    // Output G-buffers
    colortex0 = vec4(albedo, 1.0);
    colortex1 = vec4(roughness, metallic, emissive, 1.0);
    colortex2 = vec4(encodedNormal, depthNormalized, 1.0);
}
