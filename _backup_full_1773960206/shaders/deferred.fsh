// ===================================================================
// ULTRA-MINIMAL DEFERRED (Diagnostic)
// ===================================================================
// NO complex includes - just raw G-buffer output for debugging

#version 330 compatibility

uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

void main() {
    // Read G-buffers
    vec4 gbuffer0 = texture(colortex4, vTexCoord);
    vec4 gbuffer1 = texture(colortex5, vTexCoord);
    vec4 gbuffer2 = texture(colortex6, vTexCoord);

    // Discard transparent
    if (gbuffer0.a < 0.5) discard;

    // Test 1: Just output raw albedo
    vec3 albedo = gbuffer0.rgb;

    // Test 2: Simple ambient only (no complex math)
    vec3 final = albedo * 0.5;  // 50% gray

    // Output
    colortex0_out = vec4(final, 1.0);
}
