// Minimal Phase 1: Render terrain blocks
// Iris + Minecraft 1.21.11

#ifdef VSH

// Vertex attributes (MC 1.17+)
attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;

// Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

// Output
varying vec2 texCoord;
varying vec4 vertexColor;

void main() {
	// Transform to screen space
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));

	// Pass through texture coordinates and vertex color
	texCoord = vaUV0;
	vertexColor = vaColor;
}

#endif

#ifdef FSH

// Sampler
uniform sampler2D texture;

// Input
varying vec2 texCoord;
varying vec4 vertexColor;

/* RENDERTARGETS:0 */

void main() {
	// Sample texture with vertex color tint
	vec4 color = texture2D(texture, texCoord) * vertexColor;

	// Discard fully transparent pixels
	if (color.a < 0.1) discard;

	// Output to G-Buffer
	gl_FragData[0] = color;
}

#endif
