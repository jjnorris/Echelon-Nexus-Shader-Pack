// Minimal Phase 1: Simple composite pass
// Reads G-Buffer output and passes through with basic lighting

#ifdef VSH

varying vec2 texCoord;

void main() {
	// Simple full-screen quad
	gl_Position = gl_Vertex;
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif

#ifdef FSH

uniform sampler2D colortex0;

varying vec2 texCoord;

/* RENDERTARGETS:0 */

void main() {
	// Simply read and pass through G-Buffer
	vec3 color = texture2D(colortex0, texCoord).rgb;
	gl_FragData[0] = vec4(color, 1.0);
}

#endif
