// Echelon Nexus - Phase 1: Final output
// Gamma correction and screen output
// Based on Iris pipeline for Minecraft 1.21.11

// Global uniforms (shared between stages)
uniform sampler2D colortex0;

#ifdef VSH

out vec2 uv;

void main() {
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
	uv = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH

in vec2 uv;

void main() {
	vec3 color = texture(colortex0, uv).rgb;

	// Gamma correction (linear to sRGB)
	color = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));

	gl_FragColor = vec4(color, 1.0);
}

#endif
