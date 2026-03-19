// ===================================================================
// MINIMAL DEFERRED LIGHTING (Clean Foundation)
// ===================================================================
// Simple Cook-Torrance PBR with direct sun lighting and basic ambient

#version 330 compatibility

// ===================================================================
// UNIFORMS
// ===================================================================

uniform sampler2D colortex4;  // G-buffer: Albedo
uniform sampler2D colortex5;  // G-buffer: Material (roughness, metallic, emissive)
uniform sampler2D colortex6;  // G-buffer: Normal + Depth
uniform sampler2D shadowtex0; // Shadow depth
uniform sampler2D depthtex0;  // Depth texture

// Built-in Iris uniforms
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

// Shadow uniforms
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

// Time-based uniforms
uniform int frameCounter;

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"
#include "lib/lighting_common.glsl"
#include "lib/viewport.glsl"

// ===================================================================
// VARYINGS & OUTPUTS
// ===================================================================

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

// ===================================================================
// MAIN DEFERRED LIGHTING
// ===================================================================

void main() {
    // Step 1: Read G-buffers
    vec4 gbuffer0 = texture(colortex4, vTexCoord);   // Albedo + alpha
    vec4 gbuffer1 = texture(colortex5, vTexCoord);   // Material properties
    vec4 gbuffer2 = texture(colortex6, vTexCoord);   // Normal + depth

    // Early discard for transparent pixels
    if (gbuffer0.a < 0.5) discard;

    // Step 2: Unpack material
    vec3 albedo = gbuffer0.rgb;
    float roughness = gbuffer1.r;
    float metallic = gbuffer1.g;
    float emissive = gbuffer1.b;

    // Step 3: Unpack normal and depth
    vec2 encodedNormal = gbuffer2.xy;
    vec3 normal = decodeUnitVector(encodedNormal);
    float depth = gbuffer2.z;

    // Step 4: Reconstruct position
    vec3 viewPos = reconstructViewPos(vTexCoord, depth, gbufferProjectionInverse);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 viewDir = normalize(cameraPosition - worldPos);

    // Step 5: MINIMAL LIGHTING
    // Direct sunlight (simple, no shadows for now)
    vec3 sunDirection = normalize(vec3(sin(frameCounter * 0.001), 0.5, cos(frameCounter * 0.001)));
    float sunDot = max(dot(normal, sunDirection), 0.0);
    vec3 directLight = albedo * sunDot * vec3(1.0, 0.95, 0.9) * 1.0;

    // Ambient (simple, flat)
    vec3 ambientLight = albedo * vec3(0.2, 0.25, 0.3) * 0.3;

    // Emissive contribution
    vec3 emissiveLight = albedo * emissive * 0.5;

    // Combine
    vec3 finalColor = directLight + ambientLight + emissiveLight;

    // Safety clamp
    finalColor = clamp(finalColor, 0.0, 1.0);

    // Output
    colortex0_out = vec4(finalColor, 1.0);
}
