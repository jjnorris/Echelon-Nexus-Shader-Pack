// Minimal Phase 1: Final output to screen
// Basic gamma correction and output

#ifdef VSH

varying vec2 texCoord;

void main() {
	gl_Position = gl_Vertex;
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif

#ifdef FSH

uniform sampler2D colortex0;

varying vec2 texCoord;

void main() {
	// Read composited result
	vec3 color = texture2D(colortex0, texCoord).rgb;

	// Apply gamma correction (linear to sRGB)
	color = pow(max(color, 0.0), vec3(1.0 / 2.2));

	// Output to screen
	gl_FragColor = vec4(color, 1.0);
}

#endif
