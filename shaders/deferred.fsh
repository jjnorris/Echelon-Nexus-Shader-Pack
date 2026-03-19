#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

void main() {
    vec4 albedo = texture(colortex0, vTexCoord);

    // Discard transparent
    if (albedo.a < 0.5) discard;

    // SUPER SIMPLE: just multiply by 0.7 for basic ambient
    vec3 lit = albedo.rgb * 0.7;

    gl_FragColor = vec4(lit, 1.0);
}
