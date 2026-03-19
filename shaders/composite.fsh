// ===================================================================
// MINIMAL COMPOSITE POST-PROCESSING (Clean Foundation)
// ===================================================================
// Just tone mapping and gamma - no fancy effects

#version 330 compatibility

uniform sampler2D colortex0;  // Lit scene

in vec2 vTexCoord;
layout(location = 0) out vec4 colortex0_out;

// Simple ACES tone mapping
vec3 toneMappingACES(vec3 color) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;

    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
}

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;

    // Tone mapping
    color = toneMappingACES(color);

    // Gamma correction (sRGB)
    color = pow(color, vec3(1.0 / 2.2));

    // Output
    colortex0_out = vec4(color, 1.0);
}
